# Single-Clock Core Stage A Summary

Date: 2026-06-28
Branch: refactor/dpll-single-path

## Scope

This stage adds a single-clock DPLL shadow core target in the existing `DigitalPLL`
path. It does not create `DigitalPLL2`, does not add a runtime old/new selector,
does not change the ARM register ABI, and does not connect the shadow core to DAC
outputs or register readback.

The shadow core runs from `clk1` with `sample_valid`, and contains the Stage A
tracking accumulator, IQ mixer, post-IQ CIC, FLL phase difference, and hybrid
FLL/PLL filter chain. The legacy active DPLL path remains functionally unchanged.

## Changes

- Added `dpll_single_clock_core_stage_a` as an integrated single-clock core.
- Instantiated the core inside `dpll_wrapper` as a kept, non-user-visible shadow
  path.
- Registered ADC and LO inputs before the mixer, and pipelined the mixer product
  stage to close the OOC 125 MHz timing path.
- Added xsim and Vivado OOC/project-synthesis smoke scripts for this stage.
- Updated the mixer testbench for the new valid-aligned pipeline latency.

## Verification

Commands run:

- `python -m unittest discover -s verification\fixed_point -p test_*.py`
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_frontend_stage_a_xsim.ps1`
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1`
- `python scripts\audit_clk_dpll_usage.py`
- `vivado.bat -mode batch -source scripts\vivado_stage_a_project_frontend_check.tcl`
- `vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_synth_check.tcl`
- `vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`

Results:

- Fixed-point unit tests: PASS, 7 tests.
- Frontend xsim: PASS, tracking accumulator and IQ mixer testbenches.
- Single-clock core xsim: PASS, `dpll_single_clock_core_stage_a_tb`.
- `clk_dpll` migration audit: `active_clk_dpll_hits=33`; no new `clk_dpll`
  usage was added.
- Single-clock core OOC synth: PASS, 0 errors, 0 critical warnings.
- Single-clock core OOC timing: WNS `0.717 ns`, TNS `0.000 ns`, 0 setup/hold
  failing endpoints at 8 ns.
- Single-clock core OOC resources: 1738 LUT, 2634 FF, 5 DSP, 0 BRAM.
- Project synthesis smoke: PASS, `synth_design Complete!`.

## Remaining Issues

Full-project synthesis timing is not signed off. The project synthesis timing
summary still reports WNS `-2.596 ns`, TNS `-1570.148 ns`, setup failing
endpoints `1311`, and hold WNS `-3.493 ns`.

The top reported failing setup path after this stage is in the legacy
`VCO0_mul_div` multiplier path, not the new single-clock shadow core:

- `dpll_wrapper_inst/VCO0_mul_div/clk_data_in_reg_reg[16]`
- to `dpll_wrapper_inst/VCO0_mul_div/VCO0_Multiplier/.../DSP48E1/PCIN`

The shadow core is therefore ready as a verified integration target, but the
overall design is not timing-clean and no new bitstream signoff is claimed for
this stage.

## Completion Against Plan

- Stage A single-clock shadow core integration: complete.
- No ARM ABI or DAC-visible behavior change: complete.
- No `DigitalPLL2` or runtime selector: complete.
- Shadow core OOC synthesis/timing: complete.
- Project-level synthesis smoke: complete, with timing failures recorded.
- Full replacement of the legacy active DPLL path: not complete.
- ARM software update for new ABI: not started because ABI was not changed.
- Timing-clean implementation bitstream: not complete.
