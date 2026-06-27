# P4 IQ CIC Stage A Summary

Date: 2026-06-28

Branch: `agent/iq-cic`

Scope:
- Added `post_iq_cic_stage_a`, a 125 MHz post-IQ CIC primitive for shared I/Q decimation.
- Configuration uses shadow `rate_r` and `output_shift`; active configuration changes only on `config_apply`.
- Illegal `rate_r` values are rejected and recorded without changing the active configuration.
- Added internal pipeline stages through decimation, comb, barrel shift, and output saturation so the OOC 125 MHz timing check has positive slack.

Integration status:
- The module is intentionally not wired into `dpll_wrapper.v` yet.
- No top-level port, ARM register ABI, or DAC debug behavior changed.
- This does not replace the required CIC with a high-order FIR.
- Stage A uses arithmetic right shift truncation before saturation; symmetric rounding remains a P4 numerical refinement item before final tuned integration.

Verification:
- `python -m unittest discover -s verification\fixed_point -p test_*.py`: 7 tests passed.
- `python scripts\audit_clk_dpll_usage.py`: `active_clk_dpll_hits=36`.
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_iq_cic_stage_a_xsim.ps1`: `post_iq_cic_stage_a_tb` passed.
- `vivado.bat -mode batch -source scripts\vivado_iq_cic_stage_a_synth_check.tcl`: completed with 0 errors, 0 critical warnings, and 0 synthesis warnings.

OOC report snapshot:
- `post_iq_cic_stage_a`: 882 LUT, 1574 FF, 0 DSP.
- Timing at 125 MHz OOC check: WNS 3.123 ns, TNS 0.000 ns.
- Vivado emits an OOC `HD.CLK_SRC` warning because clock buffer placement is unknown in isolated synthesis.
