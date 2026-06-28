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
powershell -ExecutionPolicy Bypass -File scripts\run_post_iq_cic_golden_trace.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_hybrid_loop_golden_trace.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_single_clock_core_stage_a_xsim.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_angle_cordic_ip_trace.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_lo_dds_h_streaming_pinc_trace.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_input_multiplier_mixer_trace.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_pll_vco_mul_div_xsim.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_dpll_core_nonzero_tracking_trace.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_dpll_core_sine_lock_trace.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_dpll_core_sine_sweep_trace.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_dpll_multifrequency_path_xsim.ps1
powershell -ExecutionPolicy Bypass -File scripts\run_multifrequency_golden_trace.ps1
```

The current RTL checks cover the retained mixer unit, post-IQ CIC bit-exact fixed-point trace, hybrid FLL/PI/P fixed-point loop block, single-clock DPLL core path, CORDIC/DDS/mixer/VCO IP-aware traces, ARM mock MMIO behavior, and the 5/10/20/50/100/150/200 kHz multifrequency path. They do not replace a full float/fixed/RTL closed-loop golden comparison.

`run_post_iq_cic_golden_trace.ps1` runs the post-IQ CIC RTL simulation and
checks the generated CSV against a fixed-point model of the current RTL
non-blocking timing. It covers legal and illegal APPLY, explicit flush, R=8
and R=12, impulse/step-like stimulus, warmup suppression, symmetric rounding,
saturation checks, and I/Q shared valid alignment.

`run_multifrequency_golden_trace.ps1` runs the multifrequency RTL simulation,
loads the generated CSV trace, and checks it against the frozen 48-bit/125 MHz
fixed-point frequency-word model. The current checker uses zero loop gains, so
the golden tracking word equals the applied center word.

`run_hybrid_loop_golden_trace.ps1` runs the hybrid loop RTL simulation and
checks FLL, PI, P, anti-windup, correction saturation, and tracking-word
saturation against a Python fixed-point model.

`run_angle_cordic_ip_trace.ps1` drives the real Vivado `angle_CORDIC`
simulation model and checks `{Q,I}` packing, scaled-radian phase quadrants,
valid output, and raw no-scale-compensation magnitude behavior.

`run_lo_dds_h_streaming_pinc_trace.ps1` drives the tracked `LO_DDS_H` DDS
model and checks streaming PINC phase increments, data/phase valid alignment,
and sin/cos quadrant coverage.

`run_input_multiplier_mixer_trace.ps1` drives the real mixer multiplier IP
model and checks one-cycle product/valid alignment for changing sample IDs.

`run_pll_vco_mul_div_xsim.ps1` compiles the real multiplier and unsigned
divider IP models with `PLL_VCO_MUL_DIV` and checks legal scaling, `DIV[15]`,
zero-factor rejection, saturation, and latest-wins pending behavior.

`run_dpll_core_nonzero_tracking_trace.ps1` runs the real DDS/mixer/CIC/CORDIC/
FLL/hybrid core path with nonzero loop gains and checks multiple nonzero
corrections plus the registered next-row tracking-word update contract.

`run_dpll_core_sine_lock_trace.ps1` drives a 20.1 kHz sine input at the
equivalent 3.125 MSPS cadence into the real DDS/mixer/CIC/CORDIC/FLL/hybrid
core path. The test uses the 20 kHz post-IQ CIC configuration from the fixed
point v1 table and a `-pi/2` phase setpoint appropriate for sine stimulus,
checks valid FLL measurements, nonzero positive tracking response, and
TRACK/locked samples.

`run_dpll_core_sine_sweep_trace.ps1` drives sine inputs across the review2
5/10/20/50/100/150/200 kHz centers with the corresponding post-IQ CIC
configurations from the fixed-point v1 table. It checks valid FLL
measurements, nonzero high-side tracking response, and TRACK/locked samples
through the real DDS/mixer/CIC/CORDIC/FLL/hybrid path. It is an RTL/IP closed
loop smoke sweep, not a complete tuned control-theory sign-off model.

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
