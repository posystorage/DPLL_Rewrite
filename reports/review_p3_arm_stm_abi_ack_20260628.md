# Review P3 ARM STM ABI ACK Closure

## Scope

Closed an ARM control-flow gap from `docs/review.md`: STM-side DPLL commands no longer report success before executing ABI-gated DPLL actions.

The system bus direct `adc_clk -> pll_adc_clk` timing issue remains intentionally out of scope.

## Changes

- `STM_HOST_Write_PLL_Data` now returns `STATUS_ACK` only when `DPLL_CONFIG_APPLY` succeeds.
- `CMD_PLL_ON` over STM now returns `STATUS_ACK` only when `dpll_set_enable(1)` succeeds.
- `CMD_READ_STATUS_DATA` still sends the data response directly and avoids a duplicate status ACK.
- PC-side ABI gating remains in place for PLL ON and DPLL config APPLY.

## Verification

- `python scripts\audit_arm_dpll_control.py`
  - Confirms ARM header ABI/config/build/APPLY/CIC register exposure.
  - Confirms startup ABI check.
  - Confirms PC and STM ABI-gated APPLY/enable paths.
  - Confirms STM no longer ACKs before command execution.
- Xilinx SDK 2018.3 ARM build:
  - Command run from `DPLL_Rewrite.sdk\DPLL_2COM\Debug` with SDK 2018.3 ARM gcc in `PATH`.
  - `make all`
  - Result: `DPLL_2COM.elf` rebuilt successfully.
  - Existing warning remains: unused local `XScuGic_Config_ps` in `Uart1PS_Init`.
  - Existing makefile post-link/pre-build hook `a9-linaro-pre-build-step` is missing but marked ignored by the generated makefile.

## Non-Changes

- No FPGA register ABI address change.
- No DPLL RTL datapath change.
- No false path added.
- No change to the excluded `adc_clk -> pll_adc_clk` bus timing issue.
