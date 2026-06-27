# Review P1 Loop State Manager Progress

Date: 2026-06-28
Branch: `refactor/dpll-single-path`

## Scope

This pass addresses the `review.md` P1 functional-control findings:

- add a real FLL/PLL state manager;
- stop enabling FLL, PLL-I, and PLL-P unconditionally together;
- add magnitude/signal-present based lock gating;
- expose loop state and loss reason through the frozen v1 status ABI;
- start synchronizing ARM header symbols away from legacy PID names.

It does not claim full DPLL signoff, full ARM command refactor, timing closure, board validation, or final bitstream generation.

## RTL Changes

- Added `loop_state_manager_stage_a`.
- States implemented: `RESET`, `DISABLED`, `CONFIGURE`, `WARMUP`, `FLL_ACQUIRE`, `FLL_PLL_BLEND`, `PLL_TRACK`, `HOLDOVER`, `REACQUIRE`, `FAULT`.
- Loss reasons implemented: none, signal, phase, frequency, CIC fault, saturation, timeout.
- `dpll_single_clock_core_stage_a` now uses CORDIC magnitude for signal-present hysteresis and uses the state manager to choose:
  - FLL-only acquire;
  - blended FLL + PLL-I + PLL-P;
  - tracking coefficients;
  - holdover/reacquire behavior.
- Phase error is now CORDIC phase minus `PHASE_SETPOINT`.
- `dpll_wrapper` implements v1 register slots for:
  - `FLL_KF_BLEND`, `FLL_KF_TRACK`, `PLL_KP_BLEND`, `PLL_KI_BLEND`;
  - magnitude thresholds;
  - acquire/blend/loss dwell;
  - holdover timeout;
  - warmup samples.
- `0x0108` now reads back loop state, loss reason, signal/lock flags, and core valid/fault flags.

## ARM Header Changes

- `Peripherals.h` now defines v1 DPLL coefficient names instead of legacy `PLL0_PID_*` names.
- Added v1 macros for magnitude thresholds, dwell counters, holdover timeout, warmup samples, and loop-state/loss readback.
- Existing `helloworld.c` references were updated to the v1 macro names so the source is not left pointing at removed PID macros.

## Verification Run

Executed with Vivado 2018.3:

- `powershell -ExecutionPolicy Bypass -File scripts\run_loop_state_manager_stage_a_xsim.ps1`
  - PASS: `loop_state_manager_stage_a_tb`
- `powershell -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1`
  - PASS: `dpll_single_clock_core_stage_a_tb`
  - Includes `LO_DDS_H`, `input_multiplier`, and `angle_CORDIC` IP simulation models.
- `D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl`
  - `synth_design Complete!`
  - 0 synthesis errors.
  - Timing summary still reports failure, so this is synthesis evidence only.

## Remaining Review Items

- Full ARM command-layer refactor is still incomplete; command names and payload semantics still reflect old PID protocol in places.
- DACout1 debug formatter still needs timing-oriented raw-window/pipelined modes.
- Output MUL/DIV still uses the existing dynamic IP path and still needs a real multi-cycle FSM or reciprocal path.
- Full system verification sweeps, reacquire/noise/drop tests, DACout1 bit-exact tests, ARM mock MMIO tests, board validation, and final implementation/bitstream are not complete.
- Timing closure remains open, except the user explicitly excluded fixing the direct `adc_clk -> pll_adc_clk` system bus crossing in this goal.
