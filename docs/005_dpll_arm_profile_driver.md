# 005 ARM DPLL Profile驱动与有效性检查

更新日期：2026-07-21

## 1. 模块边界

- `dpll_profile.c/.h`：纯参数层，负责频段选择、CIC/FLL delay、Q2.30 IIR生成、默认环路参数和有效性检查，不访问硬件。
- `dpll_driver.c/.h`：MMIO驱动层，负责ABI检查、完整候选校验、变化字段比较和活动寄存器写入。
- `helloworld.c`：协议与应用层，合并PC/STM命令，维护ARM committed config和软件签名。

FPGA没有配置Shadow和全局CONFIG_APPLY。驱动只在完整候选通过校验后写入发生变化的字段。

## 2. 支持等级

| 等级 | 范围或中心 | 含义 |
|---|---|---|
| `VERIFIED` | 5.5 kHz、22 kHz、200 kHz精确DDS高字 | 已有行为级仿真锁定证据 |
| `STANDARD` | 5--200 kHz | 按当前架构规则生成，仍需具体硬件频点验收 |
| `EXTENDED` | 4--5 kHz、200--250 kHz | 允许配置且通过数学检查，不保证锁定 |

只有超出`4--250 kHz`才由驱动直接拒绝。

## 3. 频段表

| 中心频率 | ACQUIRE IIR | TRACK IIR | measurement timeout |
|---:|---:|---:|---:|
| 4--8 kHz | 1.2 kHz | 0.8 kHz | `125000` |
| 8--15 kHz | 2 kHz | 1.2 kHz | `2400*R+512` |
| 15--30 kHz | 4 kHz | 2 kHz | `2400*R+512` |
| 30--60 kHz | 8 kHz | 3.5 kHz | `2400*R+512` |
| 60--100 kHz | 12 kHz | 5 kHz | `2400*R+512` |
| 100--150 kHz | 15 kHz | 7 kHz | `2400*R+512` |
| 150--200 kHz | 18 kHz | 8 kHz | `2400*R+512` |
| 200--250 kHz | 20 kHz | 9 kHz | `2400*R+512` |

驱动从`R={16,15,12,10,8}`中选择满足镜频和吞吐约束的最大值。shift使用nominal CIC shift并保留1 bit CORDIC headroom。

## 4. 完整校验

候选配置在写入任何活动寄存器前检查：

1. 中心频率量化值位于4--250 kHz。
2. cutoff单调并落入唯一频段。
3. CIC R/shift符合20-bit数据通路约束。
4. 镜频距离不小于`2.2*acquire_cutoff`，输出率不小于`8*acquire_cutoff`。
5. IIR cutoff小于`0.4*Fs`，Q2.30系数对称、单位直流增益且极点稳定。
6. cross-dot FLL满足`Fs >= 4*L*acquire_cutoff`。
7. correction limit符号正确且未超过中心字的25%。
8. Kf/Kp/Ki可由signed 24-bit表示。
9. threshold、magnitude、dwell、warmup、timeout和IIR mode位宽合法。
10. MUL/DIV非零，DAC0幅度和偏置合法。

失败时`dpll_profile_validation_t.errors`返回字段bit mask；FPGA保持原活动配置，不执行回滚写入。

## 5. 更新粒度

- 阈值、dwell、timeout、limits、manual offset、DAC和MUL/DIV直接更新。
- Kf/Kp/Ki变化由HDL寄存器更新脉冲清控制器状态并重新捕获。
- CIC R/shift、FLL delay或IIR配置变化清检测链并重新捕获。
- 未变化字段不产生MMIO写入。

ARM启动时DPLL保持关闭，写完初始完整配置后再按控制标志决定是否开启。运行中单字段API不再因为无关参数触发全局重启。

## 6. 默认环路参数

当前5.5 kHz、22 kHz和200 kHz profile使用：

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

这组增益在其他频点属于生成默认值，不等于已逐频点验证。

## 7. 软件签名

`dpll_config_signature()`只标识ARM committed config，用于STM控制区同步，不是FPGA CRC。`0x011E`保持读取0。详细的ARM/HDL职责见`011_arm_configuration_authority.md`。
