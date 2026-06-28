# Review2 Debug Source Map Closure

Date: 2026-06-28

Scope:
- Aligned `DACout1` debug source selection with register map v1.
- Preserved `DACout1` as a debug-only output; no loop feedback or second DPLL path was added.
- Added a raw CORDIC phase output from the single-clock core for debug source 7.

Source map now implemented:
- `0`: `FREQ_CORRECTION`
- `1`: `TRACKING_WORD_MINUS_CENTER`
- `2`: `FREQ_STATE`
- `3`: `PHASE_ERROR`
- `4`: `FLL_ERROR`
- `5`: `POST_CIC_I`
- `6`: `POST_CIC_Q`
- `7`: `CORDIC_PHASE`
- `8`: `MAGNITUDE`
- `9`: `OUTPUT_WORD_DELTA`
- `10`: `LOOP_STATE_CODE`

Verification:
- `python scripts\audit_review2_closure.py`: PASS, including the DACout1 source-map check.
- `python scripts\audit_review_closure.py`: PASS.
- `python scripts\audit_clk_dpll_usage.py`: PASS, `active_clk_dpll_hits=0`.
- `powershell -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS.
- `powershell -ExecutionPolicy Bypass -File scripts\run_dpll_multifrequency_path_xsim.ps1`: PASS, 7 multifrequency cases passed.
- `vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`: PASS for synthesis, 0 errors and 0 critical warnings; timing remains not closed.
