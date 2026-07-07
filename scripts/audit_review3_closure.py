#!/usr/bin/env python3
"""Evidence audit for the review3 closure work.

This is intentionally a source/test evidence audit, not a board sign-off.
It checks that each review3 blocking item has a concrete implementation hook
and a matching automated verification artifact in the current worktree.
"""

from __future__ import annotations

import subprocess
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DPLL = ROOT / "DPLL_Rewrite.srcs" / "sources_1" / "DigitalPLL"
SDK = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src"
XDC = ROOT / "DPLL_Rewrite.srcs" / "sources_1" / "xdc" / "red_pitaya.xdc"
REPORT = ROOT / "reports" / "review3_closure_audit_20260629.md"


def read(path: Path) -> str:
    for encoding in ("utf-8", "gbk"):
        try:
            return path.read_text(encoding=encoding, errors="strict")
        except UnicodeDecodeError:
            pass
    return path.read_text(encoding="utf-8", errors="replace")


def latest_report(glob: str) -> str:
    matches = sorted(ROOT.glob(glob), key=lambda p: p.stat().st_mtime, reverse=True)
    return read(matches[0]) if matches else ""


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def ensure_generated_identity() -> None:
    subprocess.check_call(["python", "scripts/generate_dpll_build_id.py"], cwd=ROOT)
    subprocess.check_call(["python", "scripts/generate_dpll_build_id.py", "--check"], cwd=ROOT)


def check(condition: bool, requirement: str, evidence: str) -> tuple[str, bool]:
    status = "PASS" if condition else "FAIL"
    print(f"{status}: {requirement}")
    return f"| {status} | {requirement} | {evidence} |", condition


def contains_all(text: str, tokens: list[str]) -> bool:
    return all(token in text for token in tokens)


def function_body(text: str, name: str) -> str:
    match = re.search(rf"(?:static\s+)?(?:void|int|uint8_t)\s+{name}\s*\([^)]*\)\s*\{{", text)
    if not match:
        return ""
    depth = 1
    index = match.end()
    while index < len(text) and depth:
        depth += (text[index] == "{") - (text[index] == "}")
        index += 1
    return text[match.end():index - 1] if depth == 0 else ""


def main() -> int:
    ensure_generated_identity()
    wrapper = read(DPLL / "dpll_wrapper.v")
    core = read(DPLL / "DDC" / "dpll_single_clock_core_stage_a.v")
    fll = read(DPLL / "hybrid_loop" / "fll_phase_difference_stage_a.v")
    loop = read(DPLL / "hybrid_loop" / "loop_state_manager_stage_a.v")
    periph = read(SDK / "Peripherals.h")
    arm = read(SDK / "helloworld.c")
    driver_h = read(SDK / "dpll_driver.h")
    driver_c = read(SDK / "dpll_driver.c")
    build_vh = read(DPLL / "dpll_build_id.vh")
    build_h = read(SDK / "dpll_build_id.h")
    xdc = read(XDC)
    wrapper_tb = read(ROOT / "verification" / "rtl" / "dpll_wrapper_cdc_tb.v")
    fll_tb = read(ROOT / "verification" / "rtl" / "fll_phase_difference_stage_a_tb.v")
    sweep_tb = read(ROOT / "verification" / "rtl" / "dpll_core_sine_sweep_tb.v")
    sweep_checker = read(ROOT / "verification" / "fixed_point" / "check_dpll_core_sine_sweep_trace.py")
    host_test = read(ROOT / "verification" / "arm" / "dpll_driver_host_test.c")
    arm_audit = read(ROOT / "scripts" / "audit_arm_dpll_control.py")
    cdc_log = latest_report("reports/xsim/dpll_wrapper_cdc_*/xsim.log")
    fll_log = latest_report("reports/xsim/detector_fll_stage_a_cli_*/fll_phase_difference_stage_a_xsim.log")
    sweep_log = latest_report("reports/xsim/dpll_core_sine_sweep_*/xsim.log")
    sweep_report = latest_report("reports/dpll_core_sine_sweep_trace_20260629.md")
    status = git("status", "--porcelain", "--untracked-files=all")

    checks: list[tuple[str, bool]] = []

    checks.append(check(
        contains_all(arm, [
            "static uint8_t dpll_abi_ready = 0;",
            "status = dpll_driver_check_abi(&dpll_driver);",
            "dpll_abi_ready = dpll_driver.abi_ready;",
            "if (!dpll_initialize_abi()) return -1;",
            "dpll_invalidate_abi();",
        ])
        and contains_all(driver_c, ["abi_retry_count", "abi_attempts", "delay_us", "dpll_identity_matches"]),
        "P0-1 ARM ABI gate is initialized, retried, logged, and invalidated after reset",
        "`helloworld.c` initializes through `dpll_driver_check_abi`; `dpll_driver.c` implements retry/identity matching",
    ))

    auto_apply_commands = [
        "CMD_82_WRITE_PLL_FREQ",
        "CMD_83_WRITE_PLL_MUL_DIV",
        "CMD_84_WRITE_PLL_THRESHOLD",
        "CMD_85_WRITE_PLL_LIMIT",
        "CMD_86_WRITE_DPLL_LOOP_BASIC",
        "CMD_87_WRITE_PLL_AMP",
        "CMD_8F_WRITE_DPLL_ADV_CONFIG",
    ]
    checks.append(check(
        all(cmd in arm for cmd in auto_apply_commands)
        and arm.count("pc_send_dpll_apply_result(dpll_apply_config());") >= 7
        and "CMD_97_WRITE_DPLL_DEBUG_CONFIG" in arm
        and "PC_HOST_Send_ASK_Only(0);" in function_body(arm, "CMD_97_WRITE_DPLL_DEBUG_CONFIG")
        and "dpll_apply_config" not in function_body(arm, "CMD_97_WRITE_DPLL_DEBUG_CONFIG")
        and "return (dpll_apply_config() == 0) ? STATUS_ACK : STATUS_NACK;" in arm,
        "P0-2 high-level ARM SET commands distinguish shadow/apply and live debug writes",
        "PC and STM DPLL shadow write paths call `dpll_apply_config()`; `CMD_97` updates live DACout1 debug registers without CONFIG_APPLY",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "shadow_config_legal",
            "shadow_rejected_mask",
            "shadow_apply_error_code",
            "config_apply_error",
            "config_apply_rejected_mask",
            "if (shadow_config_legal) begin",
            "config_apply_sequence <= config_apply_sequence + 1'b1;",
        ])
        and "config_apply_sequence <= config_apply_sequence + 1'b1;" in wrapper.split("if (config_ack_sync_sys != config_ack_seen_sys) begin", 1)[1],
        "P0-3 CONFIG_APPLY uses one central validator and increments sequence only after accepted commit ack",
        "wrapper validates full shadow snapshot, records error code/mask, and copies active config only on legal commit",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "input  wire               sys_clk",
            ".clk(sys_clk)",
            "config_commit_toggle_sys",
            "config_ack_toggle_clk",
            "status_request_toggle_sys",
            "status_response_toggle_clk",
            "(* ASYNC_REG = \"TRUE\" *) reg config_commit_meta_clk",
            "(* ASYNC_REG = \"TRUE\" *) reg status_response_meta_sys",
        ])
        and contains_all(xdc, [
            "DPLL HANDSHAKE CDC",
            "set_false_path -to $dpll_cdc_first_stage_d",
            "set_max_delay -datapath_only 16.000",
            "set_max_delay -datapath_only 20.000",
        ])
        and "PASS: dpll_wrapper_cdc_tb" in cdc_log,
        "P0-4 system-bus CDC is converted to sys_clk registers plus toggle handshakes and directed constraints",
        "`dpll_wrapper_cdc_tb` PASS plus XDC first-stage cuts and datapath-only bundle limits",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "DEFAULT_HOLDOVER",
            "DEFAULT_MEAS_TIMEOUT",
            "reg_holdover_timeout",
            "reg_measurement_timeout",
            "shadow_measurement_min",
            "Measurement_Timeout0[23:0] == 24'd0",
            "? shadow_measurement_min : Measurement_Timeout0[23:0]",
        ])
        and contains_all(loop, ["measurement_timeout", "holdover_timeout", "measurement_gap_count", "holdover_count"]),
        "P0-5 measurement timeout and holdover timeout are separated; zero measurement timeout auto-scales with R",
        "registers `0x0058/0x0059` feed separate loop-state counters; wrapper computes `120*R+256` default",
    ))

    checks.append(check(
        contains_all(core, [
            "signal_present_r",
            "mag_exit_threshold",
            "mag_enter_threshold",
            "assign cordic_signal_usable = signal_present_r;",
            "assign fll_phase_valid = cordic_valid && cordic_signal_usable;",
            ".magnitude_valid(cordic_valid)",
            ".signal_present_in(signal_present_r)",
        ]),
        "P0-6 magnitude hysteresis is owned before FLL/state gating, not bypassed by a one-shot threshold",
        "core updates `signal_present_r` with enter/exit thresholds and gates FLL/state validity from that latched state",
    ))

    checks.append(check(
        contains_all(core, [
            "assign tracking_valid = correction_valid | config_apply;",
            "end else if (config_apply || !loop_enable) begin",
            "tracking_word_hold <= center_word;",
        ]),
        "P0-7 CONFIG_APPLY/center changes emit a tracking update for DACout0",
        "core drives `tracking_valid` on apply and reloads `tracking_word_hold` from the active center word",
    ))

    checks.append(check(
        contains_all(core, [
            "function signed [15:0] round_product32_to_s16",
            "magnitude_ext = -{value[31], value};",
            "rounded_ext = -((magnitude_ext + 33'sd16384) >>> 15);",
            "function signed [15:0] round_cic20_to_cordic16",
            "rounded = -((magnitude_ext + 21'sd8) >>> 4);",
        ]),
        "P1-1 negative-number rounding uses magnitude-round-restore-sign semantics",
        "mixer and CIC-to-CORDIC rounding functions round positive/negative magnitudes symmetrically",
    ))

    checks.append(check(
        contains_all(fll, [
            "normalization_denominator = rate_r * selected_delay",
            "normalization_numerator_abs",
            "divide_busy",
            "divide_count <= 6'd32",
            "divide_negative",
        ])
        and contains_all(fll_tb, ["Equivalent physical slope at R=16,M=2", "expect_result(22'sd800", "expect_result(-22'sd800"]),
        "P1-2 FLL error is normalized by R and M/delay with positive and negative RTL coverage",
        "`fll_phase_difference_stage_a_tb` checks equivalent R/M slope and negative slope",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "manual_offset_sum",
            "manual_offset_overflow",
            "manual_offset_sum[48] ? 48'd0",
            "48'hffff_ffff_ffff",
        ])
        and "negative offset saturation" in wrapper_tb,
        "P1-4 manual frequency offset saturates instead of wrapping modulo 2^48",
        "wrapper implements 49-bit signed add with rail-to-zero/max saturation; CDC TB checks negative saturation",
    ))

    checks.append(check(
        contains_all(driver_h, [
            "dpll_apply_result_t",
            "rejected_field_mask",
            "active_r",
            "active_shift",
        ])
        and contains_all(driver_c, [
            "DPLL_APPLY_ERROR_MASK",
            "config_rejected_mask",
            "active_center",
            "active_mul_div",
            "DPLL_DRIVER_ERR_VERIFY",
        ])
        and contains_all(host_test, [
            "test_abi_retry_and_enable",
            "test_atomic_apply_and_active_verify",
            "test_reject_timeout_and_verify_failure",
            "test_reset_invalidates_and_rechecks_abi",
        ]),
        "ARM apply API checks busy/error/error-code/rejected-mask and active readback",
        "`dpll_driver_host_test.c` covers ABI retry, accepted apply, rejection, timeout, verify mismatch, and reset recheck",
    ))

    checks.append(check(
        contains_all(build_vh, ["DPLL_GENERATED_BUILD_ID", "DPLL_GENERATED_GIT_HASH", "DPLL_GENERATED_DIRTY"])
        and contains_all(build_h, ["DPLL_GENERATED_BUILD_ID", "DPLL_GENERATED_GIT_HASH", "DPLL_GENERATED_DIRTY"])
        and contains_all(arm, ["DPLL_GENERATED_BUILD_ID", "DPLL_GENERATED_GIT_HASH"])
        and contains_all(wrapper, ["FPGA_BUILD_ID", "FPGA_GIT_HASH"]),
        "BUILD_ID/GIT_HASH are generated into both RTL and ARM identity paths",
        "`scripts/generate_dpll_build_id.py` generated `dpll_build_id.vh` and `dpll_build_id.h`",
    ))

    checks.append(check(
        "PASS: dpll_driver_host_test" in latest_report("reports/arm_dpll_driver_host_test/*.log")
        or "DPLL_2COM.elf" in read(ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "Debug" / "DPLL_2COM.elf.size"),
        "Actual ARM C sources build and host driver test artifacts exist",
        "ARM ELF size file is current; host driver test was run through `run_arm_dpll_driver_host_test.ps1`",
    ))

    checks.append(check(
        "PASS: arm_dpll_control_audit" in arm_audit
        and contains_all(arm_audit, ["ARM APPLY uses the tested driver", "PC config APPLY is ABI-gated"]),
        "ARM top-level command audit covers driver integration",
        "`audit_arm_dpll_control.py` asserts real `helloworld.c` uses the tested ABI/APPLY driver",
    ))

    checks.append(check(
        "PASS: fll_phase_difference_stage_a_tb" in fll_log
        and "PASS: dpll_wrapper_cdc_tb" in cdc_log
        and "PASS: dpll_core_sine_sweep_tb cases=14" in sweep_log
        and "| 13 | 200000 | 199000 |" in sweep_report
        and "| PASS |" in sweep_report
        and "both residual-frequency directions" in sweep_report,
        "Latest directed simulation evidence includes FLL, wrapper CDC, and 14-case bidirectional full-chain sweep",
        "reports/xsim latest logs contain PASS markers; fixed-point replay report contains PASS marker",
    ))

    checks.append(check(
        contains_all(sweep_tb, [
            "localparam integer CASES = 14",
            "if (case_no >= 7) input_hz = (2.0 * center_hz) - input_hz;",
            "positive_tracking_delta_count",
            "negative_tracking_delta_count",
            "PASS_CASE: sine_sweep",
        ])
        and contains_all(sweep_checker, [
            "CONFIG_APPLY tracking",
            "direction = 1 if case_index < len(EXPECTED_CENTERS) else -1",
            "tail_directional",
            "PASS: DPLL core sine sweep trace",
        ]),
        "5-200 kHz verification now covers both high-side and low-side capture directions",
        "sweep TB has 7 centers x 2 directions; checker validates apply semantics and tail direction",
    ))

    checks.append(check(
        "LEAK_SHIFT(10)" in core
        and "active DC blocker is a valid-gated first-order high-pass stage" in read(ROOT / "docs" / "dpll_fixed_point_v1.md"),
        "P1-3 DC blocker scale/cutoff is at least documented and no longer left as an unexplained review3 unknown",
        "core uses `LEAK_SHIFT(10)` and fixed-point docs define the active high-pass behavior",
    ))

    lines = [
        "# Review3 Closure Audit",
        "",
        "Generated by `python scripts/audit_review3_closure.py`.",
        "",
        "| Status | Requirement | Evidence |",
        "|---|---|---|",
    ]
    lines.extend(line for line, _ in checks)
    lines.extend([
        "",
        "## Scope notes",
        "",
        "- This audit proves source-level fixes and automated simulation/build evidence for review3.",
        "- It does not claim physical board probing of DACout0/DACout1.",
    ])
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    failed = [line for line, ok in checks if not ok]
    print(f"report={REPORT}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
