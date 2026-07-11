# DigitalPLL Integrated Flow Testbench

This testbench targets the current `dpll_wrapper` integration boundary rather
than the board-level `red_pitaya_top`. It keeps the simulation focused on the
DigitalPLL data path, register shell, LED status, and DAC outputs without
bringing in the Zynq PS and full Red Pitaya platform.

## Files

- `verification/rtl/dpll_integrated_flow_tb.v`
- `scripts/vivado_dpll_integrated_flow_sim.tcl`
- `scripts/run_dpll_integrated_flow_sim.ps1`

## Flow Covered

1. Generate `clk1` at 125 MHz and `sys_clk` at 100 MHz.
2. Release active-low wrapper resets.
3. Instantiate `DAC_DDS0` in the testbench to create a signed 21.5 kHz
   ADC-like sine stimulus on `ADCraw0`.
4. Use the wrapper register bus to initialize the v1 DPLL register map:
   reset first, keep lock disabled, wait, write a 22 kHz center word, write
   gains, limits, DAC0 output settings, debug DAC source, thresholds, CIC
   rate/shift, and warmup/timeout registers.
5. Wait again, write `CONFIG_APPLY`, poll `0x006F` until the apply sequence
   completes, then write `DPLL_ENABLE`.
6. Read active snapshot and status registers, including loop flags,
   magnitude, phase, frequency error, tracking word, and output word.
7. Observe `DACout0`, `DACout1`, and `led[6:0]`.
8. Switch `DACout1` debug source from CORDIC phase to magnitude during the run.

The default run length is intentionally short so Vivado 2018.3 can show the
full startup sequence quickly with real IP models. Increase `RUN_CYCLES_0` and
`RUN_CYCLES_1` in the testbench if you want to watch longer lock settling.

## Launch

From PowerShell:

```powershell
cd E:\FPGA\DPLL_Rewrite\DPLL_Rewrite_Low_Trace
powershell -ExecutionPolicy Bypass -File .\scripts\run_dpll_integrated_flow_sim.ps1
```

Or inside Vivado Tcl:

```tcl
source E:/FPGA/DPLL_Rewrite/DPLL_Rewrite_Low_Trace/scripts/vivado_dpll_integrated_flow_sim.tcl
```

The Tcl script adds the testbench to `sim_1`, sets
`dpll_integrated_flow_tb` as the simulation top, launches XSim, adds the main
bus/data/status/DAC/LED signals to the waveform, and runs until `$finish`.
