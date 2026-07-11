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

## 4. 当前待验证 Profile

当前活动 TB 已切换为 5.5 kHz 中心、5 kHz 激励，初始频差约 -500.013 Hz。它使用 ARM profile 生成规则给出的 `R=16`、`shift=8`、`L=8`、ACQUIRE 1.2 kHz、TRACK 0.8 kHz 和约 ±1.1 kHz 限幅；在完成本轮仿真前，不应把它标记为已验证锁定。

ARM profile 驱动的可配置范围现已扩展为 4--250 kHz。5--200 kHz 为标准生成区间；4--5 kHz 与 200--250 kHz 只表示参数检查通过并允许 APPLY，不表示能够锁定。
