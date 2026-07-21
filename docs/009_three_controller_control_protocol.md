# 009 ARM、STM8 与 STM32F030 控制协议

状态：已实现并冻结，协议版本 `3`，冻结日期 `2026-07-14`。

版本 `3` 的寄存器偏移、物理单位、PC 命令号、载荷长度和成功/错误语义不得原地
改变。后续只能在保留字段或新命令号上做向后兼容扩展；任何不兼容修改必须提升
`CTRL_PROTOCOL_VERSION`。ARM、STM8、STM32 的低层传输细节见
`010_arm_stm8_stm32_transport_protocol.md`。

## 1. 数据所有权

- ARM 是运行时配置权威，也是所有冲突的最终同步源。
- STM8 保存持久参数、转发通用寄存器，并直接控制 MAX2871。
- STM32F030 只编辑和显示物理定点量，不计算 DDS、FPGA 原始字或浮点数。
- DPLL 与 MAX2871 使能不持久化，上电和 ARM 复位后均默认关闭。
- 屏幕每次调节后的 APPLY 时机不变；EEPROM 仍在停止调节约 10 秒后写入。
- ARM候选校验失败时不写FPGA，恢复提交前的60字节持久区并同步回STM8；错误码
  保留给发起方，失败候选不得进入EEPROM，不执行FPGA配置回滚。

## 2. 96 字节寄存器区

所有多字节字段均为小端。`[4,64)` 为 EEPROM 持久区，未列出的字节为保留空间，
写入时原样转发和保存。

| 偏移 | 长度 | 名称 | 单位或含义 |
|---:|---:|---|---|
| 0 | 1 | ID | 固定 `0xA5` |
| 1 | 1 | protocol version | 固定 `3` |
| 2 | 1 | request sequence | STM32/STM8 每次提交后递增 |
| 3 | 1 | control flags | bit0 DPLL，bit1 MAX2871；不持久化 |
| 4 | 4 | microwave frequency | 整数 kHz，范围 `23500--6400000` |
| 8 | 1 | microwave power | `0..3` |
| 12 | 4 | center frequency | `0.1 Hz/LSB`，可设置范围 `4--250 kHz`；`5--200 kHz` 为标准设计范围 |
| 16 | 2 | output MUL | 无符号整数，非零；由 ARM 按中心频率校验输出上限 |
| 18 | 2 | output DIV | 无符号整数，非零；由 ARM 按中心频率校验输出上限 |
| 20 | 4 | Kp_track | 低 24 bit 有效 |
| 24 | 4 | Ki_track | 低 24 bit 有效 |
| 28 | 4 | Kf_acquire | 低 24 bit 有效 |
| 32 | 4 | Kf_blend | 低 24 bit 有效 |
| 36 | 4 | positive limit | 有符号整数 Hz，必须非负 |
| 40 | 4 | negative limit | 有符号整数 Hz，必须非正 |
| 44 | 2 | phase threshold | `0.01 degree/LSB` |
| 46 | 2 | DAC amplitude | mV，范围 `0..2000` |
| 48 | 2 | frequency threshold | Hz |
| 50 | 2 | fast meter interval | ms，范围 `10--34359`，默认 `500` |
| 64 | 1 | response sequence | ARM 完成一次请求后更新 |
| 65 | 1 | DPLL status | 使能、锁定、超阈、限幅、错误、ARM 在线 |
| 66 | 1 | microwave status | 使能与锁定 |
| 67 | 1 | last error | 协议、范围、复位、APPLY、ABI |
| 68 | 1 | loop state | FPGA 环路状态 |
| 69 | 1 | loss reason | FPGA 失锁原因 |
| 70 | 1 | bridge status | bit0 为 STM8 I2C 命令 BUSY；bit1 为本次启动 EEPROM 校验异常锁存 |
| 71 | 1 | debug DAC preset/action | 非持久快捷预设 `0..8`；`FE` 请求精密频率计复位；`FF` 表示 PC 完整手动配置 |
| 72 | 4 | actual frequency error | 有符号整数 Hz |
| 76 | 4 | actual phase error | 有符号 `0.01 degree/LSB` |
| 80 | 4 | DPLL realtime frequency | 无符号整数，`1 mHz/LSB`；跟踪相位字对应的 MUL/DIV 前频率 |
| 84 | 4 | fast meter result | 无符号整数，`1 Hz/LSB`；第一页“重频”参考值 |
| 88 | 4 | fast meter sequence/status | bits30:0 为 FPGA 快速结果序号，bit31 为精密频率计稳定锁定 |
| 92 | 4 | active config signature | ARM 已提交 DPLL 候选配置的软件签名 |

相位显示只做整数拆位：绝对值达到 `100 degree` 时显示整数，达到 `10 degree`
时显示一位小数，其余显示两位小数，例如 `100°`、`50.1°`、`1.05°`。

ARM 对中心频率执行 `4--250 kHz` 范围校验；MUL/DIV 只要求非零并符合字段位宽，
不根据 `center frequency * MUL / DIV` 限制输出频率。FPGA HDL 直接接受 ARM 提交的
MUL/DIV，48 bit 输出饱和仍作为实时信号链保护保留。

偏移 71 不属于 `[4,64)`，不进入 EEPROM，也不推进 request sequence。STM32
只把它作为 `D1:0..8` 的快捷选择；ARM 收到变化后直接写 FPGA live debug
寄存器，不改变ARM active signature、不触发环路重捕获。

偏移 71 的保留值 `FE` 是版本 3 的兼容扩展，表示一次精密频率计复位请求。STM32
只在 ARM 在线时写入 `FE`；ARM 收到后执行与 PC `0x96` 相同的复位，并把偏移 71
恢复为请求前的 D1 预设值。该请求不使用 STM8 命令、不推进 request sequence、
不执行DPLL局部重配置、不写EEPROM。ARM启动时会先把偏移71初始化为默认
D1 预设，因此不会重放启动前遗留的请求。STM8 只透明转发该值，无需修改或重新
烧录版本 3 固件。

## 3. ARM 与 STM8 UART 帧

请求：

```text
B1 command offset length [data...] checksum B3
```

响应：

```text
B2 status length [data...] checksum B3
```

`checksum` 为从 command/status 开始到数据末尾逐字节求和后的二进制补码，使该段
连同 checksum 的 8 bit 和为零。

| command | 含义 |
|---:|---|
| `01` | 按 offset/length 读取 |
| `02` | 按 offset/length 写入 |
| `03` | 显式保存当前持久区到 EEPROM |
| `04` | PING，返回协议版本 |

最大请求为 60 字节持久区写入，最大响应为 96 字节全区读取。STM8 不解释 DPLL
字段，只有写入微波源字段或使能位时才执行 MAX2871 动作。

ARM UART1 与 STM8 固定使用 `1 Mbps, 8N1`。STM8 保留原始实机验证过的
`CLK_PCKENR1_UART2` 时钟位和 `UART1 BRR2=0, BRR1=1`；当前 STM8 固件库中该
时钟位宏名称与芯片实际映射不一致，不得仅按宏名改成 `UART1`。

ARM 对单次 STM8 UART 事务在首次失败后最多再重试 3 次；只有初次尝试及 3 次重试
全部失败时才把 `last error` 置为协议/链路错误。协议错误包含超时、短帧、帧头、帧尾、
长度、checksum、STM8 status 和响应载荷长度异常，并不只表示 checksum 错误。所有
`last error` 提示保持约 3000 个 ARM 主循环；保持期间出现新错误时重新计数，期满且
没有新错误时自动清零。错误提示清零不改变 DPLL 因 APPLY/ABI 失败形成的安全关闭状态。

## 4. STM32 到 STM8 的 I2C 命令

| 命令 | 行为 |
|---:|---|
| `C0` | 使用寄存器参数配置并打开 MAX2871 |
| `C1` | 关闭 MAX2871 |
| `C3` | 保存持久区到 EEPROM |
| `C4` | 60 字节持久区已通过 STM32 写后回读校验，推进请求序号并请求 ARM APPLY |
| `C7` | 请求 DPLL 打开，推进请求序号 |
| `C8` | 请求 DPLL 关闭，推进请求序号 |

STM32 启动时不再发送旧 `C2 -> C9 -> C4` 序列，也不会因自身复位而复位 FPGA。
普通 I2C 数据写除 `[4,64)` 外只额外允许单字节偏移 71，用于非持久 DAC1
快捷预设；该写入不触发 `C4` 或 EEPROM 保存。
屏幕提交配置时先写 STM8 RAM，再回读逐字节校验 `[4,64)`；最多重试 3 次，只有
60 字节完全一致才发送一次 `C4`，并校验命令前后的 request sequence 恰好加一。
`C4` 是事务提交标记；序号未变化时 ARM 不复制 STM8 持久区，因此不完整写入和
未提交候选都不会覆盖 ARM 的 active 配置或回滚基线。
读取运行状态时，ARM 先把 response sequence 写成临时值，完成全部状态字段后再写回
request sequence。STM32 在两次独立读取 response sequence 之间读取完整 96 字节，
仅当三项同时成立才更新本地缓存：前后 response sequence 相等、快照内 response
sequence 等于该值、快照内 request sequence 也等于该值。实现采用 60 次重试和
每次 2 ms 回退，足以覆盖 ARM 约 50 ms 的服务周期；实际总等待还
包含 I2C 读取时间，不把 120 ms 当作严格超时值。

## 5. ARM 上电顺序

1. 初始化 PC UART0 与 STM8 UART1。
2. PING STM8 并读取全部 96 字节，包括 STM8 已加载的 EEPROM 参数。
3. 强制清除 DPLL 与 MAX2871 使能位。
4. 分别写 DPLL reset 与 frequency-meter reset，两者都复位。
5. 等待复位完成并重新检查 DPLL ABI。
6. 把中心频率、限幅、相位、频差和幅度等物理定点量换算成 FPGA 格式。
7. 生成并校验完整频点profile，只写变化字段；启动时写完整活动配置。
8. 把 DAC1 恢复为默认快捷预设 `D1:1`，即校正量 raw 低位观察窗口。
9. 回写状态与换算后的显示值，DPLL 与 MAX2871 继续保持关闭。

STM32 通常先启动；Logo 结束后直接进入第一页并在后台轮询，不使用独立的通信失败
页面。第一页用 timeout 图标区分 STM8 离线（红色）和 ARM 离线（棕红色），用 error
图标区分协议版本异常（品红色）和 EEPROM 校验异常（印度红）；第二页不显示这些图标。
若STM8 UART链路不通，ARM才重试整个启动握手；若FPGA ABI或候选配置校验失败，
ARM 仍发布在线状态和明确错误码并保持 DPLL 关闭，避免屏幕永远停留在启动等待。

第一页初始化必须先清除上方 32 行再完整重绘微波源区域，避免第二页数值残留在 `GHz`
两侧。第二页仍在后台采集 ADC 并轮询 STM8，但不得绘制 VBIAS、微波源锁定图标或第一
页通讯状态；切回第一页后再恢复这些显示。

## 6. PC API

### 6.1 PC 串口帧

请求和响应均无帧尾，多字节载荷均为小端：

```text
request  = C6 checksum command payload_length [payload...]
response = A2 checksum command payload_length [payload...]
```

`checksum` 是从 `command` 到载荷末尾的逐字节无符号和低 8 bit。总帧长度固定为
`payload_length + 4`。读命令成功时响应载荷是数据；写命令响应载荷固定为一个
status 字节。

帧解析错误为 `F0` 帧头、`F1` 总长度、`F2` 载荷长度、`F3` 命令范围、`F4`
校验和。控制命令 status 为：`00` 成功、`01` 协议/链路、`02` 参数范围、`03`
FPGA复位、`04` FPGA配置、`05` FPGA ABI。

### 6.2 版本 3 公共控制 API

| 命令 | 请求载荷 | 成功响应载荷 | 冻结语义 |
|---:|---:|---:|---|
| `0x0A` | 0 | 1 | 协议版本；版本 3 返回 `03` |
| `0x1D` | 0 | 96 | 读取完整控制区，包含物理参数、状态和快速频率 Hz |
| `0x1E` | 0 | 13 | 读取 DAC1 预设状态及完整 source/format/offset/gain live 配置 |
| `0x88` | 0 | `00` | 打开 MAX2871；不持久化 |
| `0x89` | 0 | `00` | 关闭 MAX2871；不持久化 |
| `0x8A` | 0 | `00` | 打开DPLL；不持久化，配置/ABI失败返回错误 |
| `0x8B` | 0 | `00` | 关闭 DPLL；不持久化 |
| `0x8E` | 0 | `00` | 同时复位 DPLL 和精密频率计，重检 ABI 并恢复当前配置 |
| `0x97` | 1 或 12 | `00` | 1 字节选择快捷预设；12 字节完整设置 DAC1 live 配置 |
| `0x98` | 2 | `00` | `uint16 interval_ms`，范围 `10--34359`，事务式临时 APPLY |
| `0x99` | 60 | `00` | 发送控制区 `[4,64)`，事务式临时 APPLY，不写 EEPROM |
| `0x9B` | 0 | `00` | 显式保存当前 STM8 持久区到 EEPROM |

`0x99` 的正确调用方式是先用 `0x1D` 取得 96 字节快照，只修改已定义字段，再原样
发送快照的 `[4,64)`。保留字节必须原样带回，不能自行清零。成功后 ARM、FPGA
active 配置和 STM8 RAM 一致；失败时恢复提交前配置并返回原始错误。`0x99` 与
`0x98` 都不写 EEPROM，只有随后显式调用 `0x9B` 才持久化。

### 6.3 DAC1 快捷预设与完整 API

屏幕只使用快捷预设，不接触底层格式参数。PC 使用同一个 `0x97` 命令的两种严格
载荷长度：

```text
payload length 1:  uint8 preset
payload length 12: uint32 source, uint32 format, int16 offset, int16 gain
```

完整载荷保持原 `0x97` 字节布局和小端顺序。完整设置成功后偏移 71 置为 `FF`，
屏幕显示 `D1:-`；用户随后转动该项会重新进入 `0..8` 快捷循环。`0x1E` 的 13 字节
读回依次为 `preset u8, source u32, format u32, offset i16, gain i16`。

| D1 | source 内容 | format | gain | offset | 观察含义 |
|---:|---|---:|---:|---:|---|
| 0 | `freq_correction[55:24]` | `0100` | `5000` | 0 | 最终校正量，算术缩放观察 |
| 1 | `(tracking-center)[47:16]` | `0000` | `7FFF` | 0 | 校正量 raw 低位窗，默认 |
| 2 | `freq_state[55:24]` | `0100` | `5000` | 0 | 积分状态 |
| 3 | phase error | `0000` | `7FFF` | 0 | 相位残差低位 |
| 4 | frequency error | `0000` | `7FFF` | 0 | 频率残差低位 |
| 5 | post-IIR I | `0006` | `7FFF` | 0 | 有符号 I `[19:6]` |
| 6 | post-IIR Q | `0006` | `7FFF` | 0 | 有符号 Q `[19:6]` |
| 7 | raw CORDIC phase | `0004` | `7FFF` | 0 | 全相位 `[17:4]` |
| 8 | raw magnitude | `0207` | `7FFF` | 0 | 无符号幅度 |

`format[9:8]` 分别表示 raw window、signed shift/gain/saturate、unsigned
shift/saturate；`format[5:0]` 在 raw 模式是窗口最低位，在移位模式是右移位数。
raw 模式不使用 gain/offset，表中仍写固定值以保证完整寄存器状态确定。当前顶层
物理 DAC B 使用 formatter 输出低 14 bit，因此 `D1:1` 最终对应 tracking delta
`[29:16]`。该快捷预设只改变 DAC1 观察位窗，不改变 DPLL 运算或控制区频率字段。

所有快捷和完整写入都是非固化 live 设置；整机上电或 `0x8E` 复位后统一回到
`D1:1`。这两种写法都不触发DPLL重捕获，也不写STM8 EEPROM。

### 6.4 精密频率计 API

原精密测量通道保持原始寄存器单位和触发流程，上位机真实测量继续使用这一组命令：

| 命令 | 方向 | 载荷长度 | 含义 |
|---:|---|---:|---|
| `0x10` | read | response 4 | 中心频率原始字 `u32` |
| `0x11` | read | response 4 | 相位、频率残差阈值，各 `u16` |
| `0x12` | read | response 4 | 正、负频率限值高 16 bit |
| `0x13` | read | response 16 | P、I、I2、D，各 `u32` |
| `0x14` | read | response 7 | 相位残差 `u32`、频率残差 `u16`、状态 `u8` |
| `0x15` | read | response 1 | 运行状态，`0` 空闲、`1` 运行 |
| `0x16` | read | response 6 | 门宽时钟数 `u48` |
| `0x17` | read | response 16 | 测量累加值 `u80` 和本次门宽 `u48` |
| `0x90` | write | request 4 | 写中心频率原始字 |
| `0x91` | write | request 4 | 写频率、相位残差阈值，各 `u16` |
| `0x92` | write | request 4 | 写正、负频率限值，各 `u16` |
| `0x93` | write | request 16 | 写 P、I、I2、D，各 `u32` |
| `0x94` | write | request 6 | 写门宽时钟数 `u48` |
| `0x95` | write | request 0 | 触发一次正式测量 |
| `0x96` | write | request 0 | 复位精密频率计 |

### 6.5 快速参考与诊断

日常快速频率显示应读取 `0x1D`：偏移 84 是 ARM 换算后的整数 Hz，偏移 88 是结果
序号。`0x1C` 仅用于底层诊断，返回 22 字节：status `u32`、累加值低 `u32`、中
`u32`、高 `u16`、实际结果间隔 `u32`、配置间隔周期数 `u32`。上位机不得把
`0x1C` 作为正式测量结果，也不得自行假设结果间隔等于配置间隔。

### 6.6 兼容和禁用接口

`0x0A` 版本读取在新 ARM 上返回 `3`，上位机以此选择新旧驱动路径。

因此“临时 APPLY”和“持久保存”是两个独立 API 语义。新 ARM 协议不承担兼容旧
上位机的责任；上位机侧将通过设备/协议版本同时兼容新旧设备。
旧 `0x82--0x87` 原始 FPGA 配置写命令在新 ARM 中明确返回协议错误，避免绕过
控制寄存器区形成第二份配置；只读诊断命令不受此限制。
