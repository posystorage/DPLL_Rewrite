%% Complete DPLL validation launcher
% Edit only this section, then click MATLAB Run. A fresh full run can take
% tens of minutes. Raw case files make the counterfactual and real-variant
% stages resumable.

centerFrequencyHz = 20000;
inputSampleRange = [1 4000000];
outputRoot = fullfile('results', 'dpll_complete_validation', 'manual_run');
priorAuditRoot = fullfile('results', 'dpll_root_cause_audit', ...
    '20260729_full_root_cause');

runCounterfactual = true;
runSeedCausalAudit = true;
runRealDetectorVariants = true;
runFinalReplay = true;
runFinalCausalAudit = true;
runColdStart = true;
runPosterior = true;
writeFinalReport = true;

%% Resolve inputs
rootDir = fileparts(mfilename('fullpath'));
originalDir = pwd;
cleanup = onCleanup(@() cd(originalDir)); %#ok<NASGU>
cd(rootDir);
baseCfg = dpll_recommended_config(centerFrequencyHz);
baseCfg.io.input_sample_range = inputSampleRange;
inputMat = string(baseCfg.files.pll_input_mat);
peakMat = string(baseCfg.files.peak_mat);
if ~isfolder(outputRoot), mkdir(outputRoot); end

%% Synthetic detector counterfactuals
counterfactualDir = fullfile(outputRoot, 'detector_counterfactual');
if runCounterfactual
    counterfactualAudit = run_detector_counterfactual_audit( ...
        baseCfg, counterfactualDir);
end

%% Posterior-free seed replay and analytic/causal reference truth
seedDir = fullfile(outputRoot, 'seed_candidate');
if ~isfolder(seedDir), mkdir(seedDir); end
seedReplayMat = fullfile(seedDir, 'seed_candidate_replay.mat');
if runSeedCausalAudit && ~isfile(seedReplayMat)
    seedInput = load_input_mat(inputMat, inputSampleRange);
    seedResult = simulate_dpll(seedInput, baseCfg);
    seedSummary = analyze_dpll_result(seedResult);
    result = seedResult; %#ok<NASGU>
    summary = seedSummary; %#ok<NASGU>
    save(seedReplayMat, 'result', 'summary', '-v7.3');
    clear result summary seedResult seedSummary seedInput
end
seedCausalDir = fullfile(seedDir, 'causal_predictability');
seedCausalMat = fullfile(seedCausalDir, ...
    'causal_phase_predictability_audit.mat');
if runSeedCausalAudit
    seedCausalAudit = run_causal_phase_predictability_audit( ...
        seedReplayMat, inputMat, seedCausalDir);
end

%% Real-reference detector selection without peak data
realVariantDir = fullfile(outputRoot, 'real_detector_variants');
if runRealDetectorVariants
    run_real_detector_variant_audit( ...
        inputMat, seedCausalMat, realVariantDir, ...
        input_sample_range=inputSampleRange);
end
loadedReal = load(fullfile(realVariantDir, ...
    'real_detector_variant_audit.mat'), 'audit');
realDetectorAudit = loadedReal.audit;
selectedIndex = find([realDetectorAudit.variants.id] == ...
    realDetectorAudit.selected_id, 1);
selectedVariant = realDetectorAudit.variants(selectedIndex);

%% Freeze the selected final configuration
finalCfg = dpll_recommended_config(centerFrequencyHz);
finalCfg.io.input_sample_range = inputSampleRange;
finalCfg.iir.sections = selectedVariant.cfg.iir.sections;
finalCfg.iir.track_cutoff_hz = selectedVariant.cfg.iir.track_cutoff_hz;
postCicRateHz = finalCfg.input_sample_rate_hz / finalCfg.cic.rate;
finalCfg.iir.track = dpll.design_biquad_q30( ...
    finalCfg.iir.track_cutoff_hz, postCicRateHz);
finalCfg.architecture.controller_update_mode = ...
    selectedVariant.cfg.architecture.controller_update_mode;
finalCfg.gains.kf_track = selectedVariant.cfg.gains.kf_track;

finalDir = fullfile(outputRoot, 'final_candidate');
if ~isfolder(finalDir), mkdir(finalDir); end
finalReplayMat = fullfile(finalDir, 'final_candidate_replay.mat');
if runFinalReplay || ~isfile(finalReplayMat)
    finalInput = load_input_mat(inputMat, inputSampleRange);
    result = simulate_dpll(finalInput, finalCfg); %#ok<NASGU>
    summary = analyze_dpll_result(result); %#ok<NASGU>
    save(finalReplayMat, 'result', 'summary', '-v7.3');
    clear result summary finalInput
end

%% Final causal audit and cold-start regression
finalCausalDir = fullfile(finalDir, 'causal_predictability');
finalCausalMat = fullfile(finalCausalDir, ...
    'causal_phase_predictability_audit.mat');
if runFinalCausalAudit
    finalCausalAudit = run_causal_phase_predictability_audit( ...
        finalReplayMat, inputMat, finalCausalDir);
end
if runColdStart
    coldStartAudit = run_cold_start_candidate_regression( ...
        dpll_current_config(centerFrequencyHz), finalCfg, ...
        fullfile(outputRoot, 'cold_start'));
end

%% Posterior-only pulse-event validation
if runPosterior
    posteriorAudit = run_posterior_event_causality_audit( ...
        finalReplayMat, peakMat, finalCausalMat, ...
        fullfile(finalDir, 'posterior_causality'));
    validation = posteriorAudit.validation; %#ok<NASGU>
    save(fullfile(finalDir, 'final_candidate_peak_validation.mat'), ...
        'validation', '-v7.3');
end

%% Consolidated decision report
if writeFinalReport
    completeReport = write_dpll_complete_validation_report( ...
        outputRoot, priorAuditRoot);
end

fprintf('Complete DPLL validation available at:\n  %s\n', outputRoot);
