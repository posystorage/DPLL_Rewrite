# DPLL 宽范围滤波与 FLL 改造实现说明

面向 Codex / 工程实现使用。

本文档描述数字锁相环在 5 kHz 到 200 kHz 输入范围内的推荐信号链、ARM 端配置策略、complex notch 原理、cross-dot FLL 原理、实现注意事项和验证项目。

> 设计目标：在保持 post-IQ 高刷新率的前提下，抑制实信号 IQ 混频产生的二倍镜频，避免单纯依赖 post-CIC 大 R 导致更新速率过低和 unwrap / FLL 丢步。

---

## 1. 背景与问题

当前 post-IQ CIC 只靠改变 R 兼顾抽取和镜频抑制时，会出现明显矛盾：

- 小 R：输出刷新率高，但二倍镜频抑制不足。
- 大 R：CIC 零点可能正好压住二倍镜频，但输出刷新率过低，FLL / PLL 容易在频率波动时失稳。

典型测试点：

| post-CIC R | 输出率 | 43.5 kHz 衰减 | 现象 |
|---:|---:|---:|---|
| 31 | 100.806 kS/s | -8.5 dB | 刷新足够，但镜频漏出明显 |
| 72 | 43.403 kS/s | -159 dB | 镜频压得很好，但刷新率太低 |

结论：

1. R 不应该主要用于“赌 CIC 零点压镜频”。
2. R 应主要按环路刷新率、资源和时序选择。
3. 镜频抑制应由 pre-IIR、post-IIR 和可选 complex notch 承担。
4. FLL 建议从 phase-difference / unwrap 类方法改为 cross-dot 块累加鉴频。

---

## 2. 推荐总链路

```text
ADC 125 MSPS
  │
  ├── 前级 DC blocking / high-pass
  │
  ├── 前级 CIC R=40
  │       输出 3.125 MSPS 实信号
  │
  ├── 粗测频路径
  │       过零 / 周期测量，启动和失锁重捕获时使用
  │
  └── DPLL 主路径
          │
          ├── NCO / DDS
          │
          ├── IQ mixer
          │       I/Q @ 3.125 MSPS
          │
          ├── pre-IIR
          │       抽取前先压二倍镜频和宽带噪声
          │
          ├── optional pre-CIC complex notch
          │       仅在 post alias 太靠近 DC 时启用
          │
          ├── post-IQ CIC
          │       R 按状态 / 频段配置
          │
          ├── post-IIR
          │       进一步限制 FLL / PLL 输入带宽
          │
          ├── optional post-CIC complex notch
          │       锁定后或低中频段优先使用
          │
          ├── cross-dot FLL
          │       粗 FLL / 细 FLL
          │
          └── Type-II PLL
                  PI loop filter + NCO frequency update
```

---

## 3. 频段配置表

假设：

```c
FS_IQ_HZ = 3125000.0;
fu = FS_IQ_HZ / R;
```

pre-IIR 使用 4 级一阶 IIR：

```verilog
y <= y + ((x - y) >>> S);
```

近似单级截止：

```text
fc ≈ FS_IQ / (2*pi*2^S)
```

| shift S | 近似单级 fc | 推荐用途 |
|---:|---:|---|
| 5 | 15.5 kHz | 高频段粗 FLL |
| 6 | 7.8 kHz | 中高频 fine / track |
| 7 | 3.9 kHz | 中低频 track |
| 8 | 1.94 kHz | 低频 acquire / track |
| 9 | 0.97 kHz | 5-8 kHz 稳定跟踪 |

推荐 ARM 查表：

| 输入频率段 | 粗测频周期 M | 粗测频残差目标 | R_acq / fu | R_track / fu | pre-IIR S acq->track | post-IIR fc acq / fine / track | FLL coarse L,N | FLL fine L,N | notch 策略 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 5-8 kHz | 128 | <=500 Hz | 16 / 195.3 kS/s | 32 / 97.7 kS/s | 8 -> 9 | 1.2k / 0.8k / 0.3k | 16,16 | 32,32 | 强制开，优先 post |
| 8-15 kHz | 96 | <=800 Hz | 20 / 156.3 kS/s | 32 / 97.7 kS/s | 7 -> 8 | 2.0k / 1.2k / 0.5k | 16,16 | 32,32 | 强制开 |
| 15-30 kHz | 64 | <=1.5 kHz | 24 / 130.2 kS/s | 31 / 100.8 kS/s | 6 -> 7 | 4.0k / 2.0k / 0.8k | 8,8 | 16,24 | 开 |
| 30-60 kHz | 48 | <=3 kHz | 24 / 130.2 kS/s | 31 / 100.8 kS/s | 5 -> 6 | 8.0k / 3.5k / 1.2k | 4,8 | 8,16 | 条件开 |
| 60-100 kHz | 32 | <=5 kHz | 20 / 156.3 kS/s | 24 / 130.2 kS/s | 5 -> 6 | 12k / 5k / 2k | 4,8 | 8,16 | 条件开 |
| 100-150 kHz | 32 | <=8 kHz | 16 / 195.3 kS/s | 20 / 156.3 kS/s | 5 -> 6 | 15k / 7k / 3k | 4,8 | 8,16 | 条件开 |
| 150-200 kHz | 32 | <=10 kHz | 15 / 208.3 kS/s | 16 / 195.3 kS/s | 5 -> 6 | 18k / 8k / 4k | 4,8 | 8,16 | 优先 pre-notch，post 条件开 |

说明：

- 低频 5-15 kHz：镜频约为 -2*f_nco，离 DC 很近，粗测频必须更准，post-IIR 也必须更窄。
- 中频 15-60 kHz：R=31 / 24 是主力，避免 R=72 这种低刷新率方案长期参与闭环。
- 高频 100-200 kHz：pre-IIR 对镜频更有效；post-CIC 后镜频可能 alias 到低频，post-notch 需要谨慎启用。

---

## 4. ARM 端配置结构

```c
#include <stdint.h>
#include <stdbool.h>
#include <math.h>

#define FS_IQ_HZ 3125000.0
#define PI_D     3.14159265358979323846

typedef enum {
    DPLL_STATE_FLL_COARSE = 0,
    DPLL_STATE_FLL_FINE   = 1,
    DPLL_STATE_PLL_TRACK  = 2
} dpll_state_t;

typedef struct {
    double f_min_hz;
    double f_max_hz;

    uint16_t coarse_cycles;
    double coarse_residual_target_hz;

    uint16_t R_acq;
    uint16_t R_track;

    uint8_t pre_iir_stages;
    uint8_t pre_shift_acq;
    uint8_t pre_shift_track;

    double post_fc_acq_hz;
    double post_fc_fine_hz;
    double post_fc_track_hz;

    uint8_t fll_L_coarse;
    uint8_t fll_N_coarse;
    uint8_t fll_L_fine;
    uint8_t fll_N_fine;

    double enter_fine_hz;
    double enter_pll_hz;
    double pll_bw_hz;

    bool notch_default_enable;
    double notch_r_coarse;
    double notch_r_fine;
    double notch_r_track;
} dpll_band_cfg_t;
```

配置表：

```c
static const dpll_band_cfg_t g_dpll_band_table[] = {
    {5000,   8000,   128,  500, 16, 32, 4, 8, 9,  1200,  800,  300, 16,16, 32,32,  250,  50,   80, true, 0.980, 0.990, 0.996},
    {8000,   15000,   96,  800, 20, 32, 4, 7, 8,  2000, 1200,  500, 16,16, 32,32,  400,  80,  120, true, 0.980, 0.990, 0.996},
    {15000,  30000,   64, 1500, 24, 31, 4, 6, 7,  4000, 2000,  800,  8, 8, 16,24,  800, 120,  200, true, 0.980, 0.990, 0.995},
    {30000,  60000,   48, 3000, 24, 31, 4, 5, 6,  8000, 3500, 1200,  4, 8,  8,16, 1500, 200,  400, true, 0.975, 0.988, 0.994},
    {60000, 100000,   32, 5000, 20, 24, 4, 5, 6, 12000, 5000, 2000,  4, 8,  8,16, 2500, 300,  700, true, 0.975, 0.988, 0.994},
    {100000,150000,   32, 8000, 16, 20, 4, 5, 6, 15000, 7000, 3000,  4, 8,  8,16, 4000, 500, 1000, true, 0.970, 0.985, 0.992},
    {150000,200000,   32,10000, 15, 16, 4, 5, 6, 18000, 8000, 4000,  4, 8,  8,16, 5000, 700, 1500, true, 0.970, 0.985, 0.992},
};
```

---

## 5. 辅助函数

```c
static double post_cic_fs_hz(uint16_t R)
{
    return FS_IQ_HZ / (double)R;
}

static double wrap_to_nyquist(double f_hz, double fs_hz)
{
    while (f_hz >= 0.5 * fs_hz) {
        f_hz -= fs_hz;
    }
    while (f_hz < -0.5 * fs_hz) {
        f_hz += fs_hz;
    }
    return f_hz;
}

static uint8_t cic_output_shift_3stage(uint16_t R)
{
    double gain_log2 = 3.0 * log2((double)R);
    int shift = (int)(gain_log2 + 0.5);

    if (shift < 0) {
        shift = 0;
    }
    if (shift > 31) {
        shift = 31;
    }
    return (uint8_t)shift;
}

static const dpll_band_cfg_t *select_band_cfg(double f_hz)
{
    int n = (int)(sizeof(g_dpll_band_table) / sizeof(g_dpll_band_table[0]));

    for (int i = 0; i < n; ++i) {
        if (f_hz >= g_dpll_band_table[i].f_min_hz &&
            f_hz <  g_dpll_band_table[i].f_max_hz) {
            return &g_dpll_band_table[i];
        }
    }

    if (f_hz < g_dpll_band_table[0].f_min_hz) {
        return &g_dpll_band_table[0];
    }

    return &g_dpll_band_table[n - 1];
}
```

---

## 6. Complex Notch 原理

### 6.1 它解决什么问题

实信号做 IQ 混频后，除了想要的差频分量，还会出现一个镜频分量。

若 NCO 已接近输入频率：

```text
目标分量 ≈ 输入频率 - NCO频率 ≈ 0 Hz
镜频分量 ≈ -(输入频率 + NCO频率) ≈ -2*NCO频率
```

普通低通可以压镜频，但低频段时镜频离 DC 很近，例如输入 5 kHz 时镜频约 -10 kHz。低通如果开得很窄，会增加延迟；开得太宽，镜频漏进 FLL / PLL。工程的痛苦又来了，像是滤波器也参加了需求评审。

complex notch 的作用是：只在复平面的某一个频率点附近挖一个很窄的坑，把镜频打掉，尽量不伤 DC 附近的目标信号。

### 6.2 数学形式

```text
H(z) = (1 - z0*z^-1) / (1 - r*z0*z^-1)

z0 = exp(j*2*pi*f_notch/fs)
```

其中：

- `f_notch`：要挖掉的复频率。
- `fs`：notch 所在位置的采样率。
- `r`：极点半径，越接近 1，notch 越窄，恢复越慢，对系数量化更敏感。

时域形式：

```text
y[n] = x[n] - z0*x[n-1] + r*z0*y[n-1]
```

因为 x、y、z0 都是复数，所以实现时是 I/Q 两路交叉运算。

### 6.3 固定点实现展开

令：

```text
z0 = c + j*s
x = xi + j*xq
y = yi + j*yq
```

先算：

```text
z0*x_prev:
  zx_i = c*xi_prev - s*xq_prev
  zx_q = s*xi_prev + c*xq_prev

r*z0*y_prev:
  zy_i = r*(c*yi_prev - s*yq_prev)
  zy_q = r*(s*yi_prev + c*yq_prev)
```

再算：

```text
yi = xi - zx_i + zy_i
yq = xq - zx_q + zy_q
```

### 6.4 notch 频率计算

抽取前：

```text
f_img_pre = -(2*f_nco + f_residual_est)
```

抽取后要考虑 alias：

```text
f_img_post = wrap_to_nyquist(f_img_pre, fu)
```

启用规则：

```c
if (fabs(f_img_post) > guard_hz && fabs(f_img_post) < 0.45 * fu) {
    use_post_notch = true;
} else if (fabs(f_img_pre) < 0.45 * FS_IQ_HZ) {
    use_pre_notch = true;
} else {
    notch_disable = true;
}
```

建议：

```text
guard_hz = max(3*post_iir_fc, 1500 Hz)
```

注意：post-notch 太靠近 DC 时不能开，否则它会把目标基带也一起切掉。滤波器没有道德感，它只认识频率。

### 6.5 notch 半径推荐

| 状态 | r | 说明 |
|---|---:|---|
| FLL coarse | 0.970-0.985 | 宽一点，容忍粗测频误差 |
| FLL fine | 0.985-0.992 | 中等 |
| PLL track | 0.992-0.997 | 窄一点，减少对目标相位影响 |

---

## 7. Cross-dot FLL 原理

### 7.1 它解决什么问题

原来的 phase-difference FLL 需要先得到相位，再做差分。若相位被镜频、噪声和 unwrap 错误污染，后面算得再认真也只是认真地算错。

cross-dot FLL 不直接依赖相位展开，而是比较当前复向量和 L 个样点前的复向量转了多少角度。

想象 IQ 点是复平面上的箭头：

- 若信号频率刚好被 NCO 抵消，箭头基本不转。
- 若残余频率为正，箭头每个采样点向一个方向慢慢转。
- 若残余频率为负，箭头反方向转。

cross-dot 就是在问：当前箭头相对过去箭头转了多少？

### 7.2 公式

定义：

```text
z[k] = I[k] + j*Q[k]
```

延迟共轭乘积：

```text
C[k] = z[k] * conj(z[k-L])
```

如果做块累加：

```text
Csum = sum(z[k] * conj(z[k-L]))
```

展开成 dot / cross：

```text
dot   = sum(I[k]*I[k-L] + Q[k]*Q[k-L])
cross = sum(Q[k]*I[k-L] - I[k]*Q[k-L])
```

频率误差：

```text
angle = atan2(cross, dot)
freq_error_hz = angle * fu / (2*pi*L)
```

无模糊范围：

```text
|freq_error_hz| < fu / (2*L)
```

### 7.3 为什么要块累加

逐点 cross-dot 会很抖。块累加相当于把多个箭头比较结果平均一下：

```text
N = 4, 8, 16, 32
```

优点：

1. 降低噪声。
2. 减少 atan2 / CORDIC 调用率。
3. 降低资源和时序压力。
4. 减少单点异常对 FLL 的影响。

代价：

1. 增加一点延迟。
2. 块太长时动态响应变慢。
3. 若频率误差过大导致跨块相位旋转太多，结果会变差。

### 7.4 L 怎么选

L 越小：

- 无模糊范围越大。
- 灵敏度较低。
- 适合粗 FLL。

L 越大：

- 小频差的角度累积更明显，灵敏度更高。
- 无模糊范围变小。
- 适合细 FLL。

推荐：

| 阶段 | L | N | 用途 |
|---|---:|---:|---|
| FLL coarse 高频段 | 4 | 8 | 快速拉入 |
| FLL coarse 低频段 | 8-16 | 16 | 防止低频镜频污染，残差目标更小 |
| FLL fine | 8-32 | 16-32 | 提高小残差估计精度 |
| PLL track | 可关闭 FLL 或低速残差估计 | 32+ | 只用于频率显示 / 慢校正 |

---

## 8. 运行时配置生成

```c
typedef struct {
    bool use_post_notch;
    bool use_pre_notch;
    double post_notch_hz;
    double pre_notch_hz;
    double radius;
} notch_cfg_t;

typedef struct {
    uint16_t R;
    double fu_hz;

    uint8_t cic_shift;

    uint8_t pre_iir_stages;
    uint8_t pre_iir_shift;

    double post_iir_fc_hz;
    uint8_t post_iir_sections;

    uint8_t fll_L;
    uint8_t fll_N;
    double fll_unambiguous_hz;
    double fll_enter_next_hz;

    double pll_bw_hz;
    notch_cfg_t notch;
} dpll_runtime_cfg_t;
```

notch 配置：

```c
static notch_cfg_t make_notch_cfg(double f_nco_hz,
                                  double residual_est_hz,
                                  double fu_hz,
                                  double post_iir_fc_hz,
                                  double radius,
                                  bool notch_default_enable)
{
    notch_cfg_t out = {0};

    if (!notch_default_enable) {
        return out;
    }

    double f_img_pre = -(2.0 * f_nco_hz + residual_est_hz);
    double f_img_post = wrap_to_nyquist(f_img_pre, fu_hz);

    double guard_hz = 3.0 * post_iir_fc_hz;
    if (guard_hz < 1500.0) {
        guard_hz = 1500.0;
    }

    if (fabs(f_img_post) > guard_hz && fabs(f_img_post) < 0.45 * fu_hz) {
        out.use_post_notch = true;
        out.post_notch_hz = f_img_post;
        out.radius = radius;
        return out;
    }

    if (fabs(f_img_pre) < 0.45 * FS_IQ_HZ) {
        out.use_pre_notch = true;
        out.pre_notch_hz = f_img_pre;
        out.radius = radius;
        return out;
    }

    return out;
}
```

运行配置：

```c
static dpll_runtime_cfg_t make_runtime_cfg(const dpll_band_cfg_t *band,
                                           dpll_state_t state,
                                           double f_nco_hz,
                                           double residual_est_hz)
{
    dpll_runtime_cfg_t cfg = {0};
    double radius = 0.990;

    if (state == DPLL_STATE_FLL_COARSE) {
        cfg.R = band->R_acq;
        cfg.pre_iir_shift = band->pre_shift_acq;
        cfg.post_iir_fc_hz = band->post_fc_acq_hz;
        cfg.post_iir_sections = 1;
        cfg.fll_L = band->fll_L_coarse;
        cfg.fll_N = band->fll_N_coarse;
        cfg.fll_enter_next_hz = band->enter_fine_hz;
        radius = band->notch_r_coarse;
    } else if (state == DPLL_STATE_FLL_FINE) {
        cfg.R = band->R_track;
        cfg.pre_iir_shift = band->pre_shift_track;
        cfg.post_iir_fc_hz = band->post_fc_fine_hz;
        cfg.post_iir_sections = 2;
        cfg.fll_L = band->fll_L_fine;
        cfg.fll_N = band->fll_N_fine;
        cfg.fll_enter_next_hz = band->enter_pll_hz;
        radius = band->notch_r_fine;
    } else {
        cfg.R = band->R_track;
        cfg.pre_iir_shift = band->pre_shift_track;
        cfg.post_iir_fc_hz = band->post_fc_track_hz;
        cfg.post_iir_sections = 2;
        cfg.fll_L = band->fll_L_fine;
        cfg.fll_N = band->fll_N_fine;
        cfg.pll_bw_hz = band->pll_bw_hz;
        radius = band->notch_r_track;
    }

    cfg.fu_hz = post_cic_fs_hz(cfg.R);
    cfg.cic_shift = cic_output_shift_3stage(cfg.R);
    cfg.pre_iir_stages = band->pre_iir_stages;
    cfg.fll_unambiguous_hz = cfg.fu_hz / (2.0 * (double)cfg.fll_L);

    cfg.notch = make_notch_cfg(
        f_nco_hz,
        residual_est_hz,
        cfg.fu_hz,
        cfg.post_iir_fc_hz,
        radius,
        band->notch_default_enable
    );

    return cfg;
}
```

---

## 9. FPGA 模块实现建议

### 9.1 pre_iir_stage

功能：

- 输入：IQ mixer 后的 I/Q，3.125 MSPS valid。
- 输出：预滤波后的 I/Q。
- 配置：`stage_count`、`shift_s`、`flush`。

推荐结构：

```verilog
// signed fixed-point, per I/Q channel
err = x - y;
y_next = y + (err >>> shift_s);
```

注意：

- 每一级都要保留足够 guard bits。
- flush 后 y 清零或装载当前输入，二者要统一定义。
- 切换 shift_s 时必须冻结环路并清滤波器历史。

### 9.2 complex_notch_stage

功能：

- 支持 pre-CIC notch 或 post-CIC notch。
- 输入输出均为复数 I/Q。
- 配置：`coef_c`、`coef_s`、`coef_rc`、`coef_rs`、`enable`、`flush`。

系数：

```text
c  = cos(2*pi*f_notch/fs)
s  = sin(2*pi*f_notch/fs)
rc = r*c
rs = r*s
```

差分方程：

```text
y[n] = x[n] - z0*x[n-1] + r*z0*y[n-1]
```

### 9.3 post_iir_stage

功能：

- post-CIC 后限制 FLL / PLL 输入带宽。
- 可先实现 1-2 级 biquad，也可以先用一阶级联验证。

建议：

- FLL coarse 用 1 section。
- FLL fine / PLL track 用 2 sections。
- 系数由 ARM 计算，FPGA 只加载定点系数。

### 9.4 fll_cross_dot_stage

输入：

- `i_in`, `q_in`, `valid_in`
- `delay_L`
- `block_N`
- `flush`

输出：

- `dot_sum`
- `cross_sum`
- `angle_valid` 或 `freq_error_valid`

核心：

```verilog
// conceptual only
I_d = delay_line_I[L];
Q_d = delay_line_Q[L];

dot_sample   = I*I_d + Q*Q_d;
cross_sample = Q*I_d - I*Q_d;

dot_acc   += dot_sample;
cross_acc += cross_sample;

if (block_count == block_N-1) begin
    dot_out   <= dot_acc;
    cross_out <= cross_acc;
    valid_out <= 1'b1;
    dot_acc   <= 0;
    cross_acc <= 0;
end
```

注意：

- 乘法输出位宽要足够。
- dot/cross 累加要考虑 `N` 的位宽增长。
- dot 接近 0 且能量低时，不要相信 atan2 输出。
- 可以共享 CORDIC：FLL 用 cross/dot atan2，PLL 用 Q/I atan2。

---

## 10. 状态机切换建议

```text
RESET
  -> WAIT_SIGNAL
  -> COARSE_FREQ_MEASURE
  -> FLL_COARSE
  -> FLL_FINE
  -> PLL_TRACK
  -> REACQUIRE if unlock
```

进入 FLL_COARSE：

1. 粗测频有效。
2. NCO 设置到粗测频频率。
3. 选择频段配置。
4. flush pre-IIR / CIC / post-IIR / notch / FLL history。

FLL_COARSE -> FLL_FINE：

```text
abs(fll_residual) < enter_fine_hz
连续满足 8 次以上
IQ power 有效
loop control 未饱和
```

FLL_FINE -> PLL_TRACK：

```text
abs(fll_residual) < enter_pll_hz
phase_var < PHASE_VAR_PLL_ENTRY_MAX
连续满足 16 次以上
```

失锁：

```text
IQ power 太低
phase_var 太大
FLL residual 连续超限
NCO 超出合法范围
loop integrator 饱和
```

失锁处理：

1. freeze loop。
2. 清 PLL 积分器或进入 holdover。
3. 关闭旧输出更新。
4. 重新粗测频。
5. 清所有 IQ 滤波器和 FLL 历史。
6. 重新进入 FLL_COARSE。

---

## 11. 注意事项清单

### 11.1 pre-IIR

- 低频段 shift 太大时，响应慢，切换后要给足 settle 时间。
- 不要在闭环运行中无冻结地切换 shift。
- 级联一阶 IIR 的相位延迟会进入环路总延迟预算。

### 11.2 post-CIC

- R 切换后必须 flush CIC。
- CIC gain = R^N，3 级时约为 R^3，输出 shift 必须随 R 调整。
- 不要只靠 R 的零点压镜频。
- R 越大，环路更新越慢，FLL / PLL 的动态能力越差。

### 11.3 complex notch

- post-notch 必须按抽取后的 alias 频率配置。
- notch 太靠近 DC 时必须关闭或改用 pre-notch。
- r 越接近 1，notch 越窄，但定点系数越敏感，settle 越慢。
- notch 系数更新不要太频繁。PLL_TRACK 下建议 50-100 ms 更新一次，且频率变化超过阈值再更新。
- 更新 notch 系数时建议冻结或平滑切换，否则会产生相位突变。

### 11.4 cross-dot FLL

- L 的无模糊范围必须大于当前阶段可能残差。
- N 太小噪声大，N 太大响应慢。
- dot/cross 要做能量门限，低能量时不要更新 FLL。
- cross-dot 仍会被强镜频污染，所以它不能替代滤波器。
- atan2 输出要正确处理符号、象限和定点缩放。

### 11.5 PLL

- PLL_TRACK 不要追求过大带宽。
- 输入频率总范围不等于 PLL 带宽。
- 精密频率显示应使用低速残差估计，不要为了显示分辨率拖慢主环路。

---

## 12. 验证项目

### 12.1 单点频率验证

测试点：

```text
5 kHz, 8 kHz, 10 kHz, 20 kHz, 43.5 kHz, 60 kHz,
100 kHz, 150 kHz, 180 kHz, 200 kHz
```

每个点记录：

- 粗测频误差。
- FLL_COARSE 收敛时间。
- FLL_FINE 收敛时间。
- PLL_TRACK 相位误差 RMS。
- NCO 频率稳定性。
- post-IIR / notch 前后镜频残留。

### 12.2 扰动验证

- 输入频率缓慢漂移：分钟级 +/-10%。
- 小阶跃：目标频率的 0.1%、0.5%、1%。
- 大阶跃：允许失锁，然后验证重捕获。
- 幅度变化：-20 dB 到 0 dB 相对范围。
- 加噪声：验证低能量门限和 false lock。

### 12.3 频谱检查

需要观察这些节点的频谱：

```text
IQ mixer output
pre-IIR output
post-CIC output
post-IIR output
notch output
FLL residual
PLL phase error
```

重点看：

- 二倍镜频是否被 pre-IIR / post-IIR / notch 压掉。
- notch 是否误伤 DC 附近目标。
- CIC 抽取后镜频是否 alias 到低频。
- FLL residual 是否有二倍频纹波。

---

## 13. Codex 实现任务建议

建议让 Codex 按以下顺序改：

1. 新增 `pre_iir_stage_a.v`：4 级一阶 IIR，支持 I/Q、valid、flush、shift 配置。
2. 新增 `complex_notch_stage_a.v`：复数一阶 notch，支持 pre/post 复用。
3. 新增 `post_iir_stage_a.v`：先实现一阶级联或 biquad wrapper，系数 ARM 配置。
4. 新增 `fll_cross_dot_stage_a.v`：delay line + dot/cross + block accumulator。
5. 将 FLL 鉴频从 phase difference 切到 cross-dot 输出。
6. 扩展 ARM 配置表，按频率段写入 R、IIR、notch、L、N、PLL 带宽。
7. 状态切换时增加 freeze、flush、settle 流程。
8. 增加仿真：单音、镜频、频率阶跃、低 SNR、R 切换。

---

## 14. 最小可行实现

如果要先做 MVP：

1. 保持 post-CIC R=31 或 32。
2. 加 post-IIR 两级低通。
3. 加 cross-dot FLL。
4. 再加 post complex notch。
5. 最后补 pre-IIR / pre-notch 支持宽频段。

但是，若目标确实覆盖 5-200 kHz，pre-IIR 最终必须加入。否则高频段抽取前镜频可能 alias 到低频，后级再滤波已经晚了。工程里最常见的悲剧就是“我后面再滤”，然后后面发现它已经混进来了，像需求变更一样赶不走。

---

## 15. 当前实施分阶段

### 15.1 第一阶段：最快验证

目标：针对 20 kHz 附近、43.5 kHz 二倍镜频/纹波问题，先不改变主闭环结构，只在 post-IQ CIC 后增加可旁路的两级二阶 IIR 低通，快速观察频谱和闭环残差是否改善。

实施范围：

1. 保持 `post_iq_cic` 的推荐验证点为 `R=31`，R 暂时不再为了镜频零点调大。
2. 在 `post_iq_cic_stage_a` 输出与 CORDIC/FLL 输入之间插入 `post_iir_stage_a`。
3. `post_iir_stage_a` 使用两个二阶 IIR section 串联；第一版采用同一组 biquad 系数重复两级，后续可扩展为每级独立系数。
4. FPGA 侧提供旁路、强制 acquire 系数、强制 track 系数、按状态自动选择系数四种模式。
5. `FLL_ACQUIRE / REACQUIRE / WARMUP` 优先使用 acquire 系数，默认截止频率约 12-15 kHz。
6. `FLL_FINE / PLL_TRACK` 对应现有 `FLL_PLL_BLEND / PLL_TRACK`，优先使用 track 系数，默认截止频率约 5-10 kHz。
7. 现有 `fll_phase_difference_stage_a`、`loop_state_manager_stage_a`、`hybrid_fll_pll_filter_stage_a` 接口保持不变，避免第一阶段同时引入 cross-dot 风险。

第一阶段观测项：

1. `phase_error` 频谱中 43.5 kHz 分量是否下降。
2. `freq_error` 是否仍被 2f ripple 明显拉扯。
3. `iq_valid / freq_error_valid / tracking_valid` 是否保持现有节拍关系。
4. post-IIR 旁路与启用的 A/B 对比。

### 15.2 第二阶段：宽范围修正

目标：在 3.125 MSPS IQ 后、post-CIC 前加入 pre-IIR，让抽取前镜频先被压低，避免高频段镜频 alias 到低频后再处理已经太晚。

实施范围：

1. 在 mixer 输出与 post-IQ CIC 输入之间加入 `pre_iir_stage_a`。
2. 可使用 3-4 级一阶 IIR，或按资源/相位延迟评估换成 1-2 个 biquad。
3. pre-IIR 系数或 shift 随频段和状态切换。
4. 状态切换时执行 freeze / flush / settle。
5. R 主要按环路更新率选，不再按镜频压制效果选。

### 15.3 第三阶段：FLL 改 cross-dot

目标：新增 `fll_cross_dot_stage_a`，让 FLL 直接从滤波后的 I/Q 估计残余频率，而不是依赖已经 unwrap 的相位差。

实施范围：

1. `fll_cross_dot_stage_a` 输入为滤波后的 I/Q 和 `valid`。
2. 支持 `L=1/2/4/8/16`。
3. 支持块累加长度 `N=4/8/16/32`。
4. 输出 `freq_error_valid` 和 `freq_error`，接入现有 `hybrid_fll_pll_filter_stage_a`。
5. 保留能量门限和 ambiguous/usable 语义，避免低能量或模糊估计进入 hybrid loop。
