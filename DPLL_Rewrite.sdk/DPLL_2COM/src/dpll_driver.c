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
    uint32_t words[23];

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
    return dpll_config_crc_words(words, 23U);
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
