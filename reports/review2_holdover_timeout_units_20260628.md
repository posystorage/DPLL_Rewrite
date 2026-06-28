# Review2 Holdover Timeout Units

Date: 2026-06-28

## Decision

The v1 ABI defines `HOLDOVER_TIMEOUT` as raw 125 MHz clock ticks, not post-CIC samples and not milliseconds. The wrapper applies the low 24 bits atomically through `CONFIG_APPLY`.

## Current RTL Evidence

- `dpll_wrapper.v` snapshots `Holdover_Timeout0[23:0]` into `active_holdover_timeout`.
- `dpll_single_clock_core_stage_a.v` connects that active value to both `holdover_timeout` and the no-measurement watchdog path.
- `loop_state_manager_stage_a.v` increments `measurement_gap_count` and `holdover_count` once per `clk_125m` cycle when their respective conditions are active.
- RTL treats a programmed value of zero as one tick through `nonzero_timeout()`.

## Verification

`loop_state_manager_stage_a_tb` uses `measurement_timeout=8` and `holdover_timeout=8`. It verifies the no-measurement transition to `ST_HOLDOVER`, then verifies that eight additional 125 MHz clock ticks in holdover transition to `ST_FAULT` with `LOSS_TIMEOUT`.
