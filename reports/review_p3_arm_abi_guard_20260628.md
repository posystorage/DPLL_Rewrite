# P3 ARM ABI Guard Follow-up

Date: 2026-06-28
Branch: `refactor/dpll-single-path`

## Scope

This follow-up tightens the ARM side of the frozen DPLL v1 ABI. The prior ARM sync added the v1 register names and command handlers; this checkpoint makes the startup ABI/build check functional.

## Changes

File: `DPLL_Rewrite.sdk/DPLL_2COM/src/helloworld.c`

- Added expected ARM-side constants:
  - `ARM_EXPECTED_DPLL_ABI_VERSION = 0x00000001`
  - `ARM_EXPECTED_DPLL_CONFIG_VERSION = 0x00010000`
  - `ARM_EXPECTED_DPLL_FPGA_BUILD_ID = 0xD9110002`
- Added `dpll_check_abi()` to read `DPLL_ABI_VERSION_Addr`, `DPLL_CONFIG_VERSION_Addr`, and `DPLL_FPGA_BUILD_ID_Addr` at startup.
- Added `dpll_set_enable()` so PC and STM enable commands cannot enable the DPLL when ABI/build checks fail.
- Added guarded `dpll_apply_config()` so PC/STM APPLY writes are suppressed on ABI mismatch.
- Preserved frequency-meter PID commands on the frequency-meter register bank; this change only guards the active DPLL control path.

## Verification

Command:

```powershell
$env:PATH='D:\Xilinx\SDK\2018.3\gnu\aarch32\nt\gcc-arm-none-eabi\bin;D:\Xilinx\SDK\2018.3\gnuwin\bin;' + $env:PATH
& 'D:\Xilinx\SDK\2018.3\gnuwin\bin\make.exe' -B -C DPLL_Rewrite.sdk\DPLL_2COM\Debug all
```

Result: PASS, exit code 0.

Generated:

- `DPLL_Rewrite.sdk/DPLL_2COM/Debug/DPLL_2COM.elf`
- Size: text `43664`, data `1952`, bss `29512`, dec `75128`, hex `12578`

Known build warnings:

- Existing `Uart1PS_Init` unused local variable warning.
- SDK-generated `a9-linaro-pre-build-step` is missing, but the make rule marks this pre-build error as ignored and the final make exit code is 0.

## Remaining Boundary

This does not change the FPGA register ABI. It only makes the ARM firmware refuse DPLL enable/APPLY when the frozen ABI/build identifiers do not match the bitstream.
