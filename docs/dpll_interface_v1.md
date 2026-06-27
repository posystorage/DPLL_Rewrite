# DPLL Interface v1 Freeze

Date: 2026-06-27

Status: frozen draft v1 for subagent work. Any public interface change requires an RFC in `docs/interface-change-RFC-NNN.md`.

## Top-Level Policy

The refactored DPLL core has one physical clock:

```text
clk_125m
rst_125m
```

All lower sample rates are represented as single-cycle `valid` pulses. The refactored core must not expose or internally use:

```text
clk_dpll
3.125 MHz generated clock
post-CIC generated clock
loop update generated clock
```

## Stream Contract

Single data stream:

```vhdl
data  : signed(DATA_W-1 downto 0);
valid : std_logic;
```

I/Q stream:

```vhdl
i     : signed(IQ_W-1 downto 0);
q     : signed(IQ_W-1 downto 0);
valid : std_logic;
```

Rules:

- `valid='1'` means a new sample is present during that `clk_125m` cycle.
- State updates only happen when the corresponding input valid is high.
- `valid` must be delayed by the same fixed latency as its data.
- `valid='0'` data may hold old or meaningless values but must not update state.
- Fixed-latency modules must document latency in 125 MHz clock cycles.
- Counters for lock, dwell, warmup, and timeout count valid samples unless explicitly marked as 125 MHz cycles.

## DPLL Channel v1

```vhdl
entity dpll_channel is
    port (
        clk_125m            : in  std_logic;
        rst_125m            : in  std_logic;

        sample_in           : in  signed(ADC_DECIM_W-1 downto 0);
        sample_in_valid     : in  std_logic;

        cfg                 : in  t_dpll_config;
        cfg_apply           : in  std_logic;
        cfg_version         : in  unsigned(15 downto 0);

        tracking_word       : out unsigned(47 downto 0);
        tracking_word_valid : out std_logic;

        output_word         : out unsigned(47 downto 0);
        output_word_valid   : out std_logic;

        state               : out t_loop_state;
        signal_present      : out std_logic;
        frequency_locked    : out std_logic;
        phase_locked        : out std_logic;
        locked              : out std_logic;

        debug_bus           : out t_dpll_debug
    );
end entity;
```

## Configuration Apply Contract

Configuration sources are split into:

- immediate control: reset and enable.
- live debug: DACout1 source/format/gain/offset.
- shadow configuration: center word, gains, limits, thresholds, CIC R/scale, FLL config, dwell, output MUL/DIV.
- active configuration: complete coherent snapshot used by the algorithm.

Apply sequence:

```text
ARM writes shadow registers
ARM writes CONFIG_APPLY
validate complete snapshot
active config updates atomically
flush post-IQ CIC and phase/FLL history if needed
enter WARMUP
enter FLL_ACQUIRE
```

`cic_rate` must not change active behavior until the apply sequence succeeds.

## Module Interfaces

### `adc_decimator_wrapper`

Wraps the existing front /40 CIC or its replacement.

```vhdl
sample_out       : out signed(ADC_DECIM_W-1 downto 0);
sample_out_valid : out std_logic;
```

The output valid pulse represents the 3.125 MSPS stream.

### `tracking_phase_accumulator`

Inputs:

```vhdl
tracking_word : unsigned(47 downto 0);
```

Behavior:

- Accumulates every `clk_125m` cycle.
- Frequency word unit is cycles per 125 MHz sample: `round(f / 125e6 * 2^48)`.
- Does not clear phase during mode changes unless reset/configure explicitly requires it.

### `iq_mixer`

```vhdl
sample_in       : in signed(ADC_DECIM_W-1 downto 0);
sample_in_valid : in std_logic;
cos_in          : in signed(SINCOS_W-1 downto 0);
sin_in          : in signed(SINCOS_W-1 downto 0);
out_i           : out signed(MIXER_OUT_W-1 downto 0);
out_q           : out signed(MIXER_OUT_W-1 downto 0);
out_valid       : out std_logic;
```

Sign convention v1:

```text
I = x * cos
Q = x * (-sin)
```

### `iq_cic_decimator`

```vhdl
entity iq_cic_decimator is
    generic (
        G_IN_W       : positive := 18;
        G_INTERNAL_W : positive := 44;
        G_OUT_W      : positive := 20;
        G_STAGES     : positive := 3
    );
    port (
        clk_125m      : in  std_logic;
        rst_125m      : in  std_logic;
        flush         : in  std_logic;
        rate_r        : in  unsigned(R_W-1 downto 0);
        output_shift  : in  unsigned(SHIFT_W-1 downto 0);
        in_i          : in  signed(G_IN_W-1 downto 0);
        in_q          : in  signed(G_IN_W-1 downto 0);
        in_valid      : in  std_logic;
        out_i         : out signed(G_OUT_W-1 downto 0);
        out_q         : out signed(G_OUT_W-1 downto 0);
        out_valid     : out std_logic;
        overflow_seen : out std_logic
    );
end entity;
```

Constraints:

- I/Q share one decimation phase.
- `rate_r` and `output_shift` are active snapshot fields.
- `rate_r` legal range is initially `8..312`.
- `flush` clears integrators, comb delays, and decimation phase.

### `cordic_phase_detector`

```vhdl
phase     : out signed(PHASE_W-1 downto 0);
magnitude : out unsigned(MAG_W-1 downto 0);
out_valid : out std_logic;
```

Phase convention:

- One turn is `2^PHASE_W`.
- Signed wrap range is `[-0.5 turn, +0.5 turn)`.

### `fll_phase_difference`

Supports `M = 1, 2, 4, 8` selected by `delay_sel`.

```vhdl
freq_error       : out signed(FERR_W-1 downto 0);
freq_error_valid : out std_logic;
ambiguous        : out std_logic;
```

No integrator is allowed inside this module.

### `hybrid_fll_pll_filter`

Computes:

```text
freq_state[k+1] = sat(freq_state[k] + Kf*ef + Ki*ephi)
freq_correction = sat(freq_state[k+1] + Kp*ephi)
tracking_word   = center_word + freq_correction
```

It does not own state transitions.

### `loop_state_manager`

Owns mode transitions and coefficient selection. It does not perform wide DSP arithmetic.

States v1:

```vhdl
ST_RESET
ST_DISABLED
ST_CONFIGURE
ST_WARMUP
ST_FLL_ACQUIRE
ST_FLL_PLL_BLEND
ST_PLL_TRACK
ST_HOLDOVER
ST_REACQUIRE
ST_FAULT
```

### `output_rate_multiplier`

Computes the final output word with full precision:

```text
output_word = round(tracking_word * OUTPUT_MUL / OUTPUT_DIV)
```

`OUTPUT_DIV=0` must be rejected before becoming active.

### `debug_dac_output`

DACout1 debug interface:

```vhdl
source_select : unsigned(7 downto 0);
format_mode   : unsigned(1 downto 0);
shift_or_lsb  : unsigned(5 downto 0);
invert        : std_logic;
hold_last     : std_logic;
gain          : signed(15 downto 0);
offset        : signed(15 downto 0);
dac_sample    : signed(15 downto 0);
```

DACout1 must not feed back into the DPLL loop.

## RFC Rule

No owner may change these public definitions without first adding an RFC file and getting architecture/integration approval.
