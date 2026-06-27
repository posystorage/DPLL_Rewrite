# DPLL Single-Clock Active Path Completion Report

Generated: 2026-06-28 05:55 CST
Vivado: 2018.3
Branch: refactor/dpll-single-path

## Scope Completed

- `dpll_wrapper` is now the unique active DPLL wrapper path using `clk1` plus internal `sample_valid` pulses.
- Removed the `clk_dpll` and `clk1_timesN` public ports from `dpll_wrapper`.
- Removed the top-level DLL-external 3.125 MHz DPLL clock generation chain:
  - `red_pitaya_pll.CLKOUT5 -> pll_dpll_clk_div20 -> pll_dpll_clk_div40 -> BUFG -> DPLL_clk`.
- Removed `DPLL_clk` and `pll_dpll_clk_div20` generated-clock constraints from `red_pitaya.xdc`.
- Kept `DACout1` as a debug output only; it is not a second DPLL.
- Preserved the VCO MUL/DIV order on the 48-bit tracking word before DAC DDS use.
- Added v1 ARM software aliases and fixed `DAC0_VCO_Offset_Addr` from decimal `00030` to hex `0x0030`.
- Added v1 CIC/FLL shadow/apply register macros. Post-IQ CIC R/shift are shadowed and applied only through `0x006F`.

## Verification Run

- Python fixed-point tests: PASS, `7 tests`.
- XSIM frontend Stage A: PASS.
- XSIM single-clock core Stage A: PASS.
- Vivado project synthesis smoke check: PASS, `synth_design Complete!`.
- Vivado full implementation and bitstream: PASS for bitstream generation, `write_bitstream Complete!`.

## Bitstream

- Path: `DPLL_Rewrite.runs/impl_1/red_pitaya_top.bit`
- SHA256: `484F1E9A10335033A92B7D4A733AE2F9EBB30C0D3049074235EDBDE25196EA21`

## Timing And Reports

Full routed reports were generated under `reports/vivado_full_impl`.

- Routed timing status: FAIL, timing constraints are not met.
- Routed WNS: `-8.824 ns`
- Routed TNS: `-5144.860 ns`
- TNS failing endpoints: `2795`
- Hold status: routed WHS `0.052 ns`, THS `0.000 ns`.
- DRC summary: 76 report entries, all warnings/advisories; 0 DRC errors in the full run log.
- Utilization top summary: Total LUTs `6901`, FFs `10523`, RAMB36 `15`, RAMB18 `3`, DSP48 `50`.

The remaining timing failures are not hidden by false paths. The largest routed failures are still dominated by existing adc/pll clock interaction and AXI/clocking structure, not by a restored `DPLL_clk` domain.

## clk_dpll Audit

- Active refactored-path `clk_dpll` hits: `0`.
- Legacy unused source `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/DDC_wideband_filters.vhd` still contains `clk_dpll` text, but the refactored active `dpll_wrapper` no longer instantiates it.

## Completion Against Plan

- Unique DPLL active path: complete.
- DLL-external 3.125 MHz DPLL clock removal: complete.
- ARM register header sync: complete for additive v1 macros and address fix.
- Automated simulation: complete and passing for available Stage A tests.
- Full Vivado implementation/bitstream: complete for generation.
- Timing closure/signoff: incomplete; routed timing still fails and requires a separate timing-closure phase.

