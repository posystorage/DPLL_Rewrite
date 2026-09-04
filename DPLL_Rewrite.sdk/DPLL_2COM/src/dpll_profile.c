#include "dpll_profile.h"

#include <limits.h>
#include <string.h>

#define DPLL_DDS_CLOCK_HZ        125000000.0
#define DPLL_IQ_INPUT_RATE_HZ      3125000.0
#define DPLL_PHASE_WORD_SCALE   4294967296.0
#define DPLL_Q30_SCALE           1073741824.0
#define DPLL_PI                     3.14159265358979323846
#define DPLL_SQRT2                  1.41421356237309504880
#define DPLL_IMAGE_GUARD_RATIO      2.2
#define DPLL_CORDIC_HEADROOM_BITS   2U
#define DPLL_DEFAULT_LIMIT_DIVISOR  5U
#define DPLL_MIN_CENTER_HZ          4000.0
#define DPLL_MAX_CENTER_HZ        250000.0
#define DPLL_STANDARD_MIN_HZ        5000.0
#define DPLL_STANDARD_MAX_HZ      200000.0

#define DPLL_VERIFIED_5P5K_WORD  0x0002E233U
#define DPLL_VERIFIED_22K_WORD   0x000B88CAU
#define DPLL_VERIFIED_200K_WORD  0x0068DB8CU
#define DPLL_LOW_BAND_MEAS_TIMEOUT 125000U

typedef struct {
    uint32_t max_center_hz;
    uint32_t acquire_cutoff_hz;
    uint32_t track_cutoff_hz;
    uint32_t measurement_timeout;
} dpll_filter_band_t;

static const dpll_filter_band_t dpll_filter_bands[] = {
    {   8000U,  1200U,  800U, DPLL_LOW_BAND_MEAS_TIMEOUT },
    {  15000U,  2000U, 1200U, 0U },
    {  30000U,  4000U, 8000U, 0U },
    {  60000U,  8000U, 3500U, 0U },
    { 100000U, 12000U, 5000U, 0U },
    { 150000U, 15000U, 7000U, 0U },
    { 200000U, 18000U, 8000U, 0U },
    /* Extended 200-250 kHz band; CIC R is still chosen by image guard. */
    { 250000U, 20000U, 9000U, 0U }
};

/* R <= 16 preserves useful pull-in range with the signed 24-bit Kf path. */
static const uint16_t dpll_cic_candidates[] = { 16U, 15U, 12U, 10U, 8U };

static double dpll_abs_double(double value)
{
    return (value < 0.0) ? -value : value;
}

static int64_t dpll_abs_i64(int64_t value)
{
    return (value < 0) ? -value : value;
}

static double dpll_tan_approx(double value)
{
    double value2 = value * value;
    double value3 = value * value2;
    double value5 = value3 * value2;
    double value7 = value5 * value2;
    double value9 = value7 * value2;

    return value + value3 / 3.0 + (2.0 * value5) / 15.0 +
           (17.0 * value7) / 315.0 + (62.0 * value9) / 2835.0;
}

static int32_t dpll_q30_from_double(double value)
{
    double scaled = value * DPLL_Q30_SCALE;
    scaled += (scaled >= 0.0) ? 0.5 : -0.5;
    if (scaled > (double)INT32_MAX) return INT32_MAX;
    if (scaled < (double)INT32_MIN) return INT32_MIN;
    return (int32_t)scaled;
}

static uint8_t dpll_expected_cic_shift(uint16_t rate_r)
{
    if (rate_r <= 8U) return 4U;
    if (rate_r <= 16U) return 7U;
    if (rate_r <= 31U) return 10U;
    if (rate_r <= 78U) return 13U;
    if (rate_r <= 156U) return 16U;
    return 19U;
}

static uint8_t dpll_select_fll_delay(double sample_rate_hz,
                                     double acquire_cutoff_hz)
{
    if (sample_rate_hz >= 32.0 * acquire_cutoff_hz) return 3U;
    if (sample_rate_hz >= 16.0 * acquire_cutoff_hz) return 2U;
    if (sample_rate_hz >= 8.0 * acquire_cutoff_hz) return 1U;
    return 0U;
}

static double dpll_mirror_alias_hz(double center_hz, double output_rate_hz)
{
    double alias = 2.0 * center_hz;
    uint32_t nearest_multiple = (uint32_t)(alias / output_rate_hz + 0.5);
    alias -= (double)nearest_multiple * output_rate_hz;
    return dpll_abs_double(alias);
}

static int dpll_design_biquad(double cutoff_hz,
                              double sample_rate_hz,
                              int32_t *b0,
                              int32_t *b1,
                              int32_t *b2,
                              int32_t *a1,
                              int32_t *a2)
{
    double k;
    double norm;
    double k2;

    if (cutoff_hz <= 0.0 || cutoff_hz >= 0.4 * sample_rate_hz) return -1;

    k = dpll_tan_approx(DPLL_PI * cutoff_hz / sample_rate_hz);
    k2 = k * k;
    norm = 1.0 / (1.0 + DPLL_SQRT2 * k + k2);
    *b0 = dpll_q30_from_double(k2 * norm);
    *b1 = dpll_q30_from_double(2.0 * k2 * norm);
    *b2 = *b0;
    *a1 = dpll_q30_from_double(2.0 * (k2 - 1.0) * norm);
    *a2 = dpll_q30_from_double((1.0 - DPLL_SQRT2 * k + k2) * norm);
    return 0;
}

static uint8_t dpll_biquad_is_valid(int32_t b0, int32_t b1, int32_t b2,
                                    int32_t a1, int32_t a2)
{
    const int64_t one = 1073741824LL;
    int64_t numerator = (int64_t)b0 + b1 + b2;
    int64_t denominator = one + (int64_t)a1 + a2;
    int64_t dc_error;

    if (b0 < 0 || b1 < 0 || b2 != b0 || dpll_abs_i64((int64_t)b1 - 2LL * b0) > 1LL)
        return 0U;
    if (dpll_abs_i64(a2) >= one || denominator <= 0 ||
        one - (int64_t)a1 + a2 <= 0)
        return 0U;
    dc_error = dpll_abs_i64(numerator - denominator);
    return dc_error <= (denominator / 1000LL + 2LL);
}

static uint8_t dpll_gain_is_signed24(int32_t gain)
{
    return gain >= -8388608 && gain <= 8388607;
}

int dpll_validate_runtime_profile(uint32_t center_word_hi,
                                  const dpll_filter_profile_t *profile,
                                  dpll_profile_validation_t *validation)
{
    uint32_t errors = DPLL_PROFILE_ERROR_NONE;
    uint32_t minimum_measurement_timeout = 0U;
    uint8_t expected_shift = 0U;
    double center_hz = ((double)center_word_hi * DPLL_DDS_CLOCK_HZ) /
                       DPLL_PHASE_WORD_SCALE;

    if (profile == 0) {
        errors = DPLL_PROFILE_ERROR_NULL;
    } else {
        if (center_hz < DPLL_MIN_CENTER_HZ - 0.5 ||
            center_hz > DPLL_MAX_CENTER_HZ + 0.5)
            errors |= DPLL_PROFILE_ERROR_CENTER_RANGE;
        if (profile->cic_r == 0U || profile->cic_r > 0x1FFU) {
            errors |= DPLL_PROFILE_ERROR_CIC;
        } else {
            expected_shift = (uint8_t)(dpll_expected_cic_shift(profile->cic_r) +
                                       DPLL_CORDIC_HEADROOM_BITS);
            if (profile->cic_shift + 1U < expected_shift ||
                profile->cic_shift > expected_shift + 4U)
                errors |= DPLL_PROFILE_ERROR_CIC;
            minimum_measurement_timeout = 2400U * profile->cic_r + 512U;
        }
        if (!dpll_biquad_is_valid(profile->acquire_b0, profile->acquire_b1,
                                  profile->acquire_b2, profile->acquire_a1,
                                  profile->acquire_a2) ||
            !dpll_biquad_is_valid(profile->track_b0, profile->track_b1,
                                  profile->track_b2, profile->track_a1,
                                  profile->track_a2))
            errors |= DPLL_PROFILE_ERROR_IIR_STABILITY;
        if (profile->fll_delay_sel > 3U)
            errors |= DPLL_PROFILE_ERROR_FLL_DELAY;
        if (profile->correction_limit_pos_hi <= 0 ||
            profile->correction_limit_neg_hi >= 0)
            errors |= DPLL_PROFILE_ERROR_LIMIT;
        if (!dpll_gain_is_signed24(profile->kp_track) ||
            !dpll_gain_is_signed24(profile->ki_track) ||
            !dpll_gain_is_signed24(profile->kf_acquire) ||
            !dpll_gain_is_signed24(profile->kf_blend) ||
            !dpll_gain_is_signed24(profile->kf_track) ||
            !dpll_gain_is_signed24(profile->kp_blend) ||
            !dpll_gain_is_signed24(profile->ki_blend))
            errors |= DPLL_PROFILE_ERROR_LOOP_GAIN;
        if (profile->phase_setpoint < -131072 || profile->phase_setpoint > 131071 ||
            profile->phase_threshold > 0x3FFFFU ||
            profile->freq_threshold > 0x3FFFFFU ||
            profile->magnitude_enter > 0xFFFFFU ||
            profile->magnitude_exit > 0xFFFFFU ||
            !((profile->magnitude_enter == 0U && profile->magnitude_exit == 0U) ||
              (profile->magnitude_enter > profile->magnitude_exit)) ||
            profile->acquire_dwell == 0U || profile->blend_dwell == 0U ||
            profile->loss_dwell == 0U || profile->warmup_samples == 0U ||
            profile->holdover_timeout == 0U || profile->holdover_timeout > 0xFFFFFFU ||
            profile->measurement_timeout < minimum_measurement_timeout ||
            profile->measurement_timeout > 0xFFFFFFU || profile->post_iir_mode > 3U)
            errors |= DPLL_PROFILE_ERROR_STATE_CONFIG;
    }

    if (validation != 0) {
        memset(validation, 0, sizeof(*validation));
        validation->errors = errors;
        if (profile != 0) validation->support = profile->support;
    }
    return errors == DPLL_PROFILE_ERROR_NONE ? 0 : DPLL_PROFILE_ERR_VERIFY;
}

static dpll_profile_support_t dpll_support_for_center(uint32_t center_word_hi,
                                                       double center_hz)
{
    if (center_word_hi == DPLL_VERIFIED_5P5K_WORD ||
        center_word_hi == DPLL_VERIFIED_22K_WORD ||
        center_word_hi == DPLL_VERIFIED_200K_WORD)
        return DPLL_PROFILE_SUPPORT_VERIFIED;
    if (center_hz >= DPLL_STANDARD_MIN_HZ - 0.5 &&
        center_hz <= DPLL_STANDARD_MAX_HZ + 0.5)
        return DPLL_PROFILE_SUPPORT_STANDARD;
    return DPLL_PROFILE_SUPPORT_EXTENDED;
}

static void dpll_fill_common_loop_parameters(dpll_filter_profile_t *profile)
{
    profile->kp_track = 6000000;
    profile->ki_track = 180000;
    profile->kf_acquire = 8000000;
    profile->kf_blend = 1500000;
    profile->kf_track = 250000;
    profile->kp_blend = 375000;
    profile->ki_blend = 468800;
    profile->phase_threshold = 5825U;
    profile->phase_setpoint = -65536;
    profile->freq_threshold = 2147U;
    profile->magnitude_enter = 16384U;
    profile->magnitude_exit = 8192U;
    profile->acquire_dwell = 16U;
    profile->blend_dwell = 64U;
    profile->loss_dwell = 64U;
    profile->warmup_samples = 16U;
    profile->holdover_timeout = 1250000U;
    profile->measurement_timeout = 0U;
    profile->post_iir_mode = 3U;
}

int dpll_validate_filter_profile(uint32_t center_word_hi,
                                 const dpll_filter_profile_t *profile,
                                 dpll_profile_validation_t *validation)
{
    const dpll_filter_band_t *expected_band = 0;
    uint32_t errors = DPLL_PROFILE_ERROR_NONE;
    double center_hz = ((double)center_word_hi * DPLL_DDS_CLOCK_HZ) /
                       DPLL_PHASE_WORD_SCALE;
    double sample_rate_hz = 0.0;
    double required_image_hz;
    double expected_alias_hz = 0.0;
    uint32_t expected_center_hz = (uint32_t)(center_hz + 0.5);
    uint32_t delay_l = 0U;
    uint32_t minimum_measurement_timeout = 0U;
    uint32_t index;

    if (profile == 0) {
        if (validation != 0) {
            memset(validation, 0, sizeof(*validation));
            validation->errors = DPLL_PROFILE_ERROR_NULL;
        }
        return DPLL_PROFILE_ERR_VERIFY;
    }
    if (center_hz < DPLL_MIN_CENTER_HZ - 0.5 ||
        center_hz > DPLL_MAX_CENTER_HZ + 0.5)
        errors |= DPLL_PROFILE_ERROR_CENTER_RANGE;
    for (index = 0U; index <
         (uint32_t)(sizeof(dpll_filter_bands) / sizeof(dpll_filter_bands[0]));
         ++index) {
        if (center_hz <= dpll_filter_bands[index].max_center_hz + 0.5) {
            expected_band = &dpll_filter_bands[index];
            break;
        }
    }
    if (expected_band == 0 || profile->center_hz != expected_center_hz ||
        profile->acquire_cutoff_hz != expected_band->acquire_cutoff_hz ||
        profile->track_cutoff_hz != expected_band->track_cutoff_hz ||
        profile->support != dpll_support_for_center(center_word_hi, center_hz))
        errors |= DPLL_PROFILE_ERROR_BAND;
    if (profile->cic_r < 8U || profile->cic_r > 16U ||
        profile->cic_shift != dpll_expected_cic_shift(profile->cic_r) +
                              DPLL_CORDIC_HEADROOM_BITS)
        errors |= DPLL_PROFILE_ERROR_CIC;

    if (profile->cic_r != 0U) {
        sample_rate_hz = DPLL_IQ_INPUT_RATE_HZ / (double)profile->cic_r;
        expected_alias_hz = dpll_mirror_alias_hz(center_hz, sample_rate_hz);
    }
    required_image_hz = DPLL_IMAGE_GUARD_RATIO * profile->acquire_cutoff_hz;
    if (profile->output_rate_hz != (uint32_t)(sample_rate_hz + 0.5) ||
        profile->mirror_alias_hz != (uint32_t)(expected_alias_hz + 0.5) ||
        (double)profile->mirror_alias_hz + 0.5 < required_image_hz ||
        sample_rate_hz < 8.0 * profile->acquire_cutoff_hz)
        errors |= DPLL_PROFILE_ERROR_IMAGE_GUARD;
    if (profile->acquire_cutoff_hz >= 0.4 * sample_rate_hz ||
        profile->track_cutoff_hz >= 0.4 * sample_rate_hz)
        errors |= DPLL_PROFILE_ERROR_IIR_CUTOFF;
    if (!dpll_biquad_is_valid(profile->acquire_b0, profile->acquire_b1,
                              profile->acquire_b2, profile->acquire_a1,
                              profile->acquire_a2) ||
        !dpll_biquad_is_valid(profile->track_b0, profile->track_b1,
                              profile->track_b2, profile->track_a1,
                              profile->track_a2))
        errors |= DPLL_PROFILE_ERROR_IIR_STABILITY;
    if (profile->fll_delay_sel <= 3U) delay_l = 1U << profile->fll_delay_sel;
    if (delay_l == 0U ||
        sample_rate_hz < 4.0 * delay_l * profile->acquire_cutoff_hz)
        errors |= DPLL_PROFILE_ERROR_FLL_DELAY;
    if (profile->correction_limit_pos_hi <= 0 ||
        profile->correction_limit_neg_hi >= 0 ||
        profile->correction_limit_neg_hi != -profile->correction_limit_pos_hi ||
        profile->correction_limit_pos_hi > (int32_t)(center_word_hi / 4U))
        errors |= DPLL_PROFILE_ERROR_LIMIT;
    if (!dpll_gain_is_signed24(profile->kp_track) ||
        !dpll_gain_is_signed24(profile->ki_track) ||
        !dpll_gain_is_signed24(profile->kf_acquire) ||
        !dpll_gain_is_signed24(profile->kf_blend) ||
        !dpll_gain_is_signed24(profile->kf_track) ||
        !dpll_gain_is_signed24(profile->kp_blend) ||
        !dpll_gain_is_signed24(profile->ki_blend))
        errors |= DPLL_PROFILE_ERROR_LOOP_GAIN;
    if (profile->cic_r <= (0x00FFFFFFU - 512U) / 2400U)
        minimum_measurement_timeout = 2400U * profile->cic_r + 512U;
    if (profile->phase_setpoint < -131072 || profile->phase_setpoint > 131071 ||
        profile->phase_threshold > 0x3FFFFU ||
        profile->freq_threshold > 0x3FFFFFU ||
        profile->magnitude_enter > 0xFFFFFU ||
        profile->magnitude_exit > 0xFFFFFU ||
        !((profile->magnitude_enter == 0U && profile->magnitude_exit == 0U) ||
          (profile->magnitude_enter > profile->magnitude_exit)) ||
        profile->acquire_dwell == 0U || profile->blend_dwell == 0U ||
        profile->loss_dwell == 0U || profile->warmup_samples == 0U ||
        profile->holdover_timeout == 0U || profile->holdover_timeout > 0xFFFFFFU ||
        profile->measurement_timeout < minimum_measurement_timeout ||
        profile->measurement_timeout > 0xFFFFFFU || profile->post_iir_mode > 3U)
        errors |= DPLL_PROFILE_ERROR_STATE_CONFIG;

    if (validation != 0) {
        validation->errors = errors;
        validation->support = profile->support;
    }
    return errors == DPLL_PROFILE_ERROR_NONE ? 0 : DPLL_PROFILE_ERR_VERIFY;
}

int dpll_compute_filter_profile_checked(uint32_t center_word_hi,
                                        dpll_filter_profile_t *profile,
                                        dpll_profile_validation_t *validation)
{
    const dpll_filter_band_t *band = 0;
    double center_hz;
    double output_rate_hz = 0.0;
    double mirror_alias_hz = 0.0;
    uint32_t index;
    uint16_t selected_r = 0U;

    if (profile == 0) {
        if (validation != 0) {
            memset(validation, 0, sizeof(*validation));
            validation->errors = DPLL_PROFILE_ERROR_NULL;
        }
        return DPLL_PROFILE_ERR_VERIFY;
    }

    memset(profile, 0, sizeof(*profile));
    if (validation != 0) memset(validation, 0, sizeof(*validation));
    center_hz = ((double)center_word_hi * DPLL_DDS_CLOCK_HZ) /
                DPLL_PHASE_WORD_SCALE;
    if (center_hz < DPLL_MIN_CENTER_HZ - 0.5 ||
        center_hz > DPLL_MAX_CENTER_HZ + 0.5) {
        if (validation != 0) {
            memset(validation, 0, sizeof(*validation));
            validation->errors = DPLL_PROFILE_ERROR_CENTER_RANGE;
        }
        return DPLL_PROFILE_ERR_VERIFY;
    }

    for (index = 0U; index <
         (uint32_t)(sizeof(dpll_filter_bands) / sizeof(dpll_filter_bands[0]));
         ++index) {
        if (center_hz <= (double)dpll_filter_bands[index].max_center_hz + 0.5) {
            band = &dpll_filter_bands[index];
            if (validation != 0) validation->band_index = (uint8_t)index;
            break;
        }
    }
    if (band == 0) return DPLL_PROFILE_ERR_VERIFY;

    for (index = 0U; index <
         (uint32_t)(sizeof(dpll_cic_candidates) / sizeof(dpll_cic_candidates[0]));
         ++index) {
        uint16_t candidate_r = dpll_cic_candidates[index];
        double candidate_rate = DPLL_IQ_INPUT_RATE_HZ / candidate_r;
        double candidate_alias = dpll_mirror_alias_hz(center_hz, candidate_rate);

        if (candidate_alias >= DPLL_IMAGE_GUARD_RATIO * band->acquire_cutoff_hz &&
            candidate_rate >= 8.0 * band->acquire_cutoff_hz) {
            selected_r = candidate_r;
            output_rate_hz = candidate_rate;
            mirror_alias_hz = candidate_alias;
            break;
        }
    }
    if (selected_r == 0U) {
        if (validation != 0) validation->errors = DPLL_PROFILE_ERROR_IMAGE_GUARD;
        return DPLL_PROFILE_ERR_VERIFY;
    }

    profile->center_hz = (uint32_t)(center_hz + 0.5);
    profile->output_rate_hz = (uint32_t)(output_rate_hz + 0.5);
    profile->mirror_alias_hz = (uint32_t)(mirror_alias_hz + 0.5);
    profile->acquire_cutoff_hz = band->acquire_cutoff_hz;
    profile->track_cutoff_hz = band->track_cutoff_hz;
    profile->correction_limit_pos_hi =
        (int32_t)((center_word_hi + DPLL_DEFAULT_LIMIT_DIVISOR / 2U) /
                  DPLL_DEFAULT_LIMIT_DIVISOR);
    profile->correction_limit_neg_hi = -profile->correction_limit_pos_hi;
    profile->cic_r = selected_r;
    profile->cic_shift = (uint8_t)(dpll_expected_cic_shift(selected_r) +
                                   DPLL_CORDIC_HEADROOM_BITS);
    profile->fll_delay_sel = dpll_select_fll_delay(output_rate_hz,
                                                    band->acquire_cutoff_hz);
    profile->support = dpll_support_for_center(center_word_hi, center_hz);
    dpll_fill_common_loop_parameters(profile);
    profile->measurement_timeout = band->measurement_timeout != 0U ?
        band->measurement_timeout : 2400U * selected_r + 512U;

    if (dpll_design_biquad(profile->acquire_cutoff_hz, output_rate_hz,
                           &profile->acquire_b0, &profile->acquire_b1,
                           &profile->acquire_b2, &profile->acquire_a1,
                           &profile->acquire_a2) != 0 ||
        dpll_design_biquad(profile->track_cutoff_hz, output_rate_hz,
                           &profile->track_b0, &profile->track_b1,
                           &profile->track_b2, &profile->track_a1,
                           &profile->track_a2) != 0) {
        if (validation != 0) validation->errors = DPLL_PROFILE_ERROR_IIR_CUTOFF;
        return DPLL_PROFILE_ERR_VERIFY;
    }
    return dpll_validate_filter_profile(center_word_hi, profile, validation);
}

int dpll_compute_filter_profile(uint32_t center_word_hi,
                                dpll_filter_profile_t *profile)
{
    return dpll_compute_filter_profile_checked(center_word_hi, profile, 0);
}
