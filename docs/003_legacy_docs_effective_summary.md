# 003 旧文档有效信息总结

更新日期：2026-07-11

## 1. 整理原则

原 `docs` 中的文档主要形成于单时钟重构、CORDIC 迁移、post-IIR/FLL 调试之前，混合了：

- 当时准确、现在仍有效的架构约束；
- 已经完成的施工计划和 RFC；
- 最终没有按计划实现的候选方案；
- 已被后续 RTL/ARM/仿真推翻的参数；
- 编码已经损坏的长篇中文资料。

本轮将旧文件原样移入 `docs/abandoned/`，保留 Git 历史和问题追溯能力。当前事实以以下文件为准：

1. `001_dpll_current_architecture.md`
2. `002_dpll_22khz_parameters_and_arm_notes.md`
3. 当前 RTL、ARM driver、TB 和实际仿真结果

`abandoned` 拼写正确，含义为“已弃用/不再作为当前规范”，不代表文件毫无历史价值。

## 2. 旧文档处理清单

| 旧文件 | 归档原因 | 被保留的有效信息 |
|---|---|---|
| `baseline.md` | 描述重构前的旧 DPLL、旧时钟和旧 PID/FIR，代码事实已变化 | 单通道边界、ADC1 属于频率计、DAC1 为调试、旧时序资源问题的历史背景 |
| `clk_dpll_migration_plan_stage_a.md` | 迁移已经完成，owner/分支规则不再用于施工 | 单物理时钟、valid 脉冲、禁止用 false path 隐藏问题 |
| `interface-change-RFC-001-single-clock-valid.md` | RFC 已实施，Stage A/B 端口计划已过期 | 125 MHz 单时钟、同步 reset、低速 valid 契约 |
| `owner_table_v1.md` | 旧多 agent/worktree 分工已结束 | 模块职责边界和 ABI 同步原则 |
| `subagent_dispatch_v1.md` | 派工计划已完成 | 不引入第二 DPLL、不恢复 PII2/D、不改变 DAC1 debug 定位 |
| `dpll_integrated_flow_tb_plan.md` | TB 已建成且运行方法/时长已变化 | wrapper 级集成仿真范围、ARM-style APPLY 流程 |
| `rfc_config_apply_status_v1.md` | 已落地 | `0x006F` busy/error/sequence 的基本语义 |
| `rfc_vco_mul_div_config_status.md` | 已落地 | 非法 MUL/DIV 拒绝、unsigned divider、sticky error |
| `CORDIC_WordSerial_20bit_Migration_Guide_CN.md` | 迁移完成，且文件编码损坏 | 20-bit I/Q、18-bit phase、2-entry FIFO、AXI handshake、无硬编码 latency、无额外 20->16 路径 |
| `dpll_iir_cic_notch_crossdot_codex.md` | 大量内容是未实施建议，且文件编码损坏 | post-IIR 和 cross-dot 的原理、R 不应只用于“赌零点”、滤波/鉴频需联合设计 |
| `dpll_fixed_point_v1.md` | 仍有大量有效内容，但含旧 Ki、旧 damping 估计和“待确认”项目，不再适合作为冻结规范 | 48-bit frequency word、18-bit phase、20-bit I/Q/magnitude、56-bit state、产品 shift、Q2.30 IIR |
| `dpll_interface_v1.md` | 是重构草案接口，不等于当前 Verilog wrapper/core 端口 | valid 语义、shadow/active 配置、模块责任划分 |
| `dpll_register_map_v1.md` | 大部分地址仍有效，但名称、缺失项和部分 readback 已与 RTL 不一致 | 地址布局、debug source、core flags、ABI identity |
| `deep-research-report.md` | 研究对象偏向 50 MHz 精密频率计，且引用标记/编码损坏，不是当前 22 kHz DPLL 施工规范 | phasemeter-first、连续相位/时间戳、NCO+残余相位、DMTD/TDC 等长期方向 |

## 3. 从旧文档继承的有效设计原则

### 3.1 单路径、单时钟

- 当前只有一条 DPLL 主链。
- ADC1 的独立频率计不能被误认为第二 DPLL。
- DACout1 只做调试。
- 算法 core 统一在 125 MHz 下运行，所有低速状态只在 valid 时推进。

### 3.2 配置必须原子提交

- 中心频率、CIC、IIR、FLL/PI、阈值、dwell、limits、MUL/DIV 构成同一 active snapshot。
- ARM 应先写完整 shadow set，再 APPLY，再核对 active snapshot/CRC，最后 enable。
- 不能在闭环运行时零散修改 shadow 寄存器并假设它们立即生效。
- debug DAC 是 live-only，不应导致重捕获。

### 3.3 固定点尺度必须端到端一致

- frequency word 为 48 bit，参考 125 MHz。
- phase 为 18-bit modulo turn。
- post-IQ I/Q 和 magnitude 为 20 bit。
- FLL error 为 22 bit。
- 系数为 signed 24 bit。
- IIR 系数为 signed Q2.30。
- state/correction 为 signed 56 bit。
- full-width tracking word 必须保留到最终 MUL/DIV，不能在环路中途截成旧 PID 宽度。

### 3.4 捕获和跟踪是不同任务

- FLL 负责较大频偏捕获。
- PI 负责相位拉入和稳态跟踪。
- state 5 是混合相位捕获，不是“等待状态”。
- state 6 才是正式 track/locked 状态。
- 进入 state 6 需要连续 dwell，不是瞬时进入阈值即可。

### 3.5 滤波、抽取和鉴频必须联合设计

- post-CIC R 决定更新率、CIC 增益、镜像 alias 位置和状态机测量速率。
- IIR cutoff 决定镜像抑制与环路延迟。
- FLL delay L 决定鉴频灵敏度和无模糊范围。
- 不能只靠加大 R 压镜像，也不能只改 Kf/Ki/Kp 掩盖错误的输入尺度。

### 3.6 状态和 sticky 必须区分

- sticky 表示“自上次清零以来曾发生”，不是当前正在发生。
- `phase_locked/frequency_locked` 是瞬时阈值状态。
- `locked` 还要求 state 6 和完整 loop_ok。
- 调试时必须把 error、term、state、valid 和 sticky 首次置位时间放在一起看。

## 4. 当前 ABI 快速参考

Base address：

```text
DPLL_BASE_ADDR = M_AXI_GP0_Base_Addr + 0x600000
absolute       = DPLL_BASE_ADDR + (index << 2)
```

当前 identity：

```text
ABI_VERSION    = 0x00000004
CONFIG_VERSION = 0x00010007
```

Build ID 和 Git hash 由脚本生成，不应在文档中写死为长期常量。

### 4.1 写/影子寄存器

| index | 当前含义 | 类型 |
|---:|---|---|
| `0x0000` | reset trigger | immediate |
| `0x0010` | center word high 32 | shadow |
| `0x0011` | readback selector | live/legacy |
| `0x0020` | DPLL enable | immediate |
| `0x0021` | Kp track | shadow |
| `0x0022` | Ki track | shadow |
| `0x0023` | Kf acquire | shadow |
| `0x0024` | Kf blend | shadow |
| `0x0025` | Kf track | shadow |
| `0x0026` | Kp blend | shadow |
| `0x0027` | Ki blend | shadow |
| `0x0028` | signed correction positive-limit high 32，内部补 16 个低位零 | shadow |
| `0x0029` | signed correction negative-limit high 32，内部补 16 个低位零 | shadow |
| `0x002A` | manual frequency offset | shadow |
| `0x0030` | DAC0 offset | shadow |
| `0x0031` | DAC0 amplitude | shadow |
| `0x0032` | output MUL | shadow |
| `0x0033` | output DIV | shadow |
| `0x0040` | debug DAC offset | live |
| `0x0041` | debug DAC gain | live |
| `0x0042` | debug DAC source | live |
| `0x0043` | debug DAC format | live |
| `0x0050` | phase lock threshold | shadow |
| `0x0051` | phase setpoint | shadow |
| `0x0052` | frequency lock threshold | shadow |
| `0x0053` | magnitude enter threshold | shadow |
| `0x0054` | magnitude exit threshold | shadow |
| `0x0055` | acquire dwell | shadow |
| `0x0056` | blend dwell | shadow |
| `0x0057` | loss dwell | shadow |
| `0x0058` | holdover timeout | shadow |
| `0x0059` | measurement timeout | shadow，0=RTL auto |
| `0x0060` | post-IQ CIC R | shadow |
| `0x0061` | post-IQ CIC shift | shadow |
| `0x0062` | FLL delay selector | shadow |
| `0x0063` | warmup samples | shadow |
| `0x0064` | post-IIR mode | shadow |
| `0x0065..0x0069` | ACQUIRE biquad b0/b1/b2/a1/a2 | shadow |
| `0x006A..0x006E` | TRACK biquad b0/b1/b2/a1/a2 | shadow |
| `0x006F` | CONFIG_APPLY trigger/status | command/readback |
| `0x0070` | APPLY rejected field mask | read-only |

### 4.2 状态/readback

| index | 当前 RTL readback |
|---:|---|
| `0x0100` | legacy summary status byte |
| `0x0101` | raw 20-bit magnitude |
| `0x0102` | sign-extended phase error；不是 raw CORDIC phase |
| `0x0103` | sign-extended 22-bit FLL error |
| `0x0104` | frequency correction low 32 |
| `0x0105` | tracking word low 32 |
| `0x0106` | sign-extended phase error，当前与 `0x0102` 重复 |
| `0x0107` | frequency state low 32 |
| `0x0108` | core flags/state/loss |
| `0x0109` | active CIC `{shift,R}` |
| `0x010A` | tracking word high 16 |
| `0x010B` | final VCO word low 32 |
| `0x010C` | final VCO word high 16 |
| `0x010D` | config version |
| `0x010E` | ABI version |
| `0x010F` | FPGA build ID |
| `0x0110` | active center high 32 |
| `0x0111` | active CIC `{shift,R}`，当前与 `0x0109` 重复 |
| `0x0112` | active `{MUL,DIV}` |
| `0x0113..0x0119` | active Kp/Ki/Kf 参数 |
| `0x011A` | active measurement timeout |
| `0x011B` | active holdover timeout |
| `0x011C` | applied ABI version |
| `0x011D` | FPGA Git hash |
| `0x011E` | active config CRC |
| `0x011F` | active post-IIR mode |
| `0x0120..0x0129` | active ACQUIRE/TRACK IIR 系数 |

旧寄存器文档把 `0x0102` 命名为 raw CORDIC phase，这是当前代码不成立的地方；RTL 返回的是 phase error。

### 4.3 `0x0108` core flags

| bit | 含义 |
|---:|---|
| 24 | post-IIR 使用 TRACK bank |
| 23 | post-IIR bypass |
| 22 | CORDIC output format error sticky |
| 21 | CORDIC input out-of-range sticky |
| 20 | CORDIC input overrun sticky |
| 19 | pre-CIC backpressure sticky |
| 18 | manual offset overflow |
| 17 | VCO MUL/DIV config error sticky |
| 16:13 | loop state |
| 12:9 | loss reason |
| 8 | signal present |
| 7 | phase locked |
| 6 | frequency locked |
| 5 | locked |
| 4 | tracking valid |
| 3 | frequency error valid |
| 2 | post-IIR I/Q valid |
| 1 | CIC illegal config |
| 0 | CIC overflow sticky |

### 4.4 CONFIG_APPLY status

`0x006F` readback：

```text
bit 0      busy
bit 1      error
bits 7:4   error code
bits 15:8  apply sequence
```

拒绝原因 mask 从 `0x0070` 读取。ARM 应等待 sequence 变化且 busy 清零，再核对 active snapshot。

## 5. 保留为未来研究、但不是当前实现的内容

旧研究文档中的以下方向仍有价值，但必须与当前 RTL 分开：

- 从连续相位轨迹通过线性回归/Λ-counter 估计频率；
- 使用 `NCO frequency + residual phase slope` 形成更完整的测频输出；
- DMTD/DDMTD 做相位/频差放大；
- comparator + TDC 连续时间戳；
- pilot tone 校正 ADC sampling jitter；
- pre-IIR 或 pre-CIC anti-alias filter；
- complex notch 抑制镜像；
- Kalman/PLL 混合估计；
- Allan deviation、phase-noise PSD 和 gap-free 测量链。

这些适合后续精密测频/相位计路线，不应混入当前 22 kHz DPLL 参数表。

## 6. 以后维护文档的规则

- 计划文档必须标注 `planned`，不能写成 current architecture。
- 参数必须注明来源：RTL default、ARM default、TB candidate、board verified 或 simulation-only。
- 修改产品 shift、位宽、R、FLL delay 或 coefficient scale 时，必须同步更新 RTL、ARM、host test 和本文档。
- 每次形成新的稳定频点 profile，应单独记录中心频率、输入偏差、完整寄存器集、状态切换时间和最终 lock 证据。
- 旧调试记录完成使命后移入 `docs/abandoned`，主目录只保留当前权威说明。
