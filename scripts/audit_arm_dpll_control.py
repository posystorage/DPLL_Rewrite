#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARM = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "helloworld.c"
PERIPH = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "Peripherals.h"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="strict")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"FAIL: {label}")
    print(f"PASS: {label}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise SystemExit(f"FAIL: {label}")
    print(f"PASS: {label}")


def main() -> None:
    arm = read_text(ARM)
    periph = read_text(PERIPH)

    require(periph, "DPLL_ABI_VERSION_Addr", "ARM header exposes DPLL ABI register")
    require(periph, "DPLL_CONFIG_VERSION_Addr", "ARM header exposes DPLL config version register")
    require(periph, "DPLL_FPGA_BUILD_ID_Addr", "ARM header exposes DPLL build ID register")
    require(periph, "DPLL_CONFIG_APPLY_Addr", "ARM header exposes DPLL CONFIG_APPLY register")
    require(periph, "DPLL_POST_IQ_CIC_R_Addr", "ARM header exposes post-IQ CIC R register")

    require(arm, "ARM_EXPECTED_DPLL_ABI_VERSION", "ARM declares expected DPLL ABI")
    require(arm, "ARM_EXPECTED_DPLL_CONFIG_VERSION", "ARM declares expected DPLL config version")
    require(arm, "ARM_EXPECTED_DPLL_FPGA_BUILD_ID", "ARM declares expected DPLL FPGA build ID")
    require(arm, "status = dpll_driver_check_abi(&dpll_driver);", "ARM checks DPLL ABI through the tested driver")
    require(arm, "status = dpll_driver_apply(&dpll_driver, result);", "ARM APPLY uses the tested driver")
    require(arm, "return (dpll_apply_config() == 0) ? STATUS_ACK : STATUS_NACK;", "STM config write reports APPLY success")
    require(arm, "action_status = (dpll_set_enable(1) == 0) ? STATUS_ACK : STATUS_NACK;", "STM PLL ON reports ABI-gated enable result")
    require(arm, "if (action_status != 0)", "STM read-status path does not send duplicate ACK")
    require(arm, "if (dpll_set_enable(1) != 0)", "PC PLL ON is ABI-gated")
    require(arm, "if (dpll_apply_config() != 0)", "PC config APPLY is ABI-gated")
    forbid(arm, "STM_HOST_ASK_Status(STATUS_ACK);\n\t\t\tswitch(STM_HOST_CMD_GET)", "STM no longer ACKs before executing command")

    print("PASS: arm_dpll_control_audit")


if __name__ == "__main__":
    main()
