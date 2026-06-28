# Review P0 Post-IQ CIC Round/Warmup Closure

Date: 2026-06-28

## Scope

- Updated `post_iq_cic_stage_a` only; no public interface, register ABI, or top-level port changes.
- Added legal-APPLY/reset/flush warmup suppression for the first three decimated post-IQ CIC outputs.
- Added symmetric signed rounding before output saturation, using a one-bit widened signed pipeline to avoid minimum-negative absolute-value overflow.
- Preserved illegal post-IQ CIC configuration behavior: illegal `R` is rejected, `illegal_config_seen` is set, and the active CIC state is not flushed.

## Verification

- `scripts\run_iq_cic_stage_a_xsim.ps1`: PASS
- `scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS
- `scripts\run_dpll_multifrequency_path_xsim.ps1`: PASS
- `scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`: synthesis complete with refreshed reports

## Timing Notes

- `reports/vivado_single_clock_core_stage_a_project_synth/timing_summary_synth.rpt`
  - `pll_adc_clk` intra-clock setup WNS: `+0.701 ns`
  - Known remaining setup issue not addressed in this scope: `adc_clk -> pll_adc_clk` WNS `-2.816 ns`
  - Existing `clk_fpga_3` WNS remains `-0.370 ns`

## Guardrails

- No false paths were added.
- CIC was not replaced with FIR.
- No ARM register ABI change was made.
- No `clk_dpll` path was reintroduced.
