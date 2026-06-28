# Review P2 Output MUL/DIV IP Path

## Scope

- Reworked `PLL_VCO_MUL_DIV` so the output frequency scaling path uses the existing Xilinx `mult_gen_pll` and `div_gen_pll` IPs with explicit sequencing.
- Kept `DACout0` scaling as `tracking_word * MUL / DIV`.
- Did not replace the divider with behavioral arithmetic.

## RTL Changes

- Added a real FSM around the IP path:
  - latch latest pending sample/factors on `sample_valid`;
  - wait for the 1-cycle `mult_gen_pll` latency;
  - present divisor and dividend to `div_gen_pll` until both AXI-stream inputs handshake;
  - wait for `m_axis_dout_tvalid`;
  - decode the 80-bit divider output as `{64-bit quotient, 16-bit fractional}`;
  - round by fractional bit 15 and saturate to 48 bits.
- Fixed the previous divider output width handling by using the full 80-bit result bus.
- Guarded zero MUL/DIV factors as `1`.
- Clamped DIV factors with bit 15 set to `0x7fff` because the existing divider IP is configured with a signed divisor input.

## Verification

- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_pll_vco_mul_div_xsim.ps1`
  - PASS: `pll_vco_mul_div_tb`.
  - The test compiles and simulates the real `mult_gen_pll` and `div_gen_pll` VHDL simulation models.
  - Covered integer divide, fractional rounding, DIV=0 guard, signed-divisor high-bit clamp, saturation, and busy overwrite behavior.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`
  - Project synthesis completed: `synth_design Complete!`
  - 0 synthesis errors, 0 critical warnings.
  - Timing still fails in the project-level timing summary; this is the known remaining timing closure work and is not claimed fixed here.

## Remaining

- Full implementation timing is still not closed.
- The direct system-bus `adc_clk` to `pll_adc_clk` timing crossing remains intentionally excluded per user instruction.
