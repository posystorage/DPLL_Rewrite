# DPLL Refactor Owner Table v1

Date: 2026-06-27

Status: active owner table for branch/worktree creation and subagent dispatch.

## Integration Branch

```text
refactor/dpll-single-path
```

Only the integration owner may merge role branches. Every merge must be an atomic commit with tests or an explicit "not run" note in the commit message/body.

## Eight Role Branches

| Role | Branch | Worktree | Owns |
|---|---|---|---|
| clock-valid | `agent/clock-valid` | `..\worktrees\agent-clock-valid` | clocking, valid, CDC notes, `adc_decimator_wrapper`, CDC docs/tests |
| frontend-nco-mixer | `agent/frontend-nco-mixer` | `..\worktrees\agent-frontend-nco-mixer` | DC blocker, tracking phase accumulator, sin/cos wrapper, IQ mixer |
| iq-cic | `agent/iq-cic` | `..\worktrees\agent-iq-cic` | post-IQ CIC, optional cleanup IIR, CIC model/tests |
| detector-fll | `agent/detector-fll` | `..\worktrees\agent-detector-fll` | CORDIC wrapper, wrapped phase error, FLL phase difference |
| hybrid-loop | `agent/hybrid-loop` | `..\worktrees\agent-hybrid-loop` | hybrid filter, anti-windup, lock detector, loop state manager |
| register-dac | `agent/register-dac` | `..\worktrees\agent-register-dac` | register snapshot/status, output MUL/DIV, debug bus, DACout1 debug |
| arm-control | `agent/arm-control` | `..\worktrees\agent-arm-control` | SDK DPLL register header/API/config/status/commands/mock MMIO |
| model-verification-timing | `agent/model-verification-timing` | `..\worktrees\agent-model-verification-timing` | float/fixed models, coefficient generator, tests, Vivado Tcl/report collection, timing/resource docs |

## Shared Rules

- Do not edit files outside your owner scope.
- Public interface changes require `docs/interface-change-RFC-NNN.md` first.
- Do not change ARM register ABI unless FPGA, ARM, docs, and tests are changed together.
- Do not reintroduce `clk_dpll` in the refactored core.
- Do not add `DigitalPLL2`.
- Do not add old/new runtime selection.
- Do not replace post-IQ CIC with high-order FIR.
- Do not restore PII2, PID I2, PID D, or D-filter semantics.
- Do not claim tests that were not run.

## Initial Merge Order

1. `agent/model-verification-timing` initial model scaffolding and report scripts.
2. `agent/clock-valid` single-clock/valid skeleton.
3. `agent/frontend-nco-mixer`.
4. `agent/iq-cic`.
5. `agent/detector-fll`.
6. `agent/hybrid-loop`.
7. `agent/register-dac`.
8. `agent/arm-control`.
9. final integration on `refactor/dpll-single-path`.

## Frozen Shared Documents

- `docs/baseline.md`
- `docs/dpll_interface_v1.md`
- `docs/dpll_fixed_point_v1.md`
- `docs/dpll_register_map_v1.md`
- `docs/owner_table_v1.md`
