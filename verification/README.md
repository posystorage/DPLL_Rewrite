# Verification P1 Scaffold

This directory belongs to `agent/model-verification-timing`.

## Fixed-Point Smoke Tests

Run from the repository root:

```powershell
python -m unittest discover -s verification\fixed_point -p test_*.py
```

The tests cover v1 frequency words, phase wrapping, CIC width bounds, and the rule that tracking correction remains full width before output MUL/DIV.

## Vivado 2018.3 Audit Reports

Run from the repository root with Vivado 2018.3 on `PATH`:

```powershell
vivado -mode batch -source scripts\vivado_audit_reports.tcl
```

Reports are written to `reports\vivado_audit` by default. The script opens `impl_1` when available; if the run is unavailable it attempts to launch the implementation run to `route_design`.

The first required report set is:

- `audit_timing_summary.rpt`
- `audit_timing_paths.rpt`
- `audit_utilization_hier.rpt`
- `audit_clock_utilization.rpt`
- `audit_clock_interaction.rpt`
- `audit_cdc.rpt`
- `audit_drc.rpt`
- `audit_methodology.rpt`
- `audit_route_status.rpt`
- `audit_bus_skew.rpt`

If a Vivado 2018.3 command is unavailable in the local installation, the script writes an adjacent `*.ERROR.txt` file instead of silently succeeding.
