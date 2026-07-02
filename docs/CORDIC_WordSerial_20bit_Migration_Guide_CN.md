# DPLL CORDIC Word Serial + 20-bit 输入/18-bit 有效相位：一步到位迁移指南

适用分支：

```text
refactor/dpll-single-path
```

目标：

- CORDIC 改为 `Word Serial + Maximum`
- 125 MHz 单物理时钟
- 完整 AXI4-Stream valid/ready 对接
- post-IQ CIC 20-bit I/Q 直接进入 CORDIC
- 删除 `round_cic20_to_cordic16`
- CORDIC Output Width=20，得到真正有效的 18-bit scaled-radian 环路相位
- magnitude 全链路改为 20 bit
- 不保留旧 16-bit CORDIC 兼容路径
- 不硬编码 CORDIC latency
- 增加 overrun、输入范围、输出格式等断言和 sticky status

---

## 1. 最终推荐配置

### 1.1 推荐主方案

```text
Functional Selection          Translate
Architecture                  Word Serial
Pipelining Mode               Maximum
Data Format                   Signed Fraction
Input Width                   20
Output Width                  20
Phase Format                  Scaled Radians
Coarse Rotation               Enabled
Compensation Scaling          Disabled
Rounding Mode                 Nearest Even
AXI Flow Control              Blocking
ARESETn                       Enabled
ACLKEN                        Disabled（除非工程明确需要）
TLAST/TUSER                   Disabled
ACLK metadata                 125000000 Hz
```

这套配置的含义：

```text
post-IQ CIC output width       20 bit
CORDIC X/Y input width         20 bit
CORDIC magnitude width         20 bit
CORDIC raw phase field width   20 bit
effective modulo phase width   18 bit
```

Scaled Radians 使用 2QN 格式，raw phase 字段顶部有两个格式位。对 20-bit raw phase：

```text
phase_mod18 = phase_raw20[17:0]
```

这与当前工程 `PHASE_WIDTH=18` 的物理相位量纲一致。旧实现是把 14 个有效 phase bit 左移 4 位；新实现则让原来恒为 0 的低 4 bit 变成真实 CORDIC 结果。

### 1.2 不推荐本轮采用的 20-bit 有效相位方案

若要求真正的 20-bit modulo phase：

```text
CORDIC Output Width = 22
PHASE_WIDTH          = 20
phase_mod20          = phase_raw22[19:0]
```

此方案还必须：

- `FERR_WIDTH` 建议从 22 增加到至少 24；
- `PRODUCT_SHIFT` 从 18 调整到 20，或把所有 phase-domain gain 除以 4；
- phase threshold 乘 4；
- frequency threshold、FLL model 和 coefficient generator 联合重标；
- 更新全部 ARM 默认值和 golden vectors。

因此本轮推荐停在：

```text
20-bit input
20-bit output
18-bit effective phase
```

---

## 2. Word Serial 后必须修改 valid/ready

当前 RTL 将 `cordic_input_valid_r` 作为单周期 pulse 直接送给 Parallel CORDIC。Word Serial 不能保证每个时钟都能接收新输入。

AXI 接收事件必须定义为：

```text
input_fire = s_axis_cartesian_tvalid
          && s_axis_cartesian_tready
```

对于 Blocking flow control，输出事件为：

```text
output_fire = m_axis_dout_tvalid
           && m_axis_dout_tready
```

由于下游始终能接收，建议：

```text
m_axis_dout_tready = 1'b1
```

禁止继续：

```text
iq_valid → 单周期 tvalid pulse → 不检查 tready
```

否则当 CORDIC 未 ready 时，该样本会丢失。

### 2.1 推荐使用两项同步小 FIFO

post-IQ CIC 没有 ready，不能被 CORDIC 反压。因此在两者之间放一个 2-entry register FIFO：

```text
post-IQ CIC pulse source
→ 2-entry input FIFO
→ AXI tvalid/tready
→ Word Serial CORDIC
```

要求：

- `iq_valid` 时写 FIFO；
- `tvalid && tready` 时读 FIFO；
- 满时再来输入，设置 `cordic_input_overrun_seen`；
- 正常配置 R>=8 时不应 overrun；
- 不丢样、不覆盖旧样本；
- FIFO 与 CORDIC 在 config apply/reset 时同时清空。

不建议只靠“样本通常很慢”而忽略 ready。

---

## 3. `round_cic20_to_cordic16` 的作用

当前函数做三件事：

```text
20-bit signed CIC value
→ 除以 16（算术右移 4）
→ 对被丢弃的 4 bit 做对称 round-to-nearest
→ 饱和到 signed 16 bit
```

它存在的唯一原因是：

```text
post-IQ CIC output = 20 bit
old CORDIC input   = 16 bit
```

它不是自动增益控制，也不是向量归一化。它不会保证：

```text
sqrt(I²+Q²)
```

一定处于 CORDIC magnitude 的无溢出范围。

改成 20-bit CORDIC 输入后，应彻底删除：

- `round_cic20_to_cordic16`
- `cordic_i_rounded`
- `cordic_q_rounded`
- `cordic_round_valid_r`
- `cordic_i_baseband_r`
- `cordic_q_baseband_r`
- `cordic_i_in_r[15:0]`
- `cordic_q_in_r[15:0]`
- 旧两级 20→16 格式转换路径

新的 FIFO 直接保存：

```text
i_baseband[19:0]
q_baseband[19:0]
```

---

## 4. 20-bit AXI TDATA 打包

CORDIC AXI 字段按 byte boundary 排列。

20-bit operand 占 24-bit lane。

### 4.1 输入 S_AXIS_CARTESIAN

Translate 的输入为 X_IN 和 Y_IN：

```text
X_IN = I
Y_IN = Q
```

推荐打包：

```verilog
wire [23:0] cordic_x_lane =
    {{4{i_sample[19]}}, i_sample[19:0]};

wire [23:0] cordic_y_lane =
    {{4{q_sample[19]}}, q_sample[19:0]};

wire [47:0] cordic_s_tdata =
    {cordic_y_lane, cordic_x_lane};
```

即：

```text
bits 19:0   X_IN / I
bits 23:20  X padding
bits 43:24  Y_IN / Q
bits 47:44  Y padding
```

实际端口宽度必须以重新生成后的 `angle_CORDIC_stub.v` 为准。

### 4.2 输出 M_AXIS_DOUT

Translate 输出顺序：

```text
X_OUT / magnitude 在低 lane
PHASE_OUT          在高 lane
```

20-bit Output Width 时：

```verilog
wire [19:0] cordic_magnitude20 =
    cordic_m_tdata[19:0];

wire signed [19:0] cordic_phase_raw20 =
    cordic_m_tdata[43:24];

wire signed [17:0] cordic_phase18 =
    cordic_phase_raw20[17:0];
```

输出 padding 可用于断言：

```verilog
assert(cordic_m_tdata[23:20] ==
       {4{cordic_m_tdata[19]}});

assert(cordic_m_tdata[47:44] ==
       {4{cordic_m_tdata[43]}});
```

---

## 5. 推荐新增独立 adapter

新增文件：

```text
DigitalPLL/detector_fll/cordic_word_serial_adapter.v
```

建议接口：

```verilog
module cordic_word_serial_adapter #(
    parameter integer IQ_WIDTH    = 20,
    parameter integer PHASE_WIDTH = 18,
    parameter integer MAG_WIDTH   = 20
) (
    input  wire                         clk_125m,
    input  wire                         rst_125m,
    input  wire                         clear,

    input  wire                         in_valid,
    input  wire signed [IQ_WIDTH-1:0]   i_in,
    input  wire signed [IQ_WIDTH-1:0]   q_in,

    output wire                         out_valid,
    output wire signed [PHASE_WIDTH-1:0] phase_out,
    output wire        [MAG_WIDTH-1:0]   magnitude_out,

    output wire                         busy,
    output reg                          input_overrun_seen,
    output reg                          input_out_of_range_seen,
    output reg                          output_format_error_seen
);
```

adapter 的责任：

- 2-entry input FIFO；
- CORDIC AXI handshake；
- reset sequencing；
- 20-bit lane packing；
- 20-bit magnitude 解包；
- 20 raw phase → 18 modulo phase；
- sticky error；
- 不包含 phase setpoint；
- 不包含 magnitude threshold；
- 不包含 FLL；
- 不包含 loop state。

---

## 6. ARESETn 和 config apply

建议在 IP 中启用 `ARESETn`。

CORDIC ARESETn：

- 同步；
- active-low；
- 需要至少保持低两个周期；
- 释放后再等待一个 guard cycle 接收新样本。

推荐 adapter 内实现 reset sequencer：

```text
rst_125m / clear pulse
→ ARESETn 低至少 3 个 clk_125m
→ 清空 FIFO
→ 清空 pending AXI transaction
→ 再等待 1 cycle
→ 允许输入
```

`clear` 建议连接：

```text
config_apply | cic_flush
```

这样切换 CIC R、shift 或环路配置时，旧 CORDIC transaction 不会在新配置下冒出来。

禁止：

- 只清下游 phase register，不清 Word Serial CORDIC 内部状态；
- config apply 后接受旧 transaction 输出；
- 硬编码 latency 等待若干周期。

---

## 7. 输入范围与 scale

Signed Fraction 的 Translate 输入应保持在合法规范范围。

对于 20-bit 1Q18 解释，建议在每个 `in_valid` 时检查：

```text
-1.0 <= I <= +1.0
-1.0 <= Q <= +1.0
```

对应整数范围：

```text
-2^18 <= value <= +2^18
```

越界时：

```text
input_out_of_range_seen = 1
```

不要在 CORDIC adapter 内增加动态 AGC 或每样本归一化。

幅度控制应通过已有：

```text
POST_IQ_CIC_SCALE
```

完成，并由 fixed-point model 确保 I/Q 不经常越界。

当前配置保持：

```text
No Scale Compensation
```

理由：

- phase 不受共同 scale factor 影响；
- magnitude 可通过模型标定；
- 避免新增补偿乘法器。

但 magnitude threshold 必须按新 20-bit 输出重新生成。

---

## 8. magnitude 全链路改为 20 bit

不要在 CORDIC 输出后立刻截回 16 bit，否则会留下新的历史包袱。

需要修改：

### FPGA

- `cordic_magnitude`：16 → 20
- `cordic_magnitude_hold`：16 → 20
- `magnitude` output：16 → 20
- `mag_enter_threshold`：16 → 20
- `mag_exit_threshold`：16 → 20
- `state_magnitude_r`：16 → 20
- `loop_state_manager_stage_a.MAG_WIDTH`：20
- wrapper active/shadow magnitude threshold：20
- status readback magnitude：低 20 bit
- debug source magnitude：完整 20 bit
- golden model magnitude：20 bit

### ARM

- magnitude thresholds 使用 20 bit；
- 默认值不能继续原样使用旧 16-bit 数字；
- 初始估算可按旧值左移 4，但最终必须由模型和板上实测重标；
- status 打印使用 unsigned 20-bit；
- 增加 input-range、overrun、format error 状态读回。

---

## 9. phase 路径修改

删除：

```verilog
assign cordic_phase_word =
    {cordic_phase[13:0], 4'b0000};
```

改成：

```verilog
assign cordic_phase_word =
    cordic_phase_raw20[17:0];
```

保持：

```text
PHASE_WIDTH = 18
```

因此以下物理量纲不变：

- phase_setpoint
- phase_lock_threshold
- phase_error
- FLL phase history
- Kp/Ki/Kf 的 phase-code 输入尺度
- PRODUCT_SHIFT=18

原则上不需要因为这次 CORDIC 位宽修改而整体改变 Kp/Ki/Kf。

但必须重新运行模型，因为低 4 bit 现在包含真实噪声和信号，不再恒为 0。

---

## 10. 14-bit ADC 下提高 CORDIC 位宽是否有数学意义

### 10.1 有意义，但不是“制造新信息”

单个 ADC 样本只有 14 bit，并不意味着后续相位只能有 14 bit。

DPLL 的 CORDIC 输入不是原始 ADC：

```text
ADC
→ 混频
→ 多样本 CIC 积分/抽取
→ I/Q 窄带估计
→ CORDIC
```

混频和 CIC 对同一窄带信号进行相干累积。理想情况下，量化噪声和宽带噪声会被平均，而信号相干叠加，因此 post-CIC I/Q 可以具有超过单样本 14-bit 的有效分辨率。

增加 CORDIC 输入位宽的实际价值：

- 保留 CIC 产生的低位信息；
- 避免 20→16 的四位量化损失；
- 减少 angle 计算本身的量化；
- 让 FLL/PLL 的 phase error 不再以 16 倍台阶跳变；
- 降低算法量化成为主噪声源的概率。

### 10.2 相位量化步长

当前真正有效的 14-bit modulo phase：

```text
2π / 2^14 ≈ 383.5 µrad
≈ 0.02197°
```

推荐 18-bit modulo phase：

```text
2π / 2^18 ≈ 23.97 µrad
≈ 0.001373°
```

20-bit modulo phase：

```text
2π / 2^20 ≈ 5.99 µrad
≈ 0.000343°
```

18 bit 相比当前有效 14 bit 细 16 倍。

### 10.3 为什么推荐 18 有效位而不是 20

达到 18-bit phase LSB 量级，所需的相位信噪水平粗略约在 92 dB 量级；20-bit phase LSB 则约在 104 dB 量级。该估算只是判断量级，不代表系统实际 SNR。

14-bit ADC 理想单音 SNR 约 86 dB，真实 ENOB 往往更低；但 CIC 和窄带相干处理可以提供处理增益，因此 18-bit phase 作为内部算法精度有现实意义。

20-bit effective phase：

- 可作为 guard bits；
- 在强信号、窄带、长平均下可能有价值；
- 但很可能被 ADC ENOB、模拟噪声、时钟抖动、NCO spur 和基带干扰淹没；
- 会引起环路参数、阈值和模型更大范围修改。

结论：

```text
20-bit I/Q input + 18-bit effective phase：推荐
20-bit effective phase：暂不推荐
```

---

## 11. Vivado IP 手动修改教程

### 11.1 修改前

1. 提交当前代码和 XCI：
   ```bash
   git add -A
   git commit -m "baseline before CORDIC word-serial width migration"
   ```
2. 关闭所有正在运行的 synth/impl。
3. 记录当前：
   - XCI
   - generated stub
   - utilization
   - CORDIC OOC timing
   - full timing

### 11.2 Customize IP

在 Sources 或 IP Sources 中：

```text
angle_CORDIC
→ 右键
→ Customize IP
```

设置：

```text
Functional Selection   Translate
Architecture           Word Serial
Pipelining Mode        Maximum
Data Format            Signed Fraction
Input Width            20
Output Width           20
Phase Format           Scaled Radians
Coarse Rotation        Enabled
Scale Compensation     No Scale Compensation
Rounding               Nearest Even
Flow Control           Blocking
ARESETn                 Enabled
ACLKEN                  Disabled
TLAST/TUSER             Disabled
```

确认 GUI 显示的 latency 和 throughput，截图保存。

### 11.3 ACLK metadata

确认 Tcl 中：

```tcl
set ip [get_ips angle_CORDIC]

foreach p [list_property $ip] {
    if {[string match -nocase "*FREQ_HZ*" $p]} {
        puts "$p = [get_property $p $ip]"
    }
}
```

ACLK 对应值必须为：

```text
125000000
```

重新生成后，OOC XDC 必须包含：

```tcl
create_clock -period 8.000
```

### 11.4 重新生成

```tcl
set ip [get_ips angle_CORDIC]

reset_target all $ip
generate_target all $ip
```

若已有 OOC run：

```tcl
get_runs *angle_CORDIC*
```

然后 reset/launch 对应 run。

### 11.5 检查 generated stub

必须以新生成的 stub 为准。预期包含：

```verilog
input  wire         aclk;
input  wire         aresetn;

input  wire         s_axis_cartesian_tvalid;
output wire         s_axis_cartesian_tready;
input  wire [47:0]  s_axis_cartesian_tdata;

output wire         m_axis_dout_tvalid;
input  wire         m_axis_dout_tready;
output wire [47:0]  m_axis_dout_tdata;
```

若端口不同，不要猜测；让 RTL adapter 完全按实际 stub 修改。

---

## 12. 修改后检查核对表

### A. IP 配置

- [ ] Architecture = Word Serial
- [ ] Pipelining = Maximum
- [ ] Translate
- [ ] Signed Fraction
- [ ] Input Width = 20
- [ ] Output Width = 20
- [ ] Scaled Radians
- [ ] Coarse Rotation enabled
- [ ] Scale compensation disabled
- [ ] Nearest Even
- [ ] Blocking flow control
- [ ] ARESETn enabled
- [ ] ACLK metadata 125 MHz
- [ ] OOC XDC period 8.000 ns

### B. 端口和打包

- [ ] input tdata 实际宽度为 48
- [ ] output tdata 实际宽度为 48
- [ ] X/I 在低 24-bit lane
- [ ] Y/Q 在高 24-bit lane
- [ ] magnitude 在 output 低 lane
- [ ] phase 在 output 高 lane
- [ ] input pad 正确
- [ ] output sign pad assertion 通过

### C. AXI handshake

- [ ] tvalid 在 tready=0 时保持
- [ ] tdata 在 tvalid=1 且 tready=0 时保持
- [ ] input transaction 只在 valid&&ready 时消费
- [ ] m_axis_dout_tready=1
- [ ] output valid 只使用 output fire
- [ ] 不硬编码 latency
- [ ] 2-entry FIFO 存在
- [ ] overrun sticky 可观测
- [ ] R=8 下无 overrun
- [ ] reset/config apply during busy 测试通过

### D. 清理旧逻辑

- [ ] 删除 `round_cic20_to_cordic16`
- [ ] 删除 `cordic_i_rounded`
- [ ] 删除 `cordic_q_rounded`
- [ ] 删除 `cordic_round_valid_r`
- [ ] 删除旧 16-bit input register
- [ ] 删除 `{cordic_phase[13:0],4'b0000}`
- [ ] grep 不再找到旧转换逻辑
- [ ] 没有 16-bit compatibility mux

### E. phase/magnitude

- [ ] phase raw 20 正确提取
- [ ] phase modulo 18 取 `[17:0]`
- [ ] +π/-π wrap 测试通过
- [ ] 四象限 atan2 测试通过
- [ ] magnitude 全链路 20 bit
- [ ] threshold 全链路 20 bit
- [ ] magnitude threshold 已重新生成
- [ ] input range sticky 已实现
- [ ] magnitude overflow/format sticky 已实现

### F. reset

- [ ] ARESETn 至少低 2 cycles
- [ ] reset release guard cycle
- [ ] config_apply 清 FIFO
- [ ] config_apply 清 CORDIC transaction
- [ ] config_apply 后无旧 output
- [ ] global reset during busy 测试通过

### G. 数学/模型

- [ ] Python model 使用 20-bit I/Q
- [ ] phase quantizer 为 18 effective bits
- [ ] 与 `atan2(Q,I)` 比较
- [ ] random vector bit accuracy
- [ ] 轴点：(+I,0)、(-I,0)、(0,+Q)、(0,-Q)
- [ ] near-zero vector
- [ ] near ±π wrap
- [ ] 输入接近合法范围边界
- [ ] phase upper 14 bits 与旧路径合理一致
- [ ] 新低 4 bit 不恒零
- [ ] gain/threshold 表重新生成

### H. 环路回归

- [ ] 5 kHz
- [ ] 10 kHz
- [ ] 20 kHz
- [ ] 50 kHz
- [ ] 100 kHz
- [ ] 150 kHz
- [ ] 200 kHz
- [ ] R=8 最大吞吐
- [ ] R=312 最低吞吐
- [ ] FLL acquire
- [ ] FLL→PLL blend
- [ ] PLL track
- [ ] holdover
- [ ] reacquire
- [ ] phase step
- [ ] frequency step
- [ ] no change to physical Kp/Ki/Kf scale

### I. 综合实现

- [ ] CORDIC OOC synth
- [ ] CORDIC OOC timing
- [ ] full synth
- [ ] full implementation
- [ ] timing summary
- [ ] utilization hierarchical
- [ ] CDC
- [ ] DRC
- [ ] no unconstrained path
- [ ] no new high fanout ready/reset net
- [ ] compare old/new LUT/FF
- [ ] compare old/new CORDIC latency
- [ ] compare full-design WNS

---

## 13. Codex 命令表

先设置：

```bash
export REPO=/absolute/path/to/DPLL_Rewrite
```

Codex CLI 支持 `codex exec` 非交互运行、`-C` 指定工作目录，以及从 stdin 读取 prompt。以下任务应按顺序执行，每一步先 review diff 再进入下一步。

### 命令 1：只审计新 IP 接口，不修改 XCI

```bash
codex exec \
  --sandbox workspace-write \
  --ask-for-approval never \
  -C "$REPO" - <<'PROMPT'
你负责审计用户已经手动重新生成的 angle_CORDIC IP。

硬约束：
- 不得修改任何 .xci、自动生成 IP 文件、DCP 或 Vivado IP 配置。
- 不得修改 RTL。
- 只读取实际 generated stub、XCI、OOC XDC 和当前 dpll_single_clock_core_stage_a.v。
- 确认 Word Serial、Maximum、Input Width、Output Width、Flow Control、ARESETn、ACLK metadata。
- 列出实际端口名称、方向和宽度。
- 列出 s_axis_cartesian_tdata 和 m_axis_dout_tdata 的实际宽度。
- 确认是否存在 s_axis_cartesian_tready 和 m_axis_dout_tready。
- 确认 OOC create_clock 是 8.000 ns。
- 将报告写入 reports/cordic_word_serial_ip_audit.md。
- 如果配置不是 20-bit input、20-bit output、Blocking、ARESETn enabled，不要修改，明确报错并停止。
- 不要声称未执行的命令通过。

最后输出读取过的文件、发现的接口和阻塞问题。
PROMPT
```

### 命令 2：实现独立 adapter 和单元测试

```bash
codex exec \
  --sandbox workspace-write \
  --ask-for-approval never \
  -C "$REPO" - <<'PROMPT'
基于 reports/cordic_word_serial_ip_audit.md 中的真实 generated stub，实现：
DigitalPLL/detector_fll/cordic_word_serial_adapter.v

要求：
- 不修改 XCI 和任何 generated IP 文件。
- 使用真实 angle_CORDIC 端口。
- 20-bit signed I/Q 输入。
- 2-entry 同步寄存器 FIFO。
- 完整 AXI valid/ready。
- Blocking output ready 固定为 1。
- ARESETn 同步低有效，reset/clear 后至少低 3 cycles，再有 1 cycle guard。
- clear 时清 FIFO，抑制旧 transaction 输出。
- 20-bit operand 使用 24-bit byte lane，X=I 在低 lane，Y=Q 在高 lane。
- 提取 20-bit magnitude 和 20-bit raw phase。
- 输出 phase 为 raw phase[17:0]，PHASE_WIDTH=18。
- 输出 magnitude 为完整 20 bit。
- 增加 busy、input_overrun_seen、input_out_of_range_seen、output_format_error_seen。
- 检查输入范围 -2^18...+2^18。
- 检查 output padding sign extension。
- 不硬编码 latency。
- 不加入 AGC、动态归一化或兼容 16-bit 路径。

建立独立 testbench，至少覆盖：
- ready backpressure；
- tvalid/tdata hold；
- FIFO 同时 push/pop；
- FIFO overflow sticky；
- reset during pending；
- clear during CORDIC busy；
- output field extraction；
- phase wrap；
- output padding error。

运行可用的 lint/iverilog/xsim 测试。记录实际命令和结果。
PROMPT
```

### 命令 3：接入 core，删除历史 20→16 转换

```bash
codex exec \
  --sandbox workspace-write \
  --ask-for-approval never \
  -C "$REPO" - <<'PROMPT'
将 cordic_word_serial_adapter 接入当前单路 DPLL core。

主要文件：
- DPLL_Rewrite.srcs/sources_1/DigitalPLL/core/dpll_single_clock_core_stage_a.v
- 新 adapter
- 直接相关 package/module

要求：
- 不修改 XCI/generated IP。
- post_iq_cic 的 20-bit i_baseband/q_baseband 直接进入 adapter。
- 删除 round_cic20_to_cordic16 函数及所有旧 wire/reg/valid stage。
- 删除旧 angle_CORDIC 直接实例。
- 删除 {cordic_phase[13:0],4'b0000}。
- phase 使用 adapter 的真实 18-bit 输出。
- magnitude 改为 20 bit。
- config_apply 或 cic_flush 连接 adapter clear。
- 所有 downstream valid 以 adapter out_valid 为准。
- 不硬编码 CORDIC latency。
- 不改变 FLL/PLL phase 物理量纲。
- 不恢复第二时钟或 CDC。
- 不保留 16-bit compatibility mux。

更新相关 testbench，并运行回归。
最后使用 grep 证明旧函数和旧 zero-padding 已完全删除。
PROMPT
```

### 命令 4：magnitude 20-bit 全链路与 ARM

```bash
codex exec \
  --sandbox workspace-write \
  --ask-for-approval never \
  -C "$REPO" - <<'PROMPT'
将 CORDIC magnitude 和 magnitude thresholds 从 16 bit 一次性升级为 20 bit。

覆盖：
- dpll_single_clock_core_stage_a
- loop_state_manager_stage_a
- dpll_wrapper shadow/active config
- status/readback
- debug DAC magnitude source
- ARM register definitions
- ARM dpll_config_t/dpll_status_t
- default profile/coefficient data
- Python/fixed-point model
- RTL/ARM tests

要求：
- 不保留 16-bit magnitude compatibility path。
- ARM 32-bit register 中使用低 20 bit。
- 非法高位必须校验。
- 旧 threshold 可用于初始对比时左移 4，但最终默认值应由模型重新生成。
- 增加 adapter sticky status 的 FPGA/ARM readback：
  input_overrun_seen
  input_out_of_range_seen
  output_format_error_seen
- ABI_VERSION 必须增加。
- 更新寄存器文档。
- 运行 ARM mock MMIO 和 RTL regression。
PROMPT
```

### 命令 5：模型和 bit-accurate 验证

```bash
codex exec \
  --sandbox workspace-write \
  --ask-for-approval never \
  -C "$REPO" - <<'PROMPT'
扩展 CORDIC 和 DPLL 固定点验证。

必须验证：
- 20-bit signed-fraction I/Q。
- 20-bit CORDIC raw output。
- 18-bit effective scaled-radian phase。
- phase_code 与 atan2(Q,I) 的 wrap-aware error。
- magnitude 的 CORDIC scale factor。
- axis、quadrant、near-zero、near-wrap、range-boundary、随机向量。
- 当前旧路径上 14 个有效 phase bits 与新路径对应高位的一致性。
- 新 phase 低 4 bit 不恒为零。
- 5/10/20/50/100/150/200 kHz closed-loop。
- R=8 和 R=312。
- reset/config apply during transaction。
- 不发生 input overrun。

输出：
- reports/cordic_20in_20out_fixed_point.md
- golden vectors
- 推荐 magnitude thresholds
- phase quantization RMS
- 失败向量明细

不得把 tolerance 放宽到掩盖 packing、符号或 wrap bug。
PROMPT
```

### 命令 6：最终 review、综合脚本和清理

```bash
codex exec \
  --sandbox workspace-write \
  --ask-for-approval never \
  -C "$REPO" - <<'PROMPT'
对 CORDIC Word Serial 迁移做最终专项 review。

检查：
- 唯一 angle_CORDIC active instance。
- 无旧 Parallel 接口假设。
- 无 round_cic20_to_cordic16。
- 无 16-bit magnitude path。
- 无 phase zero-padding。
- AXI valid/ready 完整。
- tdata packing 与 generated stub 一致。
- reset/config apply 不泄漏旧 transaction。
- 无 hard-coded latency。
- 无 overrun。
- ABI 已更新。
- 文档、RTL、ARM、模型一致。

补充或更新 Tcl，使其生成：
- CORDIC OOC timing
- full timing summary
- utilization hierarchical
- CDC
- DRC
- high fanout
- CORDIC through/boundary timing

不要修改 IP 参数。
运行所有可用测试。
输出 reports/cordic_word_serial_final_review.md，按 blocker/high/medium/low 分类。
PROMPT
```

---

## 14. 最终验收判定

只有全部满足才完成：

```text
20-bit CIC I/Q direct to CORDIC
Word Serial + Maximum
Blocking valid/ready
no lost input sample
no hardcoded latency
ARESETn correct
20-bit magnitude end-to-end
real 18-bit phase
no zero padding
no round_cic20_to_cordic16
no 16-bit compatibility path
model and RTL bit-accurate
R=8 no overrun
config apply no stale output
ARM ABI updated
OOC 8 ns
full timing and CDC pass
```
