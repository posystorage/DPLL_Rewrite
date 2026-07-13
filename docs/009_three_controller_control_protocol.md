# 009 ARM、STM8 与 STM32F030 控制协议

状态：已实现，协议版本 `2`。

## 1. 数据所有权

- ARM 是运行时配置权威，也是所有冲突的最终同步源。
- STM8 保存持久参数、转发通用寄存器，并直接控制 MAX2871。
- STM32F030 只编辑和显示物理定点量，不计算 DDS、FPGA 原始字或浮点数。
- DPLL 与 MAX2871 使能不持久化，上电和 ARM 复位后均默认关闭。
- 屏幕每次调节后的 APPLY 时机不变；EEPROM 仍在停止调节约 10 秒后写入。

## 2. 96 字节寄存器区

所有多字节字段均为小端。`[4,64)` 为 EEPROM 持久区，未列出的字节为保留空间，
写入时原样转发和保存。

| 偏移 | 长度 | 名称 | 单位或含义 |
|---:|---:|---|---|
| 0 | 1 | ID | 固定 `0xA5` |
| 1 | 1 | protocol version | 固定 `2` |
| 2 | 1 | request sequence | STM32/STM8 每次提交后递增 |
| 3 | 1 | control flags | bit0 DPLL，bit1 MAX2871；不持久化 |
| 4 | 4 | microwave frequency | `100 kHz/LSB` |
| 8 | 1 | microwave power | `0..3` |
| 12 | 4 | center frequency | `0.1 Hz/LSB`，范围 `4--125 kHz` |
| 16 | 2 | output MUL | 无符号整数，非零 |
| 18 | 2 | output DIV | 无符号整数，非零 |
| 20 | 4 | Kp_track | 低 24 bit 有效 |
| 24 | 4 | Ki_track | 低 24 bit 有效 |
| 28 | 4 | Kf_acquire | 低 24 bit 有效 |
| 32 | 4 | Kf_blend | 低 24 bit 有效 |
| 36 | 4 | positive limit | 有符号整数 Hz，必须非负 |
| 40 | 4 | negative limit | 有符号整数 Hz，必须非正 |
| 44 | 2 | phase threshold | `0.01 degree/LSB` |
| 46 | 2 | DAC amplitude | mV，范围 `0..2000` |
| 48 | 2 | frequency threshold | Hz |
| 50 | 2 | fast meter interval | ms，默认 `500` |
| 64 | 1 | response sequence | ARM 完成一次请求后更新 |
| 65 | 1 | DPLL status | 使能、锁定、超阈、限幅、错误、ARM 在线 |
| 66 | 1 | microwave status | 使能与锁定 |
| 67 | 1 | last error | 协议、范围、复位、APPLY、ABI |
| 68 | 1 | loop state | FPGA 环路状态 |
| 69 | 1 | loss reason | FPGA 失锁原因 |
| 70 | 1 | bridge status | bit0 为 STM8 I2C 命令 BUSY |
| 72 | 4 | actual frequency error | 有符号整数 Hz |
| 76 | 4 | actual phase error | 有符号 `0.01 degree/LSB` |
| 80 | 4 | DPLL output frequency | 无符号整数 Hz |
| 84 | 4 | fast meter result | 无符号整数 Hz |
| 88 | 4 | fast meter sequence | FPGA 快速结果序号 |
| 92 | 4 | active config CRC | FPGA active 配置 CRC |

相位显示只做整数拆位：绝对值达到 `100 degree` 时显示整数，达到 `10 degree`
时显示一位小数，其余显示两位小数，例如 `100°`、`50.1°`、`1.05°`。

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

## 4. STM32 到 STM8 的 I2C 命令

| 命令 | 行为 |
|---:|---|
| `C0` | 使用寄存器参数配置并打开 MAX2871 |
| `C1` | 关闭 MAX2871 |
| `C3` | 保存持久区到 EEPROM |
| `C4` | DPLL 参数已更新，推进请求序号并请求 ARM APPLY |
| `C7` | 请求 DPLL 打开，推进请求序号 |
| `C8` | 请求 DPLL 关闭，推进请求序号 |

STM32 启动时不再发送旧 `C2 -> C9 -> C4` 序列，也不会因自身复位而复位 FPGA。
读取运行状态时，ARM 先把 response sequence 写成临时值，完成全部状态字段后再写回
request sequence；STM32 仅接受前后 response sequence 一致且等于 request sequence
的快照。

## 5. ARM 上电顺序

1. 初始化 PC UART0 与 STM8 UART1。
2. PING STM8 并读取全部 96 字节，包括 STM8 已加载的 EEPROM 参数。
3. 强制清除 DPLL 与 MAX2871 使能位。
4. 分别写 DPLL reset 与 frequency-meter reset，两者都复位。
5. 等待复位完成并重新检查 DPLL ABI。
6. 把中心频率、限幅、相位、频差和幅度等物理定点量换算成 FPGA 格式。
7. 生成完整频点 profile，覆盖四个屏幕增益和物理设置，一次性 APPLY。
8. 回写状态与换算后的显示值，DPLL 与 MAX2871 继续保持关闭。

STM32 通常先启动；在 ARM 完成上述步骤前直接显示通信失败，不增加临时启动状态。

## 6. PC API

现有精密频率计触发与读取命令保持不变。新增控制接口目前只提供驱动 API，不接
上位机界面：

| 命令 | 方向 | 语义 |
|---:|---|---|
| `0x1D` | read | 读取 96 字节控制区 |
| `0x99` | write | 发送持久区 60 字节，校验并临时 APPLY，不写 EEPROM |
| `0x9B` | write | 显式保存当前持久区到 EEPROM |

`0x0A` 版本读取在新 ARM 上返回 `2`，上位机以此选择新旧驱动路径。

因此“临时 APPLY”和“持久保存”是两个独立 API 语义。新 ARM 协议不承担兼容旧
上位机的责任；上位机侧将通过设备/协议版本同时兼容新旧设备。
旧 `0x82--0x87` 原始 FPGA 配置写命令在新 ARM 中明确返回协议错误，避免绕过
控制寄存器区形成第二份配置；只读诊断命令不受此限制。
