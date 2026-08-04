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

## Detector-scaling and FM-response experiments

Open `start_dpll_tracking_experiments.m`, edit its first parameter section,
and click MATLAB Run. It performs two posterior-free experiments without
changing the DPLL datapath implementation:

1. Replays the same real 3.125 MHz reference data at post-IQ CIC output shifts
   8, 9, and 10. Complete replay MAT files retain every fixed-point trace and
   state/status counter.
2. Injects deterministic sinusoidal phase modulation at 1, 2, 5, 10, 20, 40,
   60, and 80 Hz. Each point saves its generated `int16` input codes, analytic
   truth, full replay, measurement window, and least-squares complex tone fit.

Outputs are written under a timestamped directory:

```text
results/tracking_experiments/yyyyMMdd_HHmmss/
```

The directory contains CSV source tables, MAT experiment manifests, a Markdown
report, and figures in 600 dpi PNG, vector PDF/SVG, and editable MATLAB FIG
formats. Source provenance includes the real input file SHA-256. The launcher
never opens the pulse-position MAT file, so these experiments cannot leak
`samplingPeakDistance` into detector selection or frequency-response fitting.

## High-frequency root-cause investigation

`start_dpll_high_frequency_investigation.m` runs the complete resumable study:

1. amplitude linearity and unmodulated-carrier checks;
2. PI-only, FLL-only, and reduced-FLL isolation;
3. effective P and Ki sweeps;
4. FPGA-realizable multirate FLL, phase prediction, and direct-frequency
   feedforward variants;
5. frozen real-reference candidate replays;
6. posterior peak validation only after candidate freeze;
7. final 1--80 Hz response and cold-start regression.

Every case immediately saves its raw measurement window, exact configuration,
controller terms, PSD, tone fit, and status counters. Generated figures are
stored as 600 dpi PNG, vector PDF/SVG, and editable FIG files.

The selected simulation preset is:

```matlab
cfg = dpll_optimized_config(20000);
```

It requires `P_PRODUCT_SHIFT=9` at the core instantiation in
`DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/dpll_single_clock_core_stage_a.v`.
The post-IQ CIC shift remains register-controlled and is set to 9. Because the
P-product shift is global, `Kp_blend` is reduced from 6000000 to 750000 so that
cold-start BLEND behavior retains its former effective proportional gain.

## Reference-phase ceiling validation

After creating the frozen optimized replay, run:

```matlab
start_dpll_reference_phase_validation
```

This posterior-only study performs two checks without changing or rerunning the
PLL controller:

1. It reconstructs the detector-observable reference phase as NCO accumulated
   phase plus detector residual phase. Real-pulse residuals are separated into
   the reference/peak mismatch and the remaining PLL-versus-reference error.
2. It generates synthetic event positions from the same real reference phase,
   exactly 113 reference cycles apart, and integrates the frozen tracking word
   at those event times.

Each run writes a timestamped directory under:

```text
results/reference_phase_validation/yyyyMMdd_HHmmss/
```

The result includes full derived MAT data, interval-level CSV tables, a fixed
delay scan, autocorrelation and PSD tables, a Markdown report, and figures in
600 dpi PNG, vector PDF/SVG, and editable MATLAB FIG formats. The true peak
positions are used only in the real-pulse posterior plots; they do not generate
the exact-113-cycle synthetic events and never modify the frozen replay.

## Complete root-cause audit

Run start_dpll_root_cause_audit.m to execute the full frozen-boundary audit:

1. calibrate zero-crossing, local-sinusoid, and FFT-analytic phase estimators
   against known synthetic phase modulation without loading peaks;
2. measure post-IQ CIC, IIR, and CORDIC gain, phase, group delay, and AM-to-PM;
3. audit the 62.5/3.125 MHz sample-coordinate mapping and detector cadence;
4. compare all frozen phase estimators at real posterior peak timestamps;
5. inspect the saved peak resolution and the configured extraction source;
6. repeat the detector-observable ceiling and exact-113-cycle validation.

Each run stores generated calibration codes, derived MAT data, interval-level
and summary CSV tables, source hashes, a Markdown decision report, and figures
in PNG/PDF/SVG/FIG formats under results/dpll_root_cause_audit/yyyyMMdd_HHmmss/.

The root-cause audit requires only the saved peak distances, not the original
62.5 MHz pulse waveform. Peak data is loaded only after estimator parameters
and known-truth calibration results are frozen.

## Complete causal validation

`start_dpll_complete_validation.m` is the one-click launcher for the final
causal audit. It runs or resumes:

1. RTL, delayed-ideal, zero-delay-ideal, IIR, and scheduler counterfactuals;
2. past-only phase-prediction limits using the real reference waveform;
3. real-reference 2/4/8 kHz and one/two-section IIR selection;
4. final frozen replay, cold-start regression, and posterior peak validation;
5. a consolidated Markdown report, CSV decision tables, raw MAT files, and
   PNG/PDF/SVG/FIG paper figures.

The selected FPGA-realizable preset is `dpll_recommended_config(20000)`:

```matlab
cfg.shifts.p_product = 8;       % HDL P_PRODUCT_SHIFT
cfg.cic.output_shift = 9;       % ARM register
cfg.gains.kp_track = 6000000;
cfg.gains.ki_track = 2500000;
cfg.gains.kp_blend = 375000;
cfg.iir.track_cutoff_hz = 8000; % two existing sections
```

The complete current-data result is under
`results/dpll_complete_validation/20260730_final/`. The final report separates
the 0.56-cycle loop-only residual from the 8.60-cycle pulse/reference event
variation. The latter dominates the recovered peak-interval residual and is
not removable by a reference-only causal PLL.

## Controlled P-shift and TRACK-IIR matrix

`start_dpll_p_shift_iir_matrix.m` is the one-click launcher for the controlled
P9/P8 by 2/8 kHz experiment. It keeps CIC shift 9, Kp/Ki
6000000/2500000, FLL settings, startup, input range, and latency model fixed.
The four real-reference replay files are saved before the peak-distance vector
is loaded. Candidate selection uses only the reference waveform and synthetic
exact-113 events.

Posterior validation now scales the fixed-clock comparison from the supplied
`samplingPeakMeanDistance` prior rather than the hidden distance-vector mean.
It also overlays an independent zero-phase FFT reference-event estimate and
reports the remaining loop-only error.

The complete full-record result is under
`results/p_shift_iir_matrix/20260731_full/`. It contains replay and validation
MAT files, combined and interval-level CSV tables, a Markdown report, and
PNG/PDF/SVG/FIG figures. The frozen reference-only selection is P8 / 8 kHz:

```text
exact-113 RMS       0.770180 output cycles
loop-only RMS       0.548976 output cycles
total peak RMS      8.474147 output cycles
reference-event RMS 8.462413 output cycles
```
