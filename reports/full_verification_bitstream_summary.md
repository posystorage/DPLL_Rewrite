# Full Verification And Bitstream Summary

Generated on 2026-06-28 with Vivado 2018.3.

Superseded:
This report describes an earlier integration snapshot at input commit
`3b1f900`. The current `refactor/dpll-single-path` HEAD has since retired the
local /40 clock-valid scaffold and local tracking phase accumulator. Use
`verification/README.md`, `reports/review_closure_audit_20260628.md`, and
`reports/review2_closure_audit_20260628.md` for current verification entry
points.

## Scope

- Branch: `refactor/dpll-single-path`
- Input commit before this report: `3b1f900` (`archive/dpll-thbox-t3-vco-muldiv-sample-valid-20260628`)
- Flow script: `scripts/vivado_full_bitstream_reports.tcl`
- Full implementation report directory: `reports/vivado_full_impl`
- Bitstream: `DPLL_Rewrite.runs/impl_1/red_pitaya_top.bit`

## Automated Verification

Historical passed commands for this snapshot:

- `python -m unittest discover -s verification\fixed_point -p test_*.py`
- `scripts\run_clock_valid_stage_a_xsim.ps1` (retired after this snapshot)
- `scripts\run_frontend_stage_a_xsim.ps1` (current script now runs the retained mixer test only)
- `scripts\run_iq_cic_stage_a_xsim.ps1`
- `scripts\run_detector_fll_stage_a_xsim.ps1`
- `scripts\run_hybrid_loop_stage_a_xsim.ps1`
- `scripts\vivado_stage_a_synth_check.tcl` (retired after this snapshot)
- `scripts\vivado_frontend_stage_a_synth_check.tcl` (current script now checks the retained mixer only)
- `scripts\vivado_iq_cic_stage_a_synth_check.tcl`
- `scripts\vivado_detector_fll_stage_a_synth_check.tcl`
- `scripts\vivado_hybrid_loop_stage_a_synth_check.tcl`
- `scripts\vivado_full_bitstream_reports.tcl` completed `synth_1` and `impl_1` through `write_bitstream`.

Important caveat:

- Full implementation produced a bitstream, but timing signoff did not pass.

## Bitstream

- Path: `DPLL_Rewrite.runs/impl_1/red_pitaya_top.bit`
- Size: 2,083,850 bytes
- Last write time: 2026-06-28 02:11:38
- SHA256: `F7F6A84F453A292444D2E72FA2BEE4DDCD143E6DC68C7557427E291F02DDEA9C`
- Vivado manifest: `reports/vivado_full_impl/manifest.txt`
- Manifest status: `synth_status=synth_design Complete!`, `impl_status=write_bitstream Complete!`, `impl_progress=100%`

## Full Implementation Results

Timing summary from `reports/vivado_full_impl/timing_summary.rpt`:

- Timing status: constraints are not met.
- WNS: -4.063 ns
- TNS: -4468.473 ns
- Setup failing endpoints: 2463
- Hold: clean, WHS 0.051 ns, THS 0.000 ns
- Pulse width: clean, WPWS 1.000 ns, TPWS 0.000 ns

Worst reported setup path:

- WNS -2.338 ns in `adc_clk`, from `i_ps/axi_slave_gp0/rd_do_reg/C` to `i_ps/axi_slave_gp0/ack_cnt_reg[1]/R`.

Clock interaction highlights:

- `adc_clk -> pll_adc_clk`: WNS -4.06 ns, TNS -4295.22 ns.
- `DPLL_clk -> pll_adc_clk`: WNS -1.81 ns, TNS -17.82 ns.
- `DPLL_clk -> pll_clk_adc_2x`: WNS -0.67 ns, TNS -12.74 ns.
- `pll_adc_clk -> DPLL_clk`: WNS -2.27 ns, TNS -5.99 ns.
- `pll_clk_adc_2x -> DPLL_clk`: WNS -0.03 ns, TNS -0.03 ns.

Route status:

- Fully routed.
- Routing errors: 0.

Utilization top row from `reports/vivado_full_impl/utilization_hier.rpt`:

- LUTs: 7335 total, 7007 logic, 328 SRL.
- FFs: 11909.
- RAMB36: 22.
- RAMB18: 6.
- DSP48: 63.

DRC summary from `reports/vivado_full_impl/drc.rpt`:

- Violations found: 69.
- All are warning/advisory level in this report.
- Main warning groups: BUFC-1, DPIP-1, DPOP-1, DPOP-2, REQP-1709.
- `REQP-1709` reports PLL clock output buffering/phase-alignment risk on `pll_dpll_clk_div10`.

Methodology summary from `reports/vivado_full_impl/methodology.rpt`:

- Violations found: 1079.
- Main warning groups: CKLD-2, TIMING-4, TIMING-16, TIMING-18, TIMING-27, TIMING-30, XDCC-5, XDCH-2.
- `TIMING-30` continues to flag sub-optimal generated-clock master source selection.

CDC report:

- `reports/vivado_full_impl/cdc.rpt` states all analyzed paths are safely timed.
- This does not waive the full timing failures above.

## Refactor Status

- `active_clk_dpll_hits=33` after the VCO MUL/DIV migration.
- The newly added Stage A primitives remain free of `clk_dpll`.
- Legacy `clk_dpll` remains in the old DDC/PID/status/debug portions of `dpll_wrapper` and in the wrapper boundary.
- This bitstream is an implementation artifact for the current integration state, not final timing-clean signoff.

## Required Next Work

- Replace the legacy DDC/PID/status/debug `clk_dpll` islands with the single-clock valid pipeline.
- Do not remove the public `clk_dpll` wrapper/top boundary until RFC-001 Stage B gates and ARM/register ABI synchronization are satisfied.
- Fix the timing failures without adding false paths to hide real synchronization or design problems.
- Synchronize ARM for ABI-affecting register changes before enabling post-IQ CIC APPLY/config registers or DACout1 debug mux semantics.
