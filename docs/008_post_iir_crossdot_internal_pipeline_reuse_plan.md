# 008 post-IIR 与 cross-dot 内部流水线复用施工及验收规范

状态：施工方案，尚未修改功能 RTL。

适用器件与工具：`xc7z010clg400-1`，Vivado 2018.3，`clk_125m = 125 MHz`。

## 1. 目标

本次改造只处理以下两个模块的内部乘法器流水线复用：

- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/post_iir_stage_a.v`
- `DPLL_Rewrite.srcs/sources_1/DigitalPLL/hybrid_loop/fll_phase_difference_stage_a.v`
  中的 `fll_cross_dot_stage_a`

本次明确保持 I/Q 两路独立：

- post-IIR 保留 I 路、Q 路两套独立乘法流水线和独立状态。
- 不允许让 I 路和 Q 路在同一个乘法器上交替执行。
- cross-dot 保留 dot、cross 两套独立乘法流水线，不压缩为单乘法器。
- 不进行操作数半字拆分后复用单个原生 DSP48E1 的激进优化。

资源目标如下：

| 模块 | 当前 DSP48E1 | 本阶段目标 | 节省 |
|---|---:|---:|---:|
| post-IIR | 40 | 4 | 36 |
| cross-dot | 10 | 4 | 6 |
| 合计 | 50 | 8 | 42 |

以当前完整实现需要 98 个 DSP 为基线，改造后整机目标约为：

```text
98 - 42 = 56 DSP48E1
```

器件共有 80 个 DSP，预计保留 24 个余量。

## 2. 不在本次范围内

以下改动全部禁止混入本次施工：

- I/Q 共用同一个乘法器。
- 修改 post-IIR 系数位宽、Q 格式、系数值或滤波器阶数。
- 利用当前低通系数的 `b0=b2`、`b1=2*b0` 特性减少乘法；系数接口仍需支持任意合法 Q2.30 biquad。
- 将 32 bit 系数降为 18 bit 或进行其他系数量化。
- 修改 CIC 抽取率选择、FLL delay、block size、FLL 标度或环路增益。
- 修改寄存器地址、ARM 接口、状态机阈值、CORDIC、DDS 或 hybrid loop。
- 以 LUT 乘法替代 DSP 乘法来伪造 DSP 数下降。
- 为追求更低 DSP 数改变 fixed-point 舍入、饱和或除法结果。

## 3. 基线事实

### 3.1 当前失败性质

当前实现不是普通的布线拥塞或时序收敛失败。实现日志在 placement feasibility
阶段直接失败：

```text
This design requires 98 DSP48E1 cells but only 80 compatible sites are available.
```

最新综合 checkpoint 的层次资源报告为：

| 层次 | DSP48E1 |
|---|---:|
| `dpll_single_clock_core_stage_a_inst` | 55 |
| `post_iir_inst` | 40 |
| `fll_cross_dot_inst` | 10 |

报告位置：

```text
reports/vivado_dsp/current_synth_utilization_hier.rpt
```

### 3.2 数据到达率

前级 CIC 固定将 125 MSPS 抽取为 3.125 MSPS，post-IQ CIC 再按 `R` 抽取：

```text
f_iq = 3.125 MHz / R
IQ 输入间隔 = 125 MHz / f_iq = 40R clocks
```

| 场景 | R | IQ 对速率 | 相邻 IQ 对间隔 |
|---|---:|---:|---:|
| 最坏合法配置 | 8 | 390.625 kpair/s | 320 clocks |
| 已验证 200 kHz profile | 12 | 260.416667 kpair/s | 480 clocks |
| 22 kHz profile | 16 | 195.3125 kpair/s | 640 clocks |

所有吞吐验收必须以 `R=8` 的 320 clocks 为硬下界，不能只用常用的
`R=12` 或 `R=16` 证明。

## 4. 总体设计约束

### 4.1 接口保持不变

两个模块的端口列表保持不变。本阶段不增加系统级 `ready`，也不修改
`dpll_single_clock_core_stage_a` 的连接关系。

允许增加以下模块内部信号：

- `busy`
- issue/retire valid pipeline
- operation tag
- section/term counter
- sample、coefficient 和历史状态快照
- 串行缩放状态和计数器
- 仿真专用 overrun assertion

新增内部状态不得进入寄存器映射，不得改变现有 ABI/build identity 的语义。

### 4.2 有效数据契约

- 只在 `in_valid`/`sample_valid` 为 1 时接收新 IQ 对。
- filtered post-IIR 可以延迟输出，但每个被接受的输入必须且只能产生一个
  `out_valid`。
- bypass 模式保持当前一拍寄存输出行为。
- cross-dot 的 `freq_error_valid` 和 `freq_error_block_valid` 以“第几个有效 IQ
  样本”为基准保持不变；允许相对 125 MHz 时钟增加内部计算延迟。
- RTL 不得依赖输入数据在 valid 低时保持稳定。

### 4.3 配置和清零优先级

优先级必须保持为：

```text
reset > clear/selection_changed > 正常计算 > 接收新输入
```

`clear`、复位或系数 bank 选择变化发生时：

- 立即取消所有在途乘法、缩放和除法操作。
- 清空 issue/retire valid、部分累加和 replay 状态。
- 不允许旧操作在清零后产生 `out_valid`、`freq_error_valid` 或 block valid。
- IIR 历史、FLL history、block count 和 accumulator 按原 RTL 语义清零。

### 4.4 配置快照

post-IIR 接受 filtered 输入时必须锁存本次计算使用的：

- `i_in`、`q_in`
- `b0`、`b1`、`b2`、`a1`、`a2`
- 两路两个 section 的历史值

一次样本计算过程中不得重新读取可能变化的系数端口作为乘法操作数。

cross-dot 接受样本时必须锁存：

- 当前 `i_in`、`q_in`
- 本次使用的 `delayed_i`、`delayed_q`
- `selected_delay`
- block 结束时使用的 `rate_r` 和 normalization denominator

## 5. post-IIR 施工设计

### 5.1 保留的数学表达式

I、Q 每一路仍分别执行两个串联 biquad：

```text
y1 = round_sat(
       x0*b0 + x1*b1 + x2*b2
       - y1_hist*a1 - y2_hist*a2)

y2 = round_sat(
       y1*b0 + s2_x1*b1 + s2_x2*b2
       - s2_y1*a1 - s2_y2*a2)
```

运算顺序变化不得改变最终的数学整数和。五个乘积必须先符号扩展到
`ACC_WIDTH=64` 后累加，最后只调用一次现有 `round_sat`。

禁止逐项截断、逐项舍入或在两个 section 之间省略现有的 20 bit
`round_sat`，否则不再位精确等价。

### 5.2 乘法器结构

建立两套独立的有符号宽乘法流水线：

```text
I multiplier: signed 20 x signed 32 -> signed 52
Q multiplier: signed 20 x signed 32 -> signed 52
```

要求：

- I 和 Q 在同一拍发出相同 section/term 的操作，但样本操作数相互独立。
- 每套 `20x32` 乘法器预期映射 2 个 DSP48E1。
- 乘法器必须有输入寄存、乘积寄存和明确的 valid/tag pipeline。
- 推荐把 RTL 可见乘法延迟定义为固定 localparam，例如
  `MUL_LATENCY=2` 或 `3`，所有控制依赖 valid/tag，不依赖手写的模糊拍数。
- 可使用 Vivado 2018.3 支持的 `(* use_dsp = "yes" *)`，但最终以综合报告
  为准，attribute 本身不是验收证据。

不得为每个 term 写一个常驻 `sample * coeff` wire。源码中只应存在 I、Q
各一个会推断宽乘法器的乘法表达式。

### 5.3 issue 顺序

每个 section 的五个操作按以下顺序发出：

| term | sample operand | coefficient | accumulate |
|---:|---|---|---|
| 0 | `x0` | `b0` | add |
| 1 | `x1` | `b1` | add |
| 2 | `x2` | `b2` | add |
| 3 | `y1_hist` | `a1` | subtract |
| 4 | `y2_hist` | `a2` | subtract |

operation tag 至少包含：

```text
valid, section, term, subtract, last_term
```

乘积返回时根据对应 tag 加入 I/Q 各自的 64 bit accumulator。

### 5.4 section 边界

section 1 最后一个乘积返回后：

1. 使用 `accumulator + final_signed_product` 构造完整 section sum。
2. 对完整 sum 执行原 `round_sat`。
3. 锁存 `i_s1_next` 和 `q_s1_next`。
4. 下一拍开始发出 section 2 的五个 term。

不能在最后一个乘积返回的同一个时序块中对旧 accumulator 直接舍入。
必须显式包含最后一个乘积，防止 nonblocking assignment 造成少加一项。

section 2 最后一个乘积返回后：

1. 形成完整 sum。
2. 执行原 `round_sat`。
3. 同一事务提交 I/Q 输出和全部 section 历史。
4. `out_valid` 拉高一拍。
5. 返回 idle，等待下一个 IQ 对。

### 5.5 历史状态提交

所有历史只在整个 IQ 对计算成功完成时提交，推荐使用事务式更新：

```text
s1_x2 <= old_s1_x1
s1_x1 <= captured_input
s1_y2 <= old_s1_y1
s1_y1 <= s1_next

s2_x2 <= old_s2_x1
s2_x1 <= s1_next
s2_y2 <= old_s2_y1
s2_y1 <= s2_next
```

I、Q 分别维护各自寄存器，不允许共享 accumulator、history 或临时结果。

### 5.6 bypass 和模式切换

- `MODE_BYPASS` 不进入复用 FSM，保持当前寄存输出行为。
- 从 bypass 切入 filtered、ACQUIRE/TRACK/AUTO bank 变化时，保持当前
  `selection_changed` 清空一拍语义。
- filtered 计算正在进行时如果 bank 选择变化，必须取消该样本，不输出旧 bank
  与新 bank 混合计算的结果。
- `active_bypass`、`active_use_track` 的外部可见语义保持不变。

### 5.7 post-IIR 拍数预算

以乘法 pipeline latency 不超过 3 拍计：

| 阶段 | 预算 |
|---|---:|
| 接受并锁存输入 | 1 clock |
| section 1 发出五项 | 5 clocks |
| section 1 pipeline drain/舍入 | 不超过 3 clocks |
| section 2 发出五项 | 5 clocks |
| section 2 pipeline drain/提交 | 不超过 4 clocks |
| 合计 | 不超过 18 clocks，硬上限 20 clocks |

吞吐硬指标：

```text
最大 filtered initiation interval <= 20 clocks
等效吞吐 >= 125 MHz / 20 = 6.25 M IQ pairs/s
R=8 利用率 <= 20 / 320 = 6.25%
R=12 利用率 <= 20 / 480 = 4.17%
```

## 6. cross-dot 施工设计

### 6.1 保留的数学表达式

每个有效样本仍计算：

```text
dot_sample   = I*I_delay + Q*Q_delay
cross_sample = Q*I_delay - I*Q_delay
```

每 16 个具备历史的样本形成：

```text
dot_sum   = sum(dot_sample)
cross_sum = sum(cross_sample)
```

频率误差仍为当前整数运算：

```text
abs(cross_sum) * ANGLE_FREQ_SCALE
---------------------------------
abs(dot_sum) * rate_r * delay
```

其中 `ANGLE_FREQ_SCALE=10680836`、输出饱和、符号、ambiguous 和 replay
语义全部保持不变。

### 6.2 两套独立乘法流水线

建立两套独立 `signed 20 x signed 20 -> signed 40` 宽乘法流水线：

- dot multiplier：只服务 dot 路径。
- cross multiplier：只服务 cross 路径。

每套宽乘法器预计映射 2 个 DSP48E1，共4个 DSP。

两拍 issue 调度：

| issue | dot multiplier | cross multiplier | cross sign |
|---:|---|---|---|
| 0 | `I * I_delay` | `Q * I_delay` | add |
| 1 | `Q * Q_delay` | `I * Q_delay` | subtract |

每条 pipeline 使用独立 valid/tag。两个 term 均返回后才允许：

- 更新 dot/cross block accumulator。
- 增加 block count。
- 判断 block complete。

不得将四个乘法压缩到同一个乘法器；该优化属于后续 I/Q/路径合并阶段。

### 6.3 history 更新

接收 `sample_valid` 时先锁存当前和 delayed 样本，再推进 delay history。

乘法操作只能读取锁存快照，不能在后续拍读取已经移位后的 history。对
`L=1/2/4/8` 必须逐一验证无 off-by-one。

history 未达到 selected delay 时：

- 只推进 history 和 valid count。
- 不发出乘法。
- 不增加 block count。

### 6.4 块末无 DSP 缩放

当前块末宽乘法不得继续保留为并行 `*`。改为显式串行 shift-add：

```text
numerator   = cross_abs * 24'd10680836
denominator = dot_abs * normalization_denominator
```

推荐在同一个 24 拍计数器中并行维护两个 accumulator：

```text
for bit = 0..23:
    if ANGLE_FREQ_SCALE[bit]:
        numerator += cross_abs << bit

    if bit < DEN_WIDTH and normalization_denominator[bit]:
        denominator += dot_abs << bit
```

要求：

- 所有 shift 和 accumulator 位宽与当前组合乘法结果一致。
- 不允许先截断再进入除法。
- numerator、denominator 的最终值必须逐 bit 等于原 Verilog 无符号乘法。
- 综合后这两项不得占用 DSP。
- shift-add 完成后再启动现有 71 拍串行除法。

### 6.5 replay 时序

当前设计在 block 结果计算完成后设置 `replay_count=16`，随后在每次
`sample_valid` 上回放同一个 `freq_error`。

改造后必须保持：

- 第一个后续有效样本输出第一次 replay。
- 第一次 replay 同时产生一拍 `freq_error_block_valid`。
- 总计产生16次 `freq_error_valid`。
- 不得按 125 MHz 连续回放。
- ambiguous block 同样按原语义回放16次零值和 ambiguous。

### 6.6 cross-dot 拍数预算

| 操作 | 预算 |
|---|---:|
| 两拍发出四个 sample products | 2 clocks |
| product drain 和 block accumulate | 不超过 4 clocks |
| 单样本 arithmetic busy | 硬上限 6 clocks |
| block 末 numerator/denominator shift-add | 24 clocks |
| 串行除法 | 71 clocks |
| 状态切换和结果提交 | 不超过 5 clocks |
| block 末后台计算合计 | 硬上限 100 clocks |

最坏 `R=8` 时：

```text
sample arithmetic load <= 6 / 320 = 1.875%
block-result deadline load <= 100 / 320 = 31.25%
```

block 末结果必须在下一个 IQ 样本到达前完成，确保 replay 的有效样本序号
与原实现一致。

## 7. 仿真保护和可观测性

### 7.1 busy

两个模块内部必须有命名稳定的 busy 信号，供 testbench 层次访问：

```text
post_iir_inst.filter_busy
fll_cross_dot_inst.sample_math_busy
fll_cross_dot_inst.result_busy
```

名称允许在实现时微调，但测试必须能够观察对应三种状态。

### 7.2 overrun assertion

在 `ifndef SYNTHESIS` 下加入 assertion 或等效 `$display/$fatal` 检查：

- filtered post-IIR busy 时不得再次收到 `in_valid`。
- cross-dot sample arithmetic busy 时不得再次收到 `sample_valid`。
- 新 block 完成时上一 block 的 result calculation 必须已经结束。

系统合法配置不应触发任何 assertion。非法背靠背激励必须被测试明确识别，
不能静默覆盖在途状态。

## 8. 测试施工要求

### 8.1 建立冻结参考

修改 RTL 前保存当前并行实现作为仅仿真 reference，或建立完全等价的 Python
大整数模型。reference 文件不得加入 synthesis source set。

比较规则：

- 按“有效样本序号”比较，不按绝对 125 MHz 周期比较。
- post-IIR 比较每个输出的 I、Q、mode/bank 和输出序号。
- cross-dot 比较每个 `freq_error_valid`、`freq_error_block_valid`、
  `freq_error`、`ambiguous` 及其有效样本序号。
- 除允许的固定流水延迟外，必须 bit-exact。

### 8.2 post-IIR 单元测试改造

更新：

```text
verification/rtl/post_iir_stage_a_tb.v
scripts/run_post_iir_stage_a_xsim.ps1
```

现有 testbench 每拍调用一次 `push_sample`，不符合改造后 filtered 计算契约。
`push_sample` 必须等待 DUT 返回 idle，或按不少于320拍的系统 cadence 驱动。

必测用例：

1. bypass 正数、负数、零和边界值。
2. ACQUIRE、TRACK、AUTO 两个 bank。
3. impulse、step、交替正负高频输入。
4. `0x7ffff`、`0x80000` 附近输入和输出饱和边界。
5. 正负数恰好位于 round half-LSB 两侧的舍入用例。
6. I 非零/Q 为零，确认 Q 历史和输出始终为零。
7. Q 非零/I 为零，确认 I 历史和输出始终为零。
8. I/Q 使用互不相关随机序列，分别与两个 scalar reference 比较。
9. 至少10000个随机 IQ 对，覆盖正负系数、饱和和非饱和结果。
10. 在每个 FSM phase 注入 `clear`，确认没有 stale output。
11. filtered 运算中切换 mode/bank，确认在途事务被取消。
12. `R=8` cadence 连续运行至少100000个 IQ 对，无 overrun、漏样或重样。

单元测试必须记录：

- accepted input count
- produced output count
- 最大 filtered latency
- 最小 observed initiation interval
- I/Q mismatch count
- reference mismatch count

### 8.3 cross-dot 专用单元测试

当前仓库没有独立的 cross-dot testbench，本次必须新增：

```text
verification/rtl/fll_cross_dot_stage_a_tb.v
scripts/run_fll_cross_dot_stage_a_xsim.ps1
```

必测用例：

1. `delay_sel=0/1/2/3`，即 `L=1/2/4/8`。
2. `rate_r=8/12/16/312`。
3. 正向旋转复向量，频差符号为正。
4. 反向旋转复向量，频差符号为负。
5. 静止复向量，输出频差为零。
6. 全零输入，`ambiguous=1`。
7. dot sum 为零、负数和接近零的边界。
8. cross sum 正负极值及 `freq_error` 正负饱和。
9. history 尚未填满时不得增加 block count。
10. 每16个有效 block sample 恰好启动一次结果计算。
11. 每个结果恰好 replay 16 个有效样本。
12. `freq_error_block_valid` 只在第一次 replay 拉高一拍。
13. sample multiply、shift-add、divider 每个 phase 注入 `clear`。
14. `R=8` cadence 连续至少100000个 IQ 对，无 sample/block overrun。
15. 至少10000个随机复样本，与冻结 RTL 或 Python 大整数模型逐事件比较。

testbench 必须直接检查内部串行缩放结果：

```text
serial_numerator   == cross_abs * 10680836
serial_denominator == dot_abs * normalization_denominator
```

### 8.4 延迟与吞吐专项测试

新增或扩展测试，自动统计以下硬指标：

| 指标 | 验收值 |
|---|---:|
| post-IIR filtered 最大 latency | <=20 clocks |
| post-IIR filtered initiation interval | <=20 clocks |
| cross-dot 单样本 arithmetic busy | <=6 clocks |
| cross-dot block result busy | <=100 clocks |
| `R=8` post-IIR overrun | 0 |
| `R=8` cross-dot sample overrun | 0 |
| `R=8` cross-dot block overrun | 0 |

必须同时跑 `R=12` 的 200 kHz profile cadence，但不能用它替代 `R=8`
最坏条件。

## 9. 回归测试要求

### 9.1 必跑命令

完成 RTL 和单元测试后，至少运行：

```powershell
.\scripts\run_post_iir_stage_a_xsim.ps1
.\scripts\run_fll_cross_dot_stage_a_xsim.ps1
.\scripts\run_single_clock_core_stage_a_xsim.ps1
.\scripts\run_dpll_multifrequency_path_xsim.ps1
.\scripts\run_dpll_core_nonzero_tracking_trace.ps1
.\scripts\run_dpll_core_sine_lock_trace.ps1
.\scripts\run_dpll_core_sine_sweep_trace.ps1
.\scripts\run_dpll_wrapper_cdc_xsim.ps1
python -m unittest discover -s verification/fixed_point -p "test_*.py"
```

所有命令必须退出码为0，日志中不得包含 `FAIL:`，并必须出现对应 PASS marker。

### 9.2 profile 行为回归

至少覆盖：

- 5.5 kHz 已验证低频 profile。
- 22 kHz 已验证 profile。
- 200 kHz/220 kHz 激励已验证高频 profile。
- 5/10/20/50/100/150/200 kHz multifrequency sweep。

验收要求：

- 最终 loop state、loss reason、locked 标志不劣化。
- `freq_error` 方向不反转。
- tracking word 和 fixed-point checker bit-exact 通过。
- 不新增 CIC、CORDIC 或 detector overrun 标志。
- 允许由固定流水延迟造成不超过20个 125 MHz clocks 的绝对时间平移。
- 以 block/sample 计数的 dwell、replay 和 lock 判定次数不得变化。

## 10. 综合与实现测试

### 10.1 模块 OOC 综合

新增两个独立 OOC 综合脚本：

```text
scripts/vivado_post_iir_pipeline_synth_check.tcl
scripts/vivado_cross_dot_pipeline_synth_check.tcl
```

每个脚本必须：

- 目标器件为 `xc7z010clg400-1`。
- 创建 8.000 ns 的 `clk_125m` 时钟。
- 输出 hierarchical utilization 和 timing summary。
- 在批处理模式下返回明确退出状态。

模块级硬验收：

| 模块 | DSP48E1 | 125 MHz WNS | 修改行相关 pipeline warning |
|---|---:|---:|---:|
| post-IIR | <=4 | >=0 ns | 0 |
| cross-dot | <=4 | >=0 ns | 0 |

以下情况直接判定失败：

- post-IIR 超过4个 DSP。
- cross-dot 超过4个 DSP。
- 修改后的乘法器落入 LUT 而 DSP 数看似下降。
- 出现指向修改乘法表达式的 `[Synth 8-5845] Not enough pipeline registers`。
- 出现 post-IIR 大量驱动 DSP pin 而产生的 `[Synth 8-6064]` 高扇出复制。
- 任一 OOC timing violation。

### 10.2 single-clock core 综合

运行：

```powershell
& 'C:\Xilinx\Vivado\2018.3\bin\vivado.bat' `
  -mode batch -source scripts\vivado_single_clock_core_stage_a_synth_check.tcl
```

当前 core 为55个 DSP；本次改造后目标约为13个 DSP：

```text
55 - 40 - 10 + 4 + 4 = 13
```

验收：

- `post_iir_inst <= 4 DSP`。
- `fll_cross_dot_inst <= 4 DSP`。
- single-clock core 总 DSP 目标 `<=13`；若其他并行改动导致增加，必须在报告中
  对每个额外 DSP 给出非本任务层次归属。
- 125 MHz WNS >= 0 ns，TNS = 0 ns。

### 10.3 完整实现

运行完整 bitstream 流程：

```powershell
& 'C:\Xilinx\Vivado\2018.3\bin\vivado.bat' `
  -mode batch -source scripts\vivado_full_bitstream_reports.tcl
```

硬验收：

| 项目 | 标准 |
|---|---|
| 完整设计 DSP | 目标约56，发布上限60 |
| DSP 余量 | 至少20个 |
| placement | 成功，不得出现 `Place 30-640` |
| routing | fully routed，无 unrouted nets |
| bitstream | `red_pitaya_top.bit` 成功生成 |
| setup timing | 所有时钟 WNS >= 0 ns，TNS = 0 ns |
| hold timing | WHS >= 0 ns，THS = 0 ns |
| DRC | 0 error；critical warning 必须逐项解释 |

完整实现报告必须至少保存：

```text
reports/vivado_full_impl/utilization_hier.rpt
reports/vivado_full_impl/timing_summary.rpt
reports/vivado_full_impl/timing_paths.rpt
reports/vivado_full_impl/route_status.rpt
reports/vivado_full_impl/drc.rpt
reports/vivado_full_impl/manifest.txt
```

## 11. 分阶段施工顺序

### 阶段 A：冻结基线

1. 保存当前 post-IIR/cross-dot reference。
2. 保存当前单元测试输出、核心 trace 和资源报告。
3. 记录当前完整实现的98/80 DSP失败日志。
4. 确认工作区其他修改，不覆盖无关用户改动。

### 阶段 B：post-IIR

1. 增加 I/Q 两套独立乘法 pipeline。
2. 增加共同 issue controller 和独立 accumulator。
3. 实现 section barrier、round_sat 和事务式 history commit。
4. 保持 bypass、clear、selection change 语义。
5. 修改单元测试为合法 cadence，并完成 bit-exact reference 对比。
6. OOC 综合确认 `DSP<=4` 和 `WNS>=0`。

post-IIR 未通过全部单元/OOC 验收前，不开始 cross-dot 修改。

### 阶段 C：cross-dot

1. 增加 dot/cross 两套独立乘法 pipeline。
2. 实现两拍 issue 和 operation tag。
3. 实现 block accumulator 的事务式更新。
4. 将 numerator/denominator 改为24拍无 DSP shift-add。
5. 接回现有71拍 divider 和 replay。
6. 新增专用 testbench、随机 reference 测试和 OOC 综合。

### 阶段 D：集成回归

1. 运行 single-clock core 回归。
2. 运行 multifrequency、nonzero tracking、sine lock/sweep。
3. 运行 wrapper CDC 和 fixed-point 全套测试。
4. 比较改造前后的有效样本事件序列。

### 阶段 E：完整实现

1. 重新综合整个工程。
2. 确认层次 DSP 数。
3. 完成 place、route、bitstream。
4. 检查 timing、DRC 和 route status。
5. 归档 manifest 和验收摘要。

## 12. 最终交付物

施工完成时必须同时提交：

- 修改后的 `post_iir_stage_a.v`。
- 修改后的 `fll_cross_dot_stage_a`。
- 更新后的 `post_iir_stage_a_tb.v`。
- 新增的 `fll_cross_dot_stage_a_tb.v`。
- 新增/更新的 XSim 运行脚本。
- 两个模块 OOC 综合脚本及报告。
- 全部回归日志或摘要。
- 完整实现 utilization、timing、DRC、route status 和 bitstream 证据。
- 一份改造前后对比表，至少包含 DSP、LUT、FF、WNS、最大 latency、
  overrun 数和 reference mismatch 数。

## 13. 一票否决项

出现以下任一项，不得签收：

- 实际进行了 I/Q 乘法器合并。
- post-IIR 或 cross-dot 超过各自4个 DSP。
- 使用 LUT 乘法掩盖 DSP 使用量。
- 任一 bit-exact reference mismatch。
- `R=8` 出现 overrun、漏样、重样或 block 丢失。
- clear/mode change 后出现旧事务输出。
- FLL replay 次数或 block-valid 有效样本序号变化。
- 任一现有 DPLL 回归失败。
- 完整设计仍超过80个 DSP。
- place、route、timing、DRC 或 bitstream 任一硬验收不通过。

## 14. 签收表

| 检查项 | 目标 | 实测 | 结论 |
|---|---:|---:|---|
| post-IIR DSP | <=4 | 待测 | 待签 |
| cross-dot DSP | <=4 | 待测 | 待签 |
| single-clock core DSP | 目标<=13 | 待测 | 待签 |
| 完整设计 DSP | 目标56，上限60 | 待测 | 待签 |
| post-IIR 最大 latency | <=20 clocks | 待测 | 待签 |
| cross-dot sample busy | <=6 clocks | 待测 | 待签 |
| cross-dot result busy | <=100 clocks | 待测 | 待签 |
| `R=8` overrun | 0 | 待测 | 待签 |
| bit-exact mismatch | 0 | 待测 | 待签 |
| OOC timing | WNS>=0 | 待测 | 待签 |
| 完整 timing | WNS/WHS>=0 | 待测 | 待签 |
| route status | fully routed | 待测 | 待签 |
| DRC errors | 0 | 待测 | 待签 |
| bitstream | generated | 待测 | 待签 |

只有本表所有项目通过，且第13节无一票否决项时，本阶段“内部流水线复用、
I/Q 保持独立”改造才视为完成。
