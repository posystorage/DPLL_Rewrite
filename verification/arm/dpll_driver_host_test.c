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
    REG_ACTIVE_CENTER = 0x48,
    REG_ACTIVE_CIC = 0x4c,
    REG_ACTIVE_MULDIV = 0x50,
    REG_ACTIVE_KP = 0x54,
    REG_ACTIVE_KI = 0x58,
    REG_ACTIVE_KFA = 0x5c,
    REG_ACTIVE_KFB = 0x60,
    REG_ACTIVE_KFT = 0x64,
    REG_ACTIVE_KPB = 0x68,
    REG_ACTIVE_KIB = 0x6c,
    REG_APPLIED_ABI = 0x70,
    REG_GIT = 0x74
};

enum { APPLY_ACCEPT, APPLY_STUCK, APPLY_REJECT, APPLY_VERIFY_MISMATCH };

typedef struct {
    uint32_t mem[64];
    uint32_t writes_address[64];
    uint32_t writes_value[64];
    uint32_t write_count;
    uint32_t delay_count;
    uint32_t make_good_after_delays;
    uint32_t apply_mode;
    uint32_t debug_shadow;
    uint32_t debug_active;
} mock_mmio_t;

static const dpll_identity_t expected_identity = {
    0x00000001U, 0x00010001U, 0xd9110002U, 0x91eb683eU
};

static const dpll_reg_map_t regs = {
    REG_LOCK, REG_APPLY, REG_REJECTED, REG_ABI, REG_CONFIG, REG_BUILD, REG_GIT,
    REG_CENTER, REG_R, REG_SHIFT, REG_MUL, REG_DIV,
    REG_KP, REG_KI, REG_KFA, REG_KFB, REG_KFT, REG_KPB, REG_KIB,
    REG_ACTIVE_CENTER, REG_ACTIVE_CIC, REG_ACTIVE_MULDIV,
    REG_ACTIVE_KP, REG_ACTIVE_KI, REG_ACTIVE_KFA, REG_ACTIVE_KFB,
    REG_ACTIVE_KFT, REG_ACTIVE_KPB, REG_ACTIVE_KIB, REG_APPLIED_ABI
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
}

static void copy_active(mock_mmio_t *mock)
{
    MEM(mock, REG_ACTIVE_CENTER) = MEM(mock, REG_CENTER);
    MEM(mock, REG_ACTIVE_CIC) = ((MEM(mock, REG_SHIFT) & 0x3fU) << 9) |
                                 (MEM(mock, REG_R) & 0x1ffU);
    MEM(mock, REG_ACTIVE_MULDIV) = ((MEM(mock, REG_MUL) & 0xffffU) << 16) |
                                    (MEM(mock, REG_DIV) & 0xffffU);
    MEM(mock, REG_ACTIVE_KP) = MEM(mock, REG_KP);
    MEM(mock, REG_ACTIVE_KI) = MEM(mock, REG_KI);
    MEM(mock, REG_ACTIVE_KFA) = MEM(mock, REG_KFA);
    MEM(mock, REG_ACTIVE_KFB) = MEM(mock, REG_KFB);
    MEM(mock, REG_ACTIVE_KFT) = MEM(mock, REG_KFT);
    MEM(mock, REG_ACTIVE_KPB) = MEM(mock, REG_KPB);
    MEM(mock, REG_ACTIVE_KIB) = MEM(mock, REG_KIB);
    MEM(mock, REG_APPLIED_ABI) = expected_identity.abi_version;
    mock->debug_active = mock->debug_shadow;
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
    mock.debug_shadow = 0xabcdef01U;
    CHECK(dpll_driver_check_abi(&driver) == DPLL_DRIVER_OK);
    CHECK(dpll_driver_apply(&driver, &result) == DPLL_DRIVER_OK);
    CHECK(result.accepted == 1U);
    CHECK(result.applied_sequence == 1U);
    CHECK(result.active_r == 78U);
    CHECK(result.active_shift == 13U);
    CHECK(mock.writes_address[mock.write_count - 1U] == REG_APPLY);
    CHECK(mock.debug_active == mock.debug_shadow);
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

int main(void)
{
    CHECK(test_abi_retry_and_enable() == 0);
    CHECK(test_abi_mismatch_blocks_enable_and_apply() == 0);
    CHECK(test_atomic_apply_and_active_verify() == 0);
    CHECK(test_reject_timeout_and_verify_failure() == 0);
    CHECK(test_reset_invalidates_and_rechecks_abi() == 0);
    puts("PASS: dpll_driver_host_test");
    return 0;
}