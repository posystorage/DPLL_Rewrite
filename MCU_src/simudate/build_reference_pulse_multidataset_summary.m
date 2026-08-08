function aggregate = build_reference_pulse_multidataset_summary( ...
    analysis_dirs, output_root, options)
%BUILD_REFERENCE_PULSE_MULTIDATASET_SUMMARY Compare loop-free studies.

arguments
    analysis_dirs (:,1) string
    output_root (1,1) string
    options.labels (:,1) string = strings(0, 1)
    options.show_figures (1,1) logical = false
end

analysis_dirs = analysis_dirs(:);
if numel(analysis_dirs) < 2
    error('reference_analysis:TooFewStudies', ...
        'At least two analysis directories are required.');
end
if isfolder(output_root)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite multidataset summary: %s', output_root);
end
if isempty(options.labels)
    labels = arrayfun(@(k) "dataset " + k, ...
        (1:numel(analysis_dirs)).');
else
    labels = options.labels(:);
end
if numel(labels) ~= numel(analysis_dirs)
    error('reference_analysis:LabelCountMismatch', ...
        'labels must match the number of analysis directories.');
end

mkdir(output_root);
table_dir = fullfile(output_root, 'tables');
figure_dir = fullfile(output_root, 'figures');
mkdir(table_dir);
mkdir(figure_dir);

count = numel(analysis_dirs);
studies = cell(count, 1);
study_paths = strings(count, 1);
errors = cell(count, 1);
mismatches = cell(count, 1);
segments = cell(count, 1);
row_template = struct( ...
    'dataset', "", 'study_dataset_id', "", ...
    'reference_carrier_hz', NaN, 'peak_event_count', 0, ...
    'valid_interval_count', 0, ...
    'mean_peak_spacing_raw_samples', NaN, ...
    'reference_pulse_frequency_correlation', NaN, ...
    'frequency_mismatch_rms_hz', NaN, ...
    'frequency_mismatch_peak_abs_hz', NaN, ...
    'reference_event_rms_output_cycles', NaN, ...
    'reference_event_p95_abs_output_cycles', NaN, ...
    'reference_event_peak_abs_output_cycles', NaN, ...
    'reference_event_rms_mrad', NaN, ...
    'timing_residual_rms_raw_samples_62m5', NaN, ...
    'timing_residual_rms_ns', NaN, ...
    'minimum_observations_per_interval', 0, ...
    'iq_zero_event_delta_rms_output_cycles', NaN, ...
    'iq_zero_event_correlation', NaN, ...
    'best_train_delay_us', NaN, ...
    'validation_delay_improvement_percent', NaN, ...
    'segment_rms_min_output_cycles', NaN, ...
    'segment_rms_max_output_cycles', NaN, ...
    'posterior_peak_data_used_for_controller', false, ...
    'posterior_peak_data_used_for_training', false);
rows = repmat(row_template, count, 1);

for k = 1:count
    study_paths(k) = fullfile(analysis_dirs(k), ...
        'reference_pulse_relation_study.mat');
    if ~isfile(study_paths(k))
        error('reference_analysis:StudyNotFound', ...
            'Study MAT does not exist: %s', study_paths(k));
    end
    loaded = load(study_paths(k), 'study');
    if ~isfield(loaded, 'study')
        error('reference_analysis:InvalidStudy', ...
            'Study MAT has no study variable: %s', study_paths(k));
    end
    studies{k} = loaded.study;
    study = studies{k};
    summary = study.summary;
    interval = study.relation.interval;
    valid = interval.valid & ...
        isfinite(interval.reference_event_error_output_cycles);
    errors{k} = interval.reference_event_error_output_cycles(valid);
    mismatches{k} = interval.frequency_mismatch_hz(valid);

    rows(k).dataset = labels(k);
    rows(k).study_dataset_id = string(study.dataset_id);
    rows(k).reference_carrier_hz = summary.reference_carrier_hz;
    rows(k).peak_event_count = summary.peak_event_count;
    rows(k).valid_interval_count = summary.valid_interval_count;
    rows(k).mean_peak_spacing_raw_samples = ...
        mean(study.relation.peaks.interval_raw_samples);
    rows(k).reference_pulse_frequency_correlation = ...
        summary.reference_pulse_frequency_correlation;
    rows(k).frequency_mismatch_rms_hz = ...
        summary.frequency_mismatch_rms_hz;
    rows(k).frequency_mismatch_peak_abs_hz = ...
        summary.frequency_mismatch_peak_abs_hz;
    rows(k).reference_event_rms_output_cycles = ...
        summary.reference_event_rms_output_cycles;
    rows(k).reference_event_p95_abs_output_cycles = ...
        scalar_percentile(abs(errors{k}), 95);
    rows(k).reference_event_peak_abs_output_cycles = ...
        summary.reference_event_peak_abs_output_cycles;
    rows(k).reference_event_rms_mrad = summary.reference_event_rms_mrad;
    rows(k).timing_residual_rms_raw_samples_62m5 = ...
        summary.timing_residual_rms_raw_samples_62m5;
    rows(k).timing_residual_rms_ns = summary.timing_residual_rms_ns;
    rows(k).minimum_observations_per_interval = ...
        summary.minimum_observations_per_interval;
    rows(k).iq_zero_event_delta_rms_output_cycles = ...
        summary.iq_zero_event_delta_rms_output_cycles;
    rows(k).iq_zero_event_correlation = ...
        summary.iq_zero_event_correlation;
    rows(k).best_train_delay_us = 1e6 * summary.best_train_delay_s;
    rows(k).validation_delay_improvement_percent = ...
        summary.validation_delay_improvement_percent;
    rows(k).segment_rms_min_output_cycles = ...
        summary.segment_rms_min_output_cycles;
    rows(k).segment_rms_max_output_cycles = ...
        summary.segment_rms_max_output_cycles;
    rows(k).posterior_peak_data_used_for_controller = ...
        summary.posterior_peak_data_used_for_controller;
    rows(k).posterior_peak_data_used_for_training = ...
        summary.posterior_peak_data_used_for_training;

    segment = study.segment_metrics;
    segment.dataset = repmat(labels(k), height(segment), 1);
    segments{k} = movevars(segment, 'dataset', 'Before', 1);
end

summary_table = struct2table(rows);
segment_table = vertcat(segments{:});
provenance = table(labels, analysis_dirs, study_paths, ...
    arrayfun(@(p) string(dpll.file_sha256(p)), study_paths), ...
    'VariableNames', {'dataset', 'analysis_directory', ...
    'study_mat', 'study_sha256'});
writetable(summary_table, fullfile(table_dir, ...
    'multidataset_summary_metrics.csv'));
writetable(segment_table, fullfile(table_dir, ...
    'multidataset_segment_metrics.csv'));
writetable(provenance, fullfile(table_dir, ...
    'multidataset_source_provenance.csv'));

figure_files.overview = make_overview_figure(labels, errors, ...
    summary_table, figure_dir, options.show_figures);
figure_files.frequency = make_frequency_figure(labels, mismatches, ...
    summary_table, figure_dir, options.show_figures);

aggregate.schema_version = 1;
aggregate.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
aggregate.analysis_dirs = analysis_dirs;
aggregate.labels = labels;
aggregate.summary_metrics = summary_table;
aggregate.segment_metrics = segment_table;
aggregate.source_provenance = provenance;
aggregate.reference_event_errors = errors;
aggregate.frequency_mismatches = mismatches;
aggregate.figure_files = figure_files;
aggregate.simulated_loop_data_loaded = false;
aggregate.controller_configuration_used = false;
aggregate.posterior_peak_data_used_for_controller = false;
aggregate.posterior_peak_data_used_for_training = false;
aggregate.report_path = fullfile(output_root, ...
    'multidataset_reference_pulse_report_cn.md');
write_report(aggregate.report_path, aggregate);
save(fullfile(output_root, 'multidataset_reference_pulse_summary.mat'), ...
    'aggregate', '-v7.3');
end

function files = make_overview_figure(labels, errors, summary_table, ...
    figure_dir, show_figures)
visibility = 'off';
if show_figures, visibility = 'on'; end
colors = lines(numel(labels));
fig = figure('Visible', visibility, 'Color', 'w', ...
    'Position', [80 40 1500 1240]);
layout = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, '跨数据集 reference-event 误差与固定延迟泛化', ...
    'FontWeight', 'normal');

ax = nexttile(layout, 1, [1 2]);
hold(ax, 'on');
for k = 1:numel(labels)
    progress = linspace(0, 100, numel(errors{k})).';
    plot(ax, progress, errors{k}, 'LineWidth', 1.0, ...
        'Color', colors(k, :), 'DisplayName', labels(k));
end
yline(ax, 0, ':', 'Color', [0.25 0.25 0.25], ...
    'HandleVisibility', 'off');
xlabel(ax, '记录进度 (%)');
ylabel(ax, 'reference-event 误差 (等效输出点)');
title(ax, '逐峰间隔误差，共享纵轴');
legend(ax, 'Location', 'eastoutside');
grid(ax, 'on');

ax = nexttile(layout, 3);
hold(ax, 'on');
for k = 1:numel(labels)
    value = sort(abs(errors{k}));
    cumulative = 100 * (1:numel(value)).' / numel(value);
    plot(ax, value, cumulative, 'LineWidth', 1.6, ...
        'Color', colors(k, :), 'DisplayName', labels(k));
end
xlabel(ax, '|reference-event| (等效输出点)');
ylabel(ax, '累计区间比例 (%)');
title(ax, '绝对误差累计分布');
grid(ax, 'on');

ax = nexttile(layout, 4);
hold(ax, 'on');
for k = 1:numel(labels)
    rms_value = summary_table.reference_event_rms_output_cycles(k);
    p95_value = summary_table.reference_event_p95_abs_output_cycles(k);
    max_value = summary_table.reference_event_peak_abs_output_cycles(k);
    plot(ax, [rms_value max_value], [k k], '-', ...
        'Color', colors(k, :), 'LineWidth', 1.2);
    plot(ax, rms_value, k, 'o', 'Color', colors(k, :), ...
        'MarkerFaceColor', colors(k, :), 'MarkerSize', 7);
    plot(ax, p95_value, k, 'd', 'Color', colors(k, :), ...
        'MarkerFaceColor', 'w', 'MarkerSize', 7);
    plot(ax, max_value, k, '>', 'Color', colors(k, :), ...
        'MarkerFaceColor', colors(k, :), 'MarkerSize', 7);
end
set(ax, 'YTick', 1:numel(labels), 'YTickLabel', labels, ...
    'YDir', 'reverse');
xlabel(ax, '等效输出点');
title(ax, 'RMS (圆点)、P95 (菱形)、最大值 (三角)');
grid(ax, 'on');

ax = nexttile(layout, 5);
hold(ax, 'on');
xline(ax, 0, ':', 'Color', [0.25 0.25 0.25], ...
    'HandleVisibility', 'off');
yline(ax, 0, ':', 'Color', [0.25 0.25 0.25], ...
    'HandleVisibility', 'off');
short_labels = ["dat5"; "dat6"; "A"; "B"];
label_offsets = [-0.13; -0.05; 0.15; 0.12];
for k = 1:numel(labels)
    x = summary_table.best_train_delay_us(k);
    y = summary_table.validation_delay_improvement_percent(k);
    plot(ax, x, y, 'o', 'Color', colors(k, :), ...
        'MarkerFaceColor', colors(k, :), 'MarkerSize', 8);
    text(ax, x + 20, y + label_offsets(k), short_labels(k), ...
        'HorizontalAlignment', 'left', 'Color', colors(k, :), ...
        'FontSize', 10, 'Interpreter', 'none');
end
x_value = summary_table.best_train_delay_us;
y_value = summary_table.validation_delay_improvement_percent;
x_padding = max(100, 0.10 * (max(x_value) - min(x_value)));
y_padding = max(0.2, 0.12 * (max(y_value) - min(y_value)));
xlim(ax, [min(x_value) - x_padding, max(x_value) + 2 * x_padding]);
ylim(ax, [min(y_value) - y_padding, max(y_value) + y_padding]);
xlabel(ax, '训练段最优固定延迟 (us)');
ylabel(ax, '冻结后验证改善 (%)');
title(ax, '固定延迟的跨段泛化');
grid(ax, 'on');

ax = nexttile(layout, 6);
hold(ax, 'on');
for k = 1:numel(labels)
    low = summary_table.segment_rms_min_output_cycles(k);
    high = summary_table.segment_rms_max_output_cycles(k);
    overall = summary_table.reference_event_rms_output_cycles(k);
    plot(ax, [low high], [k k], '-', 'Color', colors(k, :), ...
        'LineWidth', 1.4);
    plot(ax, overall, k, 'o', 'Color', colors(k, :), ...
        'MarkerFaceColor', colors(k, :), 'MarkerSize', 7);
end
set(ax, 'YTick', 1:numel(labels), 'YTickLabel', labels, ...
    'YDir', 'reverse');
xlabel(ax, 'reference-event RMS (等效输出点)');
title(ax, '四段RMS范围与全段RMS (圆点)');
grid(ax, 'on');

files = dpll.export_paper_figure(fig, fullfile(figure_dir, ...
    'figure1_multidataset_reference_event_overview_cn'), ...
    [10.5 8.5], 'Microsoft YaHei');
if ~show_figures, close(fig); end
end

function files = make_frequency_figure(labels, mismatches, summary_table, ...
    figure_dir, show_figures)
visibility = 'off';
if show_figures, visibility = 'on'; end
colors = lines(numel(labels));
fig = figure('Visible', visibility, 'Color', 'w', ...
    'Position', [90 70 1500 980]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, '参考区间平均频率与固定时钟脉冲等效频率之差', ...
    'FontWeight', 'normal');
limit = 0;
for k = 1:numel(mismatches)
    limit = max(limit, max(abs(mismatches{k})));
end
limit = max(1, 1.05 * limit);
for k = 1:numel(labels)
    ax = nexttile(layout, k);
    progress = linspace(0, 100, numel(mismatches{k})).';
    plot(ax, progress, mismatches{k}, 'LineWidth', 1.0, ...
        'Color', colors(k, :));
    yline(ax, 0, ':', 'Color', [0.25 0.25 0.25], ...
        'HandleVisibility', 'off');
    ylim(ax, [-limit limit]);
    xlabel(ax, '记录进度 (%)');
    ylabel(ax, '参考 - 脉冲等效频率 (Hz)');
    title(ax, sprintf('%s：RMS %.3f Hz，相关系数 %.3f', ...
        labels(k), summary_table.frequency_mismatch_rms_hz(k), ...
        summary_table.reference_pulse_frequency_correlation(k)), ...
        'Interpreter', 'none');
    grid(ax, 'on');
end
files = dpll.export_paper_figure(fig, fullfile(figure_dir, ...
    'figure2_multidataset_frequency_mismatch_cn'), ...
    [10.5 8.0], 'Microsoft YaHei');
if ~show_figures, close(fig); end
end

function write_report(path, aggregate)
file_id = fopen(path, 'w', 'n', 'UTF-8');
if file_id < 0
    error('reference_analysis:ReportOpenFailed', ...
        'Cannot create report: %s', path);
end
cleanup = onCleanup(@() fclose(file_id));
table_value = aggregate.summary_metrics;
fprintf(file_id, '# dat5/dat6/dat8 输入参考与固定时钟脉冲关系汇总\n\n');
fprintf(file_id, ['本报告完全绕开DPLL。输入仅为CH2参考波形和固定62.5 MHz' ...
    '坐标中的峰时间戳；峰数据只用于posterior诊断。\n\n']);
fprintf(file_id, ['| 数据 | 载频 (Hz) | 峰数 | reference-event RMS (点) | ' ...
    'RMS (mrad) | 频率差RMS (Hz) | 训练延迟 (us) | 验证改善 |\n']);
fprintf(file_id, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(table_value)
    fprintf(file_id, '| %s | %.6f | %d | %.6f | %.6f | %.6f | %.1f | %.3f%% |\n', ...
        table_value.dataset(k), table_value.reference_carrier_hz(k), ...
        table_value.peak_event_count(k), ...
        table_value.reference_event_rms_output_cycles(k), ...
        table_value.reference_event_rms_mrad(k), ...
        table_value.frequency_mismatch_rms_hz(k), ...
        table_value.best_train_delay_us(k), ...
        table_value.validation_delay_improvement_percent(k));
end
fprintf(file_id, '\n## 判读\n\n');
fprintf(file_id, ['- dat5/dat6/dat8均满足每个峰间隔不少于20个参考频率观测点。\n' ...
    '- dat8存在两个高相关负峰族，本报告并列保留为候选A/B，不自动指定物理采样峰。\n' ...
    '- 训练段最优固定延迟冻结到验证段后的改善均很小或为负，' ...
    '不能据此宣称存在可部署的固定延迟校正。\n' ...
    '- 参考前端CIC/DC blocker的绝对群延迟尚未标定，因此延迟扫描仅是' ...
    'posterior/oracle诊断；区间相位增量和reference-event误差不依赖固定相位偏置。\n' ...
    '- 未加载任何DPLL replay、PI/2P2Z参数或控制器状态，也未将峰位用于控制器训练。\n']);
end

function value = scalar_percentile(values, percentile)
values = sort(double(values(isfinite(values))));
if isempty(values)
    value = NaN;
    return;
end
position = 1 + (numel(values) - 1) * percentile / 100;
left = floor(position);
right = ceil(position);
if left == right
    value = values(left);
else
    fraction = position - left;
    value = values(left) * (1 - fraction) + values(right) * fraction;
end
end
