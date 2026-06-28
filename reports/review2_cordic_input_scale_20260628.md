# Review2 CORDIC Input Scale Closure

Date: 2026-06-28

## Scope

- `angle_CORDIC` is the active DPLL phase/magnitude detector.
- The IP is configured as Translate, SignedFraction, Scaled_Radians, 16-bit input/output, coarse rotation enabled, nearest-even rounding, and no scale compensation.
- The active DPLL core no longer truncates `i_baseband[19:4]` and `q_baseband[19:4]` directly into the CORDIC.

## RTL Change

- Added `round_cic20_to_cordic16()` in `dpll_single_clock_core_stage_a.v`.
- The function applies sign-symmetric rounding before the 4-bit right shift from post-IQ CIC 20-bit samples to CORDIC 16-bit SignedFraction samples.
- The function saturates to the signed 16-bit range before the `{Y, X}` CORDIC input pack.

## Scale Contract

- CORDIC X input is rounded/saturated `i_baseband / 16`.
- CORDIC Y input is rounded/saturated `q_baseband / 16`.
- CORDIC phase output remains the IP Scaled_Radians 16-bit phase, expanded to the DPLL 18-bit one-turn format by appending two LSB zeros.
- CORDIC magnitude is the no-scale-compensation magnitude from the IP; ARM `MAG_ENTER_THRESHOLD` and `MAG_EXIT_THRESHOLD` are in this raw IP output scale.
- The frozen fixed-point/register documentation now defines this magnitude path as a raw 16-bit `angle_CORDIC` output. No RTL or ARM compensation is applied in v1.

## Verification

- `python scripts\audit_review2_closure.py`: PASS.
- `python scripts\audit_review2_ip_config.py`: PASS.
- `powershell -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS.
- `powershell -ExecutionPolicy Bypass -File scripts\run_multifrequency_golden_trace.ps1`: PASS.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`: synthesis completed with 0 errors and 0 critical warnings. The generated timing summary still reports timing violations; this is not timing closure.
