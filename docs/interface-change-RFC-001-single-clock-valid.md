# RFC-001: Single-Clock Valid-Pulse DPLL Boundary

Date: 2026-06-27

Owner: `agent/clock-valid`

Status: proposed

## Problem

The current `dpll_wrapper` public boundary exposes three clocks:

- `clk1`, connected to `adc_clk`.
- `clk1_timesN`, connected to `adc_clk_2x`.
- `clk_dpll`, connected to the generated `DPLL_clk`.

The current top level builds `DPLL_clk` from `pll_dpll_clk_div10`, `pll_dpll_clk_div20`, and `pll_dpll_clk_div40`, then buffers it through `BUFG`. The existing implementation reports timing failures across clock pairs involving `DPLL_clk`, and the refactor contract explicitly forbids `clk_dpll` in the refactored core.

## Decision

Refactor the existing `DigitalPLL/dpll_wrapper.v` in place. Do not add `DigitalPLL2` and do not add an old/new runtime selector.

The refactored algorithm core shall use only:

```text
clk_125m
rst_125m
```

All lower-rate behavior shall use single-cycle valid pulses in the 125 MHz clock domain:

```text
sample_3m125_valid
iq_cic_valid
phase_valid
loop_update_valid
tracking_word_valid
output_word_valid
```

No new module inside the refactored DPLL core may use `clk_dpll`.

## Compatibility Plan

The migration is split into two public-boundary stages.

### Stage A: compatibility shell

Keep the current `dpll_wrapper` top-level port names so `red_pitaya_top.v` and the AXI/ARM register boundary are not changed while the core is being replaced:

```verilog
input wire clk1;
input wire clk1_timesN;
input wire clk_dpll;
input wire rst;
```

Inside `dpll_wrapper`, instantiate the new single-clock core with:

```text
clk_125m = clk1
rst_125m = reset derived from rst in clk1 domain
```

During Stage A, `clk_dpll` may remain as an unused compatibility input at the wrapper boundary only. It must not drive logic inside the new core. Any remaining use of `clk_dpll` must be listed in the merge request and treated as incomplete migration work.

### Stage B: public boundary cleanup

After Stage A synthesis, simulation, register tests, and ARM ABI checks pass:

- remove `clk_dpll` from `dpll_wrapper`.
- remove the `DPLL_clk` divider/BUFG logic from `red_pitaya_top.v`.
- remove the `DPLL_clk` generated-clock constraint from `red_pitaya.xdc`.
- refresh timing, CDC, clock interaction, and utilization reports.

Stage B may not start until register ABI v1 and ARM compatibility checks are synchronized.

## Valid Generation

The first valid source is the replacement for the current /40 front-end decimation cadence:

```text
sample_3m125_valid = one clk_125m cycle every 40 clk_125m cycles
```

The exact phase relationship to the decimated sample must be owned and tested by the module producing `sample_out`. Downstream modules shall advance state only when their corresponding valid is high.

## Reset Rule

`rst` is currently active-low at the wrapper port. Stage A shall synchronize it into the `clk1` domain and expose an active-high internal `rst_125m`. No asynchronous reset release may enter the new core.

## Non-Goals

- No ARM register ABI change in this RFC.
- No top-level `red_pitaya_top.v` port change in Stage A.
- No DACout1 behavior change beyond preserving its debug-only role.
- No change to `ADCraw1`; it remains outside the DPLL path and continues to feed the independent frequency meter.
- No timing false path or clock group constraint shall be added to hide a real synchronous design issue.

## Acceptance Gates

Before Stage A can merge:

1. `git grep clk_dpll -- DPLL_Rewrite.srcs/sources_1/DigitalPLL` must show no use inside the new refactored core. The compatibility wrapper input may remain only in Stage A.
2. Fixed-point model smoke tests must pass.
3. An xsim smoke test or a written, specific reason for not running it must be included.
4. Vivado 2018.3 audit reports must be refreshed, or the commit body must state exactly why Vivado could not be run.
5. The merge must not touch ARM SDK files.

Before Stage B can merge:

1. `clk_dpll` must be absent from the DPLL wrapper public interface.
2. `DPLL_clk` divider/BUFG logic must be absent from `red_pitaya_top.v`.
3. `DPLL_clk` generated-clock constraints must be removed rather than replaced with false paths.
4. ARM SDK register tests must pass against register map v1.
5. Timing, CDC, clock interaction, utilization, and route reports must be archived.

## Open Questions

- Whether `clk1_timesN` remains needed by any retained FIR/IP wrapper after the post-IQ CIC replacement.
- Whether Stage A should keep legacy DDC files in the project while disconnected, or remove them in the same atomic commit as the new core insertion.
- Exact xsim smoke-test scope for the first Stage A skeleton merge.
