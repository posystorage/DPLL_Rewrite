# P4 clk_dpll Legacy Cleanup Verification

Date: 2026-06-28
Branch: refactor/dpll-single-path

## Scope

- Removed the old disabled `DigitalPLL/DDC/DDC_wideband_filters.vhd` source from the Vivado project and repository.
- Removed the obsolete `DigitalPLL/dpll_wrapper.v.bk` backup source.
- Updated the `clk_dpll` audit script and report so legacy backups are no longer treated as allowed exceptions.

## Evidence

- `python scripts\audit_clk_dpll_usage.py`
  - Result: `active_clk_dpll_hits=0`.
- `rg -n "clk_dpll" DPLL_Rewrite.srcs\sources_1\DigitalPLL`
  - Result: no DigitalPLL source hits after cleanup.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_single_clock_core_stage_a_xsim.ps1`
  - Result: `PASS: dpll_single_clock_core_stage_a_tb`.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`
  - Result: synthesis completed with 0 errors and 0 critical warnings.
  - Timing still fails in the generated timing report; this stage did not claim timing closure.

## Notes

- The frequency meter DDC source remains intact. Its two FIR instances are I/Q branches of the frequency meter path, not a second functional DPLL.
- The known direct system-bus `adc_clk -> pll_adc_clk` timing issue remains outside this goal per user instruction.
