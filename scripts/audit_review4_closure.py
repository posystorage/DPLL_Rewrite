#!/usr/bin/env python3
"""Source/evidence audit for review4 closure.

This audit is intentionally narrow: it checks that the review4 P0 fixes and
the Vivado source-tree orphan explanation are backed by current source and
test artifacts. It is not a replacement for full Vivado implementation
sign-off.
"""

from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
XPR = ROOT / "DPLL_Rewrite.xpr"
TOP = ROOT / "DPLL_Rewrite.srcs" / "sources_1" / "ReadPitaya" / "red_pitaya_top.v"
DPLL = ROOT / "DPLL_Rewrite.srcs" / "sources_1" / "DigitalPLL"
SDK = ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src"
REPORT = ROOT / "reports" / "review4_closure_audit_20260629.md"
CIC_SHIFT_REPORT = ROOT / "reports" / "cic_shift_model_20260630.md"


def read(path: Path) -> str:
    for encoding in ("utf-8", "gbk"):
        try:
            return path.read_text(encoding=encoding, errors="strict")
        except UnicodeDecodeError:
            pass
    return path.read_text(encoding="utf-8", errors="replace")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def contains_all(text: str, tokens: list[str]) -> bool:
    return all(token in text for token in tokens)


def check(condition: bool, requirement: str, evidence: str) -> tuple[str, bool]:
    status = "PASS" if condition else "FAIL"
    print(f"{status}: {requirement}")
    return f"| {status} | {requirement} | {evidence} |", condition


def main() -> int:
    xpr = read(XPR)
    top = read(TOP)
    core = read(DPLL / "core" / "dpll_single_clock_core_stage_a.v")
    wrapper = read(DPLL / "dpll_wrapper.v")
    arm = read(SDK / "helloworld.c")
    driver_h = read(SDK / "dpll_driver.h")
    driver_c = read(SDK / "dpll_driver.c")
    periph = read(SDK / "Peripherals.h")
    generator = read(ROOT / "scripts" / "generate_dpll_build_id.py")
    vco_mul_div = read(DPLL / "VCO" / "PLL_VCO_MUL_DIV.v")
    mult_xci = read(DPLL / "VCO" / "mult_gen_pll" / "mult_gen_pll.xci")
    fixed_point_doc = read(ROOT / "docs" / "dpll_fixed_point_v1.md")
    cic_shift_audit = read(ROOT / "scripts" / "audit_cic_shift_model.py")
    cic_shift_report = read(CIC_SHIFT_REPORT) if CIC_SHIFT_REPORT.exists() else ""
    system_bus_clock_audit = read(ROOT / "scripts" / "audit_system_bus_clock.py")
    system_bus_clock_report = read(ROOT / "reports" / "system_bus_clock_audit_20260630.md") if (ROOT / "reports" / "system_bus_clock_audit_20260630.md").exists() else ""
    core_tb = read(ROOT / "verification" / "rtl" / "dpll_single_clock_core_stage_a_tb.v")
    wrapper_tb = read(ROOT / "verification" / "rtl" / "dpll_wrapper_cdc_tb.v")
    arm_tb = read(ROOT / "verification" / "arm" / "dpll_driver_host_test.c")
    frontend_summary = read(ROOT / "reports" / "frontend_stage_a_summary.md")

    checks: list[tuple[str, bool]] = []

    checks.append(check(
        contains_all(xpr, [
            'File Path="$PSRCDIR/sources_1/DigitalPLL/frontend/iq_mixer_stage_a.v"',
            'File Path="$PSRCDIR/sources_1/ReadPitaya/FIFO_addr_packed/FIFO_addr_packed.xci"',
            'File Path="$PSRCDIR/sources_1/ReadPitaya/FSM_addr_packed.vhd"',
            'File Path="$PSRCDIR/sources_1/ReadPitaya/addr_packed.vhd"',
            '<Attr Name="AutoDisabled" Val="1"/>',
            '<Option Name="TopModule" Val="red_pitaya_top"/>',
        ]),
        "Vivado places addr_packed and iq_mixer_stage_a outside the active hierarchy because they are AutoDisabled under red_pitaya_top",
        "`DPLL_Rewrite.xpr` marks these files/IP as `AutoDisabled=1` while the active top is `red_pitaya_top`",
    ))

    checks.append(check(
        contains_all(top, [
            "dpll_wrapper dpll_wrapper_inst",
            ".sys_wen                 (  sys_wen[6]",
            ".sys_ren                 (  sys_ren[6]",
            ".sys_ack                 (  sys_ack[6]",
            "assign dac_a = DACout0;",
            "assign dac_b = DACout1;",
        ])
        and "addr_packed_inst" not in top
        and "FIFO_addr_packed" not in top,
        "The active top-level path is dpll_wrapper on bus channel 6; addr_packed is not instantiated",
        "`red_pitaya_top.v` instantiates `dpll_wrapper` and only retains addr_packed comments/wires from the older logger path",
    ))

    checks.append(check(
        contains_all(frontend_summary, [
            "`iq_mixer_stage_a` remains available for isolated validation",
            "active DDS IP path",
            "No top-level port, ARM register ABI, or DAC debug behavior changed",
        ])
        and contains_all(core, [
            "input_multiplier input_multiplier_i_inst",
            "input_multiplier input_multiplier_q_inst",
            "mixer_i_product_r <= mixer_i_product;",
            "mixer_q_product_r <= mixer_q_product;",
            "assign mixer_i_rounded = round_product32_to_s16(mixer_i_product_r);",
            "assign mixer_q_rounded = round_product32_to_s16(mixer_q_product_r);",
        ]),
        "iq_mixer_stage_a is a retained isolated validation primitive, not the active mixer implementation",
        "The active core uses the Xilinx `input_multiplier` IP path; frontend summary documents the retained isolated mixer",
    ))

    checks.append(check(
        contains_all(core, [
            "assign tracking_word = config_apply ? center_word : tracking_word_hold;",
            "assign tracking_valid = correction_valid | config_apply;",
        ])
        and contains_all(core_tb, [
            "config_apply did not present center word with valid",
            "tracking_word !== 48'h0100_0000_0000",
        ]),
        "P0-1 CONFIG_APPLY presents the new center word on the same cycle as tracking_valid",
        "`dpll_single_clock_core_stage_a.v` drives a config_apply mux; the core TB checks valid/data alignment",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "wire signed [49:0] manual_offset_sum",
            "$signed({2'b00, dpll_tracking_word})",
            "manual_offset_sum > $signed({2'b00, 48'hffff_ffff_ffff})",
            "? 48'hffff_ffff_ffff : manual_offset_sum[47:0]",
        ])
        and "positive offset saturation" in wrapper_tb,
        "P0-2 manual frequency offset uses a 50-bit signed sum and saturates positive overflow to max",
        "`dpll_wrapper.v` uses a 50-bit intermediate; wrapper CDC TB covers positive and negative saturation",
    ))

    checks.append(check(
        contains_all(arm, [
            "#define PC_HOST_MAX_FRAME_BYTES           64U",
            "#define DPLL_ADV_CONFIG_PAYLOAD_BYTES     46U",
            "if((Uart0_RX_Num<4)||(Uart0_RX_Num>PC_HOST_MAX_FRAME_BYTES))",
            "if (pc_payload_len() < DPLL_ADV_CONFIG_PAYLOAD_BYTES)",
        ]),
        "P0-3 PC UART parser accepts the 50-byte advanced-config frame",
        "`helloworld.c` raises the PC frame limit to 64 bytes while the advanced payload remains 46 bytes",
    ))

    checks.append(check(
        ".cic_flush(reset_pulse_clk)" in wrapper and ".cic_flush(ok_reset)" not in wrapper,
        "P0-4 CIC flush is driven by the clk1-domain reset pulse, not the sys_clk ok_reset strobe",
        "`dpll_wrapper.v` connects `cic_flush` to `reset_pulse_clk`",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "sys_err <= config_apply_busy;",
            "assign cmd_trig   = sys_wen && !config_apply_busy;",
        ])
        and "busy write did not return err" in wrapper_tb,
        "P1 busy writes are rejected visibly instead of silently modifying shadow state",
        "wrapper returns `sys_err` while busy; CDC TB checks a busy write error",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "shadow_width_legal",
            "shadow_magnitude_legal",
            "shadow_cic_shift_legal",
            "post_iq_cic_shift + 6'd1 >= shadow_expected_cic_shift",
            "post_iq_cic_shift <= shadow_expected_cic_shift + 6'd3",
            "APPLY_ERR_WIDTH",
            "Magnitude_Enter_Threshold0[15:0] > Magnitude_Exit_Threshold0[15:0]",
        ])
        and contains_all(wrapper_tb, [
            "illegal coefficient width accepted",
            "equal magnitude thresholds accepted",
            "conservative CIC shift legal value rejected",
        ]),
        "P1 validator covers width, magnitude hysteresis, and CIC shift range semantics",
        "`dpll_wrapper.v` central validator and wrapper CDC TB cover the review4 validation gaps",
    ))

    checks.append(check(
        contains_all(cic_shift_audit, [
            "CicShiftRow(8, 4)",
            "CicShiftRow(16, 7)",
            "CicShiftRow(31, 10)",
            "CicShiftRow(78, 13)",
            "CicShiftRow(156, 16)",
            "CicShiftRow(312, 19)",
            "ceil_log2(row.rate_r ** 3)",
            "5 <= retained_gain_bits <= 6",
        ])
        and contains_all(cic_shift_report, [
            "Post-IQ CIC Shift Model Audit",
            "retained gain bits",
            "5 to 6",
            "recommended_shift - 1",
            "recommended_shift + 3",
            "PASS: the implemented table preserves 5 to 6 retained gain bits",
        ])
        and contains_all(fixed_point_doc, [
            "reports/cic_shift_model_20260630.md",
            "scripts/audit_cic_shift_model.py",
            "DPLL_CORE_FLAGS[0]",
        ]),
        "P1 CIC shift table is backed by a reproducible model audit and documented as a bounded configuration contract",
        "`audit_cic_shift_model.py` checks the R/shift table against `ceil(log2(R^3))`; the fixed-point doc references the generated report",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "function [31:0] dpll_config_crc",
            "wire [31:0] active_config_crc",
            "16'h011E: status_response_data_clk <= active_config_crc",
        ])
        and contains_all(periph, [
            "DPLL_ACTIVE_CONFIG_CRC_Addr",
            "(0x011E<<2)",
        ])
        and contains_all(driver_h, [
            "shadow_phase_threshold",
            "shadow_debug_dac_format",
            "active_config_crc",
        ])
        and contains_all(driver_c, [
            "dpll_expected_active_config_crc",
            "shadow_measurement_timeout",
            "shadow_negative_limit",
            "active_config_crc",
        ])
        and contains_all(arm_tb, [
            "APPLY_BAD_CRC",
            "test_active_crc_covers_non_legacy_readback_fields",
        ])
        and "active config crc" in wrapper_tb,
        "P1 ARM applies verify the complete active configuration through an active-config CRC",
        "RTL exposes `0x011E` active CRC; ARM driver computes the same normalized CRC over shadow fields and host/RTL tests cover mismatch detection",
    ))

    tracked_build_headers = {
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/dpll_build_id.vh",
        "DPLL_Rewrite.sdk/DPLL_2COM/src/dpll_build_id.h",
    }.issubset(set(git("ls-files").splitlines()))
    checks.append(check(
        tracked_build_headers
        and contains_all(generator, [
            "CONFIG_VERSION = 0x00010003",
            "VERILOG_HEADER",
            "ARM_HEADER",
        ]),
        "Build identity headers are tracked fallbacks and the generator carries the current config version",
        "`dpll_build_id.vh` and `dpll_build_id.h` exist in git for GUI/SDK clean checkout; generator updates them for scripted builds",
    ))

    checks.append(check(
        contains_all(wrapper, [
            "reg pre_cic_backpressure_seen",
            "if (~rst_125m_stage_a && !pre_cic_ready)",
            "pre_cic_backpressure_seen <= 1'b1",
        ])
        and contains_all(periph, [
            "DPLL_CORE_FLAG_PRE_CIC_BACKPRESSURE",
            "(1U<<19)",
        ])
        and "pre-CIC backpressure fault not latched" in wrapper_tb,
        "Pre-IQ CIC input backpressure is latched into a readable fault bit",
        "`DPLL_CORE_FLAGS[19]` reports any deasserted pre-CIC `TREADY`; wrapper CDC TB forces the fault path",
    ))

    checks.append(check(
        "localparam integer MULT_LATENCY = 8" in vco_mul_div
        and 'MODELPARAM_VALUE.C_LATENCY">8<' in mult_xci,
        "VCO multiplier RTL latency assumption matches the generated multiplier IP latency",
        "`PLL_VCO_MUL_DIV.v` and `mult_gen_pll.xci` both specify an 8-cycle multiplier latency",
    ))

    checks.append(check(
        ".axi0_clk_i(adc_clk)" in top
        and ".axi0_clk_i(adc_clk_in)" not in top
        and contains_all(system_bus_clock_audit, [
            ".axi0_clk_i(adc_clk)",
            "not .axi0_clk_i(adc_clk_in)",
            "raw ADC input clock",
        ])
        and contains_all(system_bus_clock_report, [
            "System Bus Clock Audit",
            "PASS",
            "PLL/BUFG ADC clock",
        ]),
        "The PS GP0/system-bus clock is aligned with the PLL/BUFG ADC peripheral clock",
        "`red_pitaya_top.v` drives `axi0_clk_i` from `adc_clk`; `audit_system_bus_clock.py` records the timing intent",
    ))

    lines = [
        "# Review4 Closure Audit",
        "",
        "Scope: current working tree.",
        "",
        "Generated by `python scripts/audit_review4_closure.py`.",
        "",
        "| Status | Requirement | Evidence |",
        "|---|---|---|",
    ]
    lines.extend(line for line, _ in checks)
    lines.extend([
        "",
        "## Scope Notes",
        "",
        "- This audit explains why Vivado shows `addr_packed` and `iq_mixer_stage_a` outside the active hierarchy.",
        "- This audit checks source/test evidence for review4 closure. It does not claim a fresh full implementation sign-off.",
    ])
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    failed = [line for line, ok in checks if not ok]
    print(f"report={REPORT}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
