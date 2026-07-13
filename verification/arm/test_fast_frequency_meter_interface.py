import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PERIPHERALS = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "Peripherals.h"
HELLOWORLD = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "helloworld.c"


def macro_hex(source, name):
    match = re.search(rf"#define\s+{re.escape(name)}\s+.*?\(0x([0-9A-Fa-f]+)<<2\)", source)
    if match is None:
        raise AssertionError(f"missing register macro {name}")
    return int(match.group(1), 16)


def command_hex(source, name):
    match = re.search(rf"#define\s+{re.escape(name)}\s+0x([0-9A-Fa-f]+)", source)
    if match is None:
        raise AssertionError(f"missing command macro {name}")
    return int(match.group(1), 16)


class FastFrequencyMeterInterfaceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.peripherals = PERIPHERALS.read_text(encoding="utf-8")
        cls.helloworld = HELLOWORLD.read_text(encoding="utf-8")

    def test_register_map(self):
        expected = {
            "Freq_Meter_Fast_Interval_Addr": 0x0073,
            "Freq_Meter_Fast_Status_Addr": 0x0114,
            "Freq_Meter_Fast_DataL_Output_Addr": 0x0115,
            "Freq_Meter_Fast_DataM_Output_Addr": 0x0116,
            "Freq_Meter_Fast_DataH_Output_Addr": 0x0117,
            "Freq_Meter_Fast_Result_Interval_Addr": 0x0118,
        }
        for name, address in expected.items():
            self.assertEqual(macro_hex(self.peripherals, name), address)

    def test_pc_commands_and_snapshot_guard(self):
        self.assertEqual(
            command_hex(self.helloworld, "PC_CMD_READ_FREQMETER_FAST_REFERENCE"), 0x1C
        )
        self.assertEqual(
            command_hex(self.helloworld, "PC_CMD_FREQMETER_FAST_INTERVAL"), 0x98
        )
        self.assertGreaterEqual(
            self.helloworld.count("Xil_In32(Freq_Meter_Fast_Status_Addr)"), 2
        )
        self.assertIn("PC_HOST_ASK_Pack(22);", self.helloworld)
        self.assertIn("if (interval_cycles == 0U)", self.helloworld)


if __name__ == "__main__":
    unittest.main()
