# MATLAB DPLL replay

This directory replays the FPGA-equivalent 3.125 MSPS reference channel
through the stage-A DPLL and restores pulse spacing on the original 62.5 MHz
event timebase. The output MUL/DIV hardware and final DDS are outside the
agreed model boundary; the core tracking word is multiplied by 2000
numerically during validation.

## Configured data

`dpll_current_config(20000)` defaults to:

```matlab
cfg.files.pll_input_mat = ...
    'data/dat5_cc62M5_ch2_CIC_DCBlock_3M125.mat';
cfg.files.peak_mat = ...
    'data/dat5_cc62M5采样峰距离.mat';
```

Both paths are ordinary configuration fields and can be replaced for another
capture. The PLL file may use either:

```matlab
frontendOutput + metadata
```

or the legacy test contract:

```matlab
pll_input_codes + sample_rate_hz
```

`frontendOutput` is already the FPGA-equivalent pre-IQ CIC/DC-blocker output.
No additional DC blocker, normalization, or resampling is applied.

## Startup modes

Prelocked startup is the default:

```matlab
cfg.startup.mode = 'prelocked';
cfg.startup.frequency_estimation_duration_s = 0.020;
cfg.startup.preroll_duration_s = 0.050;
```

Only the PLL reference prefix is used to estimate the initial NCO frequency
and phase. The state starts in TRACK with consistent `tracking_word`,
`freq_state`, NCO phase, TRACK IIR selection, FLL, and PI. The 50 ms preroll
fills CIC/IIR/FLL state and is excluded from steady-state statistics.

Cold-start regression remains available:

```matlab
cfg.startup.mode = 'cold';
```

It follows WARMUP, FLL acquisition, BLEND, and TRACK, but is not the primary
steady-state metric.

## Run without posterior data

For one-click use, open `start_dpll_simulation.m`, edit the first parameter
section, and click MATLAB Run. It leaves `cfg`, `result`, `summary`, `prior`,
and `validation` in the workspace.

The equivalent command-line workflow is:

```matlab
cd('E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\simudate')
cfg = dpll_current_config(20000);
[result, summary, prior] = run_real_data_replay(cfg, true);
```

For a shorter development window:

```matlab
cfg.io.input_sample_range = [1 round(0.20 * 3125000)];
cfg.files.replay_output_mat = '';
```

The main path calls `load_peak_prior`, which requests only:

```matlab
channel1SampleRate
samplingPeakFirstLocation
samplingPeakMeanDistance
```

It never requests `samplingPeakDistance`. The replay result records:

```matlab
result.metadata.posterior_interval_data_used = false;
```

Core outputs include `phase_error`, `freq_error`, `freq_state`,
`freq_correction`, `tracking_word`, and `loop_state`. `result.trace` also
contains validity flags, controller terms, saturation flags, analysis masks,
and exact 125 MHz event ticks.

Always inspect `summary.analysis_cic_saturation_rate` and
`summary.analysis_cordic_out_of_range_rate`. A nonzero CORDIC range rate means
the behavioral `atan2` phase cannot be treated as hardware-equivalent until
the detector scaling/range problem is resolved.

## RTL event timing

The event model uses audited fixed latencies:

| Stage | 125 MHz ticks |
|---|---:|
| Mixer to post-CIC input | 5 |
| Post-IQ CIC output pipeline | 12 |
| Two-section post-IIR transaction | 21 |
| CORDIC adapter and IP | 26 |
| FLL-valid to core tracking-word application | 11 |
| Tracking DDS response after core word application | 9 |

The FLL and CORDIC operate in parallel. A replayed FLL error therefore uses
the most recently completed CORDIC phase, not the phase from the same IQ
transaction. Tracking-word changes are scheduled on the 125 MHz timeline.

## Separate posterior validation

Freeze and save the replay before loading true peak distances. Then run:

```matlab
validation = run_peak_validation( ...
    string(cfg.files.replay_output_mat), ...
    string(cfg.files.peak_mat), ...
    string(cfg.files.validation_output_mat), true);
```

Only this function loads `samplingPeakDistance`. It reconstructs all true peak
positions on the original 62.5 MHz coordinate:

```matlab
peak_raw = first_peak + [0; cumsum(samplingPeakDistance)];
```

It then integrates the timestamped core tracking word at those physical peak
times:

```matlab
output_cycles_per_62m5_step = 2 * 2000 * tracking_word / 2^48;
```

The factor two is the number of 125 MHz fabric ticks per 62.5 MHz sample. The
primary validation outputs are:

```matlab
fixed_interval_raw_samples
recovered_interval_output_cycles
recovered_interval_error       % relative to 113*2000 = 226000
sampling_phase_error_cycles
```

The fixed-clock interval and recovered interval use different units. The
validator converts the fixed interval into output-cycle-equivalent error before
subtracting or overlaying it:

```matlab
uncompensated_error = fixed_interval * 226000/mean(fixed_interval) - 226000;
compensated_component = uncompensated_error - recovered_error;
```

`cfg.validation.slow_window_pulses` controls a validation-only moving-mean
split. It affects plots/statistics only and never enters the PLL calculation.

The true distance vector must not be used to select Kp, Ki, shifts, filters,
or any other PLL parameter.

## Gain experiments

Current hardware preset:

```matlab
cfg.gains.kp_track = int64(6000000);
cfg.gains.ki_track = int64(2500000);
```

ARM default `Ki_track=180000` is available through `dpll_default_config`.
The HDL coefficient port is signed 24-bit, so coefficients above 8388607 are
not hardware-representable. Larger effective Kp can be explored offline by
reducing `cfg.shifts.p_product`; an HDL parameter change is required before
that result can be reproduced in hardware.

## Tests

```matlab
addpath('tests')
run_all_tests
```

The suite covers fixed-point helpers, the hybrid controller, real MAT-file
interfaces, prelocked startup, cold-start acquisition, timestamp ordering,
and posterior-leakage flags.
