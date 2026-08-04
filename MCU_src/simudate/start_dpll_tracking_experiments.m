%% DPLL detector scaling and fixed-frequency FM response
% Edit this section, then click MATLAB Run. The PLL algorithm is not changed.

close all;
clc;
scriptDir = fileparts(mfilename('fullpath'));

% Real 3.125 MHz FPGA-equivalent reference source for the CIC scaling scan.
pllInputMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5_ch2_CIC_DCBlock_3M125.mat');
inputSampleRange = [1 4000000];

% Current hardware loop preset.
centerFrequencyHz = 20000;
kpTrack = 6000000;
kiTrack = 2500000;
pProductShift = 12;
iProductShift = 18;
fllProductShift = 16;
startupMode = 'prelocked';
prelockEstimateDurationSeconds = 0.020;
prerollDurationSeconds = 0.050;

% Step 1: post-IQ CIC detector scaling.
runCicScan = true;
cicOutputShifts = [8 9 10];

% Step 2: one fixed sinusoidal modulation frequency per experiment point.
runFmSweep = true;
modulationFrequenciesHz = [1 2 5 10 20 40 60 80];
phaseModulationAmplitudeRad = 0.15;
syntheticAmplitudeCodes = 6000;
carrierLeadSeconds = 0.10;
settleCycles = 1;
measurementCycles = 2;
minimumMeasurementSeconds = 0.25;
saveFullRawFmPoints = true;

% [] uses the detector shift selected by Step 1. Set a scalar to override.
fmCicOutputShift = [];

% A timestamped directory prevents overwriting a prior experiment.
runTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
resultRoot = fullfile(scriptDir, 'results', 'tracking_experiments', runTag);

%% Build the unchanged current-hardware configuration

cfg = dpll_current_config(centerFrequencyHz);
cfg.files.pll_input_mat = pllInputMat;
cfg.io.input_sample_range = inputSampleRange;
cfg.startup.mode = startupMode;
cfg.startup.frequency_estimation_duration_s = prelockEstimateDurationSeconds;
cfg.startup.preroll_duration_s = prerollDurationSeconds;
cfg.gains.kp_track = int64(kpTrack);
cfg.gains.ki_track = int64(kiTrack);
cfg.shifts.p_product = pProductShift;
cfg.shifts.i_product = iProductShift;
cfg.shifts.fll_product = fllProductShift;

if ~isfolder(resultRoot), mkdir(resultRoot); end
fprintf('\nExperiment output: %s\n', resultRoot);
fprintf('Posterior peak positions are not loaded by this launcher.\n');

%% Step 1: scaling scan on frozen real reference data

cicExperiment = []; %#ok<NASGU>
if runCicScan
    cicExperiment = run_cic_scaling_experiment(cfg, cicOutputShifts, ...
        string(fullfile(resultRoot, 'cic_scan')));
end

%% Step 2: fixed-frequency synthetic FM response

fmExperiment = []; %#ok<NASGU>
if runFmSweep
    if isempty(fmCicOutputShift)
        if isempty(cicExperiment)
            error('dpll:MissingCicSelection', ...
                'Set fmCicOutputShift when runCicScan is false.');
        end
        selectedCicShift = cicExperiment.recommended_shift;
    else
        selectedCicShift = fmCicOutputShift;
    end
    fmCfg = cfg;
    fmCfg.cic.output_shift = selectedCicShift;
    fmOptions.phase_modulation_rad = phaseModulationAmplitudeRad;
    fmOptions.amplitude_codes = syntheticAmplitudeCodes;
    fmOptions.carrier_lead_s = carrierLeadSeconds;
    fmOptions.settle_cycles = settleCycles;
    fmOptions.measurement_cycles = measurementCycles;
    fmOptions.minimum_measurement_s = minimumMeasurementSeconds;
    fmOptions.save_full_raw = saveFullRawFmPoints;
    fmExperiment = run_fm_frequency_response_experiment(fmCfg, ...
        modulationFrequenciesHz, string(fullfile(resultRoot, 'fm_sweep')), ...
        fmOptions);
end

%% Freeze manifest and write the result report

manifest.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
manifest.result_root = resultRoot;
manifest.config = cfg;
manifest.posterior_peak_data_loaded = false;
manifest.cic_scan_completed = ~isempty(cicExperiment);
manifest.fm_sweep_completed = ~isempty(fmExperiment);
save(fullfile(resultRoot, 'experiment_manifest.mat'), ...
    'manifest', 'cicExperiment', 'fmExperiment', '-v7.3');

reportPath = '';
if ~isempty(cicExperiment) && ~isempty(fmExperiment)
    reportPath = write_tracking_experiment_report( ...
        cicExperiment, fmExperiment, resultRoot);
end

fprintf('\nExperiments complete.\n');
fprintf('  Results: %s\n', resultRoot);
if ~isempty(reportPath), fprintf('  Report : %s\n', reportPath); end
fprintf('Workspace variables: cfg, cicExperiment, fmExperiment, manifest\n');
