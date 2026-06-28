# P2 Debug DAC Formatter Pipeline Check - 2026-06-28

## Scope

This check addresses the non-bus timing hotspot reported in the debug DAC
formatter path. DACout1 remains a debug output and is not used as a second
DPLL path.

## RTL Change

- Added one registered stage between the dynamic shift/window extraction and
  the signed gain multiply.
- Moved the multiply result formatting to the following stage so the dynamic
  source selection no longer feeds directly into the DSP input path.
- Preserved the existing format ABI:
  - mode 0: raw 16-bit bit window
  - mode 1: arithmetic shift, gain, offset, signed saturation
  - mode 2: unsigned shift and positive saturation
  - invert and hold-last behavior unchanged

## Verification

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_debug_dac_formatter_stage_a_xsim.ps1
```

Result:

```text
PASS: debug_dac_formatter_stage_a_tb
```

The testbench expected latency was updated from 3 to 4 cycles to match the
added pipeline stage. Expected sample values are unchanged.

## OOC Synthesis Check

Command:

```powershell
& 'D:\Xilinx\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\vivado_debug_dac_formatter_stage_a_synth_check.tcl
```

Result:

```text
synth_design completed successfully
WNS: +1.194 ns
TNS: 0.000 ns
Failing setup endpoints: 0
Failing hold endpoints: 0
DSP48E1: 2
```

Vivado still recommends additional downstream pipeline registers for the wide
multiplier, but the checked 125 MHz OOC timing is met with no setup or hold
violations.

## Constraints

- No false path or multicycle exception was added.
- No register ABI was changed.
- No `clk_dpll` source or generated 3.125 MHz clock was reintroduced.
