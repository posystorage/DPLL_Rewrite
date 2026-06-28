import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARM = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "helloworld.c"
PERIPH = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "Peripherals.h"


def read_gbk(path: Path) -> str:
    return path.read_text(encoding="gbk", errors="strict")


def parse_expected(name: str, text: str) -> int:
    match = re.search(rf"#define\s+{name}\s+0x([0-9A-Fa-f]+)U", text)
    if not match:
        raise AssertionError(f"missing {name}")
    return int(match.group(1), 16)


def parse_dpll_addr(name: str, text: str) -> int:
    escaped = re.escape(name)
    direct = re.search(rf"#define\s+{escaped}\s+\(DPLL_BASE_ADDR\|\(0x([0-9A-Fa-f]+)<<2\)\)", text)
    if direct:
        return int(direct.group(1), 16) << 2

    alias = re.search(rf"#define\s+{escaped}\s+([A-Za-z0-9_]+)", text)
    if alias:
        return parse_dpll_addr(alias.group(1), text)

    raise AssertionError(f"missing DPLL address macro {name}")


def u32le(payload: bytes, offset: int) -> int:
    return int.from_bytes(payload[offset:offset + 4], "little")


def u16le(payload: bytes, offset: int) -> int:
    return int.from_bytes(payload[offset:offset + 2], "little")


class MockMmio:
    def __init__(self):
        self.mem = {}
        self.writes = []

    def read(self, addr: int) -> int:
        return self.mem.get(addr, 0)

    def write(self, addr: int, value: int) -> None:
        value &= 0xFFFFFFFF
        self.mem[addr] = value
        self.writes.append((addr, value))


class DpllArmModel:
    def __init__(self, addrs: dict[str, int], expected: dict[str, int], mmio: MockMmio):
        self.addrs = addrs
        self.expected = expected
        self.mmio = mmio
        self.abi_ready = False
        self.pll_lock_status = 0

    def check_abi(self) -> bool:
        ok = (
            self.mmio.read(self.addrs["DPLL_ABI_VERSION_Addr"]) == self.expected["ABI"]
            and self.mmio.read(self.addrs["DPLL_CONFIG_VERSION_Addr"]) == self.expected["CONFIG"]
            and self.mmio.read(self.addrs["DPLL_FPGA_BUILD_ID_Addr"]) == self.expected["BUILD"]
        )
        self.abi_ready = ok
        return ok

    def apply_config(self) -> int:
        if not self.abi_ready:
            self.mmio.write(self.addrs["PLL0_Lock_Ctrl_Addr"], 0)
            return -1
        self.mmio.write(self.addrs["DPLL_CONFIG_APPLY_Addr"], 1)
        return 0

    def set_enable(self, enable: int) -> int:
        if enable and not self.abi_ready:
            self.mmio.write(self.addrs["PLL0_Lock_Ctrl_Addr"], 0)
            self.pll_lock_status = 0
            return -1
        self.mmio.write(self.addrs["PLL0_Lock_Ctrl_Addr"], 1 if enable else 0)
        self.pll_lock_status = 0x20 if enable else 0
        return 0

    def write_adv_config(self, payload: bytes) -> int:
        if len(payload) < 46 or payload[3] < 42:
            return 0xF2

        sequence = [
            ("DPLL_FLL_KF_TRACK_Addr", u32le(payload, 4)),
            ("DPLL_PLL_KP_BLEND_Addr", u32le(payload, 8)),
            ("DPLL_PLL_KI_BLEND_Addr", u32le(payload, 12)),
            ("DPLL_MAG_ENTER_THRESHOLD_Addr", u32le(payload, 16)),
            ("DPLL_MAG_EXIT_THRESHOLD_Addr", u32le(payload, 20)),
            ("DPLL_ACQUIRE_DWELL_Addr", u32le(payload, 24)),
            ("DPLL_BLEND_DWELL_Addr", u32le(payload, 28)),
            ("DPLL_LOSS_DWELL_Addr", u32le(payload, 32)),
            ("DPLL_HOLDOVER_TIMEOUT_Addr", u32le(payload, 36)),
            ("DPLL_POST_IQ_CIC_R_Addr", u16le(payload, 40)),
            ("DPLL_POST_IQ_CIC_SHIFT_Addr", payload[42]),
            ("DPLL_FLL_DELAY_SEL_Addr", payload[43]),
            ("DPLL_WARMUP_SAMPLES_Addr", u16le(payload, 44)),
        ]
        for name, value in sequence:
            self.mmio.write(self.addrs[name], value)

        return 0 if self.apply_config() == 0 else self.expected["ABI_ERR"]


class DpllArmMockMmioTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.arm = read_gbk(ARM)
        cls.periph = read_gbk(PERIPH)
        names = [
            "PLL0_Lock_Ctrl_Addr",
            "DPLL_CONFIG_APPLY_Addr",
            "DPLL_ABI_VERSION_Addr",
            "DPLL_CONFIG_VERSION_Addr",
            "DPLL_FPGA_BUILD_ID_Addr",
            "DPLL_FLL_KF_TRACK_Addr",
            "DPLL_PLL_KP_BLEND_Addr",
            "DPLL_PLL_KI_BLEND_Addr",
            "DPLL_MAG_ENTER_THRESHOLD_Addr",
            "DPLL_MAG_EXIT_THRESHOLD_Addr",
            "DPLL_ACQUIRE_DWELL_Addr",
            "DPLL_BLEND_DWELL_Addr",
            "DPLL_LOSS_DWELL_Addr",
            "DPLL_HOLDOVER_TIMEOUT_Addr",
            "DPLL_POST_IQ_CIC_R_Addr",
            "DPLL_POST_IQ_CIC_SHIFT_Addr",
            "DPLL_FLL_DELAY_SEL_Addr",
            "DPLL_WARMUP_SAMPLES_Addr",
        ]
        cls.addrs = {name: parse_dpll_addr(name, cls.periph) for name in names}
        cls.expected = {
            "ABI": parse_expected("ARM_EXPECTED_DPLL_ABI_VERSION", cls.arm),
            "CONFIG": parse_expected("ARM_EXPECTED_DPLL_CONFIG_VERSION", cls.arm),
            "BUILD": parse_expected("ARM_EXPECTED_DPLL_FPGA_BUILD_ID", cls.arm),
            "ABI_ERR": parse_expected("PC_ERR_DPLL_ABI_MISMATCH", cls.arm),
        }

    def make_model(self):
        mmio = MockMmio()
        return mmio, DpllArmModel(self.addrs, self.expected, mmio)

    def load_good_abi(self, mmio: MockMmio) -> None:
        mmio.mem[self.addrs["DPLL_ABI_VERSION_Addr"]] = self.expected["ABI"]
        mmio.mem[self.addrs["DPLL_CONFIG_VERSION_Addr"]] = self.expected["CONFIG"]
        mmio.mem[self.addrs["DPLL_FPGA_BUILD_ID_Addr"]] = self.expected["BUILD"]

    def test_source_keeps_abi_gate_and_payload_len_contract(self):
        self.assertIn("if (!dpll_abi_ready)", self.arm)
        self.assertIn("Xil_Out32(DPLL_CONFIG_APPLY_Addr, 1);", self.arm)
        self.assertIn("if (pc_payload_len() < 42)", self.arm)
        self.assertIn("Xil_Out32(DPLL_WARMUP_SAMPLES_Addr, pc_get_u16(44));", self.arm)

    def test_abi_mismatch_forces_lock_off_and_blocks_enable_apply(self):
        mmio, model = self.make_model()
        self.assertFalse(model.check_abi())
        self.assertEqual(model.set_enable(1), -1)
        self.assertEqual(model.apply_config(), -1)
        self.assertEqual(
            mmio.writes,
            [
                (self.addrs["PLL0_Lock_Ctrl_Addr"], 0),
                (self.addrs["PLL0_Lock_Ctrl_Addr"], 0),
            ],
        )

    def test_matching_abi_allows_enable_and_config_apply(self):
        mmio, model = self.make_model()
        self.load_good_abi(mmio)
        self.assertTrue(model.check_abi())
        self.assertEqual(model.set_enable(1), 0)
        self.assertEqual(model.apply_config(), 0)
        self.assertEqual(
            mmio.writes[-2:],
            [
                (self.addrs["PLL0_Lock_Ctrl_Addr"], 1),
                (self.addrs["DPLL_CONFIG_APPLY_Addr"], 1),
            ],
        )

    def test_advanced_config_writes_shadow_registers_then_apply(self):
        mmio, model = self.make_model()
        self.load_good_abi(mmio)
        self.assertTrue(model.check_abi())

        fields = [
            0x01020304,
            0x11121314,
            0x21222324,
            0x31323334,
            0x41424344,
            0x51525354,
            0x61626364,
            0x71727374,
            0x81828384,
        ]
        payload = bytearray(46)
        payload[3] = 42
        for index, value in enumerate(fields):
            payload[4 + index * 4:8 + index * 4] = value.to_bytes(4, "little")
        payload[40:42] = (0x0123).to_bytes(2, "little")
        payload[42] = 0x09
        payload[43] = 0x02
        payload[44:46] = (0x0033).to_bytes(2, "little")

        self.assertEqual(model.write_adv_config(bytes(payload)), 0)
        expected_names = [
            "DPLL_FLL_KF_TRACK_Addr",
            "DPLL_PLL_KP_BLEND_Addr",
            "DPLL_PLL_KI_BLEND_Addr",
            "DPLL_MAG_ENTER_THRESHOLD_Addr",
            "DPLL_MAG_EXIT_THRESHOLD_Addr",
            "DPLL_ACQUIRE_DWELL_Addr",
            "DPLL_BLEND_DWELL_Addr",
            "DPLL_LOSS_DWELL_Addr",
            "DPLL_HOLDOVER_TIMEOUT_Addr",
            "DPLL_POST_IQ_CIC_R_Addr",
            "DPLL_POST_IQ_CIC_SHIFT_Addr",
            "DPLL_FLL_DELAY_SEL_Addr",
            "DPLL_WARMUP_SAMPLES_Addr",
            "DPLL_CONFIG_APPLY_Addr",
        ]
        self.assertEqual([addr for addr, _ in mmio.writes], [self.addrs[name] for name in expected_names])
        self.assertEqual([value for _, value in mmio.writes[-5:]], [0x0123, 0x09, 0x02, 0x0033, 1])

    def test_short_advanced_config_payload_does_not_touch_mmio(self):
        mmio, model = self.make_model()
        payload = bytearray(46)
        payload[3] = 41
        self.assertEqual(model.write_adv_config(bytes(payload)), 0xF2)
        self.assertEqual(mmio.writes, [])


if __name__ == "__main__":
    unittest.main()
