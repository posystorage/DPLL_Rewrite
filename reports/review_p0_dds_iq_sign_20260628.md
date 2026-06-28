# Review P0 DDS/IQ Sign Closure

Date: 2026-06-28

## Scope

- Aligned the DPLL Q mixer sign with the existing Xilinx `LO_DDS_H` DDS IP configuration.
- `LO_DDS_H.xci` has `Negative_Sine=true`; the DPLL Q mixer now consumes the sine output directly instead of applying a second negation.
- No public interface, register ABI, top-level port, or IP configuration changes were made.

## Evidence

- Old DDC path uses `DDS_sine <= lo_dds_m_axis_data_tdata(31 downto 16)` directly as the Q multiplier input.
- New audit script: `scripts/audit_dds_iq_sign.py`
  - Confirms `LO_DDS_H Negative_Sine=true`
  - Confirms Q mixer uses `.B(lo_sin_r1)`
  - Confirms Q mixer does not use `.B(-lo_sin_r1)`

## Verification

- `python scripts\audit_dds_iq_sign.py`: PASS
- `scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS
- `scripts\run_dpll_multifrequency_path_xsim.ps1`: PASS
- `scripts\run_detector_fll_stage_a_xsim.ps1`: PASS
- `scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`: synthesis complete

## Timing Notes

- `reports/vivado_single_clock_core_stage_a_project_synth/timing_summary_synth.rpt`
  - `pll_adc_clk` intra-clock setup WNS: `+0.701 ns`
  - Known exception not addressed in this scope: `adc_clk -> pll_adc_clk` WNS `-2.816 ns`
  - Existing `clk_fpga_3` WNS remains `-0.370 ns`

## Guardrails

- No false paths were added.
- No FIR substitution was introduced.
- DDS, multiplier, CIC, and CORDIC remain Xilinx IP based.
- No ARM register ABI change was made.
