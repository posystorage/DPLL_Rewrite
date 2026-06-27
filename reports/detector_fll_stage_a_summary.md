# Detector FLL Stage A Summary

Date: 2026-06-28

Branch: `agent/detector-fll`

Scope:
- Added `fll_phase_difference_stage_a`, a valid-driven phase difference primitive for FLL error generation.
- Supports delay selections 1, 2, 4, and 8 phase-valid samples.
- Contains no integrator and no `clk_dpll` input.

Integration status:
- The module is intentionally not wired into `dpll_wrapper.v` yet.
- No top-level port, ARM register ABI, or DAC debug behavior changed.

Verification:
- `python -m unittest discover -s verification\fixed_point -p test_*.py`: 7 tests passed.
- `python scripts\audit_clk_dpll_usage.py`: `active_clk_dpll_hits=36`.
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_detector_fll_stage_a_xsim.ps1`: `fll_phase_difference_stage_a_tb` passed.
- `vivado.bat -mode batch -source scripts\vivado_detector_fll_stage_a_synth_check.tcl`: completed with 0 errors, 0 critical warnings, and 0 synthesis warnings.

OOC report snapshot:
- `fll_phase_difference_stage_a`: 51 LUT, 97 FF, 0 DSP.
- Timing at 125 MHz OOC check: WNS 2.056 ns, TNS 0.000 ns.
- Vivado emits an OOC `HD.CLK_SRC` warning because clock buffer placement is unknown in isolated synthesis.
