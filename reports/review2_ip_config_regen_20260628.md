# Review2 IP Configuration Regeneration

Date: 2026-06-28

## Completed

- Regenerated `LO_DDS_H` metadata for the active 125 MHz single-clock DPLL path.
- Preserved `LO_DDS_H` Streaming PINC, sine/cosine output, and 48-bit phase width.
- Created replacement `div_gen_pll_u` in Vivado 2018.3 because the existing High Radix `div_gen_pll` keeps `operand_sign` disabled as `Signed`.
- Switched `PLL_VCO_MUL_DIV` to `div_gen_pll_u`; `DIV[15]=1` is now legal and handled by the unsigned divider.
- Created replacement pre-IQ CIC `pre_iq_cic_40_125m_v1` in Vivado 2018.3 because the existing `cic_compiler_0` keeps the old `Clock_Frequency=200.0` metadata disabled on the existing instance.
- Switched `dpll_wrapper.v` pre-IQ `/40` decimator to `pre_iq_cic_40_125m_v1`.

## pre-IQ CIC

- Replacement IP metadata is now `Clock_Frequency=125.0` and `Input_Sample_Frequency=125.0`.
- Functional CIC parameters remain `R=40`, `N=4`, `M=2`, 16-bit input/output, no DSP, and no output `tready`.

## Verification

- `scripts\run_pll_vco_mul_div_xsim.ps1`: PASS.
- `scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS.
- `scripts\run_dpll_multifrequency_path_xsim.ps1`: PASS.
- `python scripts\audit_review2_closure.py`: PASS.
- `python scripts\audit_review_closure.py`: PASS.
- `python scripts\audit_clk_dpll_usage.py`: PASS.
- `python scripts\audit_review2_ip_config.py`: PASS.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`: synthesis complete, 0 errors, 0 critical warnings; timing still violates at synthesis report stage.
