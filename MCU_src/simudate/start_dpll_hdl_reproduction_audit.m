%% Fresh HDL-parameter negative-control reproduction audit
% This entry never reuses an old replay. It preregisters four cases, freezes
% source/config hashes, runs all reference-only cases, and only then opens
% the real peak timestamp file for optional posterior validation.

close all;
clc;
clear;

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);

pllInputMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5_ch2_CIC_DCBlock_3M125.mat');
peakMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5采样峰距离.mat');

inputSampleRange = [1 4000000];
centerFrequencyHz = 20000;
startupMode = "prelocked";
prelockDurationSeconds = 0.020;
prerollDurationSeconds = 0.050;
exactMarginSeconds = 0.005;
onePointThresholdCycles = 1;

runPosterior = true;
showPlots = true;
exportFigures = true;
runRegressionTests = true;

resultTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
resultRoot = fullfile(scriptDir, 'results', ...
    'hdl_reproduction_audit', resultTag);

audit = run_hdl_reproduction_audit( ...
    string(pllInputMat), string(peakMat), string(resultRoot), ...
    input_sample_range=inputSampleRange, ...
    center_frequency_hz=centerFrequencyHz, ...
    startup_mode=startupMode, ...
    prelock_duration_s=prelockDurationSeconds, ...
    preroll_duration_s=prerollDurationSeconds, ...
    exact_margin_s=exactMarginSeconds, ...
    one_point_threshold_cycles=onePointThresholdCycles, ...
    run_posterior=runPosterior, show_plots=showPlots, ...
    export_figures=exportFigures);

if runRegressionTests
    addpath(fullfile(scriptDir, 'tests'));
    run_all_tests();
end

fprintf('\nHDL复现实验入口完成。工作区变量：audit, resultRoot\n');
