#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "dpll_driver.h"

enum {
    REG_LOCK = 0x00,
    REG_APPLY = 0x04,
    REG_REJECTED = 0x08,
    REG_ABI = 0x0c,
    REG_CONFIG = 0x10,
    REG_BUILD = 0x14,
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
    REG_DEBUG_OFFSET = 0x8c,
    REG_DEBUG_GAIN = 0x90,
    REG_DEBUG_SOURCE = 0x94,
    REG_DEBUG_FORMAT = 0x98,
    REG_ACTIVE_CENTER = 0x9c,
    REG_ACTIVE_CIC = 0xa0,
    REG_ACTIVE_MULDIV = 0xa4,
    REG_ACTIVE_KP = 0xa8,
    REG_ACTIVE_KI = 0xac,
    REG_ACTIVE_KFA = 0xb0,
    REG_ACTIVE_KFB = 0xb4,
    REG_ACTIVE_KFT = 0xb8,
    REG_ACTIVE_KPB = 0xbc,
    REG_ACTIVE_KIB = 0xc0,
    REG_APPLIED_ABI = 0xc4,
    REG_GIT = 0xc8,
    REG_ACTIVE_CRC = 0xcc,
    REG_POST_IIR_CONFIG = 0xd0,
    REG_POST_IIR_ACQ_B0 = 0xd4,
    REG_POST_IIR_ACQ_B1 = 0xd8,
    REG_POST_IIR_ACQ_B2 = 0xdc,
    REG_POST_IIR_ACQ_A1 = 0xe0,
    REG_POST_IIR_ACQ_A2 = 0xe4,
    REG_POST_IIR_TRACK_B0 = 0xe8,
    REG_POST_IIR_TRACK_B1 = 0xec,
    REG_POST_IIR_TRACK_B2 = 0xf0,
    REG_POST_IIR_TRACK_A1 = 0xf4,
    REG_POST_IIR_TRACK_A2 = 0xf8,
    REG_ACTIVE_POST_IIR_CONFIG = 0xfc,
    REG_ACTIVE_POST_IIR_ACQ_B0 = 0x100,
    REG_ACTIVE_POST_IIR_ACQ_B1 = 0x104,
    REG_ACTIVE_POST_IIR_ACQ_B2 = 0x108,
    REG_ACTIVE_POST_IIR_ACQ_A1 = 0x10c,
    REG_ACTIVE_POST_IIR_ACQ_A2 = 0x110,
    REG_ACTIVE_POST_IIR_TRACK_B0 = 0x114,
    REG_ACTIVE_POST_IIR_TRACK_B1 = 0x118,
    REG_ACTIVE_POST_IIR_TRACK_B2 = 0x11c,
    REG_ACTIVE_POST_IIR_TRACK_A1 = 0x120,
    REG_ACTIVE_POST_IIR_TRACK_A2 = 0x124
};

enum {
    APPLY_ACCEPT,
    APPLY_STUCK,
    APPLY_REJECT,
    APPLY_VERIFY_MISMATCH,
    APPLY_BAD_SIGNEXT,
    APPLY_BAD_CRC
};

typedef struct {
    uint32_t mem[128];
    uint32_t writes_address[64];
    uint32_t writes_value[64];
    uint32_t write_count;
    uint32_t delay_count;
    uint32_t make_good_after_delays;
    uint32_t apply_mode;
} mock_mmio_t;

static const dpll_identity_t expected_identity = {
    0x00000001U, 0x00010001U, 0xd9110002U, 0x91eb683eU
};

static const dpll_reg_map_t regs = {
    REG_LOCK, REG_APPLY, REG_REJECTED, REG_ABI, REG_CONFIG, REG_BUILD, REG_GIT,
    REG_CENTER, REG_R, REG_SHIFT, REG_MUL, REG_DIV,
    REG_KP, REG_KI, REG_KFA, REG_KFB, REG_KFT, REG_KPB, REG_KIB,
    REG_PHASE_THR, REG_PHASE_SETPOINT, REG_FREQ_THR,
    REG_MAG_ENTER, REG_MAG_EXIT,
    REG_ACQ_DWELL, REG_BLEND_DWELL, REG_LOSS_DWELL,
    REG_HOLDOVER, REG_MEAS_TIMEOUT, REG_FLL_DELAY, REG_WARMUP,
    REG_POST_IIR_CONFIG,
    REG_POST_IIR_ACQ_B0, REG_POST_IIR_ACQ_B1, REG_POST_IIR_ACQ_B2,
    REG_POST_IIR_ACQ_A1, REG_POST_IIR_ACQ_A2,
    REG_POST_IIR_TRACK_B0, REG_POST_IIR_TRACK_B1, REG_POST_IIR_TRACK_B2,
    REG_POST_IIR_TRACK_A1, REG_POST_IIR_TRACK_A2,
    REG_POS_LIMIT, REG_NEG_LIMIT, REG_MANUAL_OFFSET,
    REG_DAC0_OFFSET, REG_DAC0_AMP,
    REG_DEBUG_OFFSET, REG_DEBUG_GAIN, REG_DEBUG_SOURCE, REG_DEBUG_FORMAT,
    REG_ACTIVE_CENTER, REG_ACTIVE_CIC, REG_ACTIVE_MULDIV,
    REG_ACTIVE_KP, REG_ACTIVE_KI, REG_ACTIVE_KFA, REG_ACTIVE_KFB,
    REG_ACTIVE_KFT, REG_ACTIVE_KPB, REG_ACTIVE_KIB,
    REG_ACTIVE_POST_IIR_CONFIG,
    REG_ACTIVE_POST_IIR_ACQ_B0, REG_ACTIVE_POST_IIR_ACQ_B1, REG_ACTIVE_POST_IIR_ACQ_B2,
    REG_ACTIVE_POST_IIR_ACQ_A1, REG_ACTIVE_POST_IIR_ACQ_A2,
    REG_ACTIVE_POST_IIR_TRACK_B0, REG_ACTIVE_POST_IIR_TRACK_B1, REG_ACTIVE_POST_IIR_TRACK_B2,
    REG_ACTIVE_POST_IIR_TRACK_A1, REG_ACTIVE_POST_IIR_TRACK_A2,
    REG_APPLIED_ABI,
    REG_ACTIVE_CRC
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

static void seed_shadow(mock_mmio_t *mock)
{
    MEM(mock, REG_CENTER) = 0x12345678U;
    MEM(mock, REG_R) = 78U;
    MEM(mock, REG_SHIFT) = 13U;
    MEM(mock, REG_MUL) = 3U;
    MEM(mock, REG_DIV) = 2U;
    MEM(mock, REG_KP) = 0x010203U;
    MEM(mock, REG_KI) = 0x111213U;
    MEM(mock, REG_KFA) = 0x212223U;
    MEM(mock, REG_KFB) = 0x313233U;
    MEM(mock, REG_KFT) = 0x414243U;
    MEM(mock, REG_KPB) = 0x515253U;
    MEM(mock, REG_KIB) = 0x616263U;
    MEM(mock, REG_PHASE_THR) = 0x00012345U;
    MEM(mock, REG_PHASE_SETPOINT) = 0xfffe0001U;
    MEM(mock, REG_FREQ_THR) = 0x00123456U;
    MEM(mock, REG_MAG_ENTER) = 0x21000U;
    MEM(mock, REG_MAG_EXIT) = 0x10800U;
    MEM(mock, REG_ACQ_DWELL) = 0x21U;
    MEM(mock, REG_BLEND_DWELL) = 0x22U;
    MEM(mock, REG_LOSS_DWELL) = 0x23U;
    MEM(mock, REG_HOLDOVER) = 1250000U;
    MEM(mock, REG_MEAS_TIMEOUT) = 0U;
    MEM(mock, REG_FLL_DELAY) = 2U;
    MEM(mock, REG_WARMUP) = 64U;
    MEM(mock, REG_POST_IIR_CONFIG) = 3U;
    MEM(mock, REG_POST_IIR_ACQ_B0) = 138975519U;
    MEM(mock, REG_POST_IIR_ACQ_B1) = 277951039U;
    MEM(mock, REG_POST_IIR_ACQ_B2) = 138975519U;
    MEM(mock, REG_POST_IIR_ACQ_A1) = (uint32_t)-812870960;
    MEM(mock, REG_POST_IIR_ACQ_A2) = 295031213U;
    MEM(mock, REG_POST_IIR_TRACK_B0) = 48851600U;
    MEM(mock, REG_POST_IIR_TRACK_B1) = 97703199U;
    MEM(mock, REG_POST_IIR_TRACK_B2) = 48851600U;
    MEM(mock, REG_POST_IIR_TRACK_A1) = (uint32_t)-1409400772;
    MEM(mock, REG_POST_IIR_TRACK_A2) = 531065347U;
    MEM(mock, REG_POS_LIMIT) = 0x7ffffffeU;
    MEM(mock, REG_NEG_LIMIT) = 0x80000001U;
    MEM(mock, REG_MANUAL_OFFSET) = 0x00010000U;
    MEM(mock, REG_DAC0_OFFSET) = 0x00001234U;
    MEM(mock, REG_DAC0_AMP) = 0x00005678U;
    MEM(mock, REG_DEBUG_OFFSET) = 0xfffff111U;
    MEM(mock, REG_DEBUG_GAIN) = 0x00007fffU;
    MEM(mock, REG_DEBUG_SOURCE) = 0xabcdef01U;
    MEM(mock, REG_DEBUG_FORMAT) = 0x10203040U;
}

static uint32_t sign_extend_24(uint32_t value)
{
    return (value & 0x800000U) != 0U ? (value | 0xff000000U) : (value & 0x00ffffffU);
}

static uint32_t sign_extend_width(uint32_t value, uint32_t sign_bit)
{
    uint32_t mask = (sign_bit >= 31U) ? 0xffffffffU : ((1UL << (sign_bit + 1U)) - 1U);
    value &= mask;
    return (value & (1UL << sign_bit)) != 0U ? (value | ~mask) : value;
}

static uint32_t crc_mix(uint32_t crc, uint32_t value)
{
    uint32_t mixed = crc ^ value;
    return ((mixed << 5) | (mixed >> 27)) ^ 0x9E3779B9U;
}

static uint32_t expected_crc(mock_mmio_t *mock)
{
    uint32_t crc = 0x44504C4CU;
    uint32_t r = MEM(mock, REG_R) & 0x1ffU;
    uint32_t measurement = MEM(mock, REG_MEAS_TIMEOUT) & 0x00ffffffU;
    uint32_t negative_limit = MEM(mock, REG_NEG_LIMIT);
    uint32_t words[34];
    uint32_t i;

    if (measurement == 0U) {
        measurement = (120U * r) + 256U;
    }
    if (negative_limit == 0U) {
        negative_limit = 0x80000000U;
    }

    words[0] = MEM(mock, REG_CENTER);
    words[1] = ((MEM(mock, REG_FLL_DELAY) & 0x3U) << 15) |
               ((MEM(mock, REG_SHIFT) & 0x3fU) << 9) | r;
    words[2] = ((MEM(mock, REG_MUL) & 0xffffU) << 16) | (MEM(mock, REG_DIV) & 0xffffU);
    words[3] = sign_extend_24(MEM(mock, REG_KP));
    words[4] = sign_extend_24(MEM(mock, REG_KI));
    words[5] = sign_extend_24(MEM(mock, REG_KFA));
    words[6] = sign_extend_24(MEM(mock, REG_KFB));
    words[7] = sign_extend_24(MEM(mock, REG_KFT));
    words[8] = sign_extend_24(MEM(mock, REG_KPB));
    words[9] = sign_extend_24(MEM(mock, REG_KIB));
    words[10] = sign_extend_width(MEM(mock, REG_PHASE_SETPOINT), 17U);
    words[11] = MEM(mock, REG_PHASE_THR) & 0x0003ffffU;
    words[12] = MEM(mock, REG_FREQ_THR) & 0x003fffffU;
    words[13] = MEM(mock, REG_MAG_ENTER) & 0x000fffffU;
    words[14] = MEM(mock, REG_MAG_EXIT) & 0x000fffffU;
    words[15] = ((MEM(mock, REG_ACQ_DWELL) & 0xffffU) << 16) | (MEM(mock, REG_BLEND_DWELL) & 0xffffU);
    words[16] = ((MEM(mock, REG_LOSS_DWELL) & 0xffffU) << 16) | (MEM(mock, REG_WARMUP) & 0xffffU);
    words[17] = measurement;
    words[18] = MEM(mock, REG_HOLDOVER) & 0x00ffffffU;
    words[19] = MEM(mock, REG_POS_LIMIT);
    words[20] = negative_limit;
    words[21] = MEM(mock, REG_MANUAL_OFFSET);
    words[22] = ((sign_extend_width(MEM(mock, REG_DAC0_OFFSET), 13U) & 0xffffU) << 16) |
                (sign_extend_width(MEM(mock, REG_DAC0_AMP), 15U) & 0xffffU);
    words[23] = MEM(mock, REG_POST_IIR_CONFIG) & 0x3U;
    words[24] = MEM(mock, REG_POST_IIR_ACQ_B0);
    words[25] = MEM(mock, REG_POST_IIR_ACQ_B1);
    words[26] = MEM(mock, REG_POST_IIR_ACQ_B2);
    words[27] = MEM(mock, REG_POST_IIR_ACQ_A1);
    words[28] = MEM(mock, REG_POST_IIR_ACQ_A2);
    words[29] = MEM(mock, REG_POST_IIR_TRACK_B0);
    words[30] = MEM(mock, REG_POST_IIR_TRACK_B1);
    words[31] = MEM(mock, REG_POST_IIR_TRACK_B2);
    words[32] = MEM(mock, REG_POST_IIR_TRACK_A1);
    words[33] = MEM(mock, REG_POST_IIR_TRACK_A2);
    for (i = 0U; i < 34U; ++i) {
        crc = crc_mix(crc, words[i]);
    }
    return crc;
}

static void copy_active(mock_mmio_t *mock)
{
    MEM(mock, REG_ACTIVE_CENTER) = MEM(mock, REG_CENTER);
    MEM(mock, REG_ACTIVE_CIC) = ((MEM(mock, REG_SHIFT) & 0x3fU) << 9) |
                                 (MEM(mock, REG_R) & 0x1ffU);
    MEM(mock, REG_ACTIVE_MULDIV) = ((MEM(mock, REG_MUL) & 0xffffU) << 16) |
                                    (MEM(mock, REG_DIV) & 0xffffU);
    MEM(mock, REG_ACTIVE_KP) = sign_extend_24(MEM(mock, REG_KP));
    MEM(mock, REG_ACTIVE_KI) = sign_extend_24(MEM(mock, REG_KI));
    MEM(mock, REG_ACTIVE_KFA) = sign_extend_24(MEM(mock, REG_KFA));
    MEM(mock, REG_ACTIVE_KFB) = sign_extend_24(MEM(mock, REG_KFB));
    MEM(mock, REG_ACTIVE_KFT) = sign_extend_24(MEM(mock, REG_KFT));
    MEM(mock, REG_ACTIVE_KPB) = sign_extend_24(MEM(mock, REG_KPB));
    MEM(mock, REG_ACTIVE_KIB) = sign_extend_24(MEM(mock, REG_KIB));
    MEM(mock, REG_ACTIVE_POST_IIR_CONFIG) = MEM(mock, REG_POST_IIR_CONFIG) & 0x3U;
    MEM(mock, REG_ACTIVE_POST_IIR_ACQ_B0) = MEM(mock, REG_POST_IIR_ACQ_B0);
    MEM(mock, REG_ACTIVE_POST_IIR_ACQ_B1) = MEM(mock, REG_POST_IIR_ACQ_B1);
    MEM(mock, REG_ACTIVE_POST_IIR_ACQ_B2) = MEM(mock, REG_POST_IIR_ACQ_B2);
    MEM(mock, REG_ACTIVE_POST_IIR_ACQ_A1) = MEM(mock, REG_POST_IIR_ACQ_A1);
    MEM(mock, REG_ACTIVE_POST_IIR_ACQ_A2) = MEM(mock, REG_POST_IIR_ACQ_A2);
    MEM(mock, REG_ACTIVE_POST_IIR_TRACK_B0) = MEM(mock, REG_POST_IIR_TRACK_B0);
    MEM(mock, REG_ACTIVE_POST_IIR_TRACK_B1) = MEM(mock, REG_POST_IIR_TRACK_B1);
    MEM(mock, REG_ACTIVE_POST_IIR_TRACK_B2) = MEM(mock, REG_POST_IIR_TRACK_B2);
    MEM(mock, REG_ACTIVE_POST_IIR_TRACK_A1) = MEM(mock, REG_POST_IIR_TRACK_A1);
    MEM(mock, REG_ACTIVE_POST_IIR_TRACK_A2) = MEM(mock, REG_POST_IIR_TRACK_A2);
    MEM(mock, REG_APPLIED_ABI) = expected_identity.abi_version;
    MEM(mock, REG_ACTIVE_CRC) = expected_crc(mock);
}

static uint32_t mock_read(void *context, uint32_t address)
{
    mock_mmio_t *mock = (mock_mmio_t *)context;
    return MEM(mock, address);
}

static void mock_write(void *context, uint32_t address, uint32_t value)
{
    mock_mmio_t *mock = (mock_mmio_t *)context;
    mock->writes_address[mock->write_count] = address;
    mock->writes_value[mock->write_count] = value;
    ++mock->write_count;

    if (address != REG_APPLY || value != 1U) {
        MEM(mock, address) = value;
        return;
    }

    if (mock->apply_mode == APPLY_STUCK) {
        return;
    }
    if (mock->apply_mode == APPLY_REJECT) {
        MEM(mock, REG_APPLY) = DPLL_APPLY_ERROR_MASK | (5U << DPLL_APPLY_ERROR_CODE_SHIFT);
        MEM(mock, REG_REJECTED) = 0x0241U;
        return;
    }

    {
        uint32_t sequence = ((MEM(mock, REG_APPLY) & DPLL_APPLY_SEQ_MASK) >>
                             DPLL_APPLY_SEQ_SHIFT);
        copy_active(mock);
        if (mock->apply_mode == APPLY_VERIFY_MISMATCH) {
            MEM(mock, REG_ACTIVE_CENTER) ^= 1U;
        }
        if (mock->apply_mode == APPLY_BAD_SIGNEXT) {
            MEM(mock, REG_ACTIVE_KP) = 0x00800001U;
        }
        if (mock->apply_mode == APPLY_BAD_CRC) {
            MEM(mock, REG_ACTIVE_CRC) ^= 0x01000000U;
        }
        sequence = (sequence + 1U) & 0xffU;
        MEM(mock, REG_APPLY) = sequence << DPLL_APPLY_SEQ_SHIFT;
    }
}

static void mock_delay(void *context, uint32_t delay_us)
{
    mock_mmio_t *mock = (mock_mmio_t *)context;
    (void)delay_us;
    ++mock->delay_count;
    if (mock->make_good_after_delays != 0U &&
        mock->delay_count >= mock->make_good_after_delays) {
        seed_good_identity(mock);
    }
}

static void init_driver(dpll_driver_t *driver, mock_mmio_t *mock)
{
    dpll_io_t io;
    memset(mock, 0, sizeof(*mock));
    io.read32 = mock_read;
    io.write32 = mock_write;
    io.delay_us = mock_delay;
    io.context = mock;
    dpll_driver_init(driver, &io, &regs, &expected_identity, 4U, 100U, 8U);
    seed_shadow(mock);
}

static int test_abi_retry_and_enable(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    init_driver(&driver, &mock);
    mock.make_good_after_delays = 2U;
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    CHECK(driver.abi_ready == 1U);
    CHECK(mock.delay_count == 2U);
    CHECK(driver.abi_attempts == 3U);
    CHECK(dpll_driver_set_enable(&driver, 1U) == DPLL_DRIVER_OK);
    CHECK(mock.writes_address[mock.write_count - 1U] == REG_LOCK);
    CHECK(mock.writes_value[mock.write_count - 1U] == 1U);
    return 0;
}

static int test_abi_mismatch_blocks_enable_and_apply(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    dpll_apply_result_t result;
    init_driver(&driver, &mock);
    CHECK(dpll_driver_set_enable(&driver, 1U) == DPLL_DRIVER_ERR_ABI);
    CHECK(mock.writes_address[mock.write_count - 1U] == REG_LOCK);
    CHECK(mock.writes_value[mock.write_count - 1U] == 0U);
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_ERR_ABI);
    return 0;
}

static int test_atomic_apply_and_active_verify(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    dpll_apply_result_t result;
    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_OK);
    CHECK(result.accepted == 1U);
    CHECK(result.applied_sequence == 1U);
    CHECK(result.active_r == 78U);
    CHECK(result.active_shift == 13U);
    CHECK(mock.writes_address[mock.write_count - 1U] == REG_APPLY);
    return 0;
}

static int test_active_verify_checks_full_sign_extension(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    dpll_apply_result_t result;
    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    MEM(&mock, REG_KP) = 0xff800001U;
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_OK);

    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    MEM(&mock, REG_KP) = 0xff800001U;
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    mock.apply_mode = APPLY_BAD_SIGNEXT;
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_ERR_VERIFY);
    return 0;
}

static int test_active_crc_covers_non_legacy_readback_fields(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    dpll_apply_result_t result;
    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    mock.apply_mode = APPLY_BAD_CRC;
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_ERR_VERIFY);
    return 0;
}

static int test_reject_timeout_and_verify_failure(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    dpll_apply_result_t result;

    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    mock.apply_mode = APPLY_REJECT;
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_ERR_REJECTED);
    CHECK(result.error_code == 5U);
    CHECK(result.rejected_field_mask == 0x0241U);

    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    mock.apply_mode = APPLY_STUCK;
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_ERR_TIMEOUT);

    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    mock.apply_mode = APPLY_VERIFY_MISMATCH;
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_ERR_VERIFY);
    return 0;
}

static int test_reset_invalidates_and_rechecks_abi(void)
{
    dpll_driver_t driver;
    mock_mmio_t mock;
    init_driver(&driver, &mock);
    seed_good_identity(&mock);
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    dpll_driver_invalidate_abi(&driver);
    MEM(&mock, REG_BUILD) ^= 1U;
    CHECK(dpll_driver_set_enable(&driver, 1U) == DPLL_DRIVER_ERR_ABI);
    CHECK(driver.abi_ready == 0U);
    return 0;
}

static uint32_t center_word_hi_for_hz(uint32_t frequency_hz)
{
    return (uint32_t)((((uint64_t)frequency_hz << 32) + 62500000ULL) /
                      125000000ULL);
}

static int test_adaptive_filter_profiles(void)
{
    dpll_filter_profile_t profile;
    const uint32_t centers[] = {
        5000U, 8000U, 10000U, 15000U, 22000U, 30000U, 60000U,
        80000U, 100000U, 120000U, 150000U, 180000U, 200000U
    };
    uint32_t index;
    uint32_t center_hz;
    uint32_t fll_delay;

    CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(4999U), &profile) ==
          DPLL_DRIVER_ERR_VERIFY);
    CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(200001U), &profile) ==
          DPLL_DRIVER_ERR_VERIFY);

    for (index = 0U; index < sizeof(centers) / sizeof(centers[0]); ++index) {
        CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(centers[index]),
                                          &profile) == DPLL_DRIVER_OK);
        CHECK(profile.center_hz >= 5000U && profile.center_hz <= 200000U);
        CHECK(profile.cic_r >= 8U && profile.cic_r <= 16U);
        CHECK(profile.mirror_alias_hz * 10U >= profile.acquire_cutoff_hz * 22U);
        CHECK(profile.track_cutoff_hz <= profile.acquire_cutoff_hz);
        CHECK(profile.acquire_b0 == profile.acquire_b2);
        CHECK(profile.track_b0 == profile.track_b2);
        CHECK(profile.acquire_a1 < 0 && profile.acquire_a2 > 0);
        CHECK(profile.track_a1 < 0 && profile.track_a2 > 0);
        fll_delay = 1U << profile.fll_delay_sel;
        CHECK(3125000U >= 4U * fll_delay * profile.acquire_cutoff_hz *
                            profile.cic_r);
    }

    /* The ARM selector must cover the complete user range, including the
     * alias-frequency discontinuities between the representative points. */
    for (center_hz = 5000U; center_hz <= 200000U; center_hz += 100U) {
        CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(center_hz),
                                          &profile) == DPLL_DRIVER_OK);
        CHECK(profile.mirror_alias_hz * 10U >= profile.acquire_cutoff_hz * 22U);
        fll_delay = 1U << profile.fll_delay_sel;
        CHECK(3125000U >= 4U * fll_delay * profile.acquire_cutoff_hz *
                            profile.cic_r);
    }

    CHECK(dpll_compute_filter_profile(center_word_hi_for_hz(22000U), &profile) ==
          DPLL_DRIVER_OK);
    CHECK(profile.cic_r == 16U);
    CHECK(profile.cic_shift == 8U);
    CHECK(profile.fll_delay_sel == 3U);
    CHECK(profile.acquire_cutoff_hz == 4000U);
    CHECK(profile.track_cutoff_hz == 2000U);
    CHECK(profile.mirror_alias_hz == 44000U);
    CHECK((uint32_t)profile.acquire_b0 == 0x003E186BU);
    CHECK((uint32_t)profile.acquire_b1 == 0x007C30D5U);
    CHECK((uint32_t)profile.acquire_a1 == 0x8B9E5F9EU);
    CHECK((uint32_t)profile.acquire_a2 == 0x355A020CU);
    CHECK((uint32_t)profile.track_b0 == 0x00103681U);
    CHECK((uint32_t)profile.track_b1 == 0x00206D02U);
    CHECK((uint32_t)profile.track_a1 == 0x85D1D2A9U);
    CHECK((uint32_t)profile.track_a2 == 0x3A6F075AU);
    return 0;
}

int main(void)
{
    CHECK(test_abi_retry_and_enable() == 0);
    CHECK(test_abi_mismatch_blocks_enable_and_apply() == 0);
    CHECK(test_atomic_apply_and_active_verify() == 0);
    CHECK(test_active_verify_checks_full_sign_extension() == 0);
    CHECK(test_active_crc_covers_non_legacy_readback_fields() == 0);
    CHECK(test_reject_timeout_and_verify_failure() == 0);
    CHECK(test_reset_invalidates_and_rechecks_abi() == 0);
    CHECK(test_adaptive_filter_profiles() == 0);
    puts("PASS: dpll_driver_host_test");
    return 0;
}
