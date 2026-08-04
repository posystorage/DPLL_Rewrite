%% DPLL 2P2Z on/off final comparison launcher
% Edit only this first section, then click MATLAB Run.
%
% Both controller configurations are frozen before true peak distances are
% loaded. Reference-only replay and exact-113 validation run first for both
% candidates. Real peak timestamps are used only by the final posterior
% comparison and never enter either controller or candidate selection.

close all;
clc;
clear;

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);

% Fixed comparison order: current deployable baseline, then 2P2Z increment.
comparisonCandidateIds = ["p8_iir8k_baseline", ...
    "p8_iir8k_2p2z_wide"];

pllInputMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5_ch2_CIC_DCBlock_3M125.mat');
peakMat = fullfile(scriptDir, 'data', ...
    'dat5_cc62M5采样峰距离.mat');

% Keep this equal to the audited comparison window.
inputSampleRange = [1 4000000];
startupMode = 'prelocked';
prelockEstimateDurationSeconds = 0.020;
prerollDurationSeconds = 0.050;
exactEventMarginSeconds = 0.005;
slowWindowPulses = 21;

% One point is one output-clock cycle in the 226000-cycle interval.
onePointThresholdCycles = 1;

showPlots = true;
exportChineseFigures = true;
runPosteriorValidation = true;
runRegressionTests = false;

% Every run gets a new directory. Existing results are never replaced.
resultTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
resultRoot = fullfile(scriptDir, 'results', ...
    'manual_simulation_comparison', resultTag);

%% Freeze both candidates before loading true peak distances

catalog = build_reference_only_2p2z_candidates();
candidateCount = numel(comparisonCandidateIds);
candidates = repmat(catalog(1), candidateCount, 1);
for candidateIndex = 1:candidateCount
    catalogIndex = find(strcmp({catalog.id}, ...
        char(comparisonCandidateIds(candidateIndex))), 1);
    if isempty(catalogIndex)
        error('dpll:UnknownCandidate', 'Unknown candidate: %s', ...
            comparisonCandidateIds(candidateIndex));
    end
    candidates(candidateIndex) = catalog(catalogIndex);
end

if isfolder(resultRoot)
    error('dpll:ResultDirectoryExists', ...
        'Refusing to overwrite result directory: %s', resultRoot);
end
rawDir = fullfile(resultRoot, 'raw');
tableDir = fullfile(resultRoot, 'tables');
figureDir = fullfile(resultRoot, 'figures');
mkdir(resultRoot); mkdir(rawDir); mkdir(tableDir); mkdir(figureDir);

paths = repmat(struct('raw_dir', '', 'replay', '', 'exact', '', ...
    'posterior', ''), candidateCount, 1);
for candidateIndex = 1:candidateCount
    cfg = candidates(candidateIndex).cfg;
    cfg.files.pll_input_mat = pllInputMat;
    cfg.files.peak_mat = peakMat;
    cfg.io.input_sample_range = inputSampleRange;
    cfg.startup.mode = startupMode;
    cfg.startup.frequency_estimation_duration_s = ...
        prelockEstimateDurationSeconds;
    cfg.startup.preroll_duration_s = prerollDurationSeconds;
    cfg.validation.slow_window_pulses = slowWindowPulses;

    paths(candidateIndex).raw_dir = fullfile(rawDir, ...
        candidates(candidateIndex).id);
    mkdir(paths(candidateIndex).raw_dir);
    paths(candidateIndex).replay = fullfile( ...
        paths(candidateIndex).raw_dir, 'dpll_replay.mat');
    paths(candidateIndex).exact = fullfile( ...
        paths(candidateIndex).raw_dir, ...
        'exact113_reference_validation.mat');
    paths(candidateIndex).posterior = fullfile( ...
        paths(candidateIndex).raw_dir, ...
        'posterior_peak_validation.mat');
    cfg.files.replay_output_mat = paths(candidateIndex).replay;
    cfg.files.validation_output_mat = paths(candidateIndex).posterior;
    candidates(candidateIndex).cfg = cfg;
end

freeze.schema_version = 2;
freeze.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
freeze.candidate_ids = comparisonCandidateIds;
freeze.candidates = candidates;
freeze.paths = paths;
freeze.posterior_peak_distance_loaded = false;
freeze.posterior_peak_data_used_for_control = false;
freeze.posterior_peak_data_used_for_selection = false;
save(fullfile(resultRoot, 'candidate_comparison_freeze.mat'), ...
    'freeze', 'candidates', 'paths', '-v7.3');

fprintf('\n============================================================\n');
fprintf('DPLL 2P2Z 开/关统一对照验证\n');
fprintf('  输入范围 : [%g, %g] @ 3.125 MHz\n', ...
    inputSampleRange(1), inputSampleRange(2));
fprintf('  结果目录 : %s\n', resultRoot);
for candidateIndex = 1:candidateCount
    cfg = candidates(candidateIndex).cfg;
    fprintf(['  [%d] %s: 2P2Z=%d, CIC=%d, P%d, IIR=%.0f Hz, ' ...
        'Kp/Ki=%d/%d, BLEND Kp=%d\n'], candidateIndex, ...
        candidates(candidateIndex).label_cn, ...
        cfg.architecture.phase_2p2z_enable, cfg.cic.output_shift, ...
        cfg.shifts.p_product, cfg.iir.track_cutoff_hz, ...
        cfg.gains.kp_track, cfg.gains.ki_track, cfg.gains.kp_blend);
end
fprintf('============================================================\n\n');

%% Stage 1: freeze both causal reference-only replays

emptyRun = struct('candidate', struct(), 'cfg', struct(), ...
    'paths', struct(), 'result', struct(), 'summary', struct(), ...
    'prior', struct(), 'exact', struct(), 'validation', [], ...
    'acceptance', struct());
runs = repmat(emptyRun, candidateCount, 1);

for candidateIndex = 1:candidateCount
    candidate = candidates(candidateIndex);
    cfg = candidate.cfg;
    fprintf('\n--- reference-only replay %d/%d: %s ---\n', ...
        candidateIndex, candidateCount, candidate.label_cn);
    [result, summary, prior] = run_real_data_replay(cfg, false);
    if result.metadata.posterior_interval_data_used
        error('dpll:PosteriorContamination', ...
            'Reference-only replay is posterior-contaminated.');
    end

    exact = validate_exact_reference_cycle_events( ...
        result, exactEventMarginSeconds);
    if exact.posterior_peak_data_loaded
        error('dpll:PosteriorContamination', ...
            'Exact-113 validation loaded posterior peak data.');
    end

    save(paths(candidateIndex).exact, 'exact', 'summary', ...
        'candidate', '-v7.3');
    runs(candidateIndex).candidate = candidate;
    runs(candidateIndex).cfg = cfg;
    runs(candidateIndex).paths = paths(candidateIndex);
    runs(candidateIndex).result = result;
    runs(candidateIndex).summary = summary;
    runs(candidateIndex).prior = prior;
    runs(candidateIndex).exact = exact;
end

%% Stage 2: posterior peak validation only after both replays are frozen

if runPosteriorValidation
    for candidateIndex = 1:candidateCount
        fprintf('\n--- posterior validation %d/%d: %s ---\n', ...
            candidateIndex, candidateCount, ...
            runs(candidateIndex).candidate.label_cn);
        validation = run_peak_validation( ...
            string(paths(candidateIndex).replay), string(peakMat), ...
            string(paths(candidateIndex).posterior), false);
        runs(candidateIndex).validation = validation;
    end
end

for candidateIndex = 1:candidateCount
    runs(candidateIndex).acceptance = build_candidate_acceptance( ...
        runs(candidateIndex).summary, runs(candidateIndex).exact, ...
        runs(candidateIndex).validation, onePointThresholdCycles);
end

%% Save combined metrics, interval series, segments, and controller variables

comparisonMetrics = build_comparison_metrics(runs);
writetable(comparisonMetrics, fullfile(tableDir, ...
    'comparison_acceptance_metrics.csv'));
writetable(build_exact_interval_table(runs), fullfile(tableDir, ...
    'exact113_interval_series.csv'));
writetable(build_exact_segment_table(runs), fullfile(tableDir, ...
    'exact113_segment_metrics.csv'));
writetable(build_controller_table(runs, 10000), fullfile(tableDir, ...
    'controller_time_series.csv'));
if runPosteriorValidation
    writetable(build_posterior_interval_table(runs), fullfile(tableDir, ...
        'posterior_interval_series.csv'));
end

%% Fixed four-figure Chinese presentation

figureFiles = struct();
if exportChineseFigures
    figure1 = plot_internal_comparison_cn(runs, showPlots);
    figureFiles.figure1 = dpll.export_paper_figure(figure1, ...
        fullfile(figureDir, 'figure1_pll_internal_comparison_cn'), ...
        [9.4 7.2], 'Microsoft YaHei');

    figure2 = plot_virtual_stretch_comparison_cn(runs, ...
        onePointThresholdCycles, showPlots);
    figureFiles.figure2 = dpll.export_paper_figure(figure2, ...
        fullfile(figureDir, 'figure2_virtual_stretch_budget_cn'), ...
        [9.4 6.4], 'Microsoft YaHei');

    figure3 = plot_reference_only_distribution_cn(runs, ...
        onePointThresholdCycles, showPlots);
    figureFiles.figure3 = dpll.export_paper_figure(figure3, ...
        fullfile(figureDir, 'figure3_reference_only_distribution_cn'), ...
        [9.4 6.4], 'Microsoft YaHei');

    figure4 = plot_final_comparison_cn(runs, ...
        onePointThresholdCycles, showPlots);
    figureFiles.figure4 = dpll.export_paper_figure(figure4, ...
        fullfile(figureDir, 'figure4_final_acceptance_comparison_cn'), ...
        [10.0 8.0], 'Microsoft YaHei');

    if ~showPlots
        close(figure1); close(figure2); close(figure3); close(figure4);
    end
end

reportPath = fullfile(resultRoot, 'dpll_2p2z_comparison_report_cn.md');
write_comparison_report_cn(reportPath, comparisonMetrics, ...
    onePointThresholdCycles);

candidateRecords = repmat(struct('candidate_id', '', ...
    'candidate_label_cn', '', 'paths', struct(), 'summary', struct(), ...
    'acceptance', struct()), candidateCount, 1);
for candidateIndex = 1:candidateCount
    candidateRecords(candidateIndex).candidate_id = ...
        runs(candidateIndex).candidate.id;
    candidateRecords(candidateIndex).candidate_label_cn = ...
        runs(candidateIndex).candidate.label_cn;
    candidateRecords(candidateIndex).paths = runs(candidateIndex).paths;
    candidateRecords(candidateIndex).summary = runs(candidateIndex).summary;
    candidateRecords(candidateIndex).acceptance = ...
        runs(candidateIndex).acceptance;
end

comparisonRun.schema_version = 2;
comparisonRun.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
comparisonRun.result_root = resultRoot;
comparisonRun.candidate_ids = comparisonCandidateIds;
comparisonRun.candidate_records = candidateRecords;
comparisonRun.metrics = comparisonMetrics;
comparisonRun.figure_files = figureFiles;
comparisonRun.report_path = reportPath;
comparisonRun.posterior_peak_data_used_for_control = false;
comparisonRun.posterior_peak_data_used_for_selection = false;
save(fullfile(resultRoot, 'final_comparison_run.mat'), ...
    'comparisonRun', 'comparisonMetrics', 'candidates', 'paths', '-v7.3');

if runRegressionTests
    addpath(fullfile(scriptDir, 'tests'));
    run_all_tests();
end

fprintf('\n============================================================\n');
fprintf('DPLL 2P2Z 开/关对照完成\n');
for candidateIndex = 1:candidateCount
    value = runs(candidateIndex).acceptance;
    fprintf('  %s: exact RMS %.6f (%s), max %.6f (%s)', ...
        runs(candidateIndex).candidate.label_cn, ...
        value.reference_only.rms_cycles, ...
        pass_text_cn(value.reference_only.rms_pass), ...
        value.reference_only.max_abs_cycles, ...
        pass_text_cn(value.reference_only.all_intervals_pass));
    if ~isempty(runs(candidateIndex).validation)
        fprintf(', posterior total %.6f, loop-only %.6f', ...
            value.posterior.rms_cycles, ...
            value.posterior.loop_only_rms_cycles);
    end
    fprintf('\n');
end
fprintf('  Figure 2：%s\n', ...
    fullfile(figureDir, 'figure2_virtual_stretch_budget_cn.png'));
fprintf('  Figure 4：%s\n', ...
    fullfile(figureDir, 'figure4_final_acceptance_comparison_cn.png'));
fprintf('  报告：%s\n', reportPath);
fprintf('  结果：%s\n', resultRoot);
fprintf('============================================================\n');
fprintf(['工作区变量：runs, candidates, comparisonMetrics, ' ...
    'comparisonRun, figure1, figure2, figure3, figure4\n']);

%% Local analysis and presentation helpers

function acceptance = build_candidate_acceptance(summary, exact, ...
    validation, thresholdCycles)
referenceError = double(exact.pll_residual_error(:));
referenceAbs = abs(referenceError);
acceptance.internal.phase_rms_mrad = 1e3 * summary.phase_rms_rad;
acceptance.internal.track_fraction = summary.track_fraction;
acceptance.internal.controller_saturation_count = ...
    summary.controller_saturation_count;
acceptance.reference_only.interval_count = numel(referenceError);
acceptance.reference_only.rms_cycles = rms_plain(referenceError);
acceptance.reference_only.max_abs_cycles = max(referenceAbs);
acceptance.reference_only.over_one_point_fraction = ...
    mean(referenceAbs > thresholdCycles);
acceptance.reference_only.rms_pass = ...
    acceptance.reference_only.rms_cycles <= thresholdCycles;
acceptance.reference_only.all_intervals_pass = ...
    acceptance.reference_only.max_abs_cycles <= thresholdCycles;
acceptance.reference_only.endpoint_delta_phase_rms_mrad = ...
    exact.summary.delta_phase_113_rms_mrad;
acceptance.reference_only.endpoint_delta_phase_peak_abs_mrad = ...
    exact.summary.delta_phase_113_peak_abs_mrad;
acceptance.reference_only.posterior_data_used = false;

if isempty(validation)
    acceptance.posterior = [];
    return;
end
posteriorError = double(validation.recovered_interval_error(:));
posteriorAbs = abs(posteriorError);
acceptance.posterior.interval_count = numel(posteriorError);
acceptance.posterior.rms_cycles = rms_plain(posteriorError);
acceptance.posterior.max_abs_cycles = max(posteriorAbs);
acceptance.posterior.over_one_point_fraction = ...
    mean(posteriorAbs > thresholdCycles);
acceptance.posterior.rms_pass = ...
    acceptance.posterior.rms_cycles <= thresholdCycles;
acceptance.posterior.all_intervals_pass = ...
    acceptance.posterior.max_abs_cycles <= thresholdCycles;
acceptance.posterior.reference_event_rms_cycles = ...
    validation.summary.reference_event_rms_error;
acceptance.posterior.loop_only_rms_cycles = ...
    validation.summary.loop_only_rms_error;
acceptance.posterior.posterior_data_used = true;
end

function metrics = build_comparison_metrics(runs)
rows = repmat(struct(), numel(runs), 1);
for k = 1:numel(runs)
    value = runs(k).acceptance;
    rows(k).candidate_id = string(runs(k).candidate.id);
    rows(k).candidate_label_cn = string(runs(k).candidate.label_cn);
    rows(k).phase_2p2z_enabled = ...
        runs(k).cfg.architecture.phase_2p2z_enable;
    rows(k).p_product_shift = runs(k).cfg.shifts.p_product;
    rows(k).cic_output_shift = runs(k).cfg.cic.output_shift;
    rows(k).track_iir_cutoff_hz = runs(k).cfg.iir.track_cutoff_hz;
    rows(k).kp_track = runs(k).cfg.gains.kp_track;
    rows(k).ki_track = runs(k).cfg.gains.ki_track;
    rows(k).kp_blend = runs(k).cfg.gains.kp_blend;
    rows(k).internal_phase_rms_mrad = value.internal.phase_rms_mrad;
    rows(k).exact113_rms_cycles = value.reference_only.rms_cycles;
    rows(k).exact113_max_abs_cycles = ...
        value.reference_only.max_abs_cycles;
    rows(k).exact113_over_one_fraction = ...
        value.reference_only.over_one_point_fraction;
    rows(k).exact113_rms_pass = value.reference_only.rms_pass;
    rows(k).exact113_all_intervals_pass = ...
        value.reference_only.all_intervals_pass;
    rows(k).endpoint_phase_rms_mrad = ...
        value.reference_only.endpoint_delta_phase_rms_mrad;
    rows(k).endpoint_phase_peak_abs_mrad = ...
        value.reference_only.endpoint_delta_phase_peak_abs_mrad;
    if isempty(value.posterior)
        rows(k).posterior_total_rms_cycles = NaN;
        rows(k).posterior_total_max_abs_cycles = NaN;
        rows(k).posterior_over_one_fraction = NaN;
        rows(k).posterior_reference_event_rms_cycles = NaN;
        rows(k).posterior_loop_only_rms_cycles = NaN;
        rows(k).posterior_rms_pass = false;
        rows(k).posterior_all_intervals_pass = false;
    else
        rows(k).posterior_total_rms_cycles = value.posterior.rms_cycles;
        rows(k).posterior_total_max_abs_cycles = ...
            value.posterior.max_abs_cycles;
        rows(k).posterior_over_one_fraction = ...
            value.posterior.over_one_point_fraction;
        rows(k).posterior_reference_event_rms_cycles = ...
            value.posterior.reference_event_rms_cycles;
        rows(k).posterior_loop_only_rms_cycles = ...
            value.posterior.loop_only_rms_cycles;
        rows(k).posterior_rms_pass = value.posterior.rms_pass;
        rows(k).posterior_all_intervals_pass = ...
            value.posterior.all_intervals_pass;
    end
    rows(k).controller_saturation_count = ...
        value.internal.controller_saturation_count;
    rows(k).phase_2p2z_saturation_count = ...
        runs(k).result.status.phase_2p2z_saturation_high_count + ...
        runs(k).result.status.phase_2p2z_saturation_low_count;
    rows(k).posterior_peak_data_used_for_control = false;
    rows(k).posterior_peak_data_used_for_selection = false;
end
metrics = struct2table(rows);
end

function combined = build_exact_interval_table(runs)
combined = table();
for k = 1:numel(runs)
    exact = runs(k).exact;
    count = numel(exact.pll_residual_error);
    current = table(repmat(string(runs(k).candidate.id), count, 1), ...
        repmat(string(runs(k).candidate.label_cn), count, 1), ...
        (1:count).', exact.event_time_s(2:end), ...
        double(exact.pll_residual_error(:)), ...
        double(exact.equivalent_interval_error_cycles(:)), ...
        1e3 * double(exact.delta_phase_113_rad(:)), ...
        'VariableNames', {'candidate_id', 'candidate_label_cn', ...
        'interval_index', 'interval_end_time_s', ...
        'exact113_error_cycles', 'endpoint_equivalent_error_cycles', ...
        'endpoint_delta_phase_mrad'});
    combined = append_table(combined, current);
end
end

function combined = build_exact_segment_table(runs)
combined = table();
for k = 1:numel(runs)
    current = runs(k).exact.segment_metrics;
    count = height(current);
    current = addvars(current, ...
        repmat(string(runs(k).candidate.id), count, 1), ...
        repmat(string(runs(k).candidate.label_cn), count, 1), ...
        'Before', 1, 'NewVariableNames', ...
        {'candidate_id', 'candidate_label_cn'});
    combined = append_table(combined, current);
end
end

function combined = build_posterior_interval_table(runs)
combined = table();
for k = 1:numel(runs)
    validation = runs(k).validation;
    if isempty(validation), continue; end
    count = numel(validation.recovered_interval_error);
    current = table(repmat(string(runs(k).candidate.id), count, 1), ...
        repmat(string(runs(k).candidate.label_cn), count, 1), ...
        (1:count).', validation.peak_time_s(2:end), ...
        double(validation.uncompensated_interval_error_output_cycles(:)), ...
        double(validation.recovered_interval_error(:)), ...
        double(validation.reference_event_error(:)), ...
        double(validation.loop_only_error(:)), ...
        'VariableNames', {'candidate_id', 'candidate_label_cn', ...
        'interval_index', 'interval_end_time_s', ...
        'fixed_clock_equivalent_cycles', 'posterior_total_error_cycles', ...
        'reference_event_error_cycles', 'loop_only_error_cycles'});
    combined = append_table(combined, current);
end
end

function combined = build_controller_table(runs, maximumPoints)
combined = table();
for k = 1:numel(runs)
    result = runs(k).result;
    validIndices = find(result.trace.analysis_valid);
    if isempty(validIndices), continue; end
    position = unique(round(linspace(1, numel(validIndices), ...
        min(maximumPoints, numel(validIndices)))));
    indices = validIndices(position);
    wordToHz = double(result.config.fabric_clock_hz) / ...
        2^double(result.config.word_width);
    current = table(repmat(string(runs(k).candidate.id), ...
        numel(indices), 1), result.trace.time_s(indices), ...
        phase_mrad(result, indices), ...
        result.trace.tracking_frequency_hz(indices), ...
        double(result.trace.p_term(indices)) * wordToHz, ...
        double(result.trace.i_term(indices)) * wordToHz, ...
        double(result.trace.fll_term(indices)) * wordToHz, ...
        double(result.trace.phase_2p2z_term(indices)) * wordToHz, ...
        'VariableNames', {'candidate_id', 'time_s', ...
        'phase_error_mrad', 'tracking_frequency_hz', 'p_term_hz', ...
        'i_term_hz', 'fll_term_hz', 'phase_2p2z_term_hz'});
    combined = append_table(combined, current);
end
end

function fig = plot_internal_comparison_cn(runs, showPlots)
fig = prepare_figure(1, '图1 PLL 内部变量对照', showPlots);
layout = tiledlayout(fig, 3, 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '图1：PLL 内部变量对照（未加载真实峰间距）');
colors = comparison_colors();

nexttile;
for k = 1:numel(runs)
    indices = trace_plot_indices(runs(k).result, 8000);
    plot(runs(k).result.trace.time_s(indices), ...
        phase_mrad(runs(k).result, indices), 'Color', colors(k, :), ...
        'LineWidth', 0.8, 'DisplayName', short_label(runs(k))); hold on;
end
yline(0, ':k', 'HandleVisibility', 'off');
ylabel('相位残差（mrad）'); grid on; legend('Location', 'best');
title(sprintf('内部相位 RMS：关闭 %.3f，开启 %.3f mrad', ...
    runs(1).acceptance.internal.phase_rms_mrad, ...
    runs(2).acceptance.internal.phase_rms_mrad));

nexttile;
for k = 1:numel(runs)
    indices = trace_plot_indices(runs(k).result, 8000);
    plot(runs(k).result.trace.time_s(indices), ...
        runs(k).result.trace.tracking_frequency_hz(indices), ...
        'Color', colors(k, :), 'LineWidth', 0.8, ...
        'DisplayName', short_label(runs(k))); hold on;
end
ylabel('跟踪频率（Hz）'); grid on; legend('Location', 'best');
title('两套控制器输出频率');

nexttile;
baseline = runs(1).result;
enabled = runs(2).result;
count = min(numel(baseline.trace.time_s), numel(enabled.trace.time_s));
valid = baseline.trace.analysis_valid(1:count) & ...
    enabled.trace.analysis_valid(1:count);
validIndices = find(valid);
positions = unique(round(linspace(1, numel(validIndices), ...
    min(8000, numel(validIndices)))));
indices = validIndices(positions);
wordToHz = double(enabled.config.fabric_clock_hz) / ...
    2^double(enabled.config.word_width);
plot(enabled.trace.time_s(indices), ...
    double(enabled.trace.phase_2p2z_term(indices)) * wordToHz, ...
    'Color', [0.49 0.18 0.56], 'DisplayName', '2P2Z 直接校正量'); hold on;
plot(enabled.trace.time_s(indices), ...
    enabled.trace.tracking_frequency_hz(indices) - ...
    baseline.trace.tracking_frequency_hz(indices), ...
    'Color', [0.20 0.60 0.45], 'DisplayName', '开启-关闭输出频差');
yline(0, ':k', 'HandleVisibility', 'off');
xlabel('时间（s）'); ylabel('增量（Hz）'); grid on;
legend('Location', 'best'); title('2P2Z 实际增加了什么');
end

function fig = plot_virtual_stretch_comparison_cn(runs, threshold, showPlots)
fig = prepare_figure(2, '图2 虚拟拉伸与误差预算', showPlots);
layout = tiledlayout(fig, 2, 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '图2：真实峰 posterior 虚拟拉伸，只看补偿结果与误差来源');
colors = comparison_colors();

if isempty(runs(1).validation)
    nexttile([2 1]); axis off;
    text(0.5, 0.5, 'posterior 验证已关闭', ...
        'HorizontalAlignment', 'center');
    return;
end

nexttile;
time = runs(1).validation.peak_time_s(2:end);
plot(time, runs(1).validation.uncompensated_interval_error_output_cycles, ...
    '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 0.8, ...
    'DisplayName', '固定时钟等效误差（补偿前）'); hold on;
lineStyles = {'-', '--'};
for k = 1:numel(runs)
    plot(time, runs(k).validation.recovered_interval_error, '-', ...
        'Color', colors(k, :), 'LineWidth', 1.0, ...
        'LineStyle', lineStyles{k}, ...
        'DisplayName', [short_label(runs(k)) '最终总误差']);
end
yline(threshold, '--r', 'HandleVisibility', 'off');
yline(-threshold, '--r', 'HandleVisibility', 'off');
yline(0, ':k', 'HandleVisibility', 'off');
plot(nan, nan, '--r', 'DisplayName', '±1 点阈值');
ylabel('相邻峰间距误差（周期）'); grid on; legend('Location', 'best');
title('每个区间：DPLL 累计输出周期数 - 226000');

nexttile;
allValues = [];
for k = 1:numel(runs)
    eventError = double(runs(k).validation.reference_event_error(:));
    totalError = double(runs(k).validation.recovered_interval_error(:));
    plot(eventError, totalError, '.', 'Color', colors(k, :), ...
        'MarkerSize', 10, 'DisplayName', short_label(runs(k))); hold on;
    allValues = [allValues; eventError; totalError]; %#ok<AGROW>
end
limit = max(abs(allValues));
margin = max(1, 0.05 * limit);
plot([-limit-margin, limit+margin], [-limit-margin, limit+margin], ...
    '--k', 'LineWidth', 0.9, 'DisplayName', '总误差 = event');
xlim([-limit-margin, limit+margin]);
ylim([-limit-margin, limit+margin]);
axis square;
xlabel('reference-event（周期）');
ylabel('最终总误差（周期）'); grid on; legend('Location', 'best');
title({'逐区间误差来源：点越贴近45度线，event占比越高', ...
    sprintf('相关系数：关闭 %.4f，开启 %.4f；loop-only RMS：%.3f / %.3f 点', ...
    runs(1).validation.summary.total_vs_reference_event_correlation, ...
    runs(2).validation.summary.total_vs_reference_event_correlation, ...
    runs(1).acceptance.posterior.loop_only_rms_cycles, ...
    runs(2).acceptance.posterior.loop_only_rms_cycles)});
end

function fig = plot_reference_only_distribution_cn(runs, threshold, showPlots)
fig = prepare_figure(3, '图3 reference-only 对照', showPlots);
layout = tiledlayout(fig, 2, 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '图3：reference-only exact-113 对照（不使用真实峰）');
colors = comparison_colors();

nexttile;
for k = 1:numel(runs)
    time = runs(k).exact.event_time_s(2:end);
    plot(time, runs(k).exact.pll_residual_error, '-', ...
        'Color', colors(k, :), 'LineWidth', 0.9, ...
        'DisplayName', short_label(runs(k))); hold on;
end
yline(threshold, '--r', '+1 点', 'HandleVisibility', 'off');
yline(-threshold, '--r', '-1 点', 'HandleVisibility', 'off');
yline(0, ':k', 'HandleVisibility', 'off');
ylabel('exact-113 误差（周期）'); grid on; legend('Location', 'best');
title('每严格 113 个参考周期的输出间距误差');

nexttile;
for k = 1:numel(runs)
    values = sort(abs(double(runs(k).exact.pll_residual_error(:))));
    percentile = 100 * (1:numel(values)).' / numel(values);
    plot(values, percentile, 'Color', colors(k, :), ...
        'LineWidth', 1.2, 'DisplayName', short_label(runs(k))); hold on;
end
xline(threshold, '--r', '1 点阈值', 'HandleVisibility', 'off');
xlabel('绝对误差（周期）'); ylabel('累计区间比例（%）');
ylim([0 100]); grid on; legend('Location', 'best');
title('绝对误差累计分布，曲线越靠左越好');
end

function fig = plot_final_comparison_cn(runs, threshold, showPlots)
fig = prepare_figure(4, '图4 最终验收对照', showPlots);
layout = tiledlayout(fig, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, ['图4：端点相位残差与最终验收对照' ...
    '（1 点 = 1 output cycle = \pi mrad）']);
colors = comparison_colors();
lineStyles = {'-', '--'};
phaseThresholdMrad = pi * threshold;

nexttile([1 2]);
for k = 1:numel(runs)
    time = runs(k).exact.event_time_s(2:end);
    deltaMrad = 1e3 * double(runs(k).exact.delta_phase_113_rad(:));
    plot(time, deltaMrad, 'Color', colors(k, :), ...
        'LineStyle', lineStyles{k}, 'LineWidth', 1.0, ...
        'DisplayName', short_label(runs(k))); hold on;
end
yline(phaseThresholdMrad, '--r', 'HandleVisibility', 'off');
yline(-phaseThresholdMrad, '--r', 'HandleVisibility', 'off');
yline(0, ':k', 'HandleVisibility', 'off');
plot(nan, nan, '--r', 'DisplayName', '±\pi mrad（±1点）');
ylabel('113周期端点相位差（mrad）'); grid on;
legend('Location', 'best');
title(sprintf(['端点相位残差：关闭 RMS %.3f / 峰值 %.3f，' ...
    '开启 RMS %.3f / 峰值 %.3f mrad'], ...
    runs(1).acceptance.reference_only.endpoint_delta_phase_rms_mrad, ...
    runs(1).acceptance.reference_only.endpoint_delta_phase_peak_abs_mrad, ...
    runs(2).acceptance.reference_only.endpoint_delta_phase_rms_mrad, ...
    runs(2).acceptance.reference_only.endpoint_delta_phase_peak_abs_mrad));

nexttile;
for k = 1:numel(runs)
    values = sort(1e3 * abs(double(runs(k).exact.delta_phase_113_rad(:))));
    percentile = 100 * (1:numel(values)).' / numel(values);
    plot(values, percentile, 'Color', colors(k, :), ...
        'LineStyle', lineStyles{k}, 'LineWidth', 1.2, ...
        'DisplayName', short_label(runs(k))); hold on;
end
xline(phaseThresholdMrad, '--r', '\pi mrad 阈值', ...
    'HandleVisibility', 'off');
xlabel('绝对端点相位差（mrad）'); ylabel('累计区间比例（%）');
ylim([0 100]); grid on; legend('Location', 'best');
title('端点相位残差累计分布');

nexttile;
plot_acceptance_text_table(runs, threshold);
end

function plot_acceptance_text_table(runs, threshold)
axis off;
xlim([0 1]); ylim([0 1]);
hold on;
text(0.02, 0.96, '最终验收指标', 'FontWeight', 'bold', ...
    'FontSize', 11, 'VerticalAlignment', 'top');
text(0.53, 0.86, '关闭2P2Z', 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');
text(0.82, 0.86, '开启2P2Z', 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');

rowLabels = {'exact RMS（点）', 'exact 最大值（点）', ...
    'exact 超限区间', 'posterior 总 RMS', 'loop-only RMS'};
offValues = [runs(1).acceptance.reference_only.rms_cycles, ...
    runs(1).acceptance.reference_only.max_abs_cycles, ...
    100 * runs(1).acceptance.reference_only.over_one_point_fraction, ...
    runs(1).acceptance.posterior.rms_cycles, ...
    runs(1).acceptance.posterior.loop_only_rms_cycles];
onValues = [runs(2).acceptance.reference_only.rms_cycles, ...
    runs(2).acceptance.reference_only.max_abs_cycles, ...
    100 * runs(2).acceptance.reference_only.over_one_point_fraction, ...
    runs(2).acceptance.posterior.rms_cycles, ...
    runs(2).acceptance.posterior.loop_only_rms_cycles];
formats = {'%.3f', '%.3f', '%.1f%%', '%.3f', '%.3f'};
offPass = [offValues(1) <= threshold, offValues(2) <= threshold, ...
    offValues(3) == 0, offValues(4) <= threshold, offValues(5) <= threshold];
onPass = [onValues(1) <= threshold, onValues(2) <= threshold, ...
    onValues(3) == 0, onValues(4) <= threshold, onValues(5) <= threshold];
passColor = [0.10 0.50 0.25];
failColor = [0.75 0.15 0.12];

for row = 1:numel(rowLabels)
    y = 0.74 - (row - 1) * 0.13;
    text(0.03, y, rowLabels{row}, 'VerticalAlignment', 'middle');
    text(0.53, y, sprintf(formats{row}, offValues(row)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'Color', choose_color(offPass(row), passColor, failColor));
    text(0.82, y, sprintf(formats{row}, onValues(row)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'Color', choose_color(onPass(row), passColor, failColor));
    plot([0.02 0.98], [y - 0.06 y - 0.06], '-', ...
        'Color', [0.88 0.88 0.88], 'HandleVisibility', 'off');
end
text(0.03, 0.06, '绿色：达标；红色：未达标。RMS达标不代表逐区间达标。', ...
    'Color', [0.25 0.25 0.25], 'FontSize', 8);
end

function color = choose_color(passed, passColor, failColor)
if passed, color = passColor; else, color = failColor; end
end

function write_comparison_report_cn(path, metrics, threshold)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('dpll:ReportOpenFailed', 'Cannot create report: %s', path);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '# DPLL 2P2Z 开/关统一对照验证\n\n');
fprintf(fileId, '生成时间：%s\n\n', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf(fileId, ['两套配置在加载 `samplingPeakDistance` 前同时冻结。' ...
    '真实峰位置只用于 posterior 复核，从未进入控制器或候选选择。\n\n']);

fprintf(fileId, '## 对照指标\n\n');
fprintf(fileId, ['| 配置 | exact RMS | exact 最大值 | exact 超限 | ' ...
    '端点 RMS | posterior 总 RMS | event RMS | loop-only RMS |\n']);
fprintf(fileId, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(metrics)
    fprintf(fileId, ['| %s | %.6f | %.6f | %.2f%% | %.6f mrad | ' ...
        '%.6f | %.6f | %.6f |\n'], metrics.candidate_label_cn(k), ...
        metrics.exact113_rms_cycles(k), ...
        metrics.exact113_max_abs_cycles(k), ...
        100 * metrics.exact113_over_one_fraction(k), ...
        metrics.endpoint_phase_rms_mrad(k), ...
        metrics.posterior_total_rms_cycles(k), ...
        metrics.posterior_reference_event_rms_cycles(k), ...
        metrics.posterior_loop_only_rms_cycles(k));
end

fprintf(fileId, '\n## 图的固定职责\n\n');
fprintf(fileId, '- Figure 1：内部相位、跟踪频率和 2P2Z 实际增量。\n');
fprintf(fileId, ['- Figure 2：只画一次补偿前后时间序列，并用逐区间' ...
    '相关散点解释 reference-event 对总误差的支配程度。\n']);
fprintf(fileId, ['- Figure 3：不使用真实峰的 exact-113 时间序列和' ...
    '绝对误差分布。\n']);
fprintf(fileId, ['- Figure 4：保留端点相位残差 mrad 时间曲线和分布，' ...
    '并用紧凑表格给出最终阈值验收。\n']);

off = metrics(1, :);
on = metrics(2, :);
exactImprovement = 100 * (off.exact113_rms_cycles - ...
    on.exact113_rms_cycles) / off.exact113_rms_cycles;
loopImprovement = 100 * (off.posterior_loop_only_rms_cycles - ...
    on.posterior_loop_only_rms_cycles) / ...
    off.posterior_loop_only_rms_cycles;
fprintf(fileId, '\n## 判定\n\n');
fprintf(fileId, ['一点 RMS 阈值为 %.0f output cycle，对应端点相位差 ' ...
    '`pi mrad`。严格验收还要求最大绝对误差不超过一点。\n\n'], ...
    threshold);
fprintf(fileId, ['开启 2P2Z 后 exact-113 RMS 改善 **%.3f%%**，' ...
    'posterior loop-only RMS 改善 **%.3f%%**。\n\n'], ...
    exactImprovement, loopImprovement);
fprintf(fileId, ['2P2Z 是增量优化，不改变 posterior 总误差由 ' ...
    'reference-event 主导的结论。是否进入 HDL 应继续以' ...
    '独立参考段和实物自适应采样结果为准。\n']);
end

function fig = prepare_figure(number, name, showPlots)
fig = figure(number);
clf(fig);
if showPlots, visibility = 'on'; else, visibility = 'off'; end
set(fig, 'Visible', visibility, 'Color', 'w', 'Name', name);
end

function indices = trace_plot_indices(result, maximumPoints)
validIndices = find(result.trace.analysis_valid);
if isempty(validIndices)
    validIndices = (1:numel(result.trace.time_s)).';
end
positions = unique(round(linspace(1, numel(validIndices), ...
    min(maximumPoints, numel(validIndices)))));
indices = validIndices(positions);
end

function values = phase_mrad(result, indices)
values = double(result.trace.phase_error(indices)) * 1e3 * pi / ...
    2^(double(result.config.phase_width) - 1);
end

function colors = comparison_colors()
colors = [0.00 0.45 0.74; 0.85 0.33 0.10];
end

function label = short_label(run)
if run.cfg.architecture.phase_2p2z_enable
    label = '开启 2P2Z';
else
    label = '关闭 2P2Z';
end
end

function output = append_table(output, current)
if isempty(output), output = current; else, output = [output; current]; end
end

function value = rms_plain(values)
values = double(values(:));
if isempty(values), value = NaN; else, value = sqrt(mean(values.^2)); end
end

function text = pass_text_cn(passed)
if passed, text = '通过'; else, text = '未通过'; end
end
