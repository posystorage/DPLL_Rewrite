# Review2 VCO DIV[15] APPLY Fix

Date: 2026-06-28

## Scope

- Removed the stale wrapper-side `DIV[15]` rejection from the VCO MUL/DIV `CONFIG_APPLY` path.
- Kept `MUL=0` and `DIV=0` as illegal configuration errors.
- Updated register-map v1 documentation so the full unsigned 16-bit `OUTPUT_DIV` range is documented as legal.
- Strengthened `scripts\audit_review2_closure.py` to prove the wrapper APPLY path also accepts `DIV[15]=1`.

## Verification

- `python scripts\audit_review2_closure.py`: PASS.
- `python scripts\audit_review_closure.py`: PASS.
- `python scripts\audit_review2_ip_config.py`: PASS.
- `powershell -ExecutionPolicy Bypass -File scripts\run_pll_vco_mul_div_xsim.ps1`: PASS, including `DIV=0xffff`.
- `python -m unittest verification.arm.test_dpll_control_mock`: PASS.
- `powershell -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS.
- `powershell -ExecutionPolicy Bypass -File scripts\run_dpll_multifrequency_path_xsim.ps1`: PASS.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`: synthesis complete, 0 errors, 0 critical warnings; timing still violates at synthesis report stage.

Local archive tag before this edit:
- `archive/dpll-thbox-t3-before-review2-vco-div15-apply-fix-20260628`
