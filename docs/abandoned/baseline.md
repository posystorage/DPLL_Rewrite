# DPLL_Rewrite_THbox_T3 P0 Baseline

Date: 2026-06-27

Repository root: `E:\FPGA\DPLL_Rewrite\DPLL_Rewrite_THbox_T3`

Baseline commit before refactor:

```text
c3b853762507c2670d4563cbebdb4f03294e1184
```

Baseline purpose:

- Preserve the current working DPLL implementation before the single-path refactor.
- Record the current RTL, ARM, report, bitstream, and ABI state.
- Make later changes reviewable against a known rollback point.

## Source Baseline

Current top-level DPLL integration:

- `DPLL_Rewrite.srcs/sources_1/ReadPitaya/red_pitaya_top.v`
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/dpll_wrapper.v`
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/DDC_wideband_filters.vhd`
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ddc_frontend_lowpass_filter.vhd`
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/N_times_clk_FIR_wrapper.vhd`
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/PID/PLL_loop_filters_with_saturation.vhd`
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/VCO/PLL_VCO_MUL_DIV.v`
- `DPLL_Rewrite.srcs/sources_1/xdc/red_pitaya.xdc`

Current ARM application:

- `DPLL_Rewrite.sdk/DPLL_2COM/src/Peripherals.h`
- `DPLL_Rewrite.sdk/DPLL_2COM/src/helloworld.c`

## Confirmed Current Architecture

The current Vivado project contains one active `dpll_wrapper` instance:

```text
red_pitaya_top.dpll_wrapper_inst
```

The current functional DPLL path is single-channel:

```text
ADCraw0
-> dpll_wrapper.DDC0_inst
-> PLL0_loop_filters
-> output_summing_dac0
-> VCO0_mul_div / DAC_VCO_CH0
-> DACout0
```

`ADCraw1` is connected to `Digital_Freq_Meter_inst` in the top level only. `dpll_wrapper` does not expose an ADC1 port, so the DPLL boundary cannot be mistaken for a second ADC/DPLL path.

The two high-order FIR instances are I/Q branches of the same DPLL channel:

```text
DDC0_inst.ddc_frontend_lowpass_filter_inst_I
DDC0_inst.ddc_frontend_lowpass_filter_inst_Q
```

They are not a second DPLL.

Current `DACout1` is not a second DPLL output. The old DAC1 VCO instance is commented out. The active path is:

```text
PID_OUT_With_Limit[23:8]
-> clk_dpll to clk1 req/ack handoff
-> DACout1
```

## Current Clocking

The current DPLL core uses a generated low-speed physical clock:

```text
clk1        = adc_clk, nominal 125 MHz
clk1_timesN = adc_clk_2x
clk_dpll    = DPLL_clk
```

`DPLL_clk` is produced in `red_pitaya_top.v` through divided logic and a BUFG, and is constrained in `red_pitaya.xdc` as a generated clock:

```tcl
create_generated_clock -name DPLL_clk -source [get_ports adc_clk_p_i] -divide_by 40 [get_nets DPLL_clk]
```

The refactor must remove `clk_dpll` from the new core and express all lower-rate behavior with `valid` pulses on `clk_125m`.

## Current Register ABI Snapshot

Current DPLL base:

```text
DPLL_BASE_ADDR = 0x40600000
absolute address = DPLL_BASE_ADDR | (register_index << 2)
```

Current notable write/read indices:

| Index | Current meaning |
|---:|---|
| `0x0000` | reset |
| `0x0010` | center frequency word |
| `0x0011` | angle/readback selector |
| `0x0020` | PLL lock/enable |
| `0x0021` | PID P |
| `0x0022` | PID I |
| `0x0023` | PID I2 |
| `0x0024` | PID D |
| `0x0025` | D-filter coefficient |
| `0x0028` | positive correction limit |
| `0x0029` | negative correction limit |
| `0x002A` | manual frequency offset |
| `0x0030` | DAC0 offset in RTL |
| `0x0031` | DAC0 amplitude |
| `0x0032` | output frequency multiply factor |
| `0x0033` | output frequency divide factor |
| `0x0040` | old DAC1 offset register |
| `0x0041` | old DAC1 amplitude register |
| `0x0042` | old DAC1 frequency register |
| `0x0043` | old DAC1 phase register |
| `0x0050` | phase residual threshold |
| `0x0051` | phase residual offset |
| `0x0052` | frequency residual threshold |
| `0x0100..0x0107` | current status/readbacks |
| `0x010F` | current test value `0x12345678` |

ARM-side ABI risk:

- `DPLL_Rewrite.sdk/DPLL_2COM/src/Peripherals.h` defines `DAC0_VCO_Offset_Addr` as `(00030<<2)`, which is decimal `30`, not `0x0030`.
- Current ARM active address for that macro is therefore `0x40600078`, while the v3 register plan expects index `0x0030` at `0x406000C0`.
- This must be handled by the ARM/register owner with an explicit test and migration decision.

## Current Reports And Artifacts

Synthesis:

- `DPLL_Rewrite.runs/synth_1/red_pitaya_top.dcp`
- `DPLL_Rewrite.runs/synth_1/red_pitaya_top_utilization_synth.rpt`

Implementation:

- `DPLL_Rewrite.runs/impl_1/red_pitaya_top.bit`
- `DPLL_Rewrite.runs/impl_1/red_pitaya_top_routed.dcp`
- `DPLL_Rewrite.runs/impl_1/red_pitaya_top_timing_summary_routed.rpt`
- `DPLL_Rewrite.runs/impl_1/red_pitaya_top_utilization_placed.rpt`
- `DPLL_Rewrite.runs/impl_1/red_pitaya_top_drc_routed.rpt`
- `DPLL_Rewrite.runs/impl_1/red_pitaya_top_route_status.rpt`
- `DPLL_Rewrite.runs/impl_1/red_pitaya_top_power_routed.rpt`

SDK/hardware:

- `DPLL_Rewrite.sdk/red_pitaya_top_hw_platform_0/red_pitaya_top.bit`
- `DPLL_Rewrite.sdk/red_pitaya_top_hw_platform_0/system.hdf`
- `DPLL_Rewrite.sdk/red_pitaya_top.hdf`
- `DPLL_Rewrite.sdk/DPLL_2COM/Debug/DPLL_2COM.elf`
- `DPLL_Rewrite.sdk/BOOT.bin`

Note: `DPLL_Rewrite.sdk/DPLL_THbox.bif` contains old absolute paths under `E:\JiangSiyi\FPGA\...`; it is not currently portable to this workspace without path update.

## Current Timing And Resource Baseline

From `DPLL_Rewrite.runs/impl_1/red_pitaya_top_timing_summary_routed.rpt`:

```text
WNS = -4.227 ns
TNS = -4578.298 ns
TNS failing endpoints = 2437
Timing constraints are not met.
```

Clock-pair examples from the routed report:

```text
pll_adc_clk -> DPLL_clk       WNS -2.231 ns, TNS -5.349 ns
pll_clk_adc_2x -> DPLL_clk    WNS -0.336 ns, TNS -0.401 ns
```

From `DPLL_Rewrite.runs/impl_1/red_pitaya_top_utilization_placed.rpt`:

```text
Slice Registers = 11901 / 35200 = 33.81%
Block RAM Tile  = 25 / 60       = 41.67%
DSPs            = 63 / 80       = 78.75%
```

Known timing hotspots include:

- AXI/PS bus paths under `i_ps/axi_slave_gp0`.
- `dpll_wrapper_inst/VCO0_mul_div` DSP chain.
- Old DPLL I/Q FIR paths.
- `Digital_Freq_Meter_inst/PLL0_loop_filters` DSP/control paths.

## Baseline Verification Status

The following were inspected from existing files only:

- Git status and commit ID.
- RTL topology.
- ARM register usage.
- Existing Vivado reports.
- Existing bit/HDF/ELF/BOOT artifacts.

The following were not run during this baseline step:

- Vivado synthesis.
- Vivado implementation.
- xsim/RTL simulation.
- Hardware ILA capture.
- ARM SDK rebuild.
- Board-level functional tests.

No unexecuted test is claimed as passing.

## Frozen Refactor Constraints

- Refactor the existing `DigitalPLL` in place.
- Do not create `DigitalPLL2`.
- Do not add old/new DPLL runtime selection.
- Do not keep `clk_dpll` in the refactored DPLL core.
- Do not replace the post-IQ CIC requirement with a high-order FIR.
- Do not restore PII2.
- Do not truncate tracking correction before final MUL/DIV.
- Do not change register ABI without synchronized ARM changes.
- Do not let post-IQ CIC R change active behavior before `CONFIG_APPLY`.
- Keep `DACout1` as debug output only.
- Do not use false paths to hide synchronous design problems.
