import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HEADERS = (
    ROOT / "DPLL_Rewrite.sdk/DPLL_2COM/src/control_protocol.h",
    ROOT / "MCU_src/STM8S003_MX2871_IIC/src/control_protocol.h",
    ROOT / "MCU_src/STM32F030_LCD/HARDWARE/STM8Slave/control_protocol.h",
)
CONTROL_DOC = ROOT / "docs/009_three_controller_control_protocol.md"
TRANSPORT_DOC = ROOT / "docs/010_arm_stm8_stm32_transport_protocol.md"


def macro_table(path):
    text = path.read_text(encoding="ascii")
    return dict(re.findall(r"^#define\s+(CTRL_[A-Z0-9_]+)\s+([^\r\n]+)", text, re.M))


class ControlProtocolConsistencyTest(unittest.TestCase):
    def test_all_three_headers_are_identical(self):
        expected = macro_table(HEADERS[0])
        for header in HEADERS[1:]:
            self.assertEqual(macro_table(header), expected, header)

    def test_bank_boundaries_and_phase_unit(self):
        macros = macro_table(HEADERS[0])
        self.assertEqual(macros["CTRL_PROTOCOL_VERSION"], "3U")
        self.assertEqual(macros["CTRL_BANK_SIZE"], "96U")
        self.assertEqual(macros["CTRL_PERSIST_BEGIN"], "4U")
        self.assertEqual(macros["CTRL_PERSIST_END"], "64U")
        self.assertEqual(macros["CTRL_REG_PHASE_THRESHOLD_CDEG"], "44U")
        self.assertEqual(macros["CTRL_REG_PHASE_ERROR_CDEG"], "76U")
        self.assertEqual(macros["CTRL_REG_MWS_FREQ_KHZ"], "4U")
        self.assertEqual(macros["CTRL_DPLL_CENTER_MIN_DHZ"], "40000UL")
        self.assertEqual(macros["CTRL_DPLL_CENTER_MAX_DHZ"], "2500000UL")
        self.assertEqual(macros["CTRL_DPLL_OUTPUT_MAX_DHZ"], "625000000UL")
        self.assertEqual(macros["CTRL_FAST_INTERVAL_MAX_MS"], "34359U")
        self.assertEqual(macros["CTRL_REG_DEBUG_DAC_PRESET"], "71U")
        self.assertEqual(macros["CTRL_DEBUG_DAC_PRESET_DEFAULT"], "1U")
        self.assertEqual(macros["CTRL_DEBUG_DAC_PRESET_MANUAL"], "0xFFU")

    def test_old_microwave_unit_name_is_gone(self):
        roots = (
            ROOT / "DPLL_Rewrite.sdk/DPLL_2COM/src",
            ROOT / "MCU_src/STM8S003_MX2871_IIC/src",
            ROOT / "MCU_src/STM32F030_LCD/HARDWARE/STM8Slave",
            ROOT / "MCU_src/STM32F030_LCD/USER",
        )
        for root in roots:
            for path in root.glob("*.[ch]"):
                source = path.read_text(encoding="gbk", errors="ignore")
                self.assertNotIn("CTRL_REG_MWS_FREQ_100KHZ", source, path)

    def test_stm32_has_no_float_or_legacy_boot_push(self):
        paths = (
            ROOT / "MCU_src/STM32F030_LCD/HARDWARE/STM8Slave/STM8Slave.c",
            ROOT / "MCU_src/STM32F030_LCD/USER/control.c",
            ROOT / "MCU_src/STM32F030_LCD/USER/display.c",
        )
        source = "\n".join(path.read_text(encoding="gbk") for path in paths)
        self.assertNotRegex(source, r"\b(float|double)\b")
        init = re.search(r"void STM8Slave_Init\(void\)\s*\{(.*?)\n\}", source, re.S)
        self.assertIsNotNone(init)
        self.assertNotIn("0xC2", init.group(1))
        self.assertNotIn("0xC9", init.group(1))
        self.assertNotIn("0xC4", init.group(1))

    def test_arm_resets_both_fpga_blocks(self):
        source = (ROOT / "DPLL_Rewrite.sdk/DPLL_2COM/src/helloworld.c").read_text(
            encoding="utf-8"
        )
        body = re.search(r"static void Control_Reset_Both\(void\)\s*\{(.*?)\n\}", source, re.S)
        self.assertIsNotNone(body)
        self.assertIn("Opal_Kelly_Reset_Trigger_Addr", body.group(1))
        self.assertIn("Freq_Meter_Reset_Trigger_Addr", body.group(1))

    def test_arm_uses_tracking_word_for_output_frequency(self):
        source = (ROOT / "DPLL_Rewrite.sdk/DPLL_2COM/src/helloworld.c").read_text(
            encoding="utf-8"
        )
        body = re.search(
            r"static uint32_t control_dpll_output_millihz\(void\)\s*\{(.*?)\n\}",
            source,
            re.S,
        )
        self.assertIsNotNone(body)
        self.assertIn("DPLL_TRACKING_WORD_HI_Addr", body.group(1))
        self.assertIn("PLL0_Output_Limit", body.group(1))
        self.assertNotIn("PLL0_Output_Limit_Average", body.group(1))

    def test_runtime_frequency_fields_have_distinct_units(self):
        macros = macro_table(HEADERS[0])
        self.assertEqual(macros["CTRL_REG_OUTPUT_FREQ_MILLIHZ"], "80U")
        self.assertEqual(macros["CTRL_REG_FAST_METER_HZ"], "84U")
        self.assertEqual(macros["CTRL_REG_FAST_METER_SEQ"], "88U")
        self.assertEqual(macros["CTRL_FAST_METER_SEQ_MASK"], "0x7FFFFFFFUL")
        self.assertEqual(macros["CTRL_FREQ_METER_LOCKED_MASK"], "0x80000000UL")

    def test_lcd_runtime_frequency_layout_and_label(self):
        display = (ROOT / "MCU_src/STM32F030_LCD/USER/display.c").read_text(
            encoding="gbk"
        )
        self.assertIn('LCD_16ShowString_hanzi(14U, 112U, "重频"', display)
        self.assertIn("LCD_SHOW_ASCII_1608(46U, 112U", display)
        self.assertIn('LCD_16ShowString_hanzi(122U, 112U, "MHz"', display)
        self.assertIn("LCD_SHOW_Icon_1612(147U, 112U", display)
        self.assertIn("(online && locked) ? 0U : 1U", display)
        self.assertIn("CTRL_REG_OUTPUT_FREQ_MILLIHZ", display)
        self.assertIn("uint32_t fraction = millihz % 1000U", display)

    def test_stm8_keeps_verified_original_one_mbps_uart_setup(self):
        source = (ROOT / "MCU_src/STM8S003_MX2871_IIC/src/RedPitaya.c").read_text(
            encoding="ascii"
        )
        self.assertIn("misnamed library bit", source)
        self.assertIn("CLK_PCKENR1_UART2", source)
        self.assertIn("UART1->BRR2 = 0x00", source)
        self.assertIn("UART1->BRR1 = 0x01", source)

    def test_stm32_accepts_only_a_coherent_full_bank_snapshot(self):
        source = (
            ROOT / "MCU_src/STM32F030_LCD/HARDWARE/STM8Slave/STM8Slave.c"
        ).read_text(encoding="ascii")
        self.assertIn("IIC_Read(STM8_SLAVE_ADDR, 0U, CTRL_BANK_SIZE", source)
        self.assertIn(
            "STM8_Control_Snapshot[CTRL_REG_RESPONSE_SEQ] != sequence_after", source
        )
        self.assertIn(
            "STM8_Control_Snapshot[CTRL_REG_REQUEST_SEQ] == sequence_after", source
        )
        self.assertIn("STM8_EEPROM_Write_Cnt = 0U", source)
        self.assertIn("STM8_STATUS_RETRY_LIMIT         60U", source)
        save_service = re.search(
            r"void STM8_Slave_EEPROM_Write_Service\(void\)\s*\{(.*?)\n\}",
            source,
            re.S,
        )
        self.assertIsNotNone(save_service)
        self.assertIn("STM8_Slave_Read_Status()", save_service.group(1))

    def test_stm32_verifies_persistent_write_before_apply_command(self):
        source = (
            ROOT / "MCU_src/STM32F030_LCD/HARDWARE/STM8Slave/STM8Slave.c"
        ).read_text(encoding="ascii")
        helper = re.search(
            r"static uint8_t STM8Slave_Write_Verified\(.*?\n\}", source, re.S
        )
        self.assertIsNotNone(helper)
        self.assertIn("STM8_WRITE_VERIFY_RETRY_LIMIT   3U", source)
        self.assertIn("IIC_Write(STM8_SLAVE_ADDR, offset, length, data)", helper.group(0))
        self.assertIn("IIC_Read(STM8_SLAVE_ADDR, offset, length", helper.group(0))
        self.assertIn("data[index] != STM8_Control_Snapshot[offset + index]", helper.group(0))

        send = re.search(
            r"uint8_t STM8_Slave_Send_PLL_Cfg\(void\)\s*\{(.*?)\n\}", source, re.S
        )
        self.assertIsNotNone(send)
        body = send.group(1)
        self.assertLess(body.index("STM8Slave_Write_Verified"), body.index("0xC4U"))
        self.assertIn(")) return 0U;", body)
        self.assertIn("sequence_before", body)
        self.assertIn("sequence_after", body)
        self.assertIn("sequence_before + 1U", body)

    def test_debug_dac_preset_is_verified_live_only_and_screen_visible(self):
        driver = (
            ROOT / "MCU_src/STM32F030_LCD/HARDWARE/STM8Slave/STM8Slave.c"
        ).read_text(encoding="ascii")
        setter = re.search(
            r"uint8_t STM8_Slave_Set_Debug_DAC_Preset\(.*?\n\}", driver, re.S
        )
        self.assertIsNotNone(setter)
        self.assertIn("STM8Slave_Write_Verified", setter.group(0))
        self.assertNotIn("0xC4", setter.group(0))
        self.assertNotIn("EEPROM", setter.group(0))

        control = (ROOT / "MCU_src/STM32F030_LCD/USER/control.c").read_text(
            encoding="ascii"
        )
        display = (ROOT / "MCU_src/STM32F030_LCD/USER/display.c").read_text(
            encoding="gbk"
        )
        bridge = (ROOT / "MCU_src/STM8S003_MX2871_IIC/src/IIC.c").read_text(
            encoding="gbk", errors="ignore"
        )
        self.assertIn("#define PAGE0_MAX_ADJ_INDEX 8U", control)
        self.assertIn("#define PAGE1_MAX_ADJ_INDEX 9U", control)
        self.assertIn("CtrlP0I7_Debug_DAC", control)
        self.assertIn("CtrlP1I7_Amplitude", control)
        self.assertIn("CtrlP1I8_Frequency", control)
        self.assertIn("Display_UI_Show_Debug_DAC_Preset", display)
        self.assertIn("LCD_SHOW_ASCII_1608(132U, 65U, 'D'", display)
        self.assertIn("LCD_SHOW_ASCII_0806(154U, 37U, glyph", display)
        self.assertIn("IIC_Reg_Addr_Point==CTRL_REG_DEBUG_DAC_PRESET", bridge)

    def test_frequency_meter_reset_uses_live_token_without_stm8_command(self):
        arm = (ROOT / "DPLL_Rewrite.sdk/DPLL_2COM/src/helloworld.c").read_text(
            encoding="utf-8"
        )
        lcd_driver = (
            ROOT / "MCU_src/STM32F030_LCD/HARDWARE/STM8Slave/STM8Slave.c"
        ).read_text(encoding="ascii")
        lcd_control = (ROOT / "MCU_src/STM32F030_LCD/USER/control.c").read_text(
            encoding="ascii"
        )
        stm8_main = (
            ROOT / "MCU_src/STM8S003_MX2871_IIC/src/main.c"
        ).read_text(encoding="ascii")

        self.assertIn("CONTROL_FREQ_METER_RESET_REQUEST 0xFEU", arm)
        self.assertIn("Control_Reset_Frequency_Meter();", arm)
        helper = re.search(
            r"static void Control_Reset_Frequency_Meter\(void\)\s*\{(.*?)\n\}",
            arm,
            re.S,
        )
        self.assertIsNotNone(helper)
        self.assertIn("Freq_Meter_Reset_Trigger_Addr", helper.group(1))
        self.assertNotIn("Opal_Kelly_Reset_Trigger_Addr", helper.group(1))

        request = re.search(
            r"uint8_t STM8_Slave_Reset_Frequency_Meter\(void\)\s*\{(.*?)\n\}",
            lcd_driver,
            re.S,
        )
        self.assertIsNotNone(request)
        self.assertIn("CTRL_REG_DEBUG_DAC_PRESET", request.group(1))
        self.assertIn("FREQ_METER_RESET_REQUEST", request.group(1))
        self.assertIn("STM8Slave_Write_Verified", request.group(1))
        self.assertNotIn("STM8Slave_Command", request.group(1))
        self.assertNotIn("0xC4", request.group(1))
        self.assertIn("KEY5_Long_Press", lcd_control)
        self.assertIn("STM8_Slave_Reset_Frequency_Meter", lcd_control)
        self.assertNotIn("case 0xC6", stm8_main)

    def test_arm_owns_center_frequency_mul_div_output_limit(self):
        arm = (ROOT / "DPLL_Rewrite.sdk/DPLL_2COM/src/helloworld.c").read_text(
            encoding="utf-8"
        )
        lcd = (ROOT / "MCU_src/STM32F030_LCD/USER/control.c").read_text(
            encoding="ascii"
        )
        self.assertIn("control_output_ratio_valid", arm)
        self.assertIn("CTRL_DPLL_OUTPUT_MAX_DHZ", arm)
        self.assertIn("(uint64_t)center_dhz * multiplier", arm)
        self.assertNotIn("CTRL_DPLL_OUTPUT_MAX_DHZ", lcd)
        self.assertNotIn("uint64_t", lcd)
        self.assertIn("STM8_Slave_Read_Status()", lcd)
        self.assertIn("CTRL_ERROR_NONE", lcd)
        self.assertIn("value + step <= CTRL_DPLL_CENTER_MAX_DHZ", lcd)
        self.assertIn("center > CTRL_DPLL_CENTER_MAX_DHZ", arm)

    def test_center_frequency_display_has_fixed_six_plus_one_layout(self):
        display = (ROOT / "MCU_src/STM32F030_LCD/USER/display.c").read_text(
            encoding="gbk"
        )
        body = re.search(
            r"void Display_UI_Show_PLL_Set_Freq\(.*?\n\}", display, re.S
        )
        self.assertIsNotNone(body)
        source = body.group(0)
        self.assertIn("LCD_Show_Square(82U, 49U, 62U, 16U, WHITE)", source)
        self.assertIn("display_unsigned(82U, 49U, frequency_hz, 6U", source)
        self.assertIn("LCD_SHOW_ASCII_1608(130U, 49U, '.', DARKBLUE)", source)
        self.assertIn("LCD_SHOW_ASCII_1608(134U, 49U", source)
        self.assertNotIn("if (frequency_hz >= 100000UL)", source)

    def test_max2871_range_includes_exact_lower_bound(self):
        source = (ROOT / "MCU_src/STM8S003_MX2871_IIC/src/MAX2871.c").read_text(
            encoding="gbk"
        )
        self.assertIn("fre < CTRL_MWS_FREQ_MIN_KHZ", source)
        self.assertIn("fre > CTRL_MWS_FREQ_MAX_KHZ", source)
        self.assertNotIn("else if(fre>23500)", source)

    def test_frozen_v3_docs_cover_pc_and_both_mcu_links(self):
        control_doc = CONTROL_DOC.read_text(encoding="utf-8")
        transport_doc = TRANSPORT_DOC.read_text(encoding="utf-8")
        self.assertIn("已实现并冻结，协议版本 `3`", control_doc)
        for command in ("`0x1D`", "`0x1E`", "`0x97`", "`0x98`", "`0x99`", "`0x9B`"):
            self.assertIn(command, control_doc)
        self.assertIn("`uint16 interval_ms`", control_doc)
        self.assertIn("失败时恢复提交前配置", control_doc)

        self.assertIn("`1 Mbps, 8N1`", transport_doc)
        self.assertIn("7 bit 地址 `0x25`", transport_doc)
        self.assertIn("READ/PING/SAVE: B1", transport_doc)
        self.assertIn("`C4`", transport_doc)
        self.assertIn("CRC 使用多项式 `0x1021`", transport_doc)
        self.assertIn("偏移 71", transport_doc)


if __name__ == "__main__":
    unittest.main()
