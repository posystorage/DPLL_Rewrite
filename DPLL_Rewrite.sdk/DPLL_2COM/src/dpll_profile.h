#ifndef DPLL_PROFILE_H
#define DPLL_PROFILE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define DPLL_PROFILE_ERR_VERIFY (-4)

typedef enum {
    DPLL_PROFILE_SUPPORT_EXTENDED = 0,
    DPLL_PROFILE_SUPPORT_STANDARD = 1,
    DPLL_PROFILE_SUPPORT_VERIFIED = 2
} dpll_profile_support_t;

enum {
    DPLL_PROFILE_ERROR_NONE          = 0U,
    DPLL_PROFILE_ERROR_NULL          = 1U << 0,
    DPLL_PROFILE_ERROR_CENTER_RANGE  = 1U << 1,
    DPLL_PROFILE_ERROR_BAND          = 1U << 2,
    DPLL_PROFILE_ERROR_CIC           = 1U << 3,
    DPLL_PROFILE_ERROR_IMAGE_GUARD   = 1U << 4,
    DPLL_PROFILE_ERROR_IIR_CUTOFF    = 1U << 5,
    DPLL_PROFILE_ERROR_IIR_STABILITY = 1U << 6,
    DPLL_PROFILE_ERROR_FLL_DELAY     = 1U << 7,
    DPLL_PROFILE_ERROR_LIMIT         = 1U << 8,
    DPLL_PROFILE_ERROR_LOOP_GAIN     = 1U << 9,
    DPLL_PROFILE_ERROR_STATE_CONFIG  = 1U << 10
};

typedef struct {
    uint32_t errors;
    uint8_t band_index;
    dpll_profile_support_t support;
} dpll_profile_validation_t;

typedef struct {
    uint32_t center_hz;
    uint32_t output_rate_hz;
    uint32_t mirror_alias_hz;
    uint32_t acquire_cutoff_hz;
    uint32_t track_cutoff_hz;
    int32_t correction_limit_pos_hi;
    int32_t correction_limit_neg_hi;
    uint16_t cic_r;
    uint8_t cic_shift;
    uint8_t fll_delay_sel;
    int32_t acquire_b0;
    int32_t acquire_b1;
    int32_t acquire_b2;
    int32_t acquire_a1;
    int32_t acquire_a2;
    int32_t track_b0;
    int32_t track_b1;
    int32_t track_b2;
    int32_t track_a1;
    int32_t track_a2;
    int32_t kp_track;
    int32_t ki_track;
    int32_t kf_acquire;
    int32_t kf_blend;
    int32_t kf_track;
    int32_t kp_blend;
    int32_t ki_blend;
    int32_t phase_setpoint;
    uint32_t phase_threshold;
    uint32_t freq_threshold;
    uint32_t magnitude_enter;
    uint32_t magnitude_exit;
    uint16_t acquire_dwell;
    uint16_t blend_dwell;
    uint16_t loss_dwell;
    uint16_t warmup_samples;
    uint32_t holdover_timeout;
    uint32_t measurement_timeout;
    uint8_t post_iir_mode;
    dpll_profile_support_t support;
} dpll_filter_profile_t;

int dpll_compute_filter_profile(uint32_t center_word_hi,
                                dpll_filter_profile_t *profile);
int dpll_compute_filter_profile_checked(uint32_t center_word_hi,
                                        dpll_filter_profile_t *profile,
                                        dpll_profile_validation_t *validation);
int dpll_validate_filter_profile(uint32_t center_word_hi,
                                 const dpll_filter_profile_t *profile,
                                 dpll_profile_validation_t *validation);

#ifdef __cplusplus
}
#endif

#endif
