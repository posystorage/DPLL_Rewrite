# MATLAB DPLL replay

This directory replays FPGA-equivalent 3.125 MSPS input codes through the
frequency-tracking part of the current DPLL. It stops at `tracking_word`; the
output multiplier/divider, final output DDS, DAC, and 40 MHz clock electronics
are intentionally outside the model.

## Input contract

The MAT file must contain exactly the two required variables:

```matlab
pll_input_codes   % N-by-1 int16 FPGA-equivalent codes
sample_rate_hz    % scalar, exactly 3125000
```

No DC blocker, resampling, normalization, amplitude calibration, or ADC model
is applied. `pll_input_codes` is treated as the already converted 14-bit input
sequence described for this experiment.

## Run

```matlab
cd('E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\simudate')
cfg = dpll_current_config(20000);  % Kp=6,000,000; Ki=2,500,000
[result, summary] = run_dpll_replay("capture.mat", "replay_result.mat", cfg);
```

For the ARM profile value `Ki_track=180000`, use:

```matlab
cfg = dpll_default_config(20000);
```

All stage parameters are ordinary fields in `cfg`. In particular:

```matlab
cfg.gains.kp_track = int64(6000000);
cfg.gains.ki_track = int64(2500000);
cfg.shifts.p_product = 12;
cfg.shifts.i_product = 18;
cfg.shifts.fll_product = 16;
```

The HDL coefficient ports are signed 24-bit, so a literal coefficient above
`8388607` is not hardware-representable. To study a larger effective Kp before
editing HDL, reduce `p_product`; for example, Kp 6,000,000 with shift 8 has 16
times the proportional effect of the same coefficient with shift 12. Such a
shift change is an offline hypothesis until the HDL parameter is changed.

## Modeled chain

The replay includes:

1. 48-bit tracking NCO, advanced by 40 fabric clocks per input code.
2. Signed DDS mixer and RTL `[30:13]` truncation.
3. Three-stage post-IQ CIC with configured decimation, rounding, warmup, and
   20-bit saturation.
4. Two cascaded Q2.30 biquads, including acquire/track coefficient switching
   and detector reset on the switch.
5. CORDIC-equivalent 18-bit phase quantization.
6. Cross/dot FLL with selectable delay, 16-sample blocks, and 16-sample replay.
7. State manager and the real FLL-valid-gated FLL+PI control law.

The approved core outputs are available both at the top level and in
`result.trace`:

```matlab
phase_error
freq_error
freq_state
freq_correction
tracking_word
loop_state
```

`result.trace` also contains valid/block-valid flags, I/Q, magnitude, FLL/I/P
terms, saturation flags, input indices, and time stamps.

## Pulse prediction

The event model assumes 113 reference cycles per pulse and output multiplier
2000. It reconstructs an unwrapped reference phase from tracking phase plus
the modeled phase residual. With an optional anchor:

```matlab
cfg.pulse.first_pulse_sample_index = 123456;  % one approximate first peak
```

theoretical pulse events are placed relative to that input sample. Without an
anchor the model still generates internally aligned events, but their absolute
sequence origin is arbitrary.

For adjacent events it evaluates both identities:

```matlab
interval_samples = 2000/(2*pi) * diff(tracking_phase_at_event);
interval_error_from_phase = -2000/(2*pi) * diff(phase_error_at_event);
```

The nominal interval is 226000 output samples. Their numerical difference is
reported in `result.events.identity_error_samples`.

No measured peak-spacing/posterior result file is accepted or read anywhere
in this construction. A later comparison must use measured spacing only for
validation and plotting, never for fitting gains or selecting parameters.

## Fidelity boundary

Data-dependent CIC/IIR group delay, coefficient switching, quantization,
controller update gating, and saturation are included. Constant pipeline
latency inside the 125 MHz implementation is represented by event ordering,
not by simulating every fabric clock. This is suitable for long captured-data
sweeps and control diagnosis. Exact pipeline-cycle and rare divider boundary
LSB comparisons remain the job of the Vivado RTL testbench.

## Tests

```matlab
cd('E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\simudate')
addpath('tests')
run_all_tests
```

The smoke test requires a synthetic 20 kHz input to reach state 6 (`TRACK`),
checks tracking direction, verifies the two interval formulas, and confirms
that no posterior interval data was consumed.
