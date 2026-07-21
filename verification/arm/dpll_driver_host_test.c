#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "dpll_driver.h"

enum {
    REG_LOCK = 0x00,
    REG_RECONFIGURE = 0x04,
    REG_ABI = 0x08,
    REG_CONFIG = 0x0c,
    REG_BUILD = 0x10,
    REG_GIT = 0x14,
    REG_CENTER = 0x18,
    REG_R = 0x1c,
    REG_SHIFT = 0x20,
    REG_MUL = 0x24,
    REG_DIV = 0x28,
    REG_KP = 0x2c,
    REG_KI = 0x30,
    REG_KFA = 0x34,
    REG_KFB = 0x38,
    REG_KFT = 0x3c,
    REG_KPB = 0x40,
    REG_KIB = 0x44,
    REG_PHASE_THR = 0x48,
    REG_PHASE_SETPOINT = 0x4c,
    REG_FREQ_THR = 0x50,
    REG_MAG_ENTER = 0x54,
    REG_MAG_EXIT = 0x58,
    REG_ACQ_DWELL = 0x5c,
    REG_BLEND_DWELL = 0x60,
    REG_LOSS_DWELL = 0x64,
    REG_HOLDOVER = 0x68,
    REG_MEAS_TIMEOUT = 0x6c,
    REG_FLL_DELAY = 0x70,
    REG_WARMUP = 0x74,
    REG_POS_LIMIT = 0x78,
    REG_NEG_LIMIT = 0x7c,
    REG_MANUAL_OFFSET = 0x80,
    REG_DAC0_OFFSET = 0x84,
    REG_DAC0_AMP = 0x88,
    REG_POST_IIR_CONFIG = 0x8c,
    REG_POST_IIR_ACQ_B0 = 0x90,
    REG_POST_IIR_ACQ_B1 = 0x94,
    REG_POST_IIR_ACQ_B2 = 0x98,
    REG_POST_IIR_ACQ_A1 = 0x9c,
    REG_POST_IIR_ACQ_A2 = 0xa0,
    REG_POST_IIR_TRACK_B0 = 0xa4,
    REG_POST_IIR_TRACK_B1 = 0xa8,
    REG_POST_IIR_TRACK_B2 = 0xac,
    REG_POST_IIR_TRACK_A1 = 0xb0,
    REG_POST_IIR_TRACK_A2 = 0xb4
};

typedef struct {
    uint32_t mem[128];
    uint32_t writes_address[128];
    uint32_t writes_value[128];
    uint32_t write_count;
    uint32_t delay_count;
    uint32_t make_good_after_delays;
} mock_mmio_t;

static const dpll_identity_t expected_identity = {
    0x00000001U, 0x00010001U, 0xd9110002U, 0x91eb683eU
};

static const dpll_reg_map_t regs = {
    .lock_ctrl = REG_LOCK, .reconfigure = REG_RECONFIGURE,
    .abi_version = REG_ABI, .config_version = REG_CONFIG,
    .build_id = REG_BUILD, .git_hash = REG_GIT,
    .center = REG_CENTER, .cic_r = REG_R, .cic_shift = REG_SHIFT,
    .mul = REG_MUL, .div = REG_DIV,
    .kp_track = REG_KP, .ki_track = REG_KI,
    .kf_acquire = REG_KFA, .kf_blend = REG_KFB, .kf_track = REG_KFT,
    .kp_blend = REG_KPB, .ki_blend = REG_KIB,
    .phase_threshold = REG_PHASE_THR, .phase_setpoint = REG_PHASE_SETPOINT,
    .freq_threshold = REG_FREQ_THR, .mag_enter = REG_MAG_ENTER,
    .mag_exit = REG_MAG_EXIT, .acquire_dwell = REG_ACQ_DWELL,
    .blend_dwell = REG_BLEND_DWELL, .loss_dwell = REG_LOSS_DWELL,
    .holdover_timeout = REG_HOLDOVER, .measurement_timeout = REG_MEAS_TIMEOUT,
    .fll_delay = REG_FLL_DELAY, .warmup_samples = REG_WARMUP,
    .positive_limit = REG_POS_LIMIT, .negative_limit = REG_NEG_LIMIT,
    .manual_offset = REG_MANUAL_OFFSET, .dac0_offset = REG_DAC0_OFFSET,
    .dac0_amplitude = REG_DAC0_AMP, .post_iir_config = REG_POST_IIR_CONFIG,
    .post_iir_acq_b0 = REG_POST_IIR_ACQ_B0,
    .post_iir_acq_b1 = REG_POST_IIR_ACQ_B1,
    .post_iir_acq_b2 = REG_POST_IIR_ACQ_B2,
    .post_iir_acq_a1 = REG_POST_IIR_ACQ_A1,
    .post_iir_acq_a2 = REG_POST_IIR_ACQ_A2,
    .post_iir_track_b0 = REG_POST_IIR_TRACK_B0,
    .post_iir_track_b1 = REG_POST_IIR_TRACK_B1,
    .post_iir_track_b2 = REG_POST_IIR_TRACK_B2,
    .post_iir_track_a1 = REG_POST_IIR_TRACK_A1,
    .post_iir_track_a2 = REG_POST_IIR_TRACK_A2
};

#define MEM(mock, address) ((mock)->mem[(address) / 4U])
#define CHECK(condition) do { if (!(condition)) { \
    printf("FAIL:%s:%d: %s\n", __FILE__, __LINE__, #condition); return 1; \
} } while (0)

static void seed_good_identity(mock_mmio_t *mock)
{
    MEM(mock, REG_ABI) = expected_identity.abi_version;
    MEM(mock, REG_CONFIG) = expected_identity.config_version;
    MEM(mock, REG_BUILD) = expected_identity.build_id;
    MEM(mock, REG_GIT) = expected_identity.git_hash;
}

static uint32_t mock_read(void *context, uint32_t address)
{
    return MEM((mock_mmio_t *)context, address);
}

static void mock_write(void *context, uint32_t address, uint32_t value)
{
    mock_mmio_t *mock = (mock_mmio_t *)context;
    mock->writes_address[mock->write_count] = address;
    mock->writes_value[mock->write_count] = value;
    ++mock->write_count;
    MEM(mock, address) = value;
}

static void mock_delay(void *context, uint32_t delay_us)
{
    mock_mmio_t *mock = (mock_mmio_t *)context;
    (void)delay_us;
    ++mock->delay_count;
    if (mock->make_good_after_delays != 0U &&
        mock->delay_count >= mock->make_good_after_delays)
        seed_good_identity(mock);
}

static void init_driver(dpll_driver_t *driver, mock_mmio_t *mock)
{
    dpll_io_t io;
    memset(mock, 0, sizeof(*mock));
    io.read32 = mock_read;
    io.write32 = mock_write;
    io.delay_us = mock_delay;
    io.context = mock;
    dpll_driver_init(driver, &io, &regs, &expected_identity, 4U, 100U);
}

static uint32_t center_word_hi_for_hz(uint32_t frequency_hz)
{
    return (uint32_t)((((uint64_t)frequency_hz << 32) + 62500000ULL) /
                      125000000ULL);
}

static int make_config(dpll_config_t *config, uint32_t frequency_hz)
{
    memset(config, 0, sizeof(*config));
    config->center_word_hi = center_word_hi_for_hz(frequency_hz);
    config->mul_factor = 1U;
    config->div_factor = 1U;
    config->dac0_amplitude = 0x4000;
    return dpll_compute_filter_profile(config->center_word_hi, &config->profile);
}

static int test_abi_retry_and_enable(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    init_driver(&driver, &mock);
    mock.make_good_after_delays = 2U;
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    CHECK(driver.abi_attempts == 3U);
    CHECK(dpll_driver_set_enable(&driver, 1U) == DPLL_DRIVER_OK);
    CHECK(mock.writes_address[mock.write_count - 1U] == REG_LOCK);
    return 0;
}

static int test_abi_mismatch_blocks_writes(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    dpll_config_t config;
    dpll_config_validation_t validation;
    init_driver(&driver, &mock);
    CHECK(make_config(&config, 22000U) == DPLL_DRIVER_OK);
    CHECK(dpll_driver_write_config(&driver, &config, 0, &validation) ==
          DPLL_DRIVER_ERR_ABI);
    CHECK(mock.write_count == 1U);
    CHECK(mock.writes_address[0] == REG_LOCK && mock.writes_value[0] == 0U);
    return 0;
}

static int test_direct_write_and_change_filtering(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    dpll_config_t config;
    dpll_config_t previous;
    dpll_config_validation_t validation;
    uint32_t writes_before;

    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    CHECK(make_config(&config, 22000U) == DPLL_DRIVER_OK);
    CHECK(dpll_driver_write_config(&driver, &config, 0, &validation) == DPLL_DRIVER_OK);
    CHECK(MEM(&mock, REG_CENTER) == config.center_word_hi);
    CHECK(MEM(&mock, REG_R) == config.profile.cic_r);
    CHECK(MEM(&mock, REG_KP) == (uint32_t)config.profile.kp_track);
    CHECK(MEM(&mock, REG_POST_IIR_TRACK_A2) == (uint32_t)config.profile.track_a2);
    CHECK(MEM(&mock, REG_RECONFIGURE) == 0U);

    previous = config;
    config.profile.phase_threshold += 1U;
    writes_before = mock.write_count;
    CHECK(dpll_driver_write_config(&driver, &config, &previous, &validation) == DPLL_DRIVER_OK);
    CHECK(mock.write_count == writes_before + 1U);
    CHECK(mock.writes_address[writes_before] == REG_PHASE_THR);

    previous = config;
    config.profile.kp_track += 1;
    writes_before = mock.write_count;
    CHECK(dpll_driver_write_config(&driver, &config, &previous, &validation) == DPLL_DRIVER_OK);
    CHECK(mock.write_count == writes_before + 1U);
    CHECK(mock.writes_address[writes_before] == REG_KP);
    return 0;
}

static int test_validation_and_profiles(void)
{
    dpll_config_t config;
    dpll_config_validation_t validation;
    dpll_filter_profile_t profile;
    const uint32_t centers[] = {4000U, 5500U, 22000U, 200000U, 250000U};
    uint32_t index;

    CHECK(make_config(&config, 22000U) == DPLL_DRIVER_OK);
    CHECK(dpll_validate_config(&config, &validation) == DPLL_DRIVER_OK);
    config.mul_factor = 0U;
    CHECK(dpll_validate_config(&config, &validation) == DPLL_DRIVER_ERR_CONFIG);
    CHECK((validation.errors & DPLL_CONFIG_ERROR_MUL_DIV) != 0U);

    CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(3999U), &profile) ==
          DPLL_DRIVER_ERR_VERIFY);
    CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(250001U), &profile) ==
          DPLL_DRIVER_ERR_VERIFY);
    for (index = 0U; index < sizeof(centers) / sizeof(centers[0]); ++index) {
        CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(centers[index]), &profile) ==
              DPLL_DRIVER_OK);
        CHECK(profile.cic_r >= 8U && profile.cic_r <= 16U);
        CHECK(profile.track_cutoff_hz <= profile.acquire_cutoff_hz);
    }
    CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(22000U), &profile) ==
          DPLL_DRIVER_OK);
    CHECK(profile.cic_r == 16U && profile.cic_shift == 8U);
    CHECK(profile.kp_track == 6000000 && profile.ki_track == 180000);
    CHECK((uint32_t)profile.acquire_b0 == 0x003E186BU);
    CHECK((uint32_t)profile.track_a2 == 0x3A6F075AU);
    return 0;
}

int main(void)
{
    CHECK(test_abi_retry_and_enable() == 0);
    CHECK(test_abi_mismatch_blocks_writes() == 0);
    CHECK(test_direct_write_and_change_filtering() == 0);
    CHECK(test_validation_and_profiles() == 0);
    puts("PASS: dpll_driver_host_test");
    return 0;
}
