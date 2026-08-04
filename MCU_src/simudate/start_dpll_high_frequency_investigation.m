%% DPLL high-frequency root-cause investigation launcher
% This run is intentionally extensive. Completed cases resume from disk.

close all;
clc;
scriptDir = fileparts(mfilename('fullpath'));
runTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
resultRoot = fullfile(scriptDir, 'results', ...
    'high_frequency_investigation', runTag);

runLayer1 = true;
runLayer2 = true;
runPSweep = true;
runISweep = true;
runStructureScreen = true;
runNegativeFeedforward = true;
runRealCandidates = true;
runPosteriorValidation = true;
runFinalResponse = true;
runColdStart = true;

cfg = dpll_current_config(20000);
cfg.cic.output_shift = 9;
cfg.io.input_sample_range = [1 4000000];
if ~isfolder(resultRoot), mkdir(resultRoot); end

if runLayer1
    cases = build_dpll_investigation_cases(cfg, 'layer1');
    layer1 = run_dpll_case_set(cases, string(fullfile(resultRoot, 'layer1')));
    figures = plot_dpll_investigation_layer1(layer1, fullfile(resultRoot, 'layer1'));
    save(fullfile(resultRoot, 'layer1', 'layer1_complete.mat'), ...
        'layer1', 'figures', '-v7.3');
end
if runLayer2
    cases = build_dpll_investigation_cases(cfg, 'layer2');
    layer2 = run_dpll_case_set(cases, string(fullfile(resultRoot, 'layer2')));
    figures = plot_dpll_investigation_layer2(layer2, fullfile(resultRoot, 'layer2'));
    save(fullfile(resultRoot, 'layer2', 'layer2_complete.mat'), ...
        'layer2', 'figures', '-v7.3');
end
if runPSweep
    cases = build_dpll_investigation_cases(cfg, 'layer3p');
    layer3p = run_dpll_case_set(cases, string(fullfile(resultRoot, 'layer3p')));
    figures = plot_dpll_pi_sweep(layer3p, fullfile(resultRoot, 'layer3p'), ...
        'Layer 3A: effective proportional-gain sweep', 'layer3a_p_sweep');
    save(fullfile(resultRoot, 'layer3p', 'layer3p_complete.mat'), ...
        'layer3p', 'figures', '-v7.3');
end
if runISweep
    cases = build_dpll_investigation_cases(cfg, 'layer3i');
    layer3i = run_dpll_case_set(cases, string(fullfile(resultRoot, 'layer3i')));
    figures = plot_dpll_pi_sweep(layer3i, fullfile(resultRoot, 'layer3i'), ...
        'Layer 3B: integral-gain sweep at P shift 9', 'layer3b_i_sweep');
    save(fullfile(resultRoot, 'layer3i', 'layer3i_complete.mat'), ...
        'layer3i', 'figures', '-v7.3');
end
if runStructureScreen
    cases = build_dpll_investigation_cases(cfg, 'layer3s');
    layer3s = run_dpll_case_set(cases, string(fullfile(resultRoot, 'layer3s')));
    figures = plot_dpll_pi_sweep(layer3s, fullfile(resultRoot, 'layer3s'), ...
        'Layer 3C: FPGA-realizable structure screen', 'layer3c_structure_screen');
    save(fullfile(resultRoot, 'layer3s', 'layer3s_complete.mat'), ...
        'layer3s', 'figures', '-v7.3');
end
if runNegativeFeedforward
    cases = build_dpll_investigation_cases(cfg, 'layer3n');
    layer3n = run_dpll_case_set(cases, string(fullfile(resultRoot, 'layer3n')));
    figures = plot_dpll_pi_sweep(layer3n, fullfile(resultRoot, 'layer3n'), ...
        'Layer 3D: negative direct-frequency feedforward', ...
        'layer3d_negative_feedforward');
    save(fullfile(resultRoot, 'layer3n', 'layer3n_complete.mat'), ...
        'layer3n', 'figures', '-v7.3');
end

candidates = build_dpll_final_candidates(cfg);
if runRealCandidates
    realComparison = run_real_candidate_comparison(candidates, ...
        string(fullfile(resultRoot, 'real_candidates')));
    save(fullfile(resultRoot, 'frozen_candidate_manifest.mat'), ...
        'candidates', '-v7.3');
end
if runPosteriorValidation
    posteriorComparison = run_frozen_candidate_peak_validation( ...
        fullfile(resultRoot, 'real_candidates', 'real_candidate_comparison.mat'), ...
        cfg.files.peak_mat, string(fullfile(resultRoot, 'posterior_validation')));
end
if runFinalResponse
    finalCfg = candidates(end).cfg;
    options = struct('phase_modulation_rad', 0.03, ...
        'amplitude_codes', 6000, 'carrier_lead_s', 0.10, ...
        'settle_cycles', 1, 'measurement_cycles', 2, ...
        'minimum_measurement_s', 0.25, 'save_full_raw', true);
    finalResponse = run_fm_frequency_response_experiment(finalCfg, ...
        [1 2 5 10 20 40 60 80], ...
        string(fullfile(resultRoot, 'final_response')), options);
    final_response = finalResponse; %#ok<NASGU>
    save(fullfile(resultRoot, 'final_response', 'final_response_complete.mat'), ...
        'final_response', '-v7.3');
end
if runColdStart
    coldRegression = run_cold_start_candidate_regression( ...
        candidates(1).cfg, candidates(end).cfg, ...
        string(fullfile(resultRoot, 'cold_start')));
end

figures = plot_dpll_final_investigation_summary(resultRoot);
reportPath = write_high_frequency_investigation_report(resultRoot);
fprintf('\nInvestigation complete:\n  %s\n  %s\n', resultRoot, reportPath);
