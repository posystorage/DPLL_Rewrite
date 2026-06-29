import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARM = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "helloworld.c"
DRIVER_C = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "dpll_driver.c"
DRIVER_H = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "dpll_driver.h"
PERIPH = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "Peripherals.h"
HOST_TEST = ROOT / "verification" / "arm" / "dpll_driver_host_test.c"


def read_gbk(path: Path) -> str:
    return path.read_text(encoding="gbk", errors="strict")


def function_body(text: str, name: str) -> str:
    match = re.search(rf"(?:static\s+)?(?:void|int|uint8_t)\s+{name}\s*\([^)]*\)\s*\{{", text)
    if not match:
        raise AssertionError(f"missing function {name}")
    depth = 1
    index = match.end()
    while index < len(text) and depth:
        depth += (text[index] == "{") - (text[index] == "}")
        index += 1
    if depth:
        raise AssertionError(f"unterminated function {name}")
    return text[match.end():index - 1]


class DpllArmControlContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.arm = read_gbk(ARM)
        cls.driver_c = DRIVER_C.read_text(encoding="utf-8")
        cls.driver_h = DRIVER_H.read_text(encoding="utf-8")
        cls.periph = read_gbk(PERIPH)
        cls.host_test = HOST_TEST.read_text(encoding="utf-8")

    def test_firmware_uses_the_host_compiled_driver(self):
        self.assertIn('#include "dpll_driver.h"', self.arm)
        self.assertTrue(DRIVER_C.exists())
        self.assertTrue(DRIVER_H.exists())
        self.assertIn("dpll_driver_check_abi(&dpll_driver)", self.arm)
        self.assertIn("dpll_driver_apply(&dpll_driver, result)", self.arm)
        self.assertIn("dpll_driver_set_enable(&dpll_driver, enable)", self.arm)

    def test_abi_retry_timeout_and_reset_recheck_are_real_driver_paths(self):
        self.assertIn("driver->abi_attempts = retry + 1U", self.driver_c)
        self.assertIn("driver->io.delay_us", self.driver_c)
        self.assertIn("DPLL_DRIVER_ERR_ABI", self.driver_c)
        self.assertIn("dpll_invalidate_abi();", function_body(self.arm, "PC_HOST_CMD_Respond"))
        self.assertIn("dpll_invalidate_abi();", function_body(self.arm, "STM_HOST_CMD_Respond"))
        self.assertIn("actual abi=0x%08lx", self.arm)
        self.assertIn("expected abi=0x%08lx", self.arm)

    def test_apply_checks_busy_error_exact_sequence_and_active_readback(self):
        for needle in (
            "DPLL_APPLY_BUSY_MASK",
            "DPLL_APPLY_ERROR_MASK",
            "sequence == expected_sequence",
            "config_rejected_mask",
            "active_center",
            "active_cic",
            "active_mul_div",
            "applied_abi_version",
            "DPLL_DRIVER_ERR_VERIFY",
        ):
            self.assertIn(needle, self.driver_c + self.driver_h)

    def test_every_shadow_command_commits_before_success(self):
        commands = (
            "CMD_82_WRITE_PLL_FREQ",
            "CMD_83_WRITE_PLL_MUL_DIV",
            "CMD_84_WRITE_PLL_THRESHOLD",
            "CMD_85_WRITE_PLL_LIMIT",
            "CMD_86_WRITE_DPLL_LOOP_BASIC",
            "CMD_87_WRITE_PLL_AMP",
            "CMD_8F_WRITE_DPLL_ADV_CONFIG",
            "CMD_97_WRITE_DPLL_DEBUG_CONFIG",
        )
        for command in commands:
            with self.subTest(command=command):
                body = function_body(self.arm, command)
                self.assertIn("pc_send_dpll_apply_result(dpll_apply_config())", body)
                self.assertNotIn("PC_HOST_Send_ASK_Only(0);", body)

    def test_advanced_payload_includes_separate_measurement_timeout(self):
        self.assertRegex(self.arm, r"#define\s+DPLL_ADV_CONFIG_PAYLOAD_BYTES\s+46U")
        body = function_body(self.arm, "CMD_8F_WRITE_DPLL_ADV_CONFIG")
        self.assertIn("DPLL_MEASUREMENT_TIMEOUT_Addr, pc_get_u32(46)", body)
        self.assertIn("DPLL_HOLDOVER_TIMEOUT_Addr, pc_get_u32(36)", body)

    def test_uart_parser_accepts_complete_advanced_config_frame(self):
        self.assertRegex(self.arm, r"#define\s+PC_HOST_MAX_FRAME_BYTES\s+64U")
        parser = function_body(self.arm, "PC_HOST_CMD_Get")
        self.assertIn("Uart0_RX_Num>PC_HOST_MAX_FRAME_BYTES", parser)
        self.assertNotIn("Uart0_RX_Num>48", parser)

    def test_host_test_covers_required_driver_outcomes(self):
        for needle in (
            "test_abi_retry_and_enable",
            "test_abi_mismatch_blocks_enable_and_apply",
            "test_atomic_apply_and_active_verify",
            "APPLY_REJECT",
            "APPLY_STUCK",
            "APPLY_VERIFY_MISMATCH",
            "test_reset_invalidates_and_rechecks_abi",
            "debug_active",
        ):
            self.assertIn(needle, self.host_test)

    def test_register_contract_exposes_apply_and_active_identity(self):
        for name in (
            "DPLL_CONFIG_APPLY_Addr",
            "DPLL_CONFIG_REJECTED_MASK_Addr",
            "DPLL_ACTIVE_CENTER_Addr",
            "DPLL_ACTIVE_CIC_CONFIG_Addr",
            "DPLL_ACTIVE_MUL_DIV_Addr",
            "DPLL_APPLIED_ABI_VERSION_Addr",
        ):
            self.assertIn(name, self.periph)


if __name__ == "__main__":
    unittest.main()
