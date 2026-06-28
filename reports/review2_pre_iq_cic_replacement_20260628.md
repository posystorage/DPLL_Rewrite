# Review2 pre-IQ CIC Replacement

Date: 2026-06-28

## Scope

- Replaced the active pre-IQ `/40` CIC instance in `dpll_wrapper.v` with Vivado 2018.3 IP `pre_iq_cic_40_125m_v1`.
- Kept the Xilinx CIC Compiler topology: `R=40`, `N=4`, `M=2`, 16-bit input/output, no DSP, no output `tready`.
- Regenerated the replacement IP with `Clock_Frequency=125.0` and `Input_Sample_Frequency=125.0`.
- Left the old `cic_compiler_0` source present but auto-disabled in the project; the wrapper no longer instantiates it.

## Verification

- `python scripts\audit_review2_ip_config.py`: PASS.
- `python scripts\audit_review_closure.py`: PASS.
- `python scripts\audit_review2_closure.py`: PASS.
- `scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS.
- `scripts\run_dpll_multifrequency_path_xsim.ps1`: PASS.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`: synthesis complete, 0 errors, 0 critical warnings; timing still violates at synthesis report stage.

Local archive tag before this edit:
- `archive/dpll-thbox-t3-before-review2-pre-iq-cic-replacement-20260628`
