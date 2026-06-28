# DPLL Register Map v1 Draft

Date: 2026-06-27

Status: frozen draft v1 for coordinated FPGA/ARM implementation. ABI changes require RFC.

Base:

```text
DPLL_BASE_ADDR = 0x40600000
absolute address = DPLL_BASE_ADDR + (index << 2)
```

## ABI

Required:

```text
ABI_VERSION
FPGA_BUILD_ID
ARM_EXPECTED_ABI_VERSION
```

ARM must not enable the DPLL when ABI/build checks fail.

## Write Registers

| Index | Name | Effect |
|---:|---|---|
| `0x0000` | `DPLL_RESET` | immediate |
| `0x0010` | `CENTER_FREQUENCY_WORD` | shadow/apply |
| `0x0011` | `READBACK_SELECTOR` | live diagnostic selector |
| `0x0020` | `DPLL_ENABLE` | immediate |
| `0x0021` | `PLL_KP_TRACK` | shadow/apply |
| `0x0022` | `PLL_KI_TRACK` | shadow/apply |
| `0x0023` | `FLL_KF_ACQUIRE` | shadow/apply |
| `0x0024` | `FLL_KF_BLEND` | shadow/apply |
| `0x0025` | `FLL_KF_TRACK` | shadow/apply |
| `0x0026` | `PLL_KP_BLEND` | shadow/apply |
| `0x0027` | `PLL_KI_BLEND` | shadow/apply |
| `0x0028` | `CORRECTION_LIMIT_POS` | shadow/apply |
| `0x0029` | `CORRECTION_LIMIT_NEG` | shadow/apply |
| `0x002A` | `MANUAL_FREQUENCY_OFFSET` | shadow/apply |
| `0x0030` | `DAC0_OFFSET` | shadow/apply |
| `0x0031` | `DAC0_AMPLITUDE` | shadow/apply |
| `0x0032` | `OUTPUT_MUL` | shadow/apply |
| `0x0033` | `OUTPUT_DIV` | shadow/apply, reject zero |
| `0x0040` | `DEBUG_DAC_OFFSET` | live debug |
| `0x0041` | `DEBUG_DAC_GAIN` | live debug |
| `0x0042` | `DEBUG_DAC_SOURCE` | live debug |
| `0x0043` | `DEBUG_DAC_FORMAT` | live debug |
| `0x0050` | `PHASE_LOCK_THRESHOLD` | shadow/apply |
| `0x0051` | `PHASE_SETPOINT` | shadow/apply |
| `0x0052` | `FREQUENCY_LOCK_THRESHOLD` | shadow/apply |
| `0x0053` | `MAG_ENTER_THRESHOLD` | shadow/apply |
| `0x0054` | `MAG_EXIT_THRESHOLD` | shadow/apply |
| `0x0055` | `ACQUIRE_DWELL` | shadow/apply |
| `0x0056` | `BLEND_DWELL` | shadow/apply |
| `0x0057` | `LOSS_DWELL` | shadow/apply |
| `0x0058` | `HOLDOVER_TIMEOUT` | shadow/apply |
| `0x0060` | `POST_IQ_CIC_R` | shadow/apply |
| `0x0061` | `POST_IQ_CIC_SCALE` | shadow/apply |
| `0x0062` | `FLL_CONFIG` | shadow/apply |
| `0x0063` | `WARMUP_SAMPLES` | shadow/apply |
| `0x006F` | `CONFIG_APPLY` | apply trigger/status command |

## Read Registers

| Index | Name |
|---:|---|
| `0x0100` | `DPLL_STATUS` |
| `0x0101` | `MAGNITUDE` |
| `0x0102` | `CORDIC_PHASE` |
| `0x0103` | `FLL_ERROR` |
| `0x0104` | `FREQ_CORRECTION` |
| `0x0105` | `TRACKING_WORD_LO` |
| `0x0106` | `PHASE_ERROR` |
| `0x0107` | `AVERAGE_CORRECTION` |
| `0x0108` | `LOOP_STATE_AND_LOSS_REASON` |
| `0x0109` | `ACTIVE_CIC_CONFIG` |
| `0x010A` | `TRACKING_WORD_HI` |
| `0x010B` | `OUTPUT_WORD_LO` |
| `0x010C` | `OUTPUT_WORD_HI` |
| `0x010D` | `CONFIG_VERSION` |
| `0x010E` | `ABI_VERSION` |
| `0x010F` | `FPGA_BUILD_ID` |

## `0x0108` Core Flags

| Bits | Name |
|---:|---|
| 31:18 | reserved |
| 17 | `VCO_MUL_DIV_CONFIG_ERROR` |
| 16:13 | `LOOP_STATE` |
| 12:9 | `LOSS_REASON` |
| 8 | `SIGNAL_PRESENT` |
| 7 | `PHASE_LOCKED` |
| 6 | `FREQUENCY_LOCKED` |
| 5 | `LOCKED` |
| 4 | `TRACKING_VALID` |
| 3 | `FREQ_ERROR_VALID` |
| 2 | `IQ_VALID` |
| 1 | `CIC_ILLEGAL_CONFIG` |
| 0 | `CIC_OVERFLOW` |

`VCO_MUL_DIV_CONFIG_ERROR` is sticky until reset. It is set when a requested
output scaling sample has `MUL=0` or `DIV=0`; the illegal sample is rejected
rather than silently clamped. The active divider IP is unsigned, so the full
16-bit `DIV` range, including `DIV[15]=1`, is legal.

## Debug DAC Source

| Value | Source |
|---:|---|
| 0 | `FREQ_CORRECTION` |
| 1 | `TRACKING_WORD_MINUS_CENTER` |
| 2 | `FREQ_STATE` |
| 3 | `PHASE_ERROR` |
| 4 | `FLL_ERROR` |
| 5 | `POST_CIC_I` |
| 6 | `POST_CIC_Q` |
| 7 | `CORDIC_PHASE` |
| 8 | `MAGNITUDE` |
| 9 | `OUTPUT_WORD_DELTA` |
| 10 | `LOOP_STATE_CODE` |

## Debug DAC Format

```text
bits  5:0   SHIFT_OR_LSB
bits  9:8   MODE
bit   10    INVERT
bit   11    HOLD_LAST
bits 31:16  reserved
```

Modes:

```text
0 RAW_BIT_WINDOW
1 ARITH_SHIFT_SAT
2 UNSIGNED_SAT
3 RESERVED
```

## Known Baseline ABI Risk

Current ARM macro `DAC0_VCO_Offset_Addr` is written as `(00030<<2)` in `Peripherals.h`. This is decimal 30, not hex `0x0030`.

The v1 target ABI uses index `0x0030`. ARM/register implementation must include a mock MMIO test proving the corrected index.
