#ifndef DPLL_DRIVER_H
#define DPLL_DRIVER_H

#include <stdint.h>
#include "dpll_profile.h"

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
    uint32_t reconfigure;
    uint32_t abi_version;
    uint32_t config_version;
    uint32_t build_id;
    uint32_t git_hash;
    uint32_t center;
    uint32_t cic_r;
    uint32_t cic_shift;
    uint32_t mul;
    uint32_t div;
    uint32_t kp_track;
    uint32_t ki_track;
    uint32_t kf_acquire;
    uint32_t kf_blend;
    uint32_t kf_track;
    uint32_t kp_blend;
    uint32_t ki_blend;
    uint32_t phase_threshold;
    uint32_t phase_setpoint;
    uint32_t freq_threshold;
    uint32_t mag_enter;
    uint32_t mag_exit;
    uint32_t acquire_dwell;
    uint32_t blend_dwell;
    uint32_t loss_dwell;
    uint32_t holdover_timeout;
    uint32_t measurement_timeout;
    uint32_t fll_delay;
    uint32_t warmup_samples;
    uint32_t post_iir_config;
    uint32_t post_iir_acq_b0;
    uint32_t post_iir_acq_b1;
    uint32_t post_iir_acq_b2;
    uint32_t post_iir_acq_a1;
    uint32_t post_iir_acq_a2;
    uint32_t post_iir_track_b0;
    uint32_t post_iir_track_b1;
    uint32_t post_iir_track_b2;
    uint32_t post_iir_track_a1;
    uint32_t post_iir_track_a2;
    uint32_t positive_limit;
    uint32_t negative_limit;
    uint32_t manual_offset;
    uint32_t dac0_offset;
    uint32_t dac0_amplitude;
} dpll_reg_map_t;

typedef struct {
    uint32_t abi_version;
    uint32_t config_version;
    uint32_t build_id;
    uint32_t git_hash;
} dpll_identity_t;

typedef struct {
    uint32_t center_word_hi;
    dpll_filter_profile_t profile;
    uint16_t mul_factor;
    uint16_t div_factor;
    int32_t manual_offset;
    int16_t dac0_offset;
    int16_t dac0_amplitude;
} dpll_config_t;

typedef struct {
    dpll_profile_validation_t profile;
    uint32_t errors;
} dpll_config_validation_t;

enum {
    DPLL_CONFIG_ERROR_NONE = 0U,
    DPLL_CONFIG_ERROR_PROFILE = 1U << 0,
    DPLL_CONFIG_ERROR_MUL_DIV = 1U << 1,
    DPLL_CONFIG_ERROR_DAC = 1U << 2
};

typedef struct {
    dpll_io_t io;
    dpll_reg_map_t regs;
    dpll_identity_t expected;
    dpll_identity_t actual;
    uint32_t abi_retry_count;
    uint32_t abi_retry_delay_us;
    uint32_t abi_attempts;
    uint8_t abi_ready;
} dpll_driver_t;

enum {
    DPLL_DRIVER_OK = 0,
    DPLL_DRIVER_ERR_ABI = -1,
    DPLL_DRIVER_ERR_CONFIG = -3,
    DPLL_DRIVER_ERR_VERIFY = -4
};

#define DPLL_RECONFIG_CONTROLLER    0x00000001U
#define DPLL_RECONFIG_DETECTOR      0x00000002U

void dpll_driver_init(dpll_driver_t *driver,
                      const dpll_io_t *io,
                      const dpll_reg_map_t *regs,
                      const dpll_identity_t *expected,
                      uint32_t abi_retry_count,
                      uint32_t abi_retry_delay_us);
void dpll_driver_invalidate_abi(dpll_driver_t *driver);
int dpll_driver_check_abi(dpll_driver_t *driver);
int dpll_driver_set_enable(dpll_driver_t *driver, uint32_t enable);
int dpll_validate_config(const dpll_config_t *config,
                         dpll_config_validation_t *validation);
int dpll_driver_write_config(dpll_driver_t *driver,
                             const dpll_config_t *config,
                             const dpll_config_t *previous,
                             dpll_config_validation_t *validation);
uint32_t dpll_config_signature(const dpll_config_t *config);

#ifdef __cplusplus
}
#endif

#endif
