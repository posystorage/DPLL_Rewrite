%% DPLL reference-phase ceiling and exact-113-cycle event validation
% Edit only this first section, then click MATLAB Run.

close all;
clc;
scriptDir = fileparts(mfilename('fullpath'));

% Frozen optimized replay. This file must be generated before posterior data
% is loaded, normally by start_dpll_simulation.m.
replayMat = fullfile(scriptDir, 'data', ...
    'dat5_dpll_replay_result_optimized_pShift9.mat');

% Real peak positions are posterior-only validation data.
peakMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5采样峰距离.mat');

% Validation-only settings. They never alter the frozen PLL replay.
slowWindowPulses = 21;
fixedDelayScanSeconds = (-0.003:0.00001:0.003).';
showFigures = true;

runTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
resultRoot = fullfile(scriptDir, 'results', ...
    'reference_phase_validation', runTag);

%% Run posterior decomposition and exact-cycle synthetic-event validation

study = run_reference_phase_ceiling_validation( ...
    string(replayMat), string(peakMat), string(resultRoot), ...
    shift_scan_s=fixedDelayScanSeconds, ...
    slow_window_pulses=slowWindowPulses, ...
    show_figures=showFigures);

fprintf('\nDone. Workspace variables: study, resultRoot\n');
