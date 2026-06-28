# Review P2 Debug DAC Formatter Progress

Date: 2026-06-28
Branch: `refactor/dpll-single-path`

## Scope

This pass addresses the `review.md` DACout1 debug-output finding:

- the previous path used a large debug mux feeding a wide combinational multiply, offset add, compare, and saturation chain directly to `DACout1`;
- `DEBUG_DAC_FORMAT` existed but did not participate in formatting;
- DACout1 must remain debug output only and must not become a second DPLL.

## RTL Changes

- Added `debug_dac_formatter_stage_a`.
- `dpll_wrapper` now drives `DACout1` from the registered formatter output.
- `DEBUG_DAC_FORMAT` is active:
  - bits `[5:0]`: raw bit-window LSB or arithmetic shift;
  - bits `[9:8]`: mode;
  - bit `10`: invert;
  - bit `11`: hold-last.
- Mode `0` (`RAW_BIT_WINDOW`) uses only source register, bit slice, optional invert, and output register.
- Mode `1` (`ARITH_SHIFT_SAT`) uses a pipelined gain/offset/saturation path.
- Mode `2` (`UNSIGNED_SAT`) exposes unsigned shifted magnitude with saturation.
- `DACout1` remains a one-way debug output and does not feed back into the DPLL loop.

## Verification Run

Executed with Vivado 2018.3:

- `powershell -ExecutionPolicy Bypass -File scripts\run_debug_dac_formatter_stage_a_xsim.ps1`
  - PASS: `debug_dac_formatter_stage_a_tb`
  - Covers raw bit-window, arithmetic gain/offset, signed saturation, unsigned saturation, invert, and hold-last.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_debug_dac_formatter_stage_a_synth_check.tcl`
  - `synth_design` completed with 0 errors and 0 critical warnings.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`
  - project `synth_design Complete!`
  - 0 synthesis errors.
  - timing summary still reports failure; this is not a timing signoff.

## Remaining Review Items

- Output MUL/DIV still needs a real multi-cycle FSM or reciprocal path.
- ARM command-layer refactor is still incomplete; only header/source references have been partially moved to v1 names.
- Full implementation, timing closure, bitstream, and board validation remain open.
- The user explicitly excluded fixing the direct `adc_clk -> pll_adc_clk` system-bus crossing in this goal; other timing problems remain in scope.
