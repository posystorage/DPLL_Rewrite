#include "dpll_driver.h"

#include <string.h>

static uint32_t dpll_read(const dpll_driver_t *driver, uint32_t address)
{
    return driver->io.read32(driver->io.context, address);
}

static void dpll_write(const dpll_driver_t *driver, uint32_t address, uint32_t value)
{
    driver->io.write32(driver->io.context, address, value);
}

static void dpll_write_profile(dpll_driver_t *driver,
                               uint32_t center_word_hi,
                               const dpll_filter_profile_t *profile,
                               const dpll_config_t *previous)
{
    const dpll_filter_profile_t *old = previous == 0 ? 0 : &previous->profile;
#define WRITE_PROFILE_FIELD(field, reg_field) \
    do { if (old == 0 || profile->field != old->field) \
        dpll_write(driver, driver->regs.reg_field, (uint32_t)profile->field); } while (0)
    if (previous == 0 || center_word_hi != previous->center_word_hi)
        dpll_write(driver, driver->regs.center, center_word_hi);
    WRITE_PROFILE_FIELD(cic_r, cic_r);
    WRITE_PROFILE_FIELD(cic_shift, cic_shift);
    WRITE_PROFILE_FIELD(fll_delay_sel, fll_delay);
    WRITE_PROFILE_FIELD(correction_limit_pos_hi, positive_limit);
    WRITE_PROFILE_FIELD(correction_limit_neg_hi, negative_limit);
    WRITE_PROFILE_FIELD(measurement_timeout, measurement_timeout);
    WRITE_PROFILE_FIELD(post_iir_mode, post_iir_config);
    WRITE_PROFILE_FIELD(acquire_b0, post_iir_acq_b0);
    WRITE_PROFILE_FIELD(acquire_b1, post_iir_acq_b1);
    WRITE_PROFILE_FIELD(acquire_b2, post_iir_acq_b2);
    WRITE_PROFILE_FIELD(acquire_a1, post_iir_acq_a1);
    WRITE_PROFILE_FIELD(acquire_a2, post_iir_acq_a2);
    WRITE_PROFILE_FIELD(track_b0, post_iir_track_b0);
    WRITE_PROFILE_FIELD(track_b1, post_iir_track_b1);
    WRITE_PROFILE_FIELD(track_b2, post_iir_track_b2);
    WRITE_PROFILE_FIELD(track_a1, post_iir_track_a1);
    WRITE_PROFILE_FIELD(track_a2, post_iir_track_a2);
    WRITE_PROFILE_FIELD(kp_track, kp_track);
    WRITE_PROFILE_FIELD(ki_track, ki_track);
    WRITE_PROFILE_FIELD(kf_acquire, kf_acquire);
    WRITE_PROFILE_FIELD(kf_blend, kf_blend);
    WRITE_PROFILE_FIELD(kf_track, kf_track);
    WRITE_PROFILE_FIELD(kp_blend, kp_blend);
    WRITE_PROFILE_FIELD(ki_blend, ki_blend);
    WRITE_PROFILE_FIELD(phase_threshold, phase_threshold);
    WRITE_PROFILE_FIELD(phase_setpoint, phase_setpoint);
    WRITE_PROFILE_FIELD(freq_threshold, freq_threshold);
    WRITE_PROFILE_FIELD(magnitude_enter, mag_enter);
    WRITE_PROFILE_FIELD(magnitude_exit, mag_exit);
    WRITE_PROFILE_FIELD(acquire_dwell, acquire_dwell);
    WRITE_PROFILE_FIELD(blend_dwell, blend_dwell);
    WRITE_PROFILE_FIELD(loss_dwell, loss_dwell);
    WRITE_PROFILE_FIELD(warmup_samples, warmup_samples);
    WRITE_PROFILE_FIELD(holdover_timeout, holdover_timeout);
#undef WRITE_PROFILE_FIELD
}

int dpll_validate_config(const dpll_config_t *config,
                         dpll_config_validation_t *validation)
{
    uint32_t errors = DPLL_CONFIG_ERROR_NONE;
    dpll_profile_validation_t profile_validation;

    memset(&profile_validation, 0, sizeof(profile_validation));
    if (config == 0 ||
        dpll_validate_runtime_profile(config->center_word_hi,
                                      config == 0 ? 0 : &config->profile,
                                      &profile_validation) != 0)
        errors |= DPLL_CONFIG_ERROR_PROFILE;
    if (config == 0 || config->mul_factor == 0U || config->div_factor == 0U)
        errors |= DPLL_CONFIG_ERROR_MUL_DIV;
    if (config == 0 || config->dac0_offset < -8192 || config->dac0_offset > 8191 ||
        config->dac0_amplitude < 0)
        errors |= DPLL_CONFIG_ERROR_DAC;

    if (validation != 0) {
        validation->profile = profile_validation;
        validation->errors = errors;
    }
    return errors == DPLL_CONFIG_ERROR_NONE ? DPLL_DRIVER_OK : DPLL_DRIVER_ERR_CONFIG;
}

int dpll_driver_write_config(dpll_driver_t *driver,
                             const dpll_config_t *config,
                             const dpll_config_t *previous,
                             dpll_config_validation_t *validation)
{
    if (driver == 0 || dpll_validate_config(config, validation) != DPLL_DRIVER_OK)
        return DPLL_DRIVER_ERR_CONFIG;
    if (!driver->abi_ready && dpll_driver_check_abi(driver) != DPLL_DRIVER_OK) {
        dpll_write(driver, driver->regs.lock_ctrl, 0U);
        return DPLL_DRIVER_ERR_ABI;
    }

    dpll_write_profile(driver, config->center_word_hi, &config->profile, previous);
#define WRITE_CONFIG_FIELD(field, reg_field) \
    do { if (previous == 0 || config->field != previous->field) \
        dpll_write(driver, driver->regs.reg_field, (uint32_t)config->field); } while (0)
    WRITE_CONFIG_FIELD(mul_factor, mul);
    WRITE_CONFIG_FIELD(div_factor, div);
    WRITE_CONFIG_FIELD(manual_offset, manual_offset);
    WRITE_CONFIG_FIELD(dac0_offset, dac0_offset);
    WRITE_CONFIG_FIELD(dac0_amplitude, dac0_amplitude);
#undef WRITE_CONFIG_FIELD
    return DPLL_DRIVER_OK;
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
                      uint32_t abi_retry_delay_us)
{
    memset(driver, 0, sizeof(*driver));
    driver->io = *io;
    driver->regs = *regs;
    driver->expected = *expected;
    driver->abi_retry_count = abi_retry_count;
    driver->abi_retry_delay_us = abi_retry_delay_us;
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

uint32_t dpll_config_signature(const dpll_config_t *config)
{
    uint32_t words[34];

    if (config == 0) return 0U;
    words[0] = config->center_word_hi;
    words[1] = ((uint32_t)config->profile.fll_delay_sel << 24) |
               ((uint32_t)config->profile.cic_shift << 16) | config->profile.cic_r;
    words[2] = ((uint32_t)config->mul_factor << 16) | config->div_factor;
    words[3] = (uint32_t)config->profile.kp_track;
    words[4] = (uint32_t)config->profile.ki_track;
    words[5] = (uint32_t)config->profile.kf_acquire;
    words[6] = (uint32_t)config->profile.kf_blend;
    words[7] = (uint32_t)config->profile.kf_track;
    words[8] = (uint32_t)config->profile.kp_blend;
    words[9] = (uint32_t)config->profile.ki_blend;
    words[10] = (uint32_t)config->profile.phase_setpoint;
    words[11] = config->profile.phase_threshold;
    words[12] = config->profile.freq_threshold;
    words[13] = config->profile.magnitude_enter;
    words[14] = config->profile.magnitude_exit;
    words[15] = ((uint32_t)config->profile.acquire_dwell << 16) |
                config->profile.blend_dwell;
    words[16] = ((uint32_t)config->profile.loss_dwell << 16) |
                config->profile.warmup_samples;
    words[17] = config->profile.measurement_timeout;
    words[18] = config->profile.holdover_timeout;
    words[19] = (uint32_t)config->profile.correction_limit_pos_hi;
    words[20] = (uint32_t)config->profile.correction_limit_neg_hi;
    words[21] = (uint32_t)config->manual_offset;
    words[22] = ((uint32_t)(uint16_t)config->dac0_offset << 16) |
                (uint16_t)config->dac0_amplitude;
    words[23] = config->profile.post_iir_mode;
    words[24] = (uint32_t)config->profile.acquire_b0;
    words[25] = (uint32_t)config->profile.acquire_b1;
    words[26] = (uint32_t)config->profile.acquire_b2;
    words[27] = (uint32_t)config->profile.acquire_a1;
    words[28] = (uint32_t)config->profile.acquire_a2;
    words[29] = (uint32_t)config->profile.track_b0;
    words[30] = (uint32_t)config->profile.track_b1;
    words[31] = (uint32_t)config->profile.track_b2;
    words[32] = (uint32_t)config->profile.track_a1;
    words[33] = (uint32_t)config->profile.track_a2;
    return dpll_config_crc_words(words, 34U);
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
