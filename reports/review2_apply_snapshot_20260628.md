# Review2 Apply Snapshot Closure

Date: 2026-06-28

Scope:
- Closed the review2 `CONFIG_APPLY` gap for the active DPLL wrapper without changing the public register ABI.
- Bus registers remain the shadow configuration view.
- `CONFIG_APPLY` now copies loop/output fields into an internal active snapshot before they reach the DPLL core, VCO scaler, and DAC0 VCO.
- Invalid VCO MUL/DIV shadow settings are rejected at APPLY time and do not overwrite the previous active factors.

Active snapshot fields:
- Center frequency word.
- FLL/PLL gains for acquire, blend, and track.
- Phase/frequency lock thresholds and phase setpoint.
- Magnitude enter/exit thresholds.
- Acquire, blend, loss, holdover, and warmup counters.
- Positive and negative correction limits.
- Post-IQ CIC R/shift and FLL delay select.
- Manual output offset, DAC0 offset/amplitude, output MUL/DIV.

Verification:
- `python scripts\audit_review2_closure.py`: PASS.
- `python scripts\audit_review_closure.py`: PASS.
- `python scripts\audit_clk_dpll_usage.py`: PASS, active hits = 0.
- `powershell -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS.
- `vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`: PASS after the delayed core-apply update; synthesis completed with 0 errors and 0 critical warnings.

Known residual:
- The synthesis timing summary still reports timing violations. This change does not claim timing closure.
