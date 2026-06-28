#!/usr/bin/env python3
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DPLL = ROOT / "DPLL_Rewrite.srcs" / "sources_1" / "DigitalPLL"
SRC = ROOT / "DPLL_Rewrite.srcs" / "sources_1"
REPORT = ROOT / "reports" / "review2_closure_audit_20260628.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def check(condition: bool, label: str, evidence: str) -> tuple[str, bool]:
    status = "PASS" if condition else "FAIL"
    print(f"{status}: {label}")
    return f"| {status} | {label} | {evidence} |", condition


def git_tracked_files() -> set[str]:
    proc = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return set(proc.stdout.splitlines())


def main() -> int:
    core = read(DPLL / "core" / "dpll_single_clock_core_stage_a.v")
    dc = read(DPLL / "frontend" / "dc_blocker_valid_stage_a.v")
    fll = read(DPLL / "detector_fll" / "fll_phase_difference_stage_a.v")
    loop = read(DPLL / "hybrid_loop" / "loop_state_manager_stage_a.v")
    hybrid = read(DPLL / "hybrid_loop" / "hybrid_fll_pll_filter_stage_a.v")
    cic = read(DPLL / "iq_cic" / "post_iq_cic_stage_a.v")
    vco = read(DPLL / "VCO" / "PLL_VCO_MUL_DIV.v")
    wrapper = read(DPLL / "dpll_wrapper.v")
    periph = read(ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "Peripherals.h")
    arm = read(ROOT / "DPLL_Rewrite.sdk" / "DPLL_2COM" / "src" / "helloworld.c")
    vco_rfc = read(ROOT / "docs" / "rfc_vco_mul_div_config_status.md")
    dds_xci = read(SRC / "Freq_Meter" / "DDC" / "ip" / "LO_DDS_H" / "LO_DDS_H.xci")
    div_u_xci = read(DPLL / "VCO" / "div_gen_pll_u" / "div_gen_pll_u" / "div_gen_pll_u.xci")
    input_mult_sim = read(DPLL / "DDC" / "ip" / "input_multiplier" / "sim" / "input_multiplier.vhd")
    xpr = read(ROOT / "DPLL_Rewrite.xpr")
    tracked = git_tracked_files()

    checks: list[tuple[str, bool]] = []
    checks.append(check(
        "sample_out <= saturate_to_data(next_shifted_hp);" in dc
        and "out_valid <= 1'b1;" in dc
        and "if (out_valid)" not in dc,
        "DC blocker output data and valid update in the same input-valid cycle",
        "`sample_out` uses `next_hp_value` under `in_valid`",
    ))
    checks.append(check(
        "mixer_input_valid_r0 <= dc_valid && dds_valid;" in core
        and "if (dc_valid && dds_valid)" in core,
        "Mixer samples ADC and LO only when both DC blocker and DDS outputs are valid",
        "core gates mixer input with `dc_valid && dds_valid`",
    ))
    checks.append(check(
        "C_LATENCY => 1" in input_mult_sim
        and "mixer_product_valid <= mixer_input_valid_r1;" in core
        and "assign mixer_valid = mixer_product_valid;" in core,
        "Mixer valid is delayed for the configured one-cycle multiplier IP latency",
        "`input_multiplier` latency is 1 and core has a product-valid stage",
    ))
    checks.append(check(
        "(mixer_i_product[31] ? -32'sd16384 : 32'sd16384)" in core
        and "(mixer_q_product[31] ? -32'sd16384 : 32'sd16384)" in core,
        "Mixer rounding is sign-symmetric",
        "positive and negative products use opposite rounding bias",
    ))
    checks.append(check(
        ".measurement_timeout(holdover_timeout)" in core
        and "measurement_gap_count" in loop
        and "LOSS_TIMEOUT" in loop,
        "State manager has a no-measurement watchdog",
        "`measurement_gap_count` sends acquire/blend/track/reacquire to holdover on timeout",
    ))
    checks.append(check(
        ".measurement_valid(state_measurement_valid_r)" in core
        and "state_measurement_valid_r <= freq_error_valid_d;" in core,
        "State manager decisions are driven by valid FLL error samples",
        "core presents state measurements only after delayed `freq_error_valid`",
    ))
    checks.append(check(
        "input  wire                              clear" in fll
        and "if (rst_125m || clear)" in fll
        and ".clear(config_apply | (cordic_valid && !cordic_signal_usable))" in core,
        "FLL history clears on APPLY or unusable low-magnitude CORDIC samples",
        "FLL has explicit clear and core gates phase history by magnitude",
    ))
    checks.append(check(
        "illegal_config_seen <= 1'b0;" in cic
        and "config_apply && apply_is_legal" in cic,
        "Legal post-IQ CIC APPLY clears previous illegal-config fault",
        "sticky fault no longer permanently blocks recovery after a legal APPLY",
    ))
    checks.append(check(
        "tracking_phase_accumulator_stage_a" not in core
        and "PARAM_VALUE.Phase_Increment\">Streaming" in dds_xci
        and "LO_DDS_H tracking_lo_dds_inst" in core,
        "Active IQ LO uses DDS Streaming PINC without a redundant local phase accumulator",
        "`LO_DDS_H` is configured for streaming phase increment",
    ))
    checks.append(check(
        ".ambiguous(fll_ambiguous)" in core
        and "assign freq_error_usable = freq_error_valid && !fll_ambiguous;" in core
        and "hybrid_error_valid_r <= freq_error_usable;" in core
        and "state_measurement_valid_r <= freq_error_valid_d;" in core,
        "Ambiguous FLL measurements are blocked before state and hybrid-loop updates",
        "`fll_ambiguous` masks `freq_error_valid` through `freq_error_usable`",
    ))
    checks.append(check(
        "freq_state_after_update_next" in hybrid
        and "assign correction_sum_ext_next = freq_state_after_update_ext_next + {p_term_r[STATE_WIDTH-1], p_term_r};" in hybrid,
        "Hybrid filter correction uses the updated shared frequency state",
        "`freq_correction = sat(freq_state[k+1] + Kp*phase_error[k])`",
    ))
    checks.append(check(
        "reg [47:0] active_center_word;" in wrapper
        and "reg signed [23:0] active_kf;" in wrapper
        and "reg [15:0] active_vco_mul_factor;" in wrapper
        and "reg [15:0] active_vco_div_factor;" in wrapper
        and "reg config_apply_core_pulse;" in wrapper
        and "config_apply_core_pulse <= config_apply_pulse;" in wrapper
        and "if (config_apply_pulse) begin" in wrapper
        and ".config_apply(config_apply_core_pulse)" in wrapper
        and ".center_word(active_center_word)" in wrapper
        and ".kf(active_kf)" in wrapper
        and ".cic_rate_r(active_post_iq_cic_rate_r)" in wrapper
        and ".PLL_Mul_factor(active_vco_mul_factor)" in wrapper
        and ".PLL_Div_factor(active_vco_div_factor)" in wrapper
        and ".VCO_offset(active_vco_offset)" in wrapper
        and ".VCO_amplitude(active_vco_amplitude)" in wrapper
        and ".center_word({Centre_Freq, 16'h0000})" not in wrapper
        and ".PLL_Mul_factor(VCO_Mul_Factor0)" not in wrapper,
        "Wrapper applies a coherent active snapshot for loop and output configuration",
        "`CONFIG_APPLY` copies shadow registers into active core/VCO/DAC0 inputs",
    ))
    checks.append(check(
        "reg [7:0] config_apply_sequence;" in wrapper
        and "config_apply_sequence <= config_apply_sequence + 8'h01;" in wrapper
        and "16'h006F: sys_rdata <= {16'h0000, config_apply_sequence, 7'h00, config_apply_core_pulse};" in wrapper
        and "DPLL_CONFIG_APPLY_BUSY_MASK" in periph
        and "DPLL_CONFIG_APPLY_SEQ_MASK" in periph
        and "DPLL_APPLY_POLL_LIMIT" in arm
        and "PC_ERR_DPLL_APPLY_TIMEOUT" in arm
        and "Xil_In32(DPLL_CONFIG_APPLY_Addr)" in arm,
        "ARM waits for observable CONFIG_APPLY completion",
        "`CONFIG_APPLY` readback exposes busy/sequence status and ARM polls for a changed sequence before ACK",
    ))
    checks.append(check(
        "requested_config_is_legal" in vco
        and "PLL_Div_factor != 16'd0" in vco
        and "!PLL_Div_factor[15]" not in vco
        and "div_gen_pll_u VCO0_Divider" in vco
        and "PARAM_VALUE.operand_sign\">Unsigned" in div_u_xci
        and "MODELPARAM_VALUE.SIGNED_B\">0" in div_u_xci
        and "config_error <= 1'b1;" in vco
        and "safe_div_factor" not in vco
        and "safe_mul_factor" not in vco
        and "vco_divisor_safe" not in wrapper
        and "vco_mul_safe" not in wrapper,
        "VCO MUL/DIV rejects zero factors while using an unsigned divider for the full 16-bit DIV range",
        "`MUL=0` and `DIV=0` set sticky config error; `DIV[15]=1` is handled by `div_gen_pll_u`",
    ))
    checks.append(check(
        "wire shadow_vco_mul_div_legal = (VCO_Mul_Factor0 != 16'h0000) &&\n                                (VCO_Div_Factor0 != 16'h0000);" in wrapper
        and "VCO_Div_Factor0[15]" not in wrapper,
        "Wrapper APPLY path accepts the full unsigned 16-bit VCO DIV range",
        "`CONFIG_APPLY` rejects only `MUL=0` and `DIV=0`, not `DIV[15]=1`",
    ))
    checks.append(check(
        "vco_mul_div_config_error = vco_mul_div_runtime_config_error | vco_mul_div_apply_config_error" in wrapper
        and ".config_error(vco_mul_div_runtime_config_error)" in wrapper
        and "vco_mul_div_config_error" in wrapper
        and "DPLL_CORE_FLAG_VCO_MUL_DIV_CONFIG_ERROR (1U<<17)" in periph
        and "| 17 | `vco_mul_div_config_error` |" in vco_rfc,
        "VCO MUL/DIV configuration error is exposed through documented core status bit 17",
        "`DPLL_CORE_FLAGS_Addr[17]` reports sticky VCO scaling config errors",
    ))
    checks.append(check(
        "cordic_phase_out" in core
        and ".cordic_phase_out(dpll_cordic_phase)" in wrapper
        and "debug_tracking_delta" in wrapper
        and "debug_output_delta" in wrapper
        and "4'h1: debug_source_mux = debug_tracking_delta[47:16];" in wrapper
        and "4'h7: debug_source_mux = {{14{dpll_cordic_phase[17]}}, dpll_cordic_phase};" in wrapper
        and "4'h8: debug_source_mux = {16'h0000, dpll_magnitude};" in wrapper
        and "4'h9: debug_source_mux = debug_output_delta[47:16];" in wrapper
        and "4'h7: debug_source_mux = {{16{dpll_lo_cos[15]}}, dpll_lo_cos};" not in wrapper
        and "4'h8: debug_source_mux = {{16{dpll_lo_sin[15]}}, dpll_lo_sin};" not in wrapper,
        "DACout1 debug source selector matches register-map v1",
        "`DEBUG_DAC_SOURCE` values 1/7/8/9 map to tracking delta, CORDIC phase, magnitude, and output delta",
    ))
    legacy_dpll_xpr_entries = [
        "sources_1/DigitalPLL/frontend/tracking_phase_accumulator_stage_a.v",
        "sources_1/DigitalPLL/PID/",
        "sources_1/DigitalPLL/DDC/ip/fir_compiler_minimumphase/",
        "sources_1/DigitalPLL/DDC/ip/LO_DDS.xcix",
        "sources_1/DigitalPLL/DDC/ip/LO_DDS/LO_DDS.xci",
        "sources_1/DigitalPLL/DDC/N_times_clk_FIR_wrapper.vhd",
        "sources_1/DigitalPLL/DDC/ddc_frontend_lowpass_filter.vhd",
        "sources_1/DigitalPLL/DDC/ip/FIR_3_125MHz_Fstop240KHz_60db_28Order.coe",
        "sources_1/DigitalPLL/DDC/ip/FIR_3_125MHz_Fstop240KHz_98db_39Order.coe",
        "sources_1/DigitalPLL/DDC/ip/FIR_3_125MHz_Fstop60KHz_77db_159Order.coe",
        "sources_1/DigitalPLL/VCO/DAC_DDS/DAC_DDS.xci",
        "sources_1/DigitalPLL/VCO/div_gen_pll/div_gen_pll.xci",
        "sources_1/DigitalPLL/VCO/VCO_32bits.vhd",
        "sources_1/DigitalPLL/Assist/Status_Delay_Show.v",
        "sources_1/DigitalPLL/Assist/residuals_monitor.vhd",
        "sources_1/DigitalPLL/Assist/residuals_monitor_with_offset.vhd",
        "sources_1/DigitalPLL/DDC/boxcar_2_pts_filter.vhd",
        "sources_1/DigitalPLL/DDC/quantizer.vhd",
        "sources_1/DigitalPLL/DDC/limiter.vhd",
    ]
    legacy_tracked_prefixes = [
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/PID/",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/fir_compiler_minimumphase/",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/cic_compiler_0/",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/VCO/DAC_DDS/",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/VCO/div_gen_pll/",
    ]
    legacy_tracked_files = [
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/LO_DDS.xcix",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/N_times_clk_FIR_wrapper.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ddc_frontend_lowpass_filter.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/adjustable_boxcar_filter_v2.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/boxcar_4_pts_filter.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/first_order_IIR_highpass_filter.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/VCO/VCO_32bits.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/Assist/PLL_output_average.v",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/Assist/Status_LED_driver.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/Assist/Status_Delay_Show.v",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/Assist/residuals_monitor.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/Assist/residuals_monitor_with_offset.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/boxcar_2_pts_filter.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/quantizer.vhd",
        "DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/limiter.vhd",
    ]
    remaining_legacy_tracked = sorted(
        path for path in tracked
        if any(path.startswith(prefix) for prefix in legacy_tracked_prefixes)
        or path in legacy_tracked_files
    )
    checks.append(check(
        all(entry not in xpr for entry in legacy_dpll_xpr_entries)
        and not remaining_legacy_tracked
        and "pre_iq_cic_40_125m_v1 pre_iq_cic_40_inst" in wrapper
        and "sources_1/Freq_Meter/DDC/ip/fir_compiler_minimumphase_H/fir_compiler_minimumphase_H.xci" in xpr
        and "sources_1/Freq_Meter/DDC/ip/LO_DDS_H/LO_DDS_H.xci" in xpr
        and "sources_1/Freq_Meter/Assist/Status_Delay_Show.v" in xpr
        and "sources_1/Freq_Meter/Assist/residuals_monitor.vhd" in xpr
        and "sources_1/Freq_Meter/Assist/residuals_monitor_with_offset.vhd" in xpr
        and "sources_1/Freq_Meter/DDC/boxcar_2_pts_filter.vhd" in xpr
        and "sources_1/Freq_Meter/DDC/quantizer.vhd" in xpr
        and "sources_1/Freq_Meter/DDC/limiter.vhd" in xpr
        and "sources_1/DigitalPLL/VCO/DAC_DDS0/DAC_DDS0.xci" in xpr,
        "DPLL legacy FIR/PID/DDS/Assist sources are removed or moved out of the DPLL namespace",
        "`DPLL_Rewrite.xpr` no longer lists old DPLL FIR/PID/DDC/DDS/Assist entries; Git no longer tracks retired legacy trees; Freq_Meter helper files are under `Freq_Meter/*`",
    ))

    lines = [
        "# Review2 Closure Audit",
        "",
        "Generated by `python scripts\\audit_review2_closure.py`.",
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
