#include "dpll_driver.h"

#include <string.h>

#define DPLL_DDS_CLOCK_HZ       125000000.0
#define DPLL_IQ_INPUT_RATE_HZ     3125000.0
#define DPLL_PHASE_WORD_SCALE  4294967296.0
#define DPLL_Q30_SCALE          1073741824.0
#define DPLL_PI                    3.14159265358979323846
#define DPLL_SQRT2                 1.41421356237309504880
#define DPLL_IMAGE_GUARD_RATIO     2.2

typedef struct {
    uint32_t max_center_hz;
    uint32_t acquire_cutoff_hz;
    uint32_t track_cutoff_hz;
} dpll_filter_band_t;

static const dpll_filter_band_t dpll_filter_bands[] = {
    {   8000U,  1200U,  800U },
    {  15000U,  2000U, 1200U },
    {  30000U,  4000U, 2000U },
    {  60000U,  8000U, 3500U },
    { 100000U, 12000U, 5000U },
    { 150000U, 15000U, 7000U },
    { 200000U, 18000U, 8000U }
};

/* Keep R <= 16 so the existing 24-bit Kf range can retain useful pull-in
 * bandwidth. Pick the largest usable R to maximize CIC/image rejection. */
static const uint16_t dpll_cic_candidates[] = { 16U, 15U, 12U, 10U, 8U };

static double dpll_abs_double(double value)
{
    return (value < 0.0) ? -value : value;
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
    /* The cross/dot discriminator requires a positive dot product:
     * 2*pi*f_error*L/fs < pi/2, or fs > 4*L*f_error. Select the largest
     * delay that covers the complete acquire band. Candidate-R selection
     * already guarantees enough rate for at least L=2. */
    if (sample_rate_hz >= 32.0 * acquire_cutoff_hz) return 3U; /* L=8 */
    if (sample_rate_hz >= 16.0 * acquire_cutoff_hz) return 2U; /* L=4 */
    if (sample_rate_hz >=  8.0 * acquire_cutoff_hz) return 1U; /* L=2 */
    return 0U;                                                /* L=1 */
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

    if (cutoff_hz <= 0.0 || cutoff_hz >= 0.4 * sample_rate_hz) {
        return DPLL_DRIVER_ERR_VERIFY;
    }

    k = dpll_tan_approx(DPLL_PI * cutoff_hz / sample_rate_hz);
    k2 = k * k;
    norm = 1.0 / (1.0 + DPLL_SQRT2 * k + k2);

    *b0 = dpll_q30_from_double(k2 * norm);
    *b1 = dpll_q30_from_double(2.0 * k2 * norm);
    *b2 = *b0;
    *a1 = dpll_q30_from_double(2.0 * (k2 - 1.0) * norm);
    *a2 = dpll_q30_from_double((1.0 - DPLL_SQRT2 * k + k2) * norm);
    return DPLL_DRIVER_OK;
}

int dpll_compute_filter_profile(uint32_t center_word_hi,
                                dpll_filter_profile_t *profile)
{
    const dpll_filter_band_t *band = 0;
    double center_hz;
    double output_rate_hz = 0.0;
    double mirror_alias_hz = 0.0;
    uint32_t index;
    uint16_t selected_r = 0U;
    int status;

    if (profile == 0) {
        return DPLL_DRIVER_ERR_VERIFY;
    }

    center_hz = ((double)center_word_hi * DPLL_DDS_CLOCK_HZ) /
                DPLL_PHASE_WORD_SCALE;
    /* Allow half-Hz endpoint tolerance for the high-32-bit DDS word
     * quantization used by the register ABI. */
    if (center_hz < 4999.5 || center_hz > 200000.5) {
        return DPLL_DRIVER_ERR_VERIFY;
    }

    for (index = 0U; index <
         (uint32_t)(sizeof(dpll_filter_bands) / sizeof(dpll_filter_bands[0]));
         ++index) {
        if (center_hz <= (double)dpll_filter_bands[index].max_center_hz + 0.5) {
            band = &dpll_filter_bands[index];
            break;
        }
    }
    if (band == 0) {
        return DPLL_DRIVER_ERR_VERIFY;
    }

    for (index = 0U; index <
         (uint32_t)(sizeof(dpll_cic_candidates) / sizeof(dpll_cic_candidates[0]));
         ++index) {
        uint16_t candidate_r = dpll_cic_candidates[index];
        double candidate_rate = DPLL_IQ_INPUT_RATE_HZ / (double)candidate_r;
        double candidate_alias = dpll_mirror_alias_hz(center_hz, candidate_rate);

        /* Two identical second-order Butterworth sections give more than
         * 25 dB attenuation when the image/cutoff ratio is at least 2.2.
         * Also retain at least 8 samples per acquire cutoff period. */
        if (candidate_alias >= DPLL_IMAGE_GUARD_RATIO *
                               (double)band->acquire_cutoff_hz &&
            candidate_rate >= 8.0 * (double)band->acquire_cutoff_hz) {
            selected_r = candidate_r;
            output_rate_hz = candidate_rate;
            mirror_alias_hz = candidate_alias;
            break;
        }
    }
    if (selected_r == 0U) {
        return DPLL_DRIVER_ERR_VERIFY;
    }

    memset(profile, 0, sizeof(*profile));
    profile->center_hz = (uint32_t)(center_hz + 0.5);
    profile->mirror_alias_hz = (uint32_t)(mirror_alias_hz + 0.5);
    profile->acquire_cutoff_hz = band->acquire_cutoff_hz;
    profile->track_cutoff_hz = band->track_cutoff_hz;
    profile->cic_r = selected_r;
    profile->cic_shift = dpll_expected_cic_shift(selected_r);
    profile->fll_delay_sel = dpll_select_fll_delay(
        output_rate_hz, (double)profile->acquire_cutoff_hz);

    status = dpll_design_biquad((double)profile->acquire_cutoff_hz,
                                output_rate_hz,
                                &profile->acquire_b0,
                                &profile->acquire_b1,
                                &profile->acquire_b2,
                                &profile->acquire_a1,
                                &profile->acquire_a2);
    if (status != DPLL_DRIVER_OK) return status;

    return dpll_design_biquad((double)profile->track_cutoff_hz,
                              output_rate_hz,
                              &profile->track_b0,
                              &profile->track_b1,
                              &profile->track_b2,
                              &profile->track_a1,
                              &profile->track_a2);
}

static uint32_t dpll_read(const dpll_driver_t *driver, uint32_t address)
{
    return driver->io.read32(driver->io.context, address);
}

static void dpll_write(const dpll_driver_t *driver, uint32_t address, uint32_t value)
{
    driver->io.write32(driver->io.context, address, value);
}

static uint32_t dpll_sign_extend(uint32_t value, uint32_t sign_bit)
{
    uint32_t mask = (sign_bit >= 31U) ? 0xffffffffU : ((1UL << (sign_bit + 1U)) - 1U);
    value &= mask;
    if ((value & (1UL << sign_bit)) != 0U) {
        value |= ~mask;
    }
    return value;
}

static uint32_t dpll_config_crc_mix(uint32_t crc, uint32_t value)
{
    uint32_t mixed = crc ^ value;
    return ((mixed << 5) | (mixed >> 27)) ^ 0x9E3779B9U;
}

static uint32_t dpll_config_crc_words(const uint32_t *words, uint32_t count)
{
    uint32_t crc = 0x44504C4CU;
    uint32_t index;

    for (index = 0U; index < count; ++index) {
        crc = dpll_config_crc_mix(crc, words[index]);
    }
    return crc;
}

static uint8_t dpll_identity_matches(const dpll_identity_t *actual,
                                     const dpll_identity_t *expected)
{
    return (actual->abi_version == expected->abi_version) &&
           (actual->config_version == expected->config_version) &&
           (actual->build_id == expected->build_id) &&
           (actual->git_hash == expected->git_hash);
}

void dpll_driver_init(dpll_driver_t *driver,
                      const dpll_io_t *io,
                      const dpll_reg_map_t *regs,
                      const dpll_identity_t *expected,
                      uint32_t abi_retry_count,
                      uint32_t abi_retry_delay_us,
                      uint32_t apply_poll_limit)
{
    memset(driver, 0, sizeof(*driver));
    driver->io = *io;
    driver->regs = *regs;
    driver->expected = *expected;
    driver->abi_retry_count = abi_retry_count;
    driver->abi_retry_delay_us = abi_retry_delay_us;
    driver->apply_poll_limit = apply_poll_limit;
}

void dpll_driver_invalidate_abi(dpll_driver_t *driver)
{
    driver->abi_ready = 0U;
}

int dpll_driver_check_abi(dpll_driver_t *driver)
{
    uint32_t retry;

    driver->abi_ready = 0U;
    driver->abi_attempts = 0U;
    for (retry = 0U; retry < driver->abi_retry_count; ++retry) {
        driver->abi_attempts = retry + 1U;
        driver->actual.abi_version = dpll_read(driver, driver->regs.abi_version);
        driver->actual.config_version = dpll_read(driver, driver->regs.config_version);
        driver->actual.build_id = dpll_read(driver, driver->regs.build_id);
        driver->actual.git_hash = dpll_read(driver, driver->regs.git_hash);
        if (dpll_identity_matches(&driver->actual, &driver->expected)) {
            driver->abi_ready = 1U;
            return DPLL_DRIVER_OK;
        }
        if ((retry + 1U) < driver->abi_retry_count && driver->io.delay_us != 0) {
            driver->io.delay_us(driver->io.context, driver->abi_retry_delay_us);
        }
    }
    return DPLL_DRIVER_ERR_ABI;
}

static void dpll_clear_apply_result(dpll_apply_result_t *result)
{
    memset(result, 0, sizeof(*result));
}

static uint32_t dpll_expected_active_config_crc(const dpll_driver_t *driver)
{
    uint32_t cic_r = dpll_read(driver, driver->regs.shadow_cic_r) & 0x1FFU;
    uint32_t measurement_timeout =
        dpll_read(driver, driver->regs.shadow_measurement_timeout) & 0x00FFFFFFU;
    uint32_t negative_limit = dpll_read(driver, driver->regs.shadow_negative_limit);
    uint32_t words[34];

    if (measurement_timeout == 0U) {
        measurement_timeout = (120U * cic_r) + 256U;
    }
    if (negative_limit == 0U) {
        negative_limit = 0x80000000U;
    }

    words[0] = dpll_read(driver, driver->regs.shadow_center);
    words[1] = ((dpll_read(driver, driver->regs.shadow_fll_delay) & 0x3U) << 15) |
               ((dpll_read(driver, driver->regs.shadow_cic_shift) & 0x3FU) << 9) | cic_r;
    words[2] = ((dpll_read(driver, driver->regs.shadow_mul) & 0xFFFFU) << 16) |
               (dpll_read(driver, driver->regs.shadow_div) & 0xFFFFU);
    words[3] = dpll_sign_extend(dpll_read(driver, driver->regs.shadow_kp_track), 23U);
    words[4] = dpll_sign_extend(dpll_read(driver, driver->regs.shadow_ki_track), 23U);
    words[5] = dpll_sign_extend(dpll_read(driver, driver->regs.shadow_kf_acquire), 23U);
    words[6] = dpll_sign_extend(dpll_read(driver, driver->regs.shadow_kf_blend), 23U);
    words[7] = dpll_sign_extend(dpll_read(driver, driver->regs.shadow_kf_track), 23U);
    words[8] = dpll_sign_extend(dpll_read(driver, driver->regs.shadow_kp_blend), 23U);
    words[9] = dpll_sign_extend(dpll_read(driver, driver->regs.shadow_ki_blend), 23U);
    words[10] = dpll_sign_extend(dpll_read(driver, driver->regs.shadow_phase_setpoint), 17U);
    words[11] = dpll_read(driver, driver->regs.shadow_phase_threshold) & 0x0003FFFFU;
    words[12] = dpll_read(driver, driver->regs.shadow_freq_threshold) & 0x003FFFFFU;
    words[13] = dpll_read(driver, driver->regs.shadow_mag_enter) & 0x000FFFFFU;
    words[14] = dpll_read(driver, driver->regs.shadow_mag_exit) & 0x000FFFFFU;
    words[15] = ((dpll_read(driver, driver->regs.shadow_acquire_dwell) & 0xFFFFU) << 16) |
                (dpll_read(driver, driver->regs.shadow_blend_dwell) & 0xFFFFU);
    words[16] = ((dpll_read(driver, driver->regs.shadow_loss_dwell) & 0xFFFFU) << 16) |
                (dpll_read(driver, driver->regs.shadow_warmup_samples) & 0xFFFFU);
    words[17] = measurement_timeout;
    words[18] = dpll_read(driver, driver->regs.shadow_holdover_timeout) & 0x00FFFFFFU;
    words[19] = dpll_read(driver, driver->regs.shadow_positive_limit);
    words[20] = negative_limit;
    words[21] = dpll_read(driver, driver->regs.shadow_manual_offset);
    words[22] = ((dpll_sign_extend(dpll_read(driver, driver->regs.shadow_dac0_offset), 13U) & 0xFFFFU) << 16) |
                (dpll_sign_extend(dpll_read(driver, driver->regs.shadow_dac0_amplitude), 15U) & 0xFFFFU);
    words[23] = dpll_read(driver, driver->regs.shadow_post_iir_config) & 0x3U;
    words[24] = dpll_read(driver, driver->regs.shadow_post_iir_acq_b0);
    words[25] = dpll_read(driver, driver->regs.shadow_post_iir_acq_b1);
    words[26] = dpll_read(driver, driver->regs.shadow_post_iir_acq_b2);
    words[27] = dpll_read(driver, driver->regs.shadow_post_iir_acq_a1);
    words[28] = dpll_read(driver, driver->regs.shadow_post_iir_acq_a2);
    words[29] = dpll_read(driver, driver->regs.shadow_post_iir_track_b0);
    words[30] = dpll_read(driver, driver->regs.shadow_post_iir_track_b1);
    words[31] = dpll_read(driver, driver->regs.shadow_post_iir_track_b2);
    words[32] = dpll_read(driver, driver->regs.shadow_post_iir_track_a1);
    words[33] = dpll_read(driver, driver->regs.shadow_post_iir_track_a2);
    return dpll_config_crc_words(words, 34U);
}

int dpll_driver_apply(dpll_driver_t *driver, dpll_apply_result_t *result)
{
    uint32_t before;
    uint32_t before_sequence;
    uint32_t expected_sequence;
    uint32_t status = 0U;
    uint32_t sequence = 0U;
    uint32_t poll;
    uint32_t requested_center;
    uint32_t requested_cic;
    uint32_t requested_mul_div;
    uint32_t requested_kp_track;
    uint32_t requested_ki_track;
    uint32_t requested_kf_acquire;
    uint32_t requested_kf_blend;
    uint32_t requested_kf_track;
    uint32_t requested_kp_blend;
    uint32_t requested_ki_blend;
    uint32_t requested_post_iir_config;
    uint32_t requested_post_iir_acq_b0;
    uint32_t requested_post_iir_acq_b1;
    uint32_t requested_post_iir_acq_b2;
    uint32_t requested_post_iir_acq_a1;
    uint32_t requested_post_iir_acq_a2;
    uint32_t requested_post_iir_track_b0;
    uint32_t requested_post_iir_track_b1;
    uint32_t requested_post_iir_track_b2;
    uint32_t requested_post_iir_track_a1;
    uint32_t requested_post_iir_track_a2;
    uint32_t requested_active_config_crc;
    uint32_t active_cic;

    dpll_clear_apply_result(result);
    if (!driver->abi_ready && dpll_driver_check_abi(driver) != DPLL_DRIVER_OK) {
        dpll_write(driver, driver->regs.lock_ctrl, 0U);
        return DPLL_DRIVER_ERR_ABI;
    }

    requested_center = dpll_read(driver, driver->regs.shadow_center);
    requested_cic = ((dpll_read(driver, driver->regs.shadow_cic_shift) & 0x3FU) << 9) |
                    (dpll_read(driver, driver->regs.shadow_cic_r) & 0x1FFU);
    requested_mul_div = ((dpll_read(driver, driver->regs.shadow_mul) & 0xFFFFU) << 16) |
                        (dpll_read(driver, driver->regs.shadow_div) & 0xFFFFU);
    requested_kp_track = dpll_read(driver, driver->regs.shadow_kp_track);
    requested_ki_track = dpll_read(driver, driver->regs.shadow_ki_track);
    requested_kf_acquire = dpll_read(driver, driver->regs.shadow_kf_acquire);
    requested_kf_blend = dpll_read(driver, driver->regs.shadow_kf_blend);
    requested_kf_track = dpll_read(driver, driver->regs.shadow_kf_track);
    requested_kp_blend = dpll_read(driver, driver->regs.shadow_kp_blend);
    requested_ki_blend = dpll_read(driver, driver->regs.shadow_ki_blend);
    requested_post_iir_config = dpll_read(driver, driver->regs.shadow_post_iir_config) & 0x3U;
    requested_post_iir_acq_b0 = dpll_read(driver, driver->regs.shadow_post_iir_acq_b0);
    requested_post_iir_acq_b1 = dpll_read(driver, driver->regs.shadow_post_iir_acq_b1);
    requested_post_iir_acq_b2 = dpll_read(driver, driver->regs.shadow_post_iir_acq_b2);
    requested_post_iir_acq_a1 = dpll_read(driver, driver->regs.shadow_post_iir_acq_a1);
    requested_post_iir_acq_a2 = dpll_read(driver, driver->regs.shadow_post_iir_acq_a2);
    requested_post_iir_track_b0 = dpll_read(driver, driver->regs.shadow_post_iir_track_b0);
    requested_post_iir_track_b1 = dpll_read(driver, driver->regs.shadow_post_iir_track_b1);
    requested_post_iir_track_b2 = dpll_read(driver, driver->regs.shadow_post_iir_track_b2);
    requested_post_iir_track_a1 = dpll_read(driver, driver->regs.shadow_post_iir_track_a1);
    requested_post_iir_track_a2 = dpll_read(driver, driver->regs.shadow_post_iir_track_a2);
    requested_active_config_crc = dpll_expected_active_config_crc(driver);

    before = dpll_read(driver, driver->regs.config_apply);
    before_sequence = (before & DPLL_APPLY_SEQ_MASK) >> DPLL_APPLY_SEQ_SHIFT;
    expected_sequence = (before_sequence + 1U) & 0xFFU;
    dpll_write(driver, driver->regs.config_apply, 1U);

    for (poll = 0U; poll < driver->apply_poll_limit; ++poll) {
        status = dpll_read(driver, driver->regs.config_apply);
        sequence = (status & DPLL_APPLY_SEQ_MASK) >> DPLL_APPLY_SEQ_SHIFT;
        if ((status & DPLL_APPLY_BUSY_MASK) == 0U) {
            if ((status & DPLL_APPLY_ERROR_MASK) != 0U) {
                result->error_code = (uint8_t)((status & DPLL_APPLY_ERROR_CODE_MASK) >>
                                               DPLL_APPLY_ERROR_CODE_SHIFT);
                result->rejected_field_mask =
                    (uint16_t)(dpll_read(driver, driver->regs.config_rejected_mask) & 0xFFFFU);
                return DPLL_DRIVER_ERR_REJECTED;
            }
            if (sequence == expected_sequence) {
                break;
            }
        }
    }
    if (poll == driver->apply_poll_limit) {
        return DPLL_DRIVER_ERR_TIMEOUT;
    }

    active_cic = dpll_read(driver, driver->regs.active_cic);
    result->applied_sequence = (uint8_t)expected_sequence;
    result->active_r = (uint16_t)(active_cic & 0x1FFU);
    result->active_shift = (uint8_t)((active_cic >> 9) & 0x3FU);

    if (dpll_read(driver, driver->regs.active_center) != requested_center ||
        active_cic != requested_cic ||
        dpll_read(driver, driver->regs.active_mul_div) != requested_mul_div ||
        dpll_read(driver, driver->regs.active_kp_track) != requested_kp_track ||
        dpll_read(driver, driver->regs.active_ki_track) != requested_ki_track ||
        dpll_read(driver, driver->regs.active_kf_acquire) != requested_kf_acquire ||
        dpll_read(driver, driver->regs.active_kf_blend) != requested_kf_blend ||
        dpll_read(driver, driver->regs.active_kf_track) != requested_kf_track ||
        dpll_read(driver, driver->regs.active_kp_blend) != requested_kp_blend ||
        dpll_read(driver, driver->regs.active_ki_blend) != requested_ki_blend ||
        dpll_read(driver, driver->regs.active_post_iir_config) != requested_post_iir_config ||
        dpll_read(driver, driver->regs.active_post_iir_acq_b0) != requested_post_iir_acq_b0 ||
        dpll_read(driver, driver->regs.active_post_iir_acq_b1) != requested_post_iir_acq_b1 ||
        dpll_read(driver, driver->regs.active_post_iir_acq_b2) != requested_post_iir_acq_b2 ||
        dpll_read(driver, driver->regs.active_post_iir_acq_a1) != requested_post_iir_acq_a1 ||
        dpll_read(driver, driver->regs.active_post_iir_acq_a2) != requested_post_iir_acq_a2 ||
        dpll_read(driver, driver->regs.active_post_iir_track_b0) != requested_post_iir_track_b0 ||
        dpll_read(driver, driver->regs.active_post_iir_track_b1) != requested_post_iir_track_b1 ||
        dpll_read(driver, driver->regs.active_post_iir_track_b2) != requested_post_iir_track_b2 ||
        dpll_read(driver, driver->regs.active_post_iir_track_a1) != requested_post_iir_track_a1 ||
        dpll_read(driver, driver->regs.active_post_iir_track_a2) != requested_post_iir_track_a2 ||
        dpll_read(driver, driver->regs.applied_abi_version) != driver->expected.abi_version ||
        dpll_read(driver, driver->regs.active_config_crc) != requested_active_config_crc) {
        return DPLL_DRIVER_ERR_VERIFY;
    }

    result->accepted = 1U;
    return DPLL_DRIVER_OK;
}

int dpll_driver_set_enable(dpll_driver_t *driver, uint32_t enable)
{
    if (enable != 0U && !driver->abi_ready &&
        dpll_driver_check_abi(driver) != DPLL_DRIVER_OK) {
        dpll_write(driver, driver->regs.lock_ctrl, 0U);
        return DPLL_DRIVER_ERR_ABI;
    }
    dpll_write(driver, driver->regs.lock_ctrl, enable != 0U ? 1U : 0U);
    return DPLL_DRIVER_OK;
}
