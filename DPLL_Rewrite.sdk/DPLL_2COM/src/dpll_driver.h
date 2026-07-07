#ifndef DPLL_DRIVER_H
#define DPLL_DRIVER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint32_t (*dpll_mmio_read_fn)(void *context, uint32_t address);
typedef void (*dpll_mmio_write_fn)(void *context, uint32_t address, uint32_t value);
typedef void (*dpll_delay_us_fn)(void *context, uint32_t delay_us);

typedef struct {
    dpll_mmio_read_fn read32;
    dpll_mmio_write_fn write32;
    dpll_delay_us_fn delay_us;
    void *context;
} dpll_io_t;

typedef struct {
    uint32_t lock_ctrl;
    uint32_t config_apply;
    uint32_t config_rejected_mask;
    uint32_t abi_version;
    uint32_t config_version;
    uint32_t build_id;
    uint32_t git_hash;
    uint32_t shadow_center;
    uint32_t shadow_cic_r;
    uint32_t shadow_cic_shift;
    uint32_t shadow_mul;
    uint32_t shadow_div;
    uint32_t shadow_kp_track;
    uint32_t shadow_ki_track;
    uint32_t shadow_kf_acquire;
    uint32_t shadow_kf_blend;
    uint32_t shadow_kf_track;
    uint32_t shadow_kp_blend;
    uint32_t shadow_ki_blend;
    uint32_t shadow_phase_threshold;
    uint32_t shadow_phase_setpoint;
    uint32_t shadow_freq_threshold;
    uint32_t shadow_mag_enter;
    uint32_t shadow_mag_exit;
    uint32_t shadow_acquire_dwell;
    uint32_t shadow_blend_dwell;
    uint32_t shadow_loss_dwell;
    uint32_t shadow_holdover_timeout;
    uint32_t shadow_measurement_timeout;
    uint32_t shadow_fll_delay;
    uint32_t shadow_warmup_samples;
    uint32_t shadow_post_iir_config;
    uint32_t shadow_post_iir_acq_b0;
    uint32_t shadow_post_iir_acq_b1;
    uint32_t shadow_post_iir_acq_b2;
    uint32_t shadow_post_iir_acq_a1;
    uint32_t shadow_post_iir_acq_a2;
    uint32_t shadow_post_iir_track_b0;
    uint32_t shadow_post_iir_track_b1;
    uint32_t shadow_post_iir_track_b2;
    uint32_t shadow_post_iir_track_a1;
    uint32_t shadow_post_iir_track_a2;
    uint32_t shadow_positive_limit;
    uint32_t shadow_negative_limit;
    uint32_t shadow_manual_offset;
    uint32_t shadow_dac0_offset;
    uint32_t shadow_dac0_amplitude;
    uint32_t shadow_debug_dac_offset;
    uint32_t shadow_debug_dac_gain;
    uint32_t shadow_debug_dac_source;
    uint32_t shadow_debug_dac_format;
    uint32_t active_center;
    uint32_t active_cic;
    uint32_t active_mul_div;
    uint32_t active_kp_track;
    uint32_t active_ki_track;
    uint32_t active_kf_acquire;
    uint32_t active_kf_blend;
    uint32_t active_kf_track;
    uint32_t active_kp_blend;
    uint32_t active_ki_blend;
    uint32_t active_post_iir_config;
    uint32_t active_post_iir_acq_b0;
    uint32_t active_post_iir_acq_b1;
    uint32_t active_post_iir_acq_b2;
    uint32_t active_post_iir_acq_a1;
    uint32_t active_post_iir_acq_a2;
    uint32_t active_post_iir_track_b0;
    uint32_t active_post_iir_track_b1;
    uint32_t active_post_iir_track_b2;
    uint32_t active_post_iir_track_a1;
    uint32_t active_post_iir_track_a2;
    uint32_t applied_abi_version;
    uint32_t active_config_crc;
} dpll_reg_map_t;

typedef struct {
    uint32_t abi_version;
    uint32_t config_version;
    uint32_t build_id;
    uint32_t git_hash;
} dpll_identity_t;

typedef struct {
    uint8_t accepted;
    uint8_t applied_sequence;
    uint8_t error_code;
    uint16_t rejected_field_mask;
    uint16_t active_r;
    uint8_t active_shift;
} dpll_apply_result_t;

typedef struct {
    dpll_io_t io;
    dpll_reg_map_t regs;
    dpll_identity_t expected;
    dpll_identity_t actual;
    uint32_t abi_retry_count;
    uint32_t abi_retry_delay_us;
    uint32_t apply_poll_limit;
    uint32_t abi_attempts;
    uint8_t abi_ready;
} dpll_driver_t;

enum {
    DPLL_DRIVER_OK = 0,
    DPLL_DRIVER_ERR_ABI = -1,
    DPLL_DRIVER_ERR_TIMEOUT = -2,
    DPLL_DRIVER_ERR_REJECTED = -3,
    DPLL_DRIVER_ERR_VERIFY = -4
};

#define DPLL_APPLY_BUSY_MASK        0x00000001U
#define DPLL_APPLY_ERROR_MASK       0x00000002U
#define DPLL_APPLY_ERROR_CODE_MASK  0x000000F0U
#define DPLL_APPLY_ERROR_CODE_SHIFT 4U
#define DPLL_APPLY_SEQ_MASK         0x0000FF00U
#define DPLL_APPLY_SEQ_SHIFT        8U

void dpll_driver_init(dpll_driver_t *driver,
                      const dpll_io_t *io,
                      const dpll_reg_map_t *regs,
                      const dpll_identity_t *expected,
                      uint32_t abi_retry_count,
                      uint32_t abi_retry_delay_us,
                      uint32_t apply_poll_limit);
void dpll_driver_invalidate_abi(dpll_driver_t *driver);
int dpll_driver_check_abi(dpll_driver_t *driver);
int dpll_driver_apply(dpll_driver_t *driver, dpll_apply_result_t *result);
int dpll_driver_set_enable(dpll_driver_t *driver, uint32_t enable);

#ifdef __cplusplus
}
#endif

#endif
