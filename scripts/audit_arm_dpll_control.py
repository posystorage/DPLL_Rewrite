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
    require(periph, "DPLL_RECONFIGURE_Addr", "ARM header exposes local reconfigure command")
    require(periph, "DPLL_POST_IQ_CIC_R_Addr", "ARM header exposes post-IQ CIC R register")
    require(periph, "DPLL_RESERVED_0070_Addr", "retired APPLY error register is explicitly reserved")
    require(periph, "DPLL_RESERVED_011E_Addr", "retired FPGA config CRC register is explicitly reserved")

    require(arm, "ARM_EXPECTED_DPLL_ABI_VERSION", "ARM declares expected DPLL ABI")
    require(arm, "ARM_EXPECTED_DPLL_CONFIG_VERSION", "ARM declares expected DPLL config version")
    require(arm, "ARM_EXPECTED_DPLL_FPGA_BUILD_ID", "ARM declares expected DPLL FPGA build ID")
    require(arm, "status = dpll_driver_check_abi(&dpll_driver);", "ARM checks DPLL ABI through the tested driver")
    require(arm, "static int dpll_commit_candidate", "ARM owns the DPLL candidate transaction")
    require(arm, "dpll_validate_config(candidate", "ARM validates the complete DPLL candidate")
    require(arm, "dpll_driver_write_config(", "ARM writes only validated active configuration")
    require(arm, "apply_status = dpll_commit_candidate(&candidate);", "STM control bank uses the candidate transaction")
    require(arm, "status = dpll_commit_candidate(&candidate);", "PC advanced API uses the candidate transaction")
    require(arm, "dpll_driver_set_enable(&dpll_driver, enable)", "enable remains ABI-gated through the driver")
    require(arm, "freq_meter_commit_candidate", "frequency-meter configuration has one ARM dispatcher")
    require(arm, "debug_dac_commit_candidate", "debug DAC configuration has one ARM dispatcher")
    forbid(arm, "Xil_In32(DPLL_RESERVED_011E_Addr)", "ARM does not depend on FPGA configuration CRC")
    forbid(arm, "control_output_ratio_valid", "ARM does not impose a derived MUL/DIV output-frequency policy")
    forbid(arm, "dpll_driver_apply", "ARM has no global FPGA APPLY polling")
    forbid(arm, "restore_status = dpll_stage_and_apply", "ARM has no failed-path FPGA rollback")

    print("PASS: arm_dpll_control_audit")


if __name__ == "__main__":
    main()
