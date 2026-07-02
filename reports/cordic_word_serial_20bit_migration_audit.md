# DPLL CORDIC 20-bit Input / 18-bit Effective Phase Migration Audit

Date: 2026-07-02

Scope:
- DPLL path only.
- Frequency meter legacy `angle_CORDIC` / `input_multiplier` path is not changed.
- Vivado project file (`DPLL_Rewrite.xpr`) is not modified by this audit.

## Result

The DPLL CORDIC migration now satisfies the HDL/source-level requirements in
`docs/CORDIC_WordSerial_20bit_Migration_Guide_CN.md` for:

- 20-bit post-IQ CIC I/Q direct input to CORDIC.
- Xilinx CORDIC IP named `dpll_angle_CORDIC`.
- Word Serial + Maximum pipelining.
- 20-bit CORDIC input width.
- 20-bit CORDIC output width.
- 18-bit effective scaled-radian phase extracted from raw 20-bit phase.
- 20-bit magnitude path through DPLL wrapper/status/debug.
- AXI valid/ready handshake via `cordic_word_serial_adapter`.
- 2-entry input FIFO and sticky CORDIC diagnostics.
- No active old 14-bit-to-18-bit zero-padding phase path.
- No active `round_cic20_to_cordic16` path.

## IP Configuration

File:
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/dpll_angle_CORDIC/dpll_angle_CORDIC.xci`

Verified properties:

| Requirement | Actual |
| --- | --- |
| Component name | `dpll_angle_CORDIC` |
| Functional selection | `Translate` |
| Architecture | `Word_Serial` |
| Pipelining | `Maximum` |
| Data format | `SignedFraction` |
| Input width | `20` |
| Output width | `20` |
| Phase format | `Scaled_Radians` |
| Coarse rotation | `true` |
| Scale compensation | `No_Scale_Compensation` |
| Rounding | `Nearest_Even` |
| Flow control | `Blocking` |
| ARESETn | `true` |
| ACLKEN | `false` |
| ACLK metadata | `125000000` |
| S_AXIS_CARTESIAN TDATA | 6 bytes / 48 bits |
| M_AXIS_DOUT TDATA | 6 bytes / 48 bits |
| S_AXIS_CARTESIAN TREADY | present |
| M_AXIS_DOUT TREADY | present |
| OOC clock | `create_clock -period 8 -name aclk` |

Verification run:

```text
vivado -mode batch -source .codex_synth_dpll_cordic_ip.tcl
synth_ip dpll_angle_CORDIC
Result: synth_design completed successfully, 0 errors, 0 critical warnings.
Report BlackBoxes: none.
```

## Adapter / Packing

File:
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/detector_fll/cordic_word_serial_adapter.v`

Verified:
- `IQ_WIDTH=20`, `PHASE_WIDTH=18`, `MAG_WIDTH=20`.
- X/I packed into low 24-bit lane as `{{4{I[19]}}, I[19:0]}`.
- Y/Q packed into high 24-bit lane as `{{4{Q[19]}}, Q[19:0]}`.
- Input consumption uses `input_fire = tvalid && tready`.
- Output CORDIC `m_axis_dout_tready` is tied to `1'b1`.
- Output valid is gated by returned CORDIC valid and outstanding transaction count.
- Magnitude is extracted from `cordic_m_tdata[19:0]`.
- Effective 18-bit phase is extracted from `cordic_m_tdata[24+:PHASE_WIDTH]`, i.e. raw phase bits `[17:0]`.
- Output padding diagnostics check low/high lane sign extension.
- Input range sticky checks `-2^18 <= I/Q <= +2^18`.
- FIFO overrun sticky is present.
- Reset/clear drives CORDIC ARESETn low for 3 cycles plus a guard cycle and clears local pending state.

## Core Integration

File:
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/core/dpll_single_clock_core_stage_a.v`

Verified:
- `PHASE_WIDTH=18`.
- `CIC_WIDTH=20`.
- `MAG_WIDTH=20`.
- post-IQ CIC `i_baseband/q_baseband` connect directly to `cordic_word_serial_adapter`.
- DPLL instantiates `dpll_angle_CORDIC` only through the adapter.
- DPLL mixer uses `dpll_input_multiplier`, not the legacy frequency-meter `input_multiplier`.
- FLL/PLL phase scale remains 18-bit and `PRODUCT_SHIFT=18`.

## Removed Old Active Paths

Search found no active DPLL matches for:

- `round_cic20_to_cordic16`
- `cordic_i_rounded`
- `cordic_q_rounded`
- `cordic_round_valid_r`
- `{cordic_phase[13:0], 4'b0000}`
- legacy direct DPLL `angle_CORDIC` instance

The only remaining active legacy `angle_CORDIC` / `input_multiplier` references are in:

- `DPLL_Rewrite.srcs/sources_1/Freq_Meter/DDC/Freq_Meter_DDC_wideband_filters.vhd`

That is expected and preserves the old frequency meter path.

## Magnitude / Status

Verified in `DPLL_Rewrite.srcs/sources_1/DigitalPLL/dpll_wrapper.v`:

- Active magnitude thresholds are 20-bit registers.
- DPLL magnitude signal is 20-bit.
- status register `0x0101` returns `{12'h0, dpll_magnitude}`.
- debug source 8 returns `{12'h000, dpll_magnitude}`.
- CORDIC sticky diagnostics are exposed in status `0x0108`.

Verified in ARM driver:

- shadow magnitude thresholds are masked with `0x000FFFFF`.

## Frequency Meter Isolation

Verified:
- Frequency meter still instantiates old `input_multiplier`.
- Frequency meter still instantiates old `angle_CORDIC`.
- DPLL instantiates `dpll_input_multiplier` and `dpll_angle_CORDIC`.
- No source-level shared CORDIC instance remains between DPLL and frequency meter.

## Vivado Project Actions Still Required

Because `DPLL_Rewrite.xpr` was intentionally not edited:

- Add/import `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/dpll_angle_CORDIC/dpll_angle_CORDIC.xci` to the Vivado project.
- Ensure the DPLL adapter source `DigitalPLL/detector_fll/cordic_word_serial_adapter.v` is included.
- Ensure any stale project reference to the old/missing DPLL CORDIC wrapper-only source is replaced by the `.xci` managed IP.
- Keep frequency meter IP references pointed at `Freq_Meter/DDC/ip/angle_CORDIC/angle_CORDIC.xci` and `Freq_Meter/DDC/ip/input_multiplier/input_multiplier.xci`.

## Not Claimed By This Audit

- Full top-level project synth/impl was not run in this audit.
- Timing closure for the full design was not rerun.
- Closed-loop hardware behavior and golden-vector bit-accuracy were not rerun here.
- Existing generated synth run artifacts in `DPLL_Rewrite.runs/synth_1` are outside this audit.
