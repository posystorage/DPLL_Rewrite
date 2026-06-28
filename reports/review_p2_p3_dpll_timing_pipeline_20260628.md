# P2/P3 DPLL Timing Pipeline Report

Date: 2026-06-28
Tool: Vivado 2018.3
Branch: refactor/dpll-single-path

## Scope

This stage pipelines timing-critical paths inside the active single-clock DPLL path. It does not change the ARM register ABI, does not add a second DPLL, and does not reintroduce `clk_dpll` in the refactored core.

## RTL and IP Changes

- `mult_gen_pll` Xilinx IP was regenerated with `PipeStages=8` and matching `C_LATENCY=8`.
- `PLL_VCO_MUL_DIV` now waits for the 8-cycle multiplier latency before feeding the divider.
- `PLL_VCO_MUL_DIV` now registers divider quotient, round bit, rounded quotient, and saturated output in separate states.
- `loop_state_manager_stage_a` now registers thresholds, dwell counts, timeout values, and precomputed transition targets.
- `dpll_single_clock_core_stage_a` now snapshots state-manager measurements on the FLL-valid cadence.
- `dpll_single_clock_core_stage_a` now registers hybrid FLL/PLL filter enables, coefficients, and error inputs.
- `scripts/vivado_configure_mult_gen_pll_pipeline.tcl` configures, regenerates, and OOC-synthesizes the multiplier IP.

## Verification Run

The following regressions were run after the timing pipeline updates:

- `scripts/run_pll_vco_mul_div_xsim.ps1`: PASS.
- `scripts/run_single_clock_core_stage_a_xsim.ps1`: PASS.
- `scripts/run_dpll_multifrequency_path_xsim.ps1`: PASS.
- `scripts/run_loop_state_manager_stage_a_xsim.ps1`: PASS.
- `scripts/vivado_single_clock_core_stage_a_project_synth_check.tcl`: completed and produced updated synth timing/utilization reports.

## Synth Timing Snapshot

Report: `reports/vivado_single_clock_core_stage_a_project_synth/timing_summary_synth.rpt`

- `pll_adc_clk` intra-clock setup WNS: `+0.701 ns`.
- `pll_adc_clk` intra-clock setup TNS: `0.000 ns`.
- `pll_adc_clk` failing setup endpoints: `0`.
- `adc_clk -> pll_adc_clk` setup remains failing with WNS `-2.816 ns`; this is the known system bus direct crossing that is intentionally not fixed in this stage.
- `clk_fpga_3` setup remains failing with WNS `-0.370 ns`; this path is outside the active DPLL timing pipeline scope.
- Hold violations remain on DAC/debug and generated-clock crossings; these were not masked with false paths.

## Notes

- No false-path constraint was added for these failures.
- No public register ABI change was made.
- No post-IQ CIC runtime-R change was introduced.
- No high-order FIR replacement was introduced.
- Full implementation and bitstream should be rerun after the remaining non-DPLL timing work is either fixed or explicitly waived by project policy.
