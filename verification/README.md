# DPLL Verification

This directory belongs to `agent/model-verification-timing`.

## Fixed-Point Smoke Tests

Run from the repository root:

```powershell
python -m unittest discover -s verification\fixed_point -p test_*.py
```

The tests cover v1 frequency words, phase wrapping, CIC width bounds, and the rule that tracking correction remains full width before output MUL/DIV.

## ARM Mock MMIO Tests

Run from the repository root:

```powershell
python -m unittest discover -s verification\arm -p test_*.py
```

The tests parse the real ARM register definitions and exercise ABI gating, CONFIG_APPLY, enable control, and advanced DPLL shadow-register writes against a mock MMIO map.

## RTL XSIM Checks

Run from the repository root with Vivado 2018.3 installed at `D:\Xilinx\Vivado\2018.3`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_frontend_stage_a_xsim.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_dpll_multifrequency_path_xsim.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_multifrequency_golden_trace.ps1
```

The current RTL checks cover the retained mixer unit, the single-clock DPLL core path, and the 5/10/20/50/100/150/200 kHz multifrequency path. They do not replace a full float/fixed/RTL closed-loop golden comparison.

`run_multifrequency_golden_trace.ps1` runs the multifrequency RTL simulation,
loads the generated CSV trace, and checks it against the frozen 48-bit/125 MHz
fixed-point frequency-word model. The current checker uses zero loop gains, so
the golden tracking word equals the applied center word.

## Review Closure Audits

Run from the repository root:

```powershell
python scripts\audit_review_closure.py
python scripts\audit_review2_closure.py
python scripts\audit_review2_ip_config.py
```

The generated reports are written under `reports\`.

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
