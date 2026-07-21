# 001 当前 DPLL 完整构造

更新日期：2026-07-11

本文描述当前仓库中实际生效的 DPLL 架构。代码事实优先于旧设计计划、RFC 草案和历史调试记录。

## 1. 系统边界

当前工程只有一条 DPLL 主通道：

```text
ADC A / ADCraw0
  -> dpll_wrapper
  -> 单时钟 DPLL core
  -> 48-bit 跟踪频率字
  -> 输出 MUL/DIV
  -> 48-bit VCO/DDS
  -> DAC A / DACout0
```

其他边界：

- `ADCraw1` 只进入独立的 `Digital_Freq_Meter`，不是第二条 DPLL。
- `DACout1` 是 DPLL 调试 DAC，不参与闭环反馈。
- DPLL 算法只使用 `clk1=125 MHz`。低速处理通过 `valid` 脉冲完成，没有 `clk_dpll` 物理低速时钟。
- `sys_clk` 只用于寄存器总线；配置通过 toggle/ack CDC 原子提交到 `clk1` 域。

主要入口：

- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/dpll_wrapper.v`
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/dpll_single_clock_core_stage_a.v`
- `DPLL_Rewrite.srcs/sources_1/ReadPitaya/red_pitaya_top.v`

## 2. 当前信号链

```text
ADCraw0, 125 MSPS, signed 16 bit
  -> 固定前级 CIC IP，R=40
  -> 3.125 MSPS, signed 16 bit
  -> valid 门控 DC blocker
  -> 48-bit tracking NCO / LO_DDS_H
  -> I/Q 乘法混频
  -> 截取并正饱和到 signed 18 bit
  -> 可配置 post-IQ CIC，N=3，R=8..312
  -> signed 20-bit I/Q
  -> 两节相同 biquad 串联的 post-IIR
  -> signed 20-bit I/Q
  -> Word-Serial CORDIC Translate
  -> 18-bit 环形相位 + 20-bit magnitude
  -> phase error、cross-dot FLL、状态机
  -> FLL + PI 混合环路滤波器
  -> 56-bit frequency state/correction
  -> 48-bit tracking word
  -> manual offset
  -> unsigned 48-bit MUL/DIV
  -> 48-bit VCO/DDS
  -> DACout0
```

### 2.1 前级 CIC

`pre_iq_cic_40_125m_v1` 固定将 125 MSPS ADC 流抽取为 3.125 MSPS。该 IP 有 AXI ready；如果出现反压，`PRE_CIC_BACKPRESSURE_SEEN` 会置位。

### 2.2 DC blocker

`dc_blocker_valid_stage_a` 只在输入 valid 时推进状态，参数为：

```text
DATA_WIDTH = 16
ACC_WIDTH  = 48
LEAK_SHIFT = 10
```

其高频通带输出约为输入的一半，这是当前固定点尺度的一部分，不应被误认为额外故障衰减。

### 2.3 跟踪 NCO 与 I/Q 混频

- 跟踪字宽为 48 bit，参考时钟为 125 MHz。
- `LO_DDS_H` 输出 16-bit cos/sin；IP 已配置 Negative Sine，Q 路直接使用 IP 输出。
- 乘法结果保存 32 bit，当前实现取 `[30:13]` 形成 18-bit mixer 数据，并对正向特殊溢出做饱和。

频率字换算：

```text
word48 = round(f_hz / 125000000 * 2^48)
```

ARM/寄存器只写中心频率字的高 32 bit，FPGA 形成：

```text
center_word48 = {CENTER_FREQUENCY_WORD[31:0], 16'h0000}
```

频率修正正负限幅寄存器 `0x0028/0x0029` 采用相同的高 32-bit
DDS 字格式，但按 signed 解释：

```text
correction_limit56 = sign_extend(limit_reg32) <<< 16
limit_hz = signed(limit_reg32) * 125000000 / 2^32
```

因此限幅寄存器分辨率约为 `0.0291 Hz/LSB`，不再使用 48-bit DDS
字的亚微赫兹低位精度。内部 `freq_state/freq_correction` 仍保持
signed 56 bit。ARM profile 默认把正负限幅设置为中心频率的 `±20%`，
用户可以通过屏幕或PC API覆盖该ARM候选配置；校验通过后直接更新活动寄存器。

### 2.4 post-IQ CIC

`post_iq_cic_stage_a` 参数：

```text
input width   = 18
internal width= 44
output width  = 20
stages N      = 3
R legal       = 8..312
```

行为：

- 积分器和 comb 内部使用二补码自然回绕。
- 输出执行可配置右移、对称取整和 20-bit 饱和。
- `overflow_seen` 表示输出饱和，不表示内部自然回绕。
- CIC R/shift更新、检测链重配置命令或flush会清空CIC历史、抽取相位、输出流水线和CIC overflow sticky。

shift合法性完全由ARM profile校验，当前推荐窗口为：

```text
expected_shift - 1 <= programmed_shift <= expected_shift + 4
```

期望表：

| R 上限 | expected shift |
|---:|---:|
| 8 | 4 |
| 16 | 7 |
| 31 | 10 |
| 78 | 13 |
| 156 | 16 |
| 312 | 19 |

ARM 自适应 profile 在 nominal shift 上再加 1 bit CORDIC headroom。

### 2.5 post-IIR

`post_iir_stage_a` 在 post-CIC 和 CORDIC/FLL 之间。I、Q 各使用两节相同二阶节串联，系数为 signed Q2.30：

```text
y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2]
       - a1*y[n-1] - a2*y[n-2]
```

模式：

| `POST_IIR_CONFIG[1:0]` | 行为 |
|---:|---|
| 0 | bypass |
| 1 | 强制 ACQUIRE 系数 |
| 2 | 强制 TRACK 系数 |
| 3 | AUTO：state 4/8 后期先预热 TRACK，state 5/6 继续使用 TRACK，其余使用 ACQUIRE |

IIR 系数选择发生变化时，当前实现会清 IIR、CORDIC 和 FLL detector 历史。状态机不会在同一边沿立即接入 PI：频率满足 acquire dwell 后，state 4/8 内部先置位 `track_iir_preheat`，保持 FLL-only，并等待 4 个恢复后的 block-valid 测量，再进入 state 5。

### 2.6 CORDIC

当前 `dpll_angle_CORDIC` 为：

```text
Translate
Word Serial
Signed Fraction
20-bit input/output
Scaled Radians
Coarse Rotation enabled
No Scale Compensation
Blocking AXI flow control
```

`cordic_word_serial_adapter` 提供：

- 2-entry 输入 FIFO；
- 完整 `tvalid/tready` 握手；
- 20-bit I/Q 装入两个 24-bit AXI lane；
- 20-bit raw magnitude；
- raw phase 的 18-bit modulo 字段；
- overrun、输入越界、输出格式 sticky 状态；
- reset/clear 后 3 cycle reset 加 1 cycle guard。

正式修复后，post-IIR 的 `i_baseband/q_baseband` 直接进入 CORDIC，不存在 CORDIC 前隐藏右移。输入余量由 post-CIC shift 管理。

CORDIC 输入合法检查范围：

```text
-262144 <= I,Q <= +262144
```

CORDIC 三个 sticky 错误和 CIC 的 sticky 状态由独立 `status_clear` 清零；该清零
不复位 FIFO、CORDIC IP、CIC 积分器或 active 配置。wrapper 捕获故障后立即清除
源锁存，并把 LED5/锁定资格中的数据通路故障保持 `2^25 / 125 MHz = 0.268 s`。
重复故障重新开始该窗口。DPLL 关闭期间持续清空相位、频率和数据通路故障历史，
重新开启后从干净窗口重新判定；LED4把最近一次输出饱和保持同样的约0.268秒。

### 2.7 phase detector

相位物理量：

```text
PHASE_WIDTH = 18
一周         = 2^18
范围         = [-0.5 turn, +0.5 turn)
```

相位误差：

```text
phase_error = cordic_phase - phase_setpoint
```

减法按 18-bit 二补码自然回绕。

### 2.8 cross-dot FLL

当前 FLL 不是旧文档中的 phase unwrap/difference 路径，而是 `fll_cross_dot_stage_a`：

```text
dot   = I[k]*I[k-L] + Q[k]*Q[k-L]
cross = Q[k]*I[k-L] - I[k]*Q[k-L]
```

特性：

- delay selector 0/1/2/3 对应 L=1/2/4/8。
- 每 16 个 post-IIR I/Q 样本形成一个 cross/dot block。
- block 结果经除法归一化为 22-bit `freq_error`。
- 归一化包含 post-CIC `R` 和 delay `L`，使系数尺度跨 profile 保持一致。
- dot 非正、能量/历史不足或除数无效时标记 ambiguous，不向状态机提供有效测量。

当前约定约为：

```text
freq_error scale ~= 21.4748 LSB/Hz
```

## 3. 混合 FLL + PI 环路

环路模块为 `hybrid_fll_pll_filter_stage_a`，不是传统 PID，也没有 I2 或 D 项。

离散关系：

```text
fll_term = (freq_error  * Kf) >>> 16
i_term   = (phase_error * Ki) >>> 18
p_term   = (phase_error * Kp) >>> 12

freq_state[k+1] = sat(freq_state[k] + fll_term + i_term)
freq_correction = sat(freq_state[k+1] + p_term)
tracking_word   = clamp(center_word + freq_correction,
                        0, 0x7fff_ffff_ffff)
```

关键理解：

- FLL 和 I 项都进入累积的 `freq_state`。
- P 项不进入积分状态，只形成即时频率修正。
- P 使用 shift 12，增益远强于使用 shift 18 的 I 路，三种系数不能仅比较十进制数值大小。
- anti-windup 在 state 已顶到限制且增量继续推向饱和时冻结积分；反向离开饱和仍允许更新。
- `freq_state` 与 `freq_correction` 均为 signed 56 bit。
- `tracking_word` 虽然使用 48-bit 容器，但当前 core 上限是正 signed-48 最大值 `0x7fff_ffff_ffff`，不是完整 `0xffff_ffff_ffff`。

## 4. 状态机

| 数值 | 状态 | 控制作用 |
|---:|---|---|
| 0 | RESET | 全部关闭 |
| 1 | DISABLED | 全部关闭 |
| 2 | CONFIGURE | 配置提交后的过渡 |
| 3 | WARMUP | 等待 detector/IIR/CORDIC/FLL 历史稳定，全部控制关闭 |
| 4 | FLL_ACQUIRE | 仅 FLL；满足 acquire dwell 后在本状态内预热 TRACK IIR |
| 5 | FLL_PLL_BLEND | FLL + PI，使用 blend 参数 |
| 6 | PLL_TRACK | FLL + PI，使用 track 参数 |
| 7 | HOLDOVER | 冻结控制，等待测量恢复 |
| 8 | REACQUIRE | 仅 FLL，重新捕获 |
| 9 | FAULT | 故障等待重新 apply |

状态切换依据的是每个 cross-dot block 产生的 `measurement_valid`，不是 125 MHz 时钟周期，也不是每个 post-CIC 样本。

重要语义：

- state 3 不做 FLL/P/I 控制，只完成 warmup。
- state 4 只有 FLL；TRACK IIR 预热期间仍不启用 P/I。
- state 5 已经启用 FLL、P、I。
- state 6 仍启用 FLL，只是使用较小的 `Kf_track`。
- `phase_locked` 和 `frequency_locked` 是当前阈值判断，可在 state 5 为 1。
- 总 `locked` 只有在 `state==6` 且 signal、phase、frequency、saturation 全部正常时才为 1。

从 state 4/8 进入 state 5：先完成原 acquire dwell，再切 TRACK IIR，并取得 4 个新的 signal/frequency 有效 block。这样 IIR/CORDIC/FLL 重建发生在纯 FLL 阶段。

从 state 5 进入 state 6：频率、信号、饱和条件必须正常，并且 phase 连续满足阈值 `blend_dwell` 个 block-valid 测量。

## 5. 配置与 CDC

参数按更新影响分为三类：

1. 即时控制：reset、enable。
2. 直接生效：中心字、阈值、dwell/timeout、limits、DAC、MUL/DIV和DAC1调试配置。
3. 局部重配置：FLL/PI增益只重捕获控制器；CIC/IIR/FLL delay清检测链并重捕获。

跨时钟写流程：

```text
ARM校验完整candidate并只写变化字段
  -> sys_clk域锁存地址/数据并发出request toggle
  -> clk1域更新唯一活动寄存器
  -> 按地址产生直接更新、控制器重捕获或检测链重配置
  -> ack返回sys_clk并结束该次总线事务
```

所有配置范围、定点位宽、CIC/IIR、MUL/DIV和状态参数校验均由ARM在写活动寄存器
前完成。HDL不拒绝、不修正、不代入默认值。ARM启动时先核对ABI/config/build/git
identity，并在DPLL关闭状态下写入完整初始配置。`0x006F`改为无状态局部重配置命令，
`0x0070`和`0x011E`保留并固定读零。

## 6. 输出链与调试 DAC

主输出：

```text
tracking_word
  + signed manual offset
  -> clamp u48
  -> PLL_VCO_MUL_DIV
  -> VCO_48bits
  -> DACout0
```

ARM 在提交前只保证 `OUTPUT_MUL/DIV` 非零并符合寄存器位宽，不根据
`center * MUL / DIV` 代替使用者限制输出频率。HDL 乘除器直接使用 active 值；
乘法/除法后的 48 bit 输出饱和仍是实时信号链保护，不属于配置校验。

DACout1 调试源：

| source | 内容 |
|---:|---|
| 0 | `freq_correction[55:24]` |
| 1 | tracking-center `[47:16]` |
| 2 | `freq_state[55:24]` |
| 3 | phase error |
| 4 | FLL error |
| 5 | post-IIR I |
| 6 | post-IIR Q |
| 7 | CORDIC phase |
| 8 | raw magnitude |
| 9 | output-tracking delta `[47:16]` |
| 10 | loop state |

## 7. 当前明确没有实现的旧计划

以下内容曾出现在旧文档，但当前主链中不存在：

- `clk_dpll` 生成时钟驱动的 DPLL core；
- 第二条 DPLL；
- PII2、PID D 项；
- CORDIC 前 20->16 bit 舍入路径；
- CORDIC 前额外右移；
- phase unwrap 型 FLL 主路径；
- pre-IIR；
- complex notch；
- 运行中按状态切换 post-CIC R；
- Kalman、DMTD、TDC 或连续相位回归估计器。

这些只能作为未来研究方向，不能写成当前实现。
