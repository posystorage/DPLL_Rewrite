# P3 ARM v1 Sync Verification

Date: 2026-06-28
Branch: refactor/dpll-single-path

## Scope

- Synced ARM command names away from the old PLL PID command labels while preserving the existing command numbers for compatibility.
- Added PC read commands for DPLL ABI/build/status and advanced DPLL configuration.
- Added PC write commands for advanced DPLL configuration and DACout1 debug formatting.
- Updated ARM-side DPLL frequency limit register names to match the v1 ABI.
- Kept frequency meter limit registers on the frequency meter base address.
- Added APPLY writes after DPLL basic/advanced configuration updates and STM configuration writes.
- Added startup defaults for blend loop gains, magnitude thresholds, dwell counters, holdover, post-IQ CIC R/shift, FLL delay selection, and warmup samples.

## Verification

Command:

```powershell
$env:PATH='D:\Xilinx\SDK\2018.3\gnu\aarch32\nt\gcc-arm-none-eabi\bin;D:\Xilinx\SDK\2018.3\gnuwin\bin;' + $env:PATH
& 'D:\Xilinx\SDK\2018.3\gnuwin\bin\make.exe' -B -C DPLL_Rewrite.sdk\DPLL_2COM\Debug all
```

Result:

- Build exit code: 0.
- ELF linked: `DPLL_Rewrite.sdk/DPLL_2COM/Debug/DPLL_2COM.elf`.
- Size: text 41460, data 1952, bss 29496, dec 72908, hex 11ccc.

Warnings:

- Existing style warning: `Uart1PS_Init` declares unused `XScuGic_Config_ps`.
- Existing style warning: `main` sets `i` without later use.
- SDK generated makefile attempts `a9-linaro-pre-build-step`; this command is missing but the make rule marks the step ignored and the build exits successfully.

## Known Remaining Issue

This ARM sync does not attempt to fix the known unresolved FPGA timing closure issue. The user explicitly excluded only the direct system-bus `adc_clk -> pll_adc_clk` timing problem from the current completion target.
