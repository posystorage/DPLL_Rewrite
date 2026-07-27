%% DPLL real-data simulation launcher
% Edit only the parameters in this first section, then click MATLAB Run.

close all;
clc;

scriptDir = fileparts(mfilename('fullpath'));

% Input data files. Replace these paths to test another capture.
pllInputMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5_ch2_CIC_DCBlock_3M125.mat');
peakMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5采样峰距离.mat');

% Simulation range in the internal 3.125 MHz input coordinate.
% [1 4000000] covers the current 1.28 s peak-validation window.
% Use [1 Inf] for the complete recording (substantially slower).
inputSampleRange = [1 4000000];

% Startup. Use 'prelocked' for steady-state analysis or 'cold' for capture
% regression. Preroll is excluded from steady-state statistics.
startupMode = 'prelocked';
prelockEstimateDurationSeconds = 0.020;
prerollDurationSeconds = 0.050;

% Center frequency and current TRACK gains.
centerFrequencyHz = 20000;
kpTrack = 6000000;
kiTrack = 2500000;

% FLL and BLEND gains. These defaults match the ARM profile.
kfAcquire = 8000000;
kfBlend = 1500000;
kfTrack = 250000;
kpBlend = 6000000;
kiBlend = 468800;

% Fixed-point product shifts. Reducing a shift increases effective gain.
pProductShift = 12;
iProductShift = 18;
fllProductShift = 16;

% Validation-only slow/fast separation. This does not enter the PLL.
slowWindowPulses = 21;

% Output and display controls.
showPlots = true;
saveReplayResult = true;
runPosteriorValidation = true;
saveValidationResult = true;

% Output files. The posterior result is always stored separately.
replayOutputMat = fullfile(scriptDir, 'data', ...
    'dat5_dpll_replay_result.mat');
validationOutputMat = fullfile(scriptDir, 'data', ...
    'dat5_dpll_peak_validation.mat');

%% Build configuration

cfg = dpll_current_config(centerFrequencyHz);
cfg.files.pll_input_mat = pllInputMat;
cfg.files.peak_mat = peakMat;
cfg.io.input_sample_range = inputSampleRange;
cfg.startup.mode = startupMode;
cfg.startup.frequency_estimation_duration_s = ...
    prelockEstimateDurationSeconds;
cfg.startup.preroll_duration_s = prerollDurationSeconds;

cfg.gains.kp_track = int64(kpTrack);
cfg.gains.ki_track = int64(kiTrack);
cfg.gains.kf_acquire = int64(kfAcquire);
cfg.gains.kf_blend = int64(kfBlend);
cfg.gains.kf_track = int64(kfTrack);
cfg.gains.kp_blend = int64(kpBlend);
cfg.gains.ki_blend = int64(kiBlend);
cfg.shifts.p_product = pProductShift;
cfg.shifts.i_product = iProductShift;
cfg.shifts.fll_product = fllProductShift;
cfg.validation.slow_window_pulses = slowWindowPulses;

if saveReplayResult
    cfg.files.replay_output_mat = replayOutputMat;
else
    cfg.files.replay_output_mat = ''; %#ok<UNRCH>
end
if saveValidationResult
    cfg.files.validation_output_mat = validationOutputMat;
else
    cfg.files.validation_output_mat = ''; %#ok<UNRCH>
end

gainValues = double([cfg.gains.kp_track, cfg.gains.ki_track, ...
    cfg.gains.kf_acquire, cfg.gains.kf_blend, cfg.gains.kf_track, ...
    cfg.gains.kp_blend, cfg.gains.ki_blend]);
if any(gainValues < -8388608 | gainValues > 8388607)
    warning('dpll:NonHardwareGain', ...
        ['At least one gain exceeds signed 24-bit hardware range. ' ...
         'This run is an offline hypothesis and cannot be reproduced by ' ...
         'the current HDL coefficient port.']);
end

fprintf('\nDPLL simulation settings\n');
fprintf('  PLL input : %s\n', cfg.files.pll_input_mat);
fprintf('  Peak prior: %s\n', cfg.files.peak_mat);
fprintf('  Range     : [%g, %g] at 3.125 MHz\n', ...
    cfg.io.input_sample_range(1), cfg.io.input_sample_range(2));
fprintf('  Startup   : %s, preroll %.3f ms\n', ...
    cfg.startup.mode, 1e3 * cfg.startup.preroll_duration_s);
fprintf('  Center    : %.6f Hz\n', cfg.center_frequency_hz);
fprintf('  Kp/Ki     : %d / %d\n\n', ...
    cfg.gains.kp_track, cfg.gains.ki_track);

%% Stage 1: PLL replay without true peak distances

[result, summary, prior] = run_real_data_replay(cfg, showPlots);

fprintf('\nInternal PLL summary (no posterior peak distances)\n');
disp(summary);
fprintf('Datapath status\n');
disp(result.status);

%% Stage 2: optional posterior-only 62.5 MHz validation

validation = []; %#ok<NASGU>
if runPosteriorValidation
    if ~saveReplayResult
        error('dpll:FrozenReplayRequired', ...
            ['Posterior validation requires saveReplayResult=true so it ' ...
             'loads a frozen replay from disk.']);
    end
    validation = run_peak_validation( ...
        string(replayOutputMat), string(peakMat), ...
        string(cfg.files.validation_output_mat), showPlots);
    fprintf('\n62.5 MHz posterior validation summary\n');
    disp(validation.summary);
else
    fprintf('\nPosterior validation skipped. PLL replay remains posterior-free.\n'); %#ok<UNRCH>
end

fprintf('\nDone. Variables available in the workspace:\n');
fprintf('  cfg, result, summary, prior, validation\n');
