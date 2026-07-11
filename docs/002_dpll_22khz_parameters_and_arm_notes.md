# 002 22 kHz DPLL 参数与 ARM 开发注意事项

更新日期：2026-07-11

## 1. 参数适用范围

本文参数来自当前集成 TB 和 2026-07-10 的完整行为级仿真：

```text
DPLL center       = 22 kHz
ADC stimulus      = 21.5 kHz
initial offset    = -500 Hz
clk1              = 125 MHz
pre-CIC output    = 3.125 MSPS
post-CIC          = R=16, shift=8
```

这些是目前 22 kHz 附近的稳定调试基线，不应不经验证直接复制到 5--200 kHz 全频段。

当前 TB 保留的最佳单变量 Ki 候选为 `Ki_blend=468800`。30 ms probe 中相位已进入锁定窗口，但状态机尚未累计满 64 个 blend dwell，因此应描述为“22 kHz 可用候选/基本稳定”，不是已经完成所有硬件和长时间稳定性验收的最终量产参数。

## 2. 22 kHz 完整寄存器参数

### 2.1 中心频率和输出

| 地址 | 参数 | 值 | 说明 |
|---:|---|---:|---|
| `0x0010` | center word high | `0x000B88CA` | 约 21999.9929 Hz |
| `0x0011` | readback selector | `0` | 当前 core 中不参与算法 |
| `0x0030` | DAC0 offset | `0` | signed 14 bit |
| `0x0031` | DAC0 amplitude | `0x00007FFF` | signed 16 bit |
| `0x0032` | output MUL | `1` | unsigned 16 bit |
| `0x0033` | output DIV | `1` | unsigned 16 bit，不能为 0 |
| `0x002A` | manual frequency offset | `0` | signed 32 bit |
| `0x0028` | correction positive limit high | `0x00024E8F` | +4400.0044 Hz，中心频率的 +20% |
| `0x0029` | correction negative limit high | `0xFFFDB171` | -4400.0044 Hz，中心频率的 -20% |

中心频率换算：

```text
center_hz = center_word_hi * 125000000 / 2^32
```

修正限幅寄存器与中心频率高字使用相同单位，按 signed 32 bit 解释，
FPGA 内部补 16 个低位零：

```text
limit_hz = signed(limit_reg32) * 125000000 / 2^32
effective_limit56 = sign_extend(limit_reg32) << 16
```

200 kHz 中心频率的默认 `±20%` 限幅为：

```text
positive = 0x0014F8B6 = +40000.0135 Hz
negative = 0xFFEB074A = -40000.0135 Hz
```

该修改消除了旧 32-bit DDS 低字格式造成的 `±953.7 Hz` 意外硬限制。
它只扩大控制量允许范围，不自动扩大 FLL、ACQUIRE IIR 和信号检测器的
实际捕获带宽。

### 2.2 FLL 与 PI 参数

| 地址 | 参数 | 22 kHz TB 值 | 生效状态 |
|---:|---|---:|---|
| `0x0023` | `Kf_acquire` | `8000000` | state 4/8，仅 FLL |
| `0x0024` | `Kf_blend` | `1500000` | state 5 |
| `0x0025` | `Kf_track` | `250000` | state 6 |
| `0x0026` | `Kp_blend` | `6000000` | state 5 |
| `0x0027` | `Ki_blend` | `468800` | state 5，当前 Ki 搜索最佳候选 |
| `0x0021` | `Kp_track` | `6000000` | state 6 |
| `0x0022` | `Ki_track` | `180000` | state 6 |

系数是 signed 24 bit，写 32-bit 寄存器时 `[31:24]` 必须是 bit23 的符号扩展，否则 APPLY 会拒绝。

系数尺度：

```text
FLL term = freq_error  * Kf >>> 16
I term   = phase_error * Ki >>> 18
P term   = phase_error * Kp >>> 12
```

因此：

- 不能把 Kf/Ki/Kp 的十进制大小直接当成三条路径的相对强度。
- P 的 shift 比 I 少 6 bit；相同系数下，P 瞬时增益约是 I 单次增量的 64 倍。
- I 和 FLL 积分进 `freq_state`，P 只叠加到当前 `freq_correction`。

### 2.3 锁定阈值与状态计数

| 地址 | 参数 | 值 | 实际含义 |
|---:|---|---:|---|
| `0x0050` | phase threshold | `5825` | 约 8° |
| `0x0051` | phase setpoint | `0xFFFF0000` | 18-bit 下为 `-65536`，即 `-pi/2` |
| `0x0052` | frequency threshold | `2147` | 约 100 Hz |
| `0x0053` | magnitude enter | `16384` | raw 20-bit CORDIC magnitude |
| `0x0054` | magnitude exit | `8192` | 必须小于 enter |
| `0x0055` | acquire dwell | `16` | 16 个 cross-dot block-valid |
| `0x0056` | blend dwell | `64` | 64 个 cross-dot block-valid |
| `0x0057` | loss dwell | `64` | 64 个 bad block-valid |
| `0x0058` | holdover timeout | `1250000` | 125 MHz raw tick，10 ms |
| `0x0059` | measurement timeout | `0` | 请求 RTL 自动值，见后文严重注意项 |
| `0x0063` | warmup samples | `16` | 16 个 block-valid 测量 |

22 kHz profile 下：

```text
post-CIC rate             = 3.125 MHz / 16 = 195312.5 Hz
cross-dot block size      = 16 samples
state measurement rate    = 12207.03125 Hz
one measurement period    = 81.92 us
acquire/warmup dwell 16   = 1.31072 ms
blend/loss dwell 64       = 5.24288 ms
```

这是理解波形时最容易踩的坑之一：`blend_dwell=64` 不是 64 个 125 MHz 周期，也不是 64 个 post-CIC 样本，而是 64 个 cross-dot block 测量。

### 2.4 CIC、FLL delay 和 IIR

| 地址 | 参数 | 值 |
|---:|---|---:|
| `0x0060` | post-IQ CIC R | `16` |
| `0x0061` | post-IQ CIC shift | `8` |
| `0x0062` | FLL delay selector | `3`，即 L=8 |
| `0x0064` | post-IIR mode | `3`，AUTO |

`shift=8` 的含义：nominal R=16 shift 为 7，再增加 1 bit CORDIC headroom。正式架构中不得再在 CORDIC 前额外右移。

IIR 每个 I/Q 通道使用两个相同 biquad section 串联。

ACQUIRE bank，单节约 4 kHz：

| 地址 | 系数 | hex | signed decimal |
|---:|---|---:|---:|
| `0x0065` | b0 | `0x003E186B` | `4069483` |
| `0x0066` | b1 | `0x007C30D5` | `8138965` |
| `0x0067` | b2 | `0x003E186B` | `4069483` |
| `0x0068` | a1 | `0x8B9E5F9E` | `-1952555106` |
| `0x0069` | a2 | `0x355A020C` | `895091212` |

TRACK bank，单节约 2 kHz：

| 地址 | 系数 | hex | signed decimal |
|---:|---|---:|---:|
| `0x006A` | b0 | `0x00103681` | `1062529` |
| `0x006B` | b1 | `0x00206D02` | `2125058` |
| `0x006C` | b2 | `0x00103681` | `1062529` |
| `0x006D` | a1 | `0x85D1D2A9` | `-2049846615` |
| `0x006E` | a2 | `0x3A6F075A` | `980354906` |

AUTO 模式下：

- state 0--4、7--9 使用 ACQUIRE bank；
- state 5 和 6 使用 TRACK bank；
- bank 切换会清 detector 历史，因此状态边界附近出现短暂测量空窗是预期行为。

## 3. Ki 搜索实证

保持其他 HDL、FLL、Kp、滤波器、阈值不变，只调整 `Ki_blend`：

| Ki blend | state 5 后负峰值 | 首次进入 ±5825 | 30 ms phase | 30 ms state | good count |
|---:|---:|---:|---:|---:|---:|
| 117200 | -49534 | 未进入 | -35948 | 5 | 0 |
| 234400 | -46370 | 未进入 | -19166 | 5 | 0 |
| 351600 | -46370 | 未进入 | -11628 | 5 | 0 |
| 468800 | -46370 | 29 ms | +1468 | 5 | 20 |

结论：

- `468800` 显著优于旧 `117200`，解决了积分状态建立过慢的问题。
- 30 ms 时 phase/frequency threshold 均满足，但 `good_count=20/64`，所以尚未正式进入 state 6。
- 继续单纯增加 Ki 可能降低阻尼并加快穿过相位窗口，不应无上界地继续加倍。
- 如果后续要缩短正式 state 6 时间，应固定 Ki 后单独评估 Kp/阻尼；当前没有完成该项仿真，因此不能把更高 Kp 写成已验证参数。

结果目录：

```text
reports/xsim/ki_search/
```

## 4. ARM 推荐配置顺序

ARM 应按以下顺序配置：

1. 写 reset，保持 DPLL enable=0。
2. 检查 `ABI_VERSION`、`CONFIG_VERSION`、`FPGA_BUILD_ID`、`GIT_HASH`。
3. 调用 filter profile 生成器写中心频率、CIC、FLL delay、IIR banks。
4. 写完整 FLL/PI、阈值、dwell、limits、MUL/DIV。
5. 写 `CONFIG_APPLY`。
6. 轮询 busy/error/apply sequence。
7. 核对 active snapshot 和 active config CRC。
8. APPLY 成功后再 enable。

22 kHz 中心应使用：

```c
dpll_write_center_filter_profile(0x000B88CAU);
```

当前实现由 `dpll_profile.c` 生成完整 profile，并由
`dpll_driver_stage_profile()` 一次写入中心频率、CIC、FLL delay、IIR、
FLL/PI、阈值、dwell、warmup、timeout 和 ±20% correction limit。

## 5. ARM 同步状态

2026-07-11 的 ARM profile 驱动更新已完成以下同步。

### 5.1 默认启动 profile

`helloworld.c` 默认启动调用已改为：

```c
dpll_write_center_filter_profile(0x000B88CAU); // verified 22 kHz
```

默认上电配置会复现本文记录的 22 kHz profile。

### 5.2 环路参数

profile 模块的共用值为：

```text
Ki_track = 180000
Ki_blend = 468800
warmup   = 16
```

这些值不再分散硬编码在 `main()` 中。

### 5.3 measurement timeout 与 CRC

ARM expected CRC 与 RTL 已统一使用：

```text
measurement_timeout = 2400*R + 512
```

寄存器 `0x0059=0` 时，ARM 会按相同的自动值计算 active config CRC。

### 5.4 可配置频率范围

- `5--200 kHz`：标准生成区间。
- `4--5 kHz`、`200--250 kHz`：允许配置的扩展区间，但不承诺锁定。
- 22 kHz、200 kHz 精确中心字：标记为已验证基线。
- 所有区间都必须通过 CIC、镜频、IIR 稳定性、FLL delay、位宽、限幅和状态参数检查。

## 6. 参数设置坑点

### 6.1 APPLY 与 enable

- shadow 寄存器写入不会立即改变 active 算法。
- 必须 APPLY 成功后再 enable。
- APPLY 会让状态机重新进入 CONFIGURE/WARMUP/FLL_ACQUIRE。
- debug DAC 四个寄存器是 live 配置，不需要 APPLY，也不应触发重捕获。

### 6.2 signed 宽度

- Kf/Ki/Kp 是 signed 24 bit；高 8 bit 必须符号扩展。
- phase setpoint 是 signed 18 bit；高 14 bit 必须符号扩展。
- phase/frequency threshold 是无符号 18/22 bit，高位必须为 0。
- magnitude 是 raw unsigned 20 bit。
- DAC offset、amplitude、MUL/DIV 和 dwell 均有严格高位检查。

### 6.3 CORDIC 余量

- CORDIC 20-bit Signed Fraction 的合法建议范围是 ±2^18。
- R=16 时使用 shift=8，而不是 nominal shift=7。
- 不要同时使用 shift=8 和 CORDIC 前 `/2`，否则会重复缩放并损失 SNR。
- `input_out_of_range_seen` 是 sticky，当前 config apply 不会清除；判断新 profile 是否越界前，应先确认是否执行过真正的 core reset。

### 6.4 overflow 与启动毛刺

- post-CIC overflow 在 config apply/flush 时会清除。
- CORDIC overrun/range/format sticky 只在 `rst_125m` 清除。
- 因此状态 1 期间出现的 CORDIC sticky 可能一直保留到后续状态，不能仅凭一个 sticky 位断定 state 4/5 正在持续溢出。
- 有效诊断应同时观察当前 I/Q 峰值、CORDIC input range、sticky 首次置位时间和 config/reset 时序。

### 6.5 `phase_locked` 不等于 `locked`

- state 5 中 phase/frequency flag 可以均为 1。
- 只有完成 blend dwell 进入 state 6，且当前 loop_ok，`locked` 才为 1。
- ARM UI 不应只看 phase flag，也不应只看 frequency flag。

### 6.6 FLL 与 PI 的主导性

判断“互搏”不能只看 phase 波形，应同步记录：

```text
fll_term_r
i_term_r
p_term_r
freq_state
freq_correction
loop_state
phase_error
freq_error
```

22 kHz 调试中，进入 state 5 后累积 I/`freq_state` 是长期频率校正主体，FLL track/blend 通常为较小残余修正；P 负责即时相位阻尼。三项符号相反不自动等于互搏，必须比较它们对 `state_delta` 和最终 correction 的实际量级。

### 6.7 状态 4 到 5/6 的解释

- state 4：FLL only。
- state 5：FLL + PI 已经全部工作，是相位捕获状态。
- state 6：track 参数生效，FLL 并未完全关闭。
- state 4->5 的脉冲和 filter-bank reconfigure 可以单独研究，但本轮 Ki 搜索没有修改该逻辑。

## 7. 后续验证建议

在把 22 kHz 参数固化到 ARM 默认值前，至少补齐：

1. `Ki_blend=468800` 的更长时间仿真，确认最终进入 state 6 并保持。
2. 固定 Ki，仅扫描 `Kp_blend`，确认阻尼和相位窗口停留时间。
3. ARM 与 RTL 的 measurement timeout/CRC 公式统一。
4. ARM 启动中心、Ki、warmup 与目标 profile 同步。
5. 板上验证 CORDIC sticky 的首次置位时间，而不是只读最终 sticky。
6. 其他中心频率必须重新生成 CIC/IIR/FLL delay profile，不能只改 center word。
