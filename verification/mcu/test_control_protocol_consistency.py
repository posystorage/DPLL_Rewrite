import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HEADERS = (
    ROOT / "DPLL_Rewrite.sdk/DPLL_2COM/src/control_protocol.h",
    ROOT / "MCU_src/STM8S003_MX2871_IIC/src/control_protocol.h",
    ROOT / "MCU_src/STM32F030_LCD/HARDWARE/STM8Slave/control_protocol.h",
)


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
        self.assertEqual(macros["CTRL_BANK_SIZE"], "96U")
        self.assertEqual(macros["CTRL_PERSIST_BEGIN"], "4U")
        self.assertEqual(macros["CTRL_PERSIST_END"], "64U")
        self.assertEqual(macros["CTRL_REG_PHASE_THRESHOLD_CDEG"], "44U")
        self.assertEqual(macros["CTRL_REG_PHASE_ERROR_CDEG"], "76U")

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
            r"static uint32_t control_dpll_output_hz\(void\)\s*\{(.*?)\n\}",
            source,
            re.S,
        )
        self.assertIsNotNone(body)
        self.assertIn("DPLL_TRACKING_WORD_HI_Addr", body.group(1))
        self.assertIn("PLL0_Output_Limit", body.group(1))
        self.assertNotIn("PLL0_Output_Limit_Average", body.group(1))


if __name__ == "__main__":
    unittest.main()
