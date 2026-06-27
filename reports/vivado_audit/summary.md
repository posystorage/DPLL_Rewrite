# P1 Vivado Audit Summary

Date: 2026-06-27

Tool: Vivado 2018.3, invoked as `D:\Xilinx\Vivado\2018.3\bin\vivado.bat`

Command:

```powershell
& 'D:\Xilinx\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\vivado_audit_reports.tcl
```

Project: `E:/FPGA/DPLL_Rewrite/DPLL_Rewrite_THbox_T3/DPLL_Rewrite.xpr`

Run: `impl_1`

## Generated Reports

- `manifest.txt`
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

## Timing Result

The existing routed baseline remains timing-failing:

```text
WNS = -4.227 ns
TNS = -4578.298 ns
TNS failing endpoints = 2437
Timing constraints are not met.
```

Most severe clock-pair results include:

```text
adc_clk -> pll_adc_clk       WNS -4.227 ns, TNS -4508.301 ns
pll_adc_clk -> DPLL_clk      WNS -2.231 ns, TNS -5.349 ns
pll_clk_adc_2x -> DPLL_clk   WNS -0.336 ns, TNS -0.401 ns
DPLL_clk -> pll_adc_clk      WNS -1.93 ns,  TNS -15.89 ns
```

## CDC And Clock Interaction

`audit_cdc.rpt` reports:

```text
All paths are Safely Timed.
```

This is not equivalent to "no CDC risk"; Vivado also states that `report_cdc` analyzes only paths where clocks are defined on both source and destination sides and skips unconstrained input ports.

`audit_clock_interaction.rpt` is present and shows multiple timed inter-clock paths with negative setup slack involving `DPLL_clk`.

## DRC And Methodology

`audit_drc.rpt` reports 69 violations:

```text
BUFC-1     16
DPIP-1     16
DPOP-1      2
DPOP-2     10
REQP-1709   1
AVAL-4     12
AVAL-5      8
REQP-28     2
REQP-30     2
```

`audit_methodology.rpt` reports 1079 violations, including:

```text
TIMING-4    2
TIMING-16   1000
TIMING-18   40
TIMING-27   1
TIMING-30   3
```

## Route Status

The design is fully routed:

```text
routable nets = 18827
fully routed nets = 18827
routing errors = 0
```

## P1 Conclusion

The P1 audit report flow is repeatable and has been executed with Vivado 2018.3. The reports confirm the current baseline is a valid archived implementation for comparison, but it is not timing-clean and must not be treated as a passing timing gate.
