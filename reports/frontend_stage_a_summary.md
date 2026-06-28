# P3 Frontend Stage A Summary

Date: 2026-06-28

Branch: `agent/frontend-nco-mixer`

Superseded:
This is a historical Stage A snapshot. Current `refactor/dpll-single-path`
uses the Xilinx `LO_DDS_H` Streaming PINC DDS for the active IQ LO and no
longer tracks `tracking_phase_accumulator_stage_a` or its standalone test.

Scope:
- Added `tracking_phase_accumulator_stage_a`, a 125 MHz phase accumulator primitive with no `clk_dpll` input. This primitive was later retired and removed from the active repository.
- Added `iq_mixer_stage_a`, a 125 MHz signed IQ mixer primitive with explicit `in_valid` / `out_valid` handoff.
- Added isolated xsim testbenches and OOC synthesis checks for both primitives.

Verification:
- `python -m unittest discover -s verification\fixed_point -p test_*.py`: 7 tests passed.
- `python scripts\audit_clk_dpll_usage.py`: `active_clk_dpll_hits=36`.
- Historical run: `powershell.exe -ExecutionPolicy Bypass -File scripts\run_frontend_stage_a_xsim.ps1` passed `tracking_phase_accumulator_stage_a_tb` and `iq_mixer_stage_a_tb`. The current script only runs the retained `iq_mixer_stage_a_tb`.
- `vivado.bat -mode batch -source scripts\vivado_frontend_stage_a_synth_check.tcl`: completed with 0 errors, 0 critical warnings, and 0 synthesis warnings for both primitives.

OOC report snapshot:
- Retired `tracking_phase_accumulator_stage_a`: 49 LUT, 49 FF, 0 DSP, WNS 5.010 ns against the 8 ns `clk_125m` check.
- `iq_mixer_stage_a`: 64 LUT, 37 FF, 2 DSP, timing report states all user constraints met in OOC context.

Integration status:
- `iq_mixer_stage_a` remains available for isolated validation; the local phase accumulator was retired in favor of the active DDS IP path.
- No top-level port, ARM register ABI, or DAC debug behavior changed.
- Legacy `clk_dpll` references are expected to remain unchanged until the DDC/VCO boundary is replaced atomically.

Planned next step:
- Keep this file as historical context only; use `verification/README.md` and the review closure audits for current verification entry points.
