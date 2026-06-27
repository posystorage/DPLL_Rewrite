# clk_dpll Stage A Migration Plan

Date: 2026-06-27

Branch owner: `agent/clock-valid`

## Current Audit

Run:

```powershell
python scripts\audit_clk_dpll_usage.py
```

The generated report is `reports/clk_dpll_migration_audit.md`.

## Owner Buckets

- `clock-valid-owner`: wrapper-local clocked processes that must become `clk1` processes gated by Stage A valid pulses.
- `frontend-nco-mixer-owner`: DDC frontend, LO DDS, mixer, FIR/CORDIC legacy path. This bucket should move only after the frontend owner has a replacement plan.
- `hybrid-loop-owner`: loop filter and output summing paths. This bucket must not restore PII2 or truncate tracking correction before MUL/DIV.
- `register-dac-owner`: debug/status/DAC output and output MUL/DIV related paths. This bucket must preserve DACout1 as debug only.
- `stage-a-wrapper-boundary`: temporary wrapper port allowed by RFC-001 Stage A only.

## Merge Rule

Every commit that reduces `clk_dpll` use must update `reports/clk_dpll_migration_audit.md` and state the new active hit count in the commit body.

No commit may remove `clk_dpll` from the public wrapper boundary until RFC-001 Stage B gates are satisfied.
