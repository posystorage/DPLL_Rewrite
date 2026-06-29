# Review4 Remaining Status

Generated on 2026-06-30 after commit `bf9923f`.

## Closed In Current Working Tree

- Active configuration readback now has a complete normalized CRC at `DPLL_ACTIVE_CONFIG_CRC_Addr` (`0x011E`).
- ARM apply verification computes the same CRC over shadow configuration and rejects active/shadow mismatches.
- Build identity headers are tracked fallbacks, and `scripts/generate_dpll_build_id.py` now carries `CONFIG_VERSION = 0x00010003`.
- Pre-IQ CIC input backpressure is latched into `DPLL_CORE_FLAGS[19]`.
- VCO multiplier latency is audited against the generated `mult_gen_pll` IP latency (`8` cycles).
- Post-IQ CIC R/shift recommendations are now backed by `scripts/audit_cic_shift_model.py` and `reports/cic_shift_model_20260630.md`.

## Verification Run

- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_dpll_wrapper_cdc_xsim.ps1`: PASS.
- `powershell.exe -ExecutionPolicy Bypass -File scripts\run_arm_dpll_driver_host_test.ps1`: PASS.
- `python scripts\audit_cic_shift_model.py`: PASS.
- `python scripts\audit_review4_closure.py`: PASS.

## Still Open

Full Vivado implementation timing sign-off remains open. The current checked report under `reports/vivado_full_impl/timing_summary.rpt` still says timing constraints are not met:

- WNS: `-3.043 ns`
- TNS: `-3825.968 ns`
- Failing setup endpoints: `2285`

`reports/vivado_full_impl/cdc.rpt` says analyzed CDC paths are safely timed, but that does not close full timing sign-off.
