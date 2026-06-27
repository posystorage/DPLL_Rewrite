# DPLL Refactor Subagent Dispatch v1

Date: 2026-06-27

Base commit: `d802d24`

Integration branch: `refactor/dpll-single-path`

Policy: role branches may only merge into the integration branch through tested, atomic commits. Public interface changes require an RFC under `docs/` before RTL, SDK, or constraint changes are made.

## Baseline Audit Decisions

- There is one functional DPLL path in the current Vivado source set.
- The two FIR instances in the DDC are I and Q branches of the same DPLL channel.
- `ADCraw1` feeds the independent frequency meter path, not a second DPLL.
- `DACout1` is debug output only in the refactor; it must not become a second DPLL output.
- Current `clk_dpll` usage is legacy and must be removed from the refactored core.
- Current routed implementation is archived but not timing clean: WNS is negative and CDC/clock-interaction reports were not present.

## Role Worktrees

| Role | Branch | Worktree | First Assignment |
|---|---|---|---|
| `model-verification-timing` | `agent/model-verification-timing` | `..\worktrees\agent-model-verification-timing` | Create repeatable Vivado 2018.3 report Tcl, xsim skeleton, fixed-point model harness, and baseline report capture. |
| `clock-valid` | `agent/clock-valid` | `..\worktrees\agent-clock-valid` | Draft single-clock valid-pulse skeleton for the existing `DigitalPLL` wrapper. Remove no public port until RFC/contract check is complete. |
| `frontend-nco-mixer` | `agent/frontend-nco-mixer` | `..\worktrees\agent-frontend-nco-mixer` | Isolate 125 MHz phase accumulator, LO generation, and mixer plan using frozen widths. |
| `iq-cic` | `agent/iq-cic` | `..\worktrees\agent-iq-cic` | Plan post-IQ CIC wrapper with shadow/apply R update and model tests. |
| `detector-fll` | `agent/detector-fll` | `..\worktrees\agent-detector-fll` | Define wrapped phase detector and FLL phase-difference path against the fixed-point model. |
| `hybrid-loop` | `agent/hybrid-loop` | `..\worktrees\agent-hybrid-loop` | Replace PII2 semantics with PI plus FLL blend plan; preserve full-width correction through MUL/DIV. |
| `register-dac` | `agent/register-dac` | `..\worktrees\agent-register-dac` | Implement register v1 only after interface check; define ABI/build ID and debug DAC mux readback. |
| `arm-control` | `agent/arm-control` | `..\worktrees\agent-arm-control` | Wait for register owner sync, then update SDK headers/API, command handlers, ABI check, and BOOT build notes. |

## Merge Gates

1. Every branch must include a test or a clear "not run" reason in its commit body.
2. RTL changes touching shared ports, register addresses, or fixed-point widths must reference an accepted RFC.
3. No merge may introduce `DigitalPLL2`, an old/new runtime selector, or a second DPLL use of `DACout1`.
4. No merge may reintroduce `clk_dpll` inside the refactored core.
5. No timing exception may be used to hide a real synchronous crossing or design error.
6. Each phase must refresh automated simulation and Vivado 2018.3 implementation reports before moving to the next phase.
