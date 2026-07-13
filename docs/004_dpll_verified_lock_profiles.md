# 004 已验证锁定的 DPLL Profile

更新日期：2026-07-11

本文只记录已经由当前行为级仿真确认可锁定的 profile。它们是后续调试的可复现实验基线，不表示同一组 FLL/PI 增益可以直接外推到全部频段。

所有频率字使用 125 MHz DDS 时钟。修正限幅寄存器 `0x0028/0x0029` 是 signed DDS 高 32 位，FPGA 内部补 16 个低位零；表中的 `±20%` 是允许控制量范围，不等同于已实测捕获范围。

## 1. 共用环路参数

| 寄存器 | 参数 | 值 |
|---:|---|---:|
| `0x0021` | `Kp_track` | `6000000` |
| `0x0022` | `Ki_track` | `180000` |
| `0x0023` | `Kf_acquire` | `8000000` |
| `0x0024` | `Kf_blend` | `1500000` |
| `0x0025` | `Kf_track` | `250000` |
| `0x0026` | `Kp_blend` | `6000000` |
| `0x0027` | `Ki_blend` | `468800` |
| `0x0050` | phase-lock threshold | `5825`，约 8° |
| `0x0051` | phase setpoint | `0xFFFF0000`，`-pi/2` |
| `0x0052` | frequency-lock threshold | `2147`，约 100 Hz |
| `0x0053/0x0054` | magnitude enter/exit | `16384 / 8192` |
| `0x0055/0x0056/0x0057` | acquire/blend/loss dwell | `16 / 64 / 64` |
| `0x0063` | warmup samples | `16` |
| `0x0064` | post-IIR mode | `3`，AUTO |

## 2. 22 kHz Profile

仿真已确认锁定的低频基线：中心约 22 kHz，激励约 21.5 kHz，初始频差约 -500 Hz。

| 项目 | 值 |
|---|---|
| center word high | `0x000B88CA`，约 21999.9929 Hz |
| stimulus word | `0x000B45AE5FFA`，约 21500.0000 Hz |
| post-CIC | `R=16`，`shift=8`，输出 195312.5 Hz |
| FLL delay | selector `3`，`L=8` |
| ACQUIRE IIR cutoff | 4 kHz |
| TRACK IIR cutoff | 2 kHz |
| correction limit | `0x00024E8F / 0xFFFDB171`，约 ±4400.0044 Hz |

| bank | b0 | b1 | b2 | a1 | a2 |
|---|---|---|---|---|---|
| ACQUIRE | `003E186B` | `007C30D5` | `003E186B` | `8B9E5F9E` | `355A020C` |
| TRACK | `00103681` | `00206D02` | `00103681` | `85D1D2A9` | `3A6F075A` |

## 3. 200 kHz Profile

仿真已确认锁定的高频基线：中心约 200 kHz，激励约 220 kHz，初始频差约 +20 kHz。

| 项目 | 值 |
|---|---|
| center word high | `0x0068DB8C`，约 200000.0095 Hz |
| stimulus word | `0x007357E670E3`，约 220000.0000 Hz |
| post-CIC | `R=12`，`shift=8`，输出约 260416.667 Hz |
| FLL delay | selector `1`，`L=2` |
| ACQUIRE IIR cutoff | 18 kHz |
| TRACK IIR cutoff | 8 kHz |
| correction limit | `0x0014F8B6 / 0xFFEB074A`，约 ±40000.0135 Hz |

| bank | b0 | b1 | b2 | a1 | a2 |
|---|---|---|---|---|---|
| ACQUIRE | `024A1A1A` | `04943435` | `024A1A1A` | `A6824173` | `22A626F7` |
| TRACK | `0085F595` | `010BEB29` | `0085F595` | `91619BD8` | `30B63A7A` |

## 4. 5.5 kHz Profile

行为级仿真已确认锁定：中心约 5.5 kHz，激励 5 kHz，初始频差约 -500.013 Hz。

| 项目 | 值 |
|---|---|
| center word high | `0x0002E233`，约 5500.0128 Hz |
| stimulus word | `0x00029F16B11C`，约 5000.0000 Hz |
| post-CIC | `R=16`，`shift=8`，输出 195312.5 Hz |
| FLL delay | selector `3`，`L=8` |
| ACQUIRE IIR cutoff | 1.2 kHz |
| TRACK IIR cutoff | 0.8 kHz |
| correction limit | `0x000093A4 / 0xFFFF6C5C`，约 ±1.1 kHz |
| measurement timeout | `125000`，即 1 ms |

| bank | b0 | b1 | b2 | a1 | a2 |
|---|---|---|---|---|---|
| ACQUIRE | `0005F0F3` | `000BE1E6` | `0005F0F3` | `837E41D7` | `3C9981F6` |
| TRACK | `0002AA10` | `00055420` | `0002AA10` | `82543FE5` | `3DB6685B` |

### 低频 timeout 注意事项

旧实现的 AUTO post-IIR 在状态 `4 -> 5` 时从 ACQUIRE 切换为 TRACK，并清空 IIR/CORDIC 状态。0.8 kHz TRACK 滤波器恢复到 magnitude enter 门限约需 0.374 ms，随后还需要重建 `L=8` 历史和 16 点 cross-dot 块。

`measurement_timeout=0` 对 `R=16` 生成的自动值只有 `2400*16+512=38912` 个 125 MHz 周期，即约 0.311 ms。该时间短于低频检测链恢复时间，会先触发 `LOSS_TIMEOUT=6`。因此 4--8 kHz profile 必须显式使用至少 1 ms；当前验证值为 `125000`。

当前 RTL 将 TRACK IIR 切换提前到 state 4/8 内部的 FLL-only 预热阶段，并等待 4 个恢复后的 block-valid 测量再进入 state 5。1 ms timeout 仍然保留，用于覆盖低频 TRACK IIR、CORDIC 和 FLL history 的主动重建窗口。

50 ms 仿真中，20 ms 时为状态 5、`loss_reason=0`、signal/frequency 有效；50 ms 时进入状态 6，phase/frequency/locked 全部为 1，并通过 TB 最终检查。

ARM profile 驱动的可配置范围现已扩展为 4--250 kHz。5--200 kHz 为标准生成区间；4--5 kHz 与 200--250 kHz 只表示参数检查通过并允许 APPLY，不表示能够锁定。
