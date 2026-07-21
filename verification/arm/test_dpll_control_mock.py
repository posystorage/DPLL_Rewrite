import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARM = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "helloworld.c"
DRIVER_C = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "dpll_driver.c"
DRIVER_H = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "dpll_driver.h"
PERIPH = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "Peripherals.h"
PROTOCOL = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "control_protocol.h"
PROFILE = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "dpll_profile.c"
HOST_TEST = ROOT / "verification" / "arm" / "dpll_driver_host_test.c"


def read_source(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="strict")


def function_body(text: str, name: str) -> str:
    match = re.search(rf"(?:static\s+)?(?:void|int|uint8_t|uint32_t)\s+{name}\s*\([^)]*\)\s*\{{", text)
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
        cls.arm = read_source(ARM)
        cls.driver_c = DRIVER_C.read_text(encoding="utf-8")
        cls.driver_h = DRIVER_H.read_text(encoding="utf-8")
        cls.periph = read_source(PERIPH)
        cls.protocol = read_source(PROTOCOL)
        cls.profile = read_source(PROFILE)
        cls.host_test = HOST_TEST.read_text(encoding="utf-8")

    def test_firmware_uses_the_host_compiled_driver(self):
        self.assertIn('#include "dpll_driver.h"', self.arm)
        self.assertTrue(DRIVER_C.exists())
        self.assertTrue(DRIVER_H.exists())
        self.assertIn("dpll_driver_check_abi(&dpll_driver)", self.arm)
        self.assertIn("dpll_driver_write_config(", self.arm)
        self.assertIn("dpll_driver_set_enable(&dpll_driver, enable)", self.arm)

    def test_abi_retry_timeout_and_reset_recheck_are_real_driver_paths(self):
        self.assertIn("driver->abi_attempts = retry + 1U", self.driver_c)
        self.assertIn("driver->io.delay_us", self.driver_c)
        self.assertIn("DPLL_DRIVER_ERR_ABI", self.driver_c)
        self.assertIn("dpll_invalidate_abi();", function_body(self.arm, "PC_HOST_CMD_Respond"))
        self.assertIn("dpll_invalidate_abi();", function_body(self.arm, "Control_Reset_Both"))
        self.assertIn("actual abi=0x%08lx", self.arm)
        self.assertIn("expected abi=0x%08lx", self.arm)

    def test_driver_uses_direct_changed_field_writes_without_global_apply(self):
        for needle in (
            "dpll_driver_write_config",
            "dpll_write_profile",
            "previous == 0 || config->field != previous->field",
            "old == 0 || profile->field != old->field",
        ):
            self.assertIn(needle, self.driver_c + self.driver_h)
        self.assertNotIn("dpll_driver_apply", self.driver_c + self.driver_h)
        self.assertNotIn("DPLL_APPLY_BUSY_MASK", self.driver_c + self.driver_h)
        self.assertNotIn("apply_poll_limit", self.driver_c + self.driver_h)

    def test_control_bank_apply_and_advanced_apply_commit_before_success(self):
        bank_apply = function_body(self.arm, "Control_Apply_Persistent")
        self.assertIn("control_apply_bank()", bank_apply)
        self.assertIn("control_uart_write", bank_apply)
        self.assertIn("control_restore_persistent", bank_apply)
        command = function_body(self.arm, "CMD_99_APPLY_CONTROL_BANK")
        self.assertIn("Control_Apply_Persistent", command)

        advanced = function_body(self.arm, "CMD_8F_WRITE_DPLL_ADV_CONFIG")
        self.assertIn("candidate = DPLL_Committed_Config", advanced)
        self.assertIn("dpll_commit_candidate(&candidate)", advanced)
        self.assertIn("pc_send_dpll_config_result(status)", advanced)
        self.assertNotIn("PC_HOST_Send_ASK_Only(0);", advanced)

    def test_failed_pc_and_lcd_apply_restore_previous_persistent_bank(self):
        restore = function_body(self.arm, "control_restore_persistent")
        self.assertIn("memcpy(&Control_Bank[CTRL_PERSIST_BEGIN], previous", restore)
        self.assertIn("control_apply_bank()", restore)
        self.assertIn("control_uart_write", restore)
        self.assertIn("control_report_error(original_error)", restore)

        pc_apply = function_body(self.arm, "Control_Apply_Persistent")
        self.assertIn("memcpy(previous", pc_apply)
        self.assertGreaterEqual(pc_apply.count("control_restore_persistent"), 2)

        lcd_apply = function_body(self.arm, "Control_Link_Service")
        self.assertIn("memcpy(previous", lcd_apply)
        self.assertIn("control_restore_persistent(previous, apply_error, 1U)", lcd_apply)

    def test_lcd_persistent_bank_is_committed_only_after_request_sequence_changes(self):
        service = function_body(self.arm, "Control_Link_Service")
        sequence_test = "if (request_sequence != Control_Request_Seen)"
        self.assertIn(sequence_test, service)
        commit = service.index("memcpy(&Control_Bank[CTRL_REG_REQUEST_SEQ]")
        self.assertGreater(commit, service.index(sequence_test))
        self.assertNotIn(
            "memcpy(&Control_Bank[CTRL_REG_REQUEST_SEQ], header, sizeof(header))",
            service,
        )
        self.assertIn("Control_Bank[CTRL_REG_CONTROL_FLAGS] =", service)
        self.assertIn("Control_Bank[CTRL_REG_MWS_STATUS] =", service)

    def test_fast_interval_api_uses_ms_and_transactional_control_bank(self):
        body = function_body(self.arm, "CMD_98_WRITE_FREQMETER_FAST_INTERVAL")
        self.assertIn("pc_get_u16(4)", body)
        self.assertIn("CTRL_FAST_INTERVAL_MIN_MS", body)
        self.assertIn("CTRL_FAST_INTERVAL_MAX_MS", body)
        self.assertIn("Control_Apply_Persistent(candidate)", body)
        self.assertNotIn("Xil_Out32(Freq_Meter_Fast_Interval_Addr", body)

    def test_frequency_meter_validation_is_centralized_before_writes(self):
        validator = function_body(self.arm, "freq_meter_validate_config")
        timer = function_body(self.arm, "CMD_94_WRITE_FREQMETER_TIMER")
        bank = function_body(self.arm, "control_apply_bank")
        self.assertIn("config->gate_time_low == 0U", validator)
        self.assertNotIn("gate_time_low | candidate.gate_time_high", timer)
        self.assertLess(
            bank.index("freq_meter_validate_config(&meter_candidate)"),
            bank.index("dpll_commit_candidate(&candidate)"),
        )
        self.assertLess(
            bank.index("dpll_commit_candidate(&candidate)"),
            bank.index("freq_meter_commit_candidate(&meter_candidate)"),
        )

    def test_frequency_meter_d_gain_is_public_but_d_filter_is_arm_fixed(self):
        initializer = function_body(self.arm, "freq_meter_initialize_defaults")
        advanced = function_body(self.arm, "CMD_93_WRITE_FREQMETER_PID")
        self.assertIn("candidate.gain_d = pc_get_u32(16)", advanced)
        self.assertIn("#define FREQ_METER_D_FILTER_COEFF", self.arm)
        self.assertIn(
            "Xil_Out32(Freq_Meter_Coefd_Filter_Addr, FREQ_METER_D_FILTER_COEFF)",
            initializer,
        )
        config_decl = re.search(
            r"typedef\s+struct\s*\{(?P<body>.*?)\}\s*freq_meter_config_t\s*;",
            self.arm,
            re.S,
        )
        self.assertIsNotNone(config_decl)
        self.assertIn("gain_d", config_decl.group("body"))
        self.assertNotIn("filter", config_decl.group("body").lower())

    def test_debug_dac_command_is_live_only(self):
        body = function_body(self.arm, "CMD_97_WRITE_DPLL_DEBUG_CONFIG")
        helper = function_body(self.arm, "debug_dac_commit_candidate")
        for name in (
            "DPLL_DEBUG_DAC_SOURCE_ADDR",
            "DPLL_DEBUG_DAC_FORMAT_ADDR",
            "DPLL_DEBUG_DAC_OFFSET_ADDR",
            "DPLL_DEBUG_DAC_GAIN_ADDR",
        ):
            self.assertIn(name, helper)
        self.assertIn("debug_dac_commit_candidate(&candidate)", body)
        self.assertIn("PC_HOST_Send_ASK_Only(0U);", body)
        self.assertNotIn("dpll_apply_config", body)

        preset = function_body(self.arm, "Control_Apply_Debug_DAC_Preset")
        self.assertNotIn("dpll_apply_config", preset)
        self.assertNotIn("control_apply_bank", preset)
        self.assertIn("debug_dac_commit_candidate(config)", preset)

    def test_debug_dac_quick_presets_and_manual_api_coexist(self):
        self.assertIn("PC_CMD_READ_DPLL_DEBUG_CONFIG", self.arm)
        self.assertIn("DPLL_DEBUG_PRESET_PAYLOAD_BYTES   1U", self.arm)
        write = function_body(self.arm, "CMD_97_WRITE_DPLL_DEBUG_CONFIG")
        self.assertIn("Control_Set_Debug_DAC_Preset", write)
        self.assertIn("DPLL_DEBUG_CONFIG_PAYLOAD_BYTES", write)
        self.assertIn("CTRL_DEBUG_DAC_PRESET_MANUAL", write)
        read = function_body(self.arm, "CMD_1E_READ_DPLL_DEBUG_CONFIG")
        self.assertIn("PC_HOST_ASK_Pack(13U)", read)
        for address in (
            "DPLL_DEBUG_DAC_SOURCE_ADDR",
            "DPLL_DEBUG_DAC_FORMAT_ADDR",
            "DPLL_DEBUG_DAC_OFFSET_ADDR",
            "DPLL_DEBUG_DAC_GAIN_ADDR",
        ):
            self.assertIn(address, read)

    def test_debug_dac_presets_match_frozen_table_and_old_default(self):
        for row in (
            "{0U, 0x0100U, 0U, 0x5000U}",
            "{1U, 0x0000U, 0U, 0x7FFFU}",
            "{2U, 0x0100U, 0U, 0x5000U}",
            "{3U, 0x0000U, 0U, 0x7FFFU}",
            "{4U, 0x0000U, 0U, 0x7FFFU}",
            "{5U, 0x0006U, 0U, 0x7FFFU}",
            "{6U, 0x0006U, 0U, 0x7FFFU}",
            "{7U, 0x0004U, 0U, 0x7FFFU}",
            "{8U, 0x0207U, 0U, 0x7FFFU}",
        ):
            self.assertIn(row, self.arm)
        self.assertIn("CTRL_DEBUG_DAC_PRESET_DEFAULT      1U", self.protocol)
        startup = function_body(self.arm, "Control_Link_Startup")
        self.assertIn("CTRL_DEBUG_DAC_PRESET_DEFAULT", startup)
        reset = function_body(self.arm, "PC_HOST_CMD_Respond")
        self.assertIn(
            "Control_Set_Debug_DAC_Preset(CTRL_DEBUG_DAC_PRESET_DEFAULT)", reset
        )

    def test_runtime_frequency_units_and_meter_lock_are_distinct(self):
        self.assertIn("CTRL_REG_OUTPUT_FREQ_MILLIHZ", self.protocol)
        self.assertIn("CTRL_REG_FAST_METER_HZ", self.protocol)
        self.assertIn("CTRL_FREQ_METER_LOCKED_MASK", self.protocol)
        dpll_frequency = function_body(self.arm, "control_dpll_output_millihz")
        self.assertIn("244140625ULL", dpll_frequency)
        self.assertIn("1ULL << 38", dpll_frequency)
        runtime = function_body(self.arm, "control_collect_runtime")
        self.assertIn("CTRL_REG_OUTPUT_FREQ_MILLIHZ", runtime)
        self.assertIn("control_dpll_output_millihz()", runtime)
        self.assertIn("CTRL_REG_FAST_METER_HZ", runtime)
        self.assertIn("CTRL_FREQ_METER_LOCKED_MASK", runtime)

    def test_frequency_meter_reset_restores_previous_dac_preset(self):
        service = function_body(self.arm, "Control_Link_Service")
        token = service.index("debug_preset == CONTROL_FREQ_METER_RESET_REQUEST")
        restore = service.index(
            "Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = Control_Debug_Preset_Seen",
            token,
        )
        writeback = service.index("control_uart_write(CTRL_REG_DEBUG_DAC_PRESET", restore)
        self.assertLess(token, restore)
        self.assertLess(restore, writeback)

    def test_lcd_debug_preset_poll_is_outside_persistent_apply(self):
        service = function_body(self.arm, "Control_Link_Service")
        self.assertIn("CTRL_REG_DEBUG_DAC_PRESET - CTRL_REG_REQUEST_SEQ + 1U", service)
        self.assertIn("debug_preset != Control_Debug_Preset_Seen", service)
        self.assertIn("Control_Apply_Debug_DAC_Preset(debug_preset)", service)
        self.assertNotIn(
            "CTRL_REG_DEBUG_DAC_PRESET", function_body(self.arm, "control_apply_bank")
        )

    def test_advanced_payload_includes_separate_measurement_timeout(self):
        self.assertRegex(self.arm, r"#define\s+DPLL_ADV_CONFIG_PAYLOAD_BYTES\s+90U")
        body = function_body(self.arm, "CMD_8F_WRITE_DPLL_ADV_CONFIG")
        self.assertIn("candidate.profile.measurement_timeout = pc_get_u32(46)", body)
        self.assertIn("candidate.profile.holdover_timeout = pc_get_u32(36)", body)
        self.assertIn("dpll_commit_candidate(&candidate)", body)

    def test_uart_parser_accepts_complete_advanced_config_frame(self):
        self.assertRegex(self.arm, r"#define\s+PC_HOST_MAX_FRAME_BYTES\s+128U")
        parser = function_body(self.arm, "PC_HOST_CMD_Get")
        self.assertIn("Uart0_RX_Num>PC_HOST_MAX_FRAME_BYTES", parser)
        self.assertNotIn("Uart0_RX_Num>48", parser)

    def test_host_test_covers_required_driver_outcomes(self):
        for needle in (
            "test_abi_retry_and_enable",
            "test_abi_mismatch_blocks_writes",
            "test_direct_write_and_change_filtering",
            "test_validation_and_profiles",
        ):
            self.assertIn(needle, self.host_test)

    def test_register_contract_exposes_reconfigure_and_identity(self):
        for name in (
            "DPLL_RECONFIGURE_Addr",
            "DPLL_RESERVED_0070_Addr",
            "DPLL_RESERVED_011E_Addr",
            "DPLL_ABI_VERSION_Addr",
            "DPLL_FPGA_BUILD_ID_Addr",
        ):
            self.assertIn(name, self.periph)

    def test_control_runtime_decodes_packed_fpga_status_at_documented_bits(self):
        self.assertIn("(core_flags >> 13) & 0x0FU", self.arm)
        self.assertIn("(core_flags >> 9) & 0x0FU", self.arm)

    def test_control_uart_and_center_range_match_mcu_contract(self):
        self.assertIn("format.BaudRate = 921600;", self.arm)
        self.assertIn("XUartPs_uart1.BaudRate = 1000000U;", self.arm)
        self.assertNotIn("CTRL_DPLL_OUTPUT_MAX_DHZ", self.arm)
        self.assertNotIn("control_output_ratio_valid", self.arm)
        self.assertRegex(
            self.arm,
            r"multiplier\s*==\s*0U\s*\|\|\s*divider\s*==\s*0U",
        )
        self.assertIn("CTRL_FAST_INTERVAL_MAX_MS", self.arm)

    def test_center_range_and_extended_profile_reach_250_khz(self):
        self.assertIn("center > CTRL_DPLL_CENTER_MAX_DHZ", self.arm)
        self.assertIn("CTRL_DPLL_CENTER_MAX_DHZ          2500000UL", self.protocol)
        self.assertIn("DPLL_MAX_CENTER_HZ        250000.0", self.profile)
        self.assertIn("DPLL_STANDARD_MAX_HZ      200000.0", self.profile)
        self.assertRegex(
            self.profile,
            r"\{\s*250000U,\s*20000U,\s*9000U,\s*0U\s*\}",
        )

        rates = [16, 15, 12, 10, 8]

        def selected_rate(center_hz):
            for rate_r in rates:
                output_rate = 3_125_000.0 / rate_r
                image = 2.0 * center_hz
                image -= round(image / output_rate) * output_rate
                if abs(image) >= 2.2 * 20_000.0 and output_rate >= 8.0 * 20_000.0:
                    return rate_r
            return None

        self.assertEqual(selected_rate(200_001), 12)
        self.assertEqual(selected_rate(217_312), 12)
        self.assertEqual(selected_rate(217_313), 16)
        self.assertEqual(selected_rate(250_000), 16)
        self.assertTrue(all(selected_rate(frequency) is not None
                            for frequency in range(200_001, 250_001)))

    def test_center_change_preserves_independent_post_iir_mode(self):
        builder = function_body(self.arm, "dpll_build_control_candidate")
        self.assertIn(
            "candidate->profile.post_iir_mode =\n"
            "\t\t\t\tDPLL_Committed_Config.profile.post_iir_mode;",
            builder,
        )


if __name__ == "__main__":
    unittest.main()
