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

- 固定 `1 Mbps, 8N1`，无流控。ARM UART1 输入时钟为 100 MHz，使用
  `BRGR=20`、`BAUDDIV=4` 得到精确 `1000000`。当前 Xilinx 2018.3 驱动 API
  把最大波特率限制为 `921600`，因此 ARM 在完成 8N1 格式初始化后直接设置这两个
  硬件分频寄存器，不修改生成的 BSP。
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

ARM 将一次 UART 事务的超时、短帧、帧头/帧尾、长度、checksum、status 或响应长度
异常统一视为一次链路失败。首次失败后最多再发送 3 次相同事务，全部失败才发布
`CTRL_ERROR_PROTOCOL`。发布后的 `last error` 保持约 3000 个 ARM 主循环；期间任何
新错误都会重新开始保持计数，没有新错误时自动清零。该计时只用于人机提示，不要求
精确定时，也不改变失败后的 DPLL 安全关闭状态。

ARM UART 的接收超时中断只用于取出 RX FIFO 中的数据，不再直接代表一帧结束。只有已接收
字节数达到响应头 `length + 5` 声明的完整帧长时才进入帧校验，允许 STM8 在发送长响应期间
被 LCD 的 I2C 中断短暂抢占，避免把合法响应中的字节间隙误判成短帧。
每次发送新请求前，ARM 只清除软件接收计数与完成标志，不在事务间复位或轮询排空硬件
RX FIFO。正常响应必须由完整帧长度判定收齐；异常事务由约 100 ms 总超时和三次重试退出，
避免额外的 FIFO 清理流程成为新的阻塞点。

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
  以及偏移 71 的单字节 DAC1 快捷预设或精密频率计复位请求。运行状态、ID、版本
  和序号不能由普通 I2C 数据写覆盖。

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
2. STM32 把 `[4,64)` 写入 STM8 RAM，随后立即回读并逐字节比较全部 60 字节；
   不一致时最多重试 3 次。
3. 只有回读完全一致时 STM32 才发送一次 `C4`；校验失败则放弃本次提交，request
   sequence 不变。STM32 还会读取 `C4` 前后的 request sequence，确认它恰好加一；
   回读失败时不盲目重发 `C4`，防止同一请求被重复计数。
4. `C4` 是持久区事务的提交标记。STM8 收到后将 request sequence 加一；ARM 在序号
   不变时忽略 STM8 RAM 中尚未提交的 `[4,64)`，避免轮询污染回滚基线。
5. ARM 发现新序号后才复制候选参数、校验、换算并原子 APPLY FPGA。
6. 成功时 ARM 保留候选参数；失败时恢复提交前持久区和 FPGA active 配置，并把
   旧持久区写回 STM8 RAM。
7. ARM 写入 last error 和运行状态，最后令 response sequence 等于 request
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

正常周期刷新只执行一次上述快照读取；失败后立即返回主循环，由后续刷新继续轮询，
不在一次界面刷新内连续重试。只有用户显式 APPLY 后的确认阶段最多重试 60 次，
每次回退 2 ms。读到外部修改后的持久区时取消尚未执行的延迟 EEPROM 保存，避免
旧屏幕定时器覆盖 ARM 或上位机的新配置。

### 4.3 DAC1 live 快捷设置

STM32 修改 `D1:0..8` 时只把偏移 71 写入 STM8 RAM 并立即回读校验，不发送 `C4`，
也不启动 EEPROM 延迟保存。ARM 的约 50 ms 轮询覆盖到偏移 71；检测到预设变化后
只写 FPGA debug DAC 的 offset、gain、format、source 四个 live 寄存器。完整 PC
手动配置把偏移 71 写为 `FF`，供屏幕显示 `D1:-`，且 ARM 不再用快捷表覆盖它。

### 4.4 精密频率计复位请求

第一页长按编码器按键时，STM32 把保留值 `FE` 写入偏移 71 并立即回读校验。该
操作不发送 `C4` 或保留命令 `C6`，因此不要求修改 STM8 固件。ARM 每约 50 ms
读取偏移 71；检测到 `FE` 后执行与 PC `0x96` 相同的精密频率计复位序列，并把
偏移 71 恢复为请求前的 D1 预设值。ARM 启动时会先写入默认 D1 预设，不重放启动
前遗留的 `FE`。该操作不改变 DPLL enable、参数、active CRC 或 EEPROM。

## 5. EEPROM

- EEPROM 持久数据固定为控制区 `[4,64)`，共 60 字节。
- 偏移 71 的 DAC1 预设不进入 EEPROM；保存、加载和 CRC 均不覆盖它。
- 元数据为 magic `A5`、协议版本 `03`、CRC16 低字节、CRC16 高字节。
- CRC 使用多项式 `0x1021`、初值 `0xFFFF`，覆盖全部 60 字节。
- ID、版本、request/response sequence、enable 和运行状态均不持久化。
- magic、版本或 CRC 任一错误时加载版本 3 默认值并立即重写 EEPROM；不迁移旧版
  EEPROM，也不兼容旧布局。
- EEPROM 校验异常在本次 STM8 运行期间锁存到 `bridge status.bit1`；重写后的数据在
  下次正常启动校验通过时清除该标志。
- 屏幕停止调节约 10 秒后，在再次取得一致快照的前提下发送 `C3`。PC 临时 APPLY
  使用 `0x99`，只有显式 `0x9B` 才保存。
- STM8 离线、ARM 离线、协议版本异常或 EEPROM 校验异常时，屏幕不提交 EEPROM
  保存；不保留离线期间的“待确认保存”任务。

## 6. 启动顺序

STM32 通常先于 ARM 启动。STM32 初始化 I2C 后尝试读取一次状态，Logo 结束后直接
进入正常第一页；主循环周期性执行一次后台状态读取，不等待 ARM 启动，也不进入
独立错误页面。第一页状态区使用同一 timeout 图标的不同颜色表示 STM8/I2C 离线
（红色）和 ARM 离线（棕红色），使用同一 error 图标的不同颜色表示协议版本异常
（品红色）和 EEPROM 校验异常（印度红）；第二页不显示这些通讯图标。链路恢复后
第一页自动恢复锁定、残差、限幅和 loop_state 状态显示。

ARM 启动后循环 PING STM8 并读取完整控制区，强制清除两个 enable，随后同时复位
DPLL 与精密频率计、重检 FPGA ABI、把 EEPROM 物理参数换算并 APPLY，最后发布
一致状态。ARM 还会把非持久 DAC1 预设强制初始化为 `D1:1`，采用 format
`0x0000` 的校正量 raw 低位观察窗口；PC `0x8E` 复位后执行相同初始化。STM8 UART 链路断开时 ARM 重试
启动；FPGA ABI/APPLY 失败时 ARM 仍发布
在线状态和错误码，但保持 DPLL 关闭。

运行时控制区明确区分两路频率：偏移 80 是 DPLL 跟踪相位字对应的实时频率，
单位 `1 mHz/LSB`，不包含 MUL/DIV；偏移 84 是快速频率计参考结果，单位
`1 Hz/LSB`。偏移 88 的 bits30:0 保存快速结果序号，bit31 单独表示精密频率计
稳定锁定。STM8 只转发这 12 字节，不参与换算。

STM32切换到第二页后继续执行后台状态轮询和ADC计算，但停止绘制第一页的微波源锁定
图标与VBIAS。切回第一页时先清除上方32行，再重绘微波源区域，避免第二页增益数值
残留在`GHz`两侧。

STM32 I2C 主机在等待标志超时或检测到 `TIMEOUT/OVR/ARLO/BERR` 时执行有界总线恢复：关闭
I2C 外设、释放 SDA/SCL；若 SDA 仍为低，最多输出 9 个 SCL 脉冲，随后产生 STOP 并重新初始化
I2C。正常地址 NACK 只结束当前事务，不触发时钟恢复。

## 7. 扩展约束

- 新字段优先放在现有保留字节，并同步三份 `control_protocol.h`。
- 不改变已有偏移、单位或符号；不兼容修改必须提升协议版本。
- 控制区超过 96 字节、单次写入超过 66 字节、或需要 STM8 理解新的硬件动作时，
  才要求修改 STM8 固件。
- 新增普通 DPLL 参数不得增加专用 STM8 命令；继续使用连续区间转发和 request/
  response sequence。
