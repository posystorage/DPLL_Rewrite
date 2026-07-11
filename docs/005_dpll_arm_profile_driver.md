# 005 ARM DPLL Profile 驱动与有效性检查

更新日期：2026-07-11

## 1. 模块边界

- `dpll_profile.c/.h`：纯参数层。负责频段查表、CIC/FLL delay 选择、
  Q2.30 IIR 生成、环路默认值和有效性检查，不访问硬件。
- `dpll_driver.c/.h`：硬件事务层。负责 ABI、shadow 写入、CONFIG_APPLY、
  active readback 和 CRC。
- `helloworld.c`：协议与应用层。解析 PC/STM 命令，打印 profile 支持等级，
  不再维护一套分散的启动参数。

## 2. 支持等级

| 等级 | 范围或中心 | 含义 |
|---|---|---|
| `VERIFIED` | 5.5 kHz、22 kHz、200 kHz 精确 DDS 高字 | 已有行为级仿真锁定证据 |
| `STANDARD` | 5--200 kHz | 根据当前架构规则生成，仍需具体硬件频点验收 |
| `EXTENDED` | 4--5 kHz、200--250 kHz | 允许配置且通过数学检查，但不保证锁定 |

超出 `4--250 kHz` 才会被驱动直接拒绝。

## 3. 频段表

| 中心频率 | ACQUIRE IIR | TRACK IIR | measurement timeout |
|---:|---:|---:|---:|
| 4--8 kHz | 1.2 kHz | 0.8 kHz | `125000`，1 ms |
| 8--15 kHz | 2 kHz | 1.2 kHz | `0`，自动 |
| 15--30 kHz | 4 kHz | 2 kHz | `0`，自动 |
| 30--60 kHz | 8 kHz | 3.5 kHz | `0`，自动 |
| 60--100 kHz | 12 kHz | 5 kHz | `0`，自动 |
| 100--150 kHz | 15 kHz | 7 kHz | `0`，自动 |
| 150--200 kHz | 18 kHz | 8 kHz | `0`，自动 |
| 200--250 kHz | 20 kHz | 9 kHz | `0`，自动 |

驱动从 `R={16,15,12,10,8}` 中选择满足镜频和吞吐约束的最大值，
shift 使用 nominal CIC shift 加 1 bit CORDIC headroom。

## 4. 有效性检查

profile 在写入任何 shadow 寄存器前检查：

1. 中心频率量化值位于 4--250 kHz。
2. cutoff 单调且落入唯一频段。
3. CIC R/shift 符合当前 20-bit 数据通路约束。
4. 镜频 alias 距离不小于 `2.2 * acquire_cutoff`，输出率不小于
   `8 * acquire_cutoff`。
5. IIR cutoff 小于 `0.4 * Fs`，Q2.30 系数对称、单位直流增益且极点稳定。
6. cross-dot FLL 满足 `Fs >= 4 * L * acquire_cutoff`。
7. ±20% correction limit 符号正确、对称且未超过中心字的 25%。
8. Kf/Kp/Ki 可由 signed 24-bit 表示。
9. threshold、magnitude、dwell、warmup、timeout 和 IIR mode 位宽合法。

失败时 `dpll_profile_validation_t.errors` 返回字段化 bit mask，ARM 日志会打印
中心字和错误掩码。

## 5. 共用环路参数

当前 5.5 kHz、22 kHz 与 200 kHz 已验证 profile 使用同一组环路参数：

```text
Kp_track=6000000   Ki_track=180000
Kf_acquire=8000000 Kf_blend=1500000 Kf_track=250000
Kp_blend=6000000   Ki_blend=468800
phase_threshold=5825, phase_setpoint=-65536
freq_threshold=2147
magnitude enter/exit=16384/8192
dwell acquire/blend/loss=16/64/64
warmup=16, holdover_timeout=1250000
```

这组增益在其他频点属于生成默认值，不等于已经逐频点验证。

## 6. CRC 一致性

除 4--8 kHz 频段外，当 `measurement_timeout=0` 时，ARM 与 RTL 都使用：

```text
measurement_timeout = 2400*R + 512
```

4--8 kHz 的 0.8 kHz TRACK IIR 在状态 5 切换后需要更长的重建时间。该频段固定写入 `125000`（1 ms），避免自动值在 magnitude 和 FLL block 恢复前触发 `LOSS_TIMEOUT`。这项设置来自 5.5 kHz 中心、5 kHz 激励的 50 ms 行为级仿真验证。

profile staging 后仍必须执行 CONFIG_APPLY，并核对 apply sequence、active snapshot、
applied ABI 和 active config CRC，全部一致后才允许 enable。
