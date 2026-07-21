# 011 ARM配置权威与HDL边界

更新日期：2026-07-21

## 1. 唯一配置入口

ARM是DPLL、精密频率计和DAC1调试配置的唯一校验与调度节点。屏幕、PC和启动默认值都先合并到ARM内存中的完整候选配置，候选通过整体校验后才写FPGA。

ARM候选配置用于API合并、EEPROM和状态同步，不是FPGA Shadow。FPGA中每个参数只保留一份活动寄存器。

```text
复制ARM committed config
  -> 合并本次屏幕或PC修改
  -> ARM校验完整candidate
  -> 比较candidate和committed config
  -> 只写发生变化的FPGA寄存器
  -> 更新ARM committed config和软件签名
```

候选校验失败时不写FPGA。配置写入没有全局APPLY、busy轮询、超时回滚或active副本核对流程。

## 2. 跨时钟写入

DPLL系统总线和125 MHz信号链不直接跨域采样。wrapper使用一套公共写事务邮箱：

1. `sys_clk`域锁存地址和32位数据并翻转request；
2. `clk1`域同步request，在数据稳定后产生一个写脉冲；
3. 活动寄存器在`clk1`域更新；
4. `clk1`域翻转ack，`sys_clk`域收到ack后结束总线事务。

配置读回沿用同类请求/响应快照握手。该结构只保存一组临时地址/数据，不为每个参数复制Shadow/Active寄存器。

## 3. 参数更新行为

| 参数类别 | 生效行为 |
|---|---|
| 中心频率、阈值、dwell、timeout、上下限、manual offset | 直接生效，不重启控制器 |
| DAC0幅度/偏置、MUL/DIV、DAC1调试配置 | 直接生效，不重启DPLL |
| Kf acquire/blend/track、Kp/Ki blend/track | 更新活动系数并清控制器状态，重新捕获；不清CIC/IIR |
| CIC R/shift、FLL delay、IIR模式或系数 | 清检测链和控制器状态，重新捕获 |
| `0x006F` bit0 | 显式控制器重新捕获 |
| `0x006F` bit1 | 显式检测链重配置，同时重新捕获控制器 |

`0x006F`是无状态命令寄存器，读取固定为0，不返回busy或sequence。关闭DPLL和FPGA复位始终可以写入，不受配置事务状态限制。

## 4. ARM校验范围

ARM在写入前负责：

- 中心频率`4--250 kHz`；
- MUL/DIV非零及字段位宽；
- signed 24-bit FLL/PI系数和各阈值位宽；
- CIC R/shift及频点对应的抽取配置；
- Q2.30 IIR系数结构、直流增益和极点稳定性；
- correction limit符号、DAC0 offset/amplitude、dwell、warmup和timeout；
- 快速频率计间隔`10--34359 ms`；
- 精密频率计阈值、限幅、PID增益、门时间和寄存器位宽；
- DAC1 source、format、bit window、shift、gain和offset。

HDL不拒绝、不钳位或替换ARM写入的配置值。寄存器位宽截取属于接口定义，不属于配置策略。

## 5. HDL保留职责

HDL只保留逐拍实时工作：

- DDC、CIC、IIR、CORDIC、FLL/PI、状态机和频率计累加；
- 参数类别对应的局部clear、flush、warmup和重新捕获；
- 位宽缩减、舍入、饱和、限幅、anti-windup和实时故障状态；
- 相位残差、频率残差、输出饱和和数据通路故障的约0.268秒窗口；
- 失锁后自动重新捕获。

这些是实时信号链行为，不是配置合法性判断。

## 6. 频率计配置

精密频率计P/I/I2/D仍由PC完整API配置，增益变化沿用老设计的PID状态清理行为。D滤波系数不再属于公开API，由ARM启动时固定写入`Freq_Meter_Coefd_Filter_Addr`，当前常量为`0x0000FFFF`。后续调整该系数只需修改ARM，不需要重新修改HDL。

快速频率计刷新周期直接写入，从下一计数窗口生效，不影响DPLL或精密频率计测量流程。

## 7. 三端关系

- 屏幕/STM8持久区：ARM合并为候选配置并校验；失败时不写FPGA、不保存错误候选。
- PC `0x99`：使用同一屏幕物理参数候选路径，不写EEPROM。
- PC `0x8F`：修改高级DPLL候选字段，复用同一校验和变化字段写入路径。
- PC `0x90--0x94`、`0x98`：分别修改精密/快速频率计配置。
- PC `0x97`和屏幕`D1:0--8`：修改DAC1调试输出，不触发DPLL重捕获。
- enable、reset和正式频率计trigger是运行命令，不属于配置候选。

## 8. 验证状态

本次架构变更已通过：

- ARM主机MMIO驱动测试；
- wrapper异步时钟写入/读回测试；
- 阈值和DAC1写入不重启测试；
- 增益局部重捕获测试；
- CIC结构参数检测链重配置测试；
- CIC、状态机和单时钟DPLL核心仿真。

尚未在本次变更后执行Vivado综合、实现和板上测试；资源与时序数据必须以用户手动完成的新一轮实现报告为准。
