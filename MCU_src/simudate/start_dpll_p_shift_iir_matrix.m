%% Controlled P-product-shift and TRACK-IIR matrix validation
% Edit only this section, then click MATLAB Run. The four replay candidates
% are frozen before posterior peak distances are loaded.

close all;
clc;
clear;
scriptDir = fileparts(mfilename('fullpath'));

pllInputMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5_ch2_CIC_DCBlock_3M125.mat');
defaultCfg = dpll_default_config(20000);
peakMat = defaultCfg.files.peak_mat;
inputSampleRange = [1 4000000];
centerFrequencyHz = 20000;
startupMode = 'prelocked';
prelockEstimateDurationSeconds = 0.020;
prerollDurationSeconds = 0.050;
resultTag = '20260731_full';
resultRoot = fullfile(scriptDir, 'results', ...
    'p_shift_iir_matrix', resultTag);

%% Freeze the common configuration before building the 2-by-2 matrix

baseCfg = dpll_current_config(centerFrequencyHz);
baseCfg.files.pll_input_mat = pllInputMat;
baseCfg.files.peak_mat = peakMat;
baseCfg.io.input_sample_range = inputSampleRange;
baseCfg.startup.mode = startupMode;
baseCfg.startup.frequency_estimation_duration_s = ...
    prelockEstimateDurationSeconds;
baseCfg.startup.preroll_duration_s = prerollDurationSeconds;
baseCfg.cic.output_shift = 9;
baseCfg.gains.kp_track = int64(6000000);
baseCfg.gains.ki_track = int64(2500000);
baseCfg.gains.kf_track = int64(250000);
baseCfg.shifts.i_product = 18;
baseCfg.shifts.fll_product = 16;

candidates = build_p_shift_iir_matrix(baseCfg);
fprintf('\nP-shift/IIR matrix output: %s\n', resultRoot);
fprintf('Reference-only candidates are frozen before posterior validation.\n');
for k = 1:numel(candidates)
    fprintf('  %-10s P=%d, TRACK IIR=%g Hz, Kp_blend=%d\n', ...
        candidates(k).id, candidates(k).cfg.shifts.p_product, ...
        candidates(k).cfg.iir.track_cutoff_hz, ...
        candidates(k).cfg.gains.kp_blend);
end

experiment = run_p_shift_iir_matrix_validation( ...
    candidates, string(peakMat), string(resultRoot));
fprintf('\nMatrix validation complete.\n');
fprintf('  Selected without peaks: %s\n', ...
    experiment.selected_without_peak_data);
fprintf('  Report: %s\n', experiment.report_path);
fprintf('Workspace variables: baseCfg, candidates, experiment\n');
