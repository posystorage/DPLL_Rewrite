# P5 Hybrid Loop Stage A Summary

Date: 2026-06-28

Branch: `agent/hybrid-loop`

Scope:
- Added `hybrid_fll_pll_filter_stage_a`, a 125 MHz valid-driven FLL/PI blend primitive.
- Implements `freq_state[k+1] = sat(freq_state[k] + Kf*ef + Ki*ephi)` and `freq_correction = sat(freq_state + Kp*ephi)`.
- Outputs full 56-bit correction and only saturates to 48-bit at final `tracking_word = center_word + correction`.
- Does not implement PII2, PID D, or D-filter semantics.
- Uses internal pipeline stages so multiplier, term generation, correction sum, and output saturation are not on one 125 MHz path.

Integration status:
- The module is intentionally not wired into `dpll_wrapper.v` yet.
- No top-level port, ARM register ABI, or DAC debug behavior changed.

Verification:
- `python -m unittest discover -s verification\fixed_point -p test_*.py`: 7 tests passed.
- `python scripts\audit_clk_dpll_usage.py`: `active_clk_dpll_hits=36`.
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_hybrid_loop_stage_a_xsim.ps1`: `hybrid_fll_pll_filter_stage_a_tb` passed.
- `vivado.bat -mode batch -source scripts\vivado_hybrid_loop_stage_a_synth_check.tcl`: completed with 0 errors, 0 critical warnings, and 1 synthesis warning.

OOC report snapshot:
- `hybrid_fll_pll_filter_stage_a`: 665 LUT, 826 FF, 3 DSP.
- Timing at 125 MHz OOC check: WNS 2.024 ns, TNS 0.000 ns.
- Vivado emits an OOC `HD.CLK_SRC` warning because clock buffer placement is unknown in isolated synthesis.
- Vivado also reports one optimized unused sequential element in the FLL product path; this does not remove the FLL calculation behavior covered by xsim.
