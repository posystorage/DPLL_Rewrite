#!/usr/bin/env python3
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "DPLL_Rewrite.srcs" / "sources_1"
REPORT = ROOT / "reports" / "review2_ip_config_audit_20260628.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def xml_value(text: str, ref: str) -> str | None:
    pattern = rf'referenceId="{re.escape(ref)}">([^<]+)<'
    m = re.search(pattern, text)
    return m.group(1) if m else None


def check(condition: bool, label: str, evidence: str) -> tuple[str, bool]:
    status = "PASS" if condition else "FAIL"
    print(f"{status}: {label}")
    return f"| {status} | {label} | {evidence} |", condition


def main() -> int:
    lo_xci = read(SRC / "Freq_Meter" / "DDC" / "ip" / "LO_DDS_H" / "LO_DDS_H.xci")
    cic_xci = read(SRC / "DigitalPLL" / "DDC" / "ip" / "pre_iq_cic_40_125m_v1" / "pre_iq_cic_40_125m_v1" / "pre_iq_cic_40_125m_v1.xci")
    cordic_xci = read(SRC / "DigitalPLL" / "DDC" / "ip" / "angle_CORDIC" / "angle_CORDIC.xci")
    wrapper = read(SRC / "DigitalPLL" / "dpll_wrapper.v")
    core = read(SRC / "DigitalPLL" / "core" / "dpll_single_clock_core_stage_a.v")
    div_xci = read(SRC / "DigitalPLL" / "VCO" / "div_gen_pll_u" / "div_gen_pll_u" / "div_gen_pll_u.xci")
    manifest_path = ROOT / "reports" / "review2_ip_config_regen" / "manifest.txt"
    manifest = read(manifest_path) if manifest_path.exists() else ""

    lo_clock = xml_value(lo_xci, "PARAM_VALUE.DDS_Clock_Rate")
    lo_phase_increment = xml_value(lo_xci, "PARAM_VALUE.Phase_Increment")
    lo_phase_width = xml_value(lo_xci, "PARAM_VALUE.Phase_Width")
    lo_output = xml_value(lo_xci, "PARAM_VALUE.Output_Selection")

    cic_clock = xml_value(cic_xci, "PARAM_VALUE.Clock_Frequency")
    cic_input_sample_frequency = xml_value(cic_xci, "PARAM_VALUE.Input_Sample_Frequency")
    cic_rate = xml_value(cic_xci, "PARAM_VALUE.Fixed_Or_Initial_Rate")
    cic_stages = xml_value(cic_xci, "PARAM_VALUE.Number_Of_Stages")
    cic_diff_delay = xml_value(cic_xci, "PARAM_VALUE.Differential_Delay")
    cic_has_out_ready = xml_value(cic_xci, "PARAM_VALUE.HAS_DOUT_TREADY")
    cic_has_in_ready = xml_value(cic_xci, "BUSIFPARAM_VALUE.S_AXIS_DATA.HAS_TREADY")

    cordic_function = xml_value(cordic_xci, "PARAM_VALUE.Functional_Selection")
    cordic_format = xml_value(cordic_xci, "PARAM_VALUE.Data_Format")
    cordic_phase_format = xml_value(cordic_xci, "PARAM_VALUE.Phase_Format")
    cordic_input_width = xml_value(cordic_xci, "PARAM_VALUE.Input_Width")
    cordic_output_width = xml_value(cordic_xci, "PARAM_VALUE.Output_Width")
    cordic_coarse = xml_value(cordic_xci, "PARAM_VALUE.Coarse_Rotation")
    cordic_scale = xml_value(cordic_xci, "PARAM_VALUE.Compensation_Scaling")

    div_algorithm = xml_value(div_xci, "PARAM_VALUE.algorithm_type")
    div_sign = xml_value(div_xci, "PARAM_VALUE.operand_sign")
    div_model_sign = xml_value(div_xci, "MODELPARAM_VALUE.SIGNED_B")
    div_latency = xml_value(div_xci, "PARAM_VALUE.latency")
    div_flow = xml_value(div_xci, "PARAM_VALUE.FlowControl")
    pre_iq_ready_report = read(ROOT / "reports" / "review2_pre_iq_cic_ready_20260629.md")
    pre_iq_ready_tb = read(ROOT / "verification" / "rtl" / "pre_iq_cic_ready_tb.v")
    pre_iq_ready_checker = read(ROOT / "verification" / "fixed_point" / "check_pre_iq_cic_ready_trace.py")

    checks: list[tuple[str, bool]] = []
    checks.append(check(
        lo_clock == "125" and lo_phase_increment == "Streaming" and lo_phase_width == "48" and lo_output == "Sine_and_Cosine",
        "LO_DDS_H regenerated for the active 125 MHz single-clock DPLL path",
        f"`DDS_Clock_Rate={lo_clock}`, `Phase_Increment={lo_phase_increment}`, `Phase_Width={lo_phase_width}`, `Output_Selection={lo_output}`",
    ))
    checks.append(check(
        cic_rate == "40" and cic_stages == "4" and cic_diff_delay == "2" and cic_has_out_ready == "false",
        "pre-IQ CIC functional parameters remain fixed /40 non-blocking decimation",
        f"`R={cic_rate}`, `N={cic_stages}`, `M={cic_diff_delay}`, `HAS_DOUT_TREADY={cic_has_out_ready}`",
    ))
    checks.append(check(
        cic_has_in_ready == "1"
        and ".s_axis_data_tready(pre_cic_ready)" in wrapper
        and "ready_low_count != 0" in pre_iq_ready_tb
        and "pre-IQ CIC input ready deasserted" in pre_iq_ready_checker
        and "ADC source is not back-pressure aware" in pre_iq_ready_report,
        "pre-IQ CIC input TREADY exposure is documented and covered by continuous-ready simulation",
        "`S_AXIS_DATA.HAS_TREADY=1`; wrapper observes `pre_cic_ready`; xsim trace fails if ready deasserts during continuous ADC-valid input",
    ))
    checks.append(check(
        cic_clock == "125.0" and cic_input_sample_frequency == "125.0",
        "pre-IQ CIC clock metadata is regenerated for 125 MHz",
        f"`Clock_Frequency={cic_clock}`, `Input_Sample_Frequency={cic_input_sample_frequency}`",
    ))
    checks.append(check(
        "pre_iq_cic_40_125m_v1 pre_iq_cic_40_inst" in wrapper,
        "active wrapper uses the regenerated pre-IQ CIC replacement",
        "`dpll_wrapper.v` instantiates `pre_iq_cic_40_125m_v1` for `pre_iq_cic_40_inst`",
    ))
    checks.append(check(
        cordic_function == "Translate"
        and cordic_format == "SignedFraction"
        and cordic_phase_format == "Scaled_Radians"
        and cordic_input_width == "16"
        and cordic_output_width == "16"
        and cordic_coarse == "true"
        and cordic_scale == "No_Scale_Compensation",
        "CORDIC IP is configured for active DPLL phase/magnitude detection",
        f"`Function={cordic_function}`, `Format={cordic_format}`, `Phase={cordic_phase_format}`, `Width={cordic_input_width}/{cordic_output_width}`, `Coarse={cordic_coarse}`, `Scale={cordic_scale}`",
    ))
    checks.append(check(
        "function signed [15:0] round_cic20_to_cordic16;" in core
        and ".s_axis_cartesian_tdata({cordic_q_in, cordic_i_in})" in core
        and "q_baseband[CIC_WIDTH-1 -: 16]" not in core,
        "CORDIC input pack uses explicit 20-bit to 16-bit rounding and saturation",
        "`dpll_single_clock_core_stage_a.v` no longer directly truncates post-IQ CIC high bits into the CORDIC",
    ))
    checks.append(check(
        div_algorithm == "Radix2" and div_sign == "Unsigned" and div_model_sign == "0",
        "VCO divider IP is replaced with an unsigned Vivado 2018.3 instance",
        f"`algorithm_type={div_algorithm}`, `operand_sign={div_sign}`, `SIGNED_B={div_model_sign}`",
    ))
    checks.append(check(
        div_latency == "32" and div_flow == "NonBlocking",
        "VCO divider latency and flow control remain explicitly managed",
        f"`latency={div_latency}`, `FlowControl={div_flow}`",
    ))
    checks.append(check(
        "note.cic.Clock_Frequency disabled" in manifest and "note.div.operand_sign disabled" in manifest,
        "Vivado 2018.3 IP regeneration limitations are recorded",
        "`reports/review2_ip_config_regen/manifest.txt` records why replacement IPs were required for disabled existing-instance parameters",
    ))

    lines = [
        "# Review2 IP Configuration Audit",
        "",
        "Generated by `python scripts\\audit_review2_ip_config.py`.",
        "",
        "| Status | Requirement | Evidence |",
        "|---|---|---|",
    ]
    lines.extend(line for line, _ in checks)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    failed = [line for line, ok in checks if not ok]
    print(f"report={REPORT}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
