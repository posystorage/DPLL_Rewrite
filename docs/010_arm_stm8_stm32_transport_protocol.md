# 010 ARM、STM8 与 STM32F030 传输协议

状态：与控制协议版本 `3` 同步冻结，日期 `2026-07-14`。

本文只描述两个 MCU 与 ARM 之间的低层传输、启动、同步和 EEPROM 行为。控制区
字段及 PC API 以 `009_three_controller_control_protocol.md` 为准。三份
`control_protocol.h` 必须保持宏定义一致。

## 1. 链路和职责

```text
PC -- UART0/921600 8N1 --> Zynq ARM
STM32F030 -- I2C --> STM8S003 -- UART1/1 Mbps 8N1 --> Zynq ARM
                              +-- MAX2871
                              +-- EEPROM
```

- ARM 是运行时配置、FPGA 换算和冲突处理的权威。
- STM8 保存 96 字节共享控制区，转发任意连续区间，管理 EEPROM 和 MAX2871。
- STM32 只编辑物理定点量、显示状态并发起 APPLY/SAVE，不计算 FPGA 原始字。
- STM8 不解释 DPLL 字段。以后在保留区增加 DPLL 字段时，只要控制区总长和传输
  上限不变，不需要重新烧录 STM8。

## 2. ARM 与 STM8 UART

### 2.1 物理层

- 固定 `1 Mbps, 8N1`，无流控。
- STM8 使用 16 MHz 系统时钟和已验证的 `UART1 BRR2=0, BRR1=1`。
- STM8 固件库的 UART 时钟位宏命名与芯片映射不一致，保留已验证的
  `CLK_PCKENR1_UART2`，不得仅按宏名替换。

### 2.2 请求和响应

```text
READ/PING/SAVE: B1 command offset length checksum B3
WRITE:          B1 02 offset length data[0..length-1] checksum B3
RESPONSE:       B2 status length data[0..length-1] checksum B3
```

checksum 覆盖 `command/status`、offset/length 或 length、以及全部 data。算法是逐
字节相加后取二进制补码，因此覆盖区连同 checksum 的 8 bit 和必须为零。帧头和
`B3` 不参与校验。

| command | offset/length | 成功响应 | 行为 |
|---:|---|---|---|
| `01` READ | `offset + length <= 96` | 指定连续数据 | 不改变控制区 |
| `02` WRITE | `offset + length <= 96` | 空数据 | 原子接收后写入连续数据 |
| `03` SAVE | 固定 `0,0` | 空数据 | 保存 `[4,64)` 到 EEPROM |
| `04` PING | 固定 `0,0` | 1 字节版本 | 返回 `CTRL_PROTOCOL_VERSION` |

WRITE 不允许从偏移 0 或 1 开始，避免覆盖 ID 和版本。STM8 接收缓冲为 72 字节，
协议最大 WRITE 数据为 66 字节；当前 ARM 最大写入是 60 字节持久区。STM8 响应
缓冲为 101 字节，可一次返回完整 96 字节控制区。

response status：`00` 成功、`01` 坏帧/校验、`02` 越界、`03` 未知命令。ARM 每次
事务等待约 100 ms；超时、帧长、帧尾、校验、status 或返回长度任一不符均视为
链路失败。

### 2.3 在线状态

每个合法 UART 请求都会把 STM8 的 ARM 看门狗重装为 1000 个 2 ms tick，约 2 秒。
到期后 STM8 清除 `DPLL_STATUS.ARM_ONLINE` 并置 ERROR。ARM 正常服务约每 50 ms
读取请求和发布一次状态，因此看门狗不应在正常链路上触发。

## 3. STM32 与 STM8 I2C

### 3.1 物理层和寄存器访问

- STM32 是主机，STM8 是从机。
- 代码使用地址字节 `0x4A`，等价 7 bit 地址 `0x25`。
- STM32 时序寄存器当前配置约 381 kHz。
- 读操作先写一个 8 bit 寄存器偏移，再 repeated START 连续读取。
- 普通写操作格式为寄存器偏移后跟连续数据；STM8 只接受 `[4,64)` 持久区写入，
  运行状态、ID、版本和序号不能由普通 I2C 数据写覆盖。

### 3.2 I2C 命令

当第一个写入字节在 `C0--C9` 时，STM8 把它解释为命令而不是寄存器偏移，立即置
`bridge status.bit0 BUSY`，在主循环执行完成后清 BUSY。

| 命令 | 行为 | 是否推进 request sequence |
|---:|---|---:|
| `C0` | 使用当前频率/功率配置并打开 MAX2871 | 否 |
| `C1` | 关闭 MAX2871 | 否 |
| `C2` | 从 EEPROM 重载持久区；版本 3 正常启动不使用 | 否 |
| `C3` | 保存当前 `[4,64)` 到 EEPROM | 否 |
| `C4` | 通知 ARM 持久参数已修改并请求 APPLY | 是 |
| `C5` | 保留 | 否 |
| `C6` | 保留 | 否 |
| `C7` | 设置 DPLL enable 并请求 ARM 处理 | 是 |
| `C8` | 清除 DPLL enable 并请求 ARM 处理 | 是 |
| `C9` | 保留；版本 3 正常启动不使用 | 否 |

STM32 在命令前后轮询 BUSY，最多 5000 次，每次间隔 200 us。命令函数还保留
与具体硬件动作对应的短延时。DPLL 和 MAX2871 enable 不进入 EEPROM，上电默认关闭。

## 4. APPLY 同步

### 4.1 屏幕发起

1. STM32 修改本地 96 字节缓存中的物理参数。
2. STM32 把 `[4,64)` 写入 STM8 RAM。
3. STM32 发送 `C4`；STM8 将 request sequence 加一。
4. ARM 发现新序号，读取候选参数、校验、换算并原子 APPLY FPGA。
5. 成功时 ARM 保留候选参数；失败时恢复提交前持久区和 FPGA active 配置，并把
   旧持久区写回 STM8 RAM。
6. ARM 写入 last error 和运行状态，最后令 response sequence 等于 request
   sequence。STM32 只有读到一致快照后才认为本次请求完成。

`C7/C8` 使用相同序号握手。APPLY 失败不会触发 EEPROM 保存；DPLL 在回滚完成后
恢复提交前配置和 enable 状态，若 ABI/链路导致回滚本身失败则保持关闭并报告错误。

### 4.2 ARM 发布一致快照

ARM 发布状态时先把 response sequence 写成 `final_sequence XOR 0x80`，再写状态和
24 字节运行数据，最后写回 final sequence。STM32 的读取顺序是：

1. 单独读取 response sequence。
2. 读取完整 96 字节控制区。
3. 再次单独读取 response sequence。
4. 仅当前后序号相同、快照内 response sequence 相同、且快照内 request sequence
   也相同时接受快照。

STM32 最多重试 60 次，每次回退 2 ms。读到外部修改后的持久区时取消尚未执行的
延迟 EEPROM 保存，避免旧屏幕定时器覆盖 ARM 或上位机的新配置。

## 5. EEPROM

- EEPROM 持久数据固定为控制区 `[4,64)`，共 60 字节。
- 元数据为 magic `A5`、协议版本 `03`、CRC16 低字节、CRC16 高字节。
- CRC 使用多项式 `0x1021`、初值 `0xFFFF`，覆盖全部 60 字节。
- ID、版本、request/response sequence、enable 和运行状态均不持久化。
- magic、版本或 CRC 任一错误时加载版本 3 默认值并立即重写 EEPROM；不迁移旧版
  EEPROM，也不兼容旧布局。
- 屏幕停止调节约 10 秒后，在再次取得一致快照的前提下发送 `C3`。PC 临时 APPLY
  使用 `0x99`，只有显式 `0x9B` 才保存。

## 6. 启动顺序

STM32 通常先于 ARM 启动。STM32 初始化 I2C 后持续检查 ID `A5`、版本 `03`、一致
快照和 ARM_ONLINE；条件未满足时只显示通信失败，不加载临时 UI 参数，也不主动
复位 FPGA。

ARM 启动后循环 PING STM8 并读取完整控制区，强制清除两个 enable，随后同时复位
DPLL 与精密频率计、重检 FPGA ABI、把 EEPROM 物理参数换算并 APPLY，最后发布
一致状态。STM8 UART 链路断开时 ARM 重试启动；FPGA ABI/APPLY 失败时 ARM 仍发布
在线状态和错误码，但保持 DPLL 关闭。

## 7. 扩展约束

- 新字段优先放在现有保留字节，并同步三份 `control_protocol.h`。
- 不改变已有偏移、单位或符号；不兼容修改必须提升协议版本。
- 控制区超过 96 字节、单次写入超过 66 字节、或需要 STM8 理解新的硬件动作时，
  才要求修改 STM8 固件。
- 新增普通 DPLL 参数不得增加专用 STM8 命令；继续使用连续区间转发和 request/
  response sequence。
