# Stage A Clock/Valid Scaffold Summary

Date: 2026-06-27

Branch: `agent/clock-valid`

## Scope

This Stage A commit adds a small 125 MHz reset/valid scaffold and instantiates it inside the existing `dpll_wrapper`.

It does not change:

- top-level `red_pitaya_top.v`
- ARM SDK files
- register ABI
- DACout0/DACout1 behavior
- existing legacy DPLL datapath behavior

The legacy `clk_dpll` logic still exists in `dpll_wrapper`; this commit only creates the tested Stage A replacement timing primitive required before migrating legacy blocks to valid pulses.

## Added RTL

- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/clocking/dpll_clock_valid_stage_a.v`

Generated signals:

- `rst_125m`: reset synchronized to `clk1`/125 MHz.
- `sample_3m125_valid`: one-cycle valid pulse every 40 `clk1` cycles.

## Verification

Python fixed-point smoke tests:

```text
python -m unittest discover -s verification\fixed_point -p test_*.py
7 tests passed
```

Vivado 2018.3 xsim smoke test:

```text
powershell.exe -ExecutionPolicy Bypass -File scripts\run_clock_valid_stage_a_xsim.ps1
PASS dpll_clock_valid_stage_a_tb
```

Vivado 2018.3 out-of-context synthesis:

```text
vivado -mode batch -source scripts\vivado_stage_a_synth_check.tcl
synth_design completed successfully
0 errors, 0 critical warnings, 0 warnings
```

OOC timing report warning:

```text
HD.CLK_SRC of clock port "clk_125m" is not set
```

This warning is expected for an in-memory OOC check and is not used as a timing closure result.
