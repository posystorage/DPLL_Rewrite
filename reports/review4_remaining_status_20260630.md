# Review4 Remaining Status

Generated on 2026-06-30 after the review4 recheck and timing-closure pass.

## Closed In Current Working Tree

- Active configuration readback now has a complete normalized CRC at `DPLL_ACTIVE_CONFIG_CRC_Addr` (`0x011E`).
- ARM apply verification computes the same CRC over shadow configuration and rejects active/shadow mismatches.
- Build identity headers are tracked fallbacks, and `scripts/generate_dpll_build_id.py` now carries `CONFIG_VERSION = 0x00010003`.
- Pre-IQ CIC input backpressure is latched into `DPLL_CORE_FLAGS[19]`.
- VCO multiplier latency is audited against the generated `mult_gen_pll` IP latency (`8` cycles).
- Post-IQ CIC R/shift recommendations are now backed by `scripts/audit_cic_shift_model.py` and `reports/cic_shift_model_20260630.md`.
- PS GP0/system-bus clock now uses the PLL/BUFG `adc_clk` instead of raw `adc_clk_in`; this removes the avoidable raw-input-clock to peripheral-clock system-bus launch path in source.
- `CONFIG_APPLY` VCO MUL/DIV validation is now staged across a small sys_clk state machine instead of completing wide multiply/compare/error-code logic in one bus cycle.
- The active core registers rounded mixer I/Q and valid before the post-IQ CIC, removing the direct mixer-to-44-bit-integrator timing path.
- The hybrid FLL/PLL loop output path is pipelined through state-sum, state, and correction stages, removing the previous DSP/product-to-tracking-word long combinational path.
- The active core registers multiplier products before mixer rounding, cutting the multiplier-to-CIC input path.
- The active core registers post-IQ CIC outputs before CORDIC rounding, cutting the CIC-to-CORDIC input path.

## Verification Run

- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1`: PASS.
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_hybrid_loop_stage_a_xsim.ps1`: PASS.
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_dpll_wrapper_cdc_xsim.ps1`: PASS.
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_arm_dpll_driver_host_test.ps1`: PASS.
- `python verification\fixed_point\check_hybrid_loop_trace.py`: PASS.
- `python scripts\audit_cic_shift_model.py`: PASS.
- `python scripts\audit_system_bus_clock.py`: PASS.
- `python scripts\audit_review4_closure.py`: PASS.
- `python scripts\generate_dpll_build_id.py --check`: PASS.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_full_bitstream_reports.tcl`: bitstream generated, timing met.

## Closed

Full Vivado implementation timing sign-off is now closed. The current checked report under `reports/vivado_full_impl/timing_summary.rpt` says all user-specified timing constraints are met:

- WNS: `0.004 ns`
- TNS: `0.000 ns`
- Failing setup endpoints: `0`

The avoidable `adc_clk -> pll_adc_clk` bus-clock failure is no longer present; `reports/vivado_full_impl/clock_interaction.rpt` reports that pair with positive WNS. Non-excluded failing pairs are tracked in `reports/full_timing_exception_audit_20260628.md`:

- Failing clock pairs: `0`.
- User-excluded failing clock pairs: `0`.
- Non-excluded failing clock pairs: `0`.

Current worst setup path is met with slack `0.004 ns` in the VCO divider path. The design produces a bitstream, no false path or clock-group waiver was added to hide synchronous failures, and review4 full implementation sign-off is `CLOSED`.
