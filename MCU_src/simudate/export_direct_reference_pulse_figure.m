function result = export_direct_reference_pulse_figure( ...
    study_source, output_dir, options)
%EXPORT_DIRECT_REFERENCE_PULSE_FIGURE Clear per-dataset direct comparison.

arguments
    study_source
    output_dir (1,1) string
    options.dataset_label (1,1) string = ""
    options.base_name (1,1) string = ...
        "figure3_direct_reference_pulse_comparison_cn"
    options.show_figure (1,1) logical = false
    options.export_data (1,1) logical = true
end

if ischar(study_source) || isstring(study_source)
    study_path = string(study_source);
    if ~isfile(study_path)
        error('reference_analysis:StudyNotFound', ...
            'Study MAT does not exist: %s', study_path);
    end
    loaded = load(study_path, 'study');
    study = loaded.study;
else
    study_path = "";
    study = study_source;
end
if ~isstruct(study) || ~isfield(study, 'relation') || ...
        ~isfield(study, 'summary')
    error('reference_analysis:InvalidStudy', ...
        'study_source must provide relation and summary structures.');
end
if strlength(options.dataset_label) == 0
    if isfield(study, 'dataset_id')
        label = string(study.dataset_id);
    else
        label = string(study.summary.dataset_id);
    end
else
    label = options.dataset_label;
end
if ~isfolder(output_dir), mkdir(output_dir); end
base_path = fullfile(output_dir, options.base_name);
extensions = [".png"; ".fig"];
for k = 1:numel(extensions)
    if isfile(base_path + extensions(k))
        error('reference_analysis:OutputExists', ...
            'Refusing to overwrite direct comparison figure: %s', ...
            base_path + extensions(k));
    end
end

relation = study.relation;
summary = study.summary;
valid = relation.interval.valid & ...
    isfinite(relation.interval.reference_average_frequency_hz) & ...
    isfinite(relation.interval.pulse_equivalent_frequency_hz) & ...
    isfinite(relation.interval.reference_event_error_output_cycles);
time_s = relation.interval.mid_time_s(valid);
reference_frequency_hz = ...
    relation.interval.reference_average_frequency_hz(valid);
pulse_frequency_hz = ...
    relation.interval.pulse_equivalent_frequency_hz(valid);
frequency_mismatch_hz = relation.interval.frequency_mismatch_hz(valid);
event_error_output_cycles = ...
    relation.interval.reference_event_error_output_cycles(valid);
event_error_mrad = relation.interval.reference_event_error_mrad(valid);
interval_index = relation.interval.index(valid);
plot_table = table(interval_index, time_s, reference_frequency_hz, ...
    pulse_frequency_hz, frequency_mismatch_hz, ...
    event_error_output_cycles, event_error_mrad, ...
    'VariableNames', {'interval_index', 'time_s', ...
    'reference_average_frequency_hz', ...
    'pulse_equivalent_frequency_113_over_T_hz', ...
    'reference_minus_pulse_frequency_hz', ...
    'reference_event_error_output_cycles', ...
    'reference_event_error_mrad'});

visibility = 'off';
if options.show_figure, visibility = 'on'; end
reference_color = [0.10 0.42 0.72];
pulse_color = [0.88 0.30 0.12];
error_color = [0.55 0.20 0.65];
cdf_color = [0.82 0.25 0.14];
fig = figure('Visible', visibility, 'Color', 'w', ...
    'Name', '输入参考与固定时钟脉冲直接对照');
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, sprintf('%s：输入参考与固定时钟脉冲逐间隔直接对照（无DPLL）', ...
    label), 'Interpreter', 'none', 'FontWeight', 'normal');

ax = nexttile(layout, 1);
plot(ax, time_s, reference_frequency_hz, '-', ...
    'Color', reference_color, 'LineWidth', 1.0, ...
    'DisplayName', '参考区间平均频率');
hold(ax, 'on');
plot(ax, time_s, pulse_frequency_hz, 'o-', ...
    'Color', pulse_color, 'MarkerSize', 2.5, 'LineWidth', 0.8, ...
    'DisplayName', '脉冲峰间距等效频率 113/T');
xlabel(ax, '时间（s）');
ylabel(ax, '频率（Hz）');
title(ax, sprintf('两条曲线越重合，同步越好；相关系数 %.3f', ...
    summary.reference_pulse_frequency_correlation));
legend(ax, 'Location', 'best');
grid(ax, 'on');

ax = nexttile(layout, 2);
yyaxis(ax, 'left');
frequency_line = plot(ax, time_s, frequency_mismatch_hz, '-', ...
    'Color', reference_color, 'LineWidth', 0.9);
hold(ax, 'on');
yline(ax, 0, ':k', 'HandleVisibility', 'off');
ylabel(ax, '参考频率 - 脉冲等效频率（Hz）');
yyaxis(ax, 'right');
event_line = plot(ax, time_s, event_error_output_cycles, '-', ...
    'Color', pulse_color, 'LineWidth', 0.9, ...
    'DisplayName', 'reference-event误差');
yline(ax, 0, ':', 'Color', [0.35 0.35 0.35], ...
    'HandleVisibility', 'off');
target_line = yline(ax, 1, '--', '±1点目标', ...
    'Color', [0.20 0.52 0.28], 'LabelHorizontalAlignment', 'left');
yline(ax, -1, '--', 'Color', [0.20 0.52 0.28], ...
    'HandleVisibility', 'off');
xlabel(ax, '时间（s）');
ylabel(ax, 'reference-event误差（等效输出点）');
title(ax, sprintf(['同一区间失配的双单位对照：RMS %.3f Hz；' ...
    '%.3f 点；%.3f mrad'], ...
    summary.frequency_mismatch_rms_hz, ...
    summary.reference_event_rms_output_cycles, ...
    summary.reference_event_rms_mrad));
legend(ax, [frequency_line event_line target_line], ...
    {'参考-脉冲频差（左轴）', ...
     'reference-event误差（右轴）', '±1点目标'}, ...
    'Location', 'best');
grid(ax, 'on');

ax = nexttile(layout, 3);
absolute_error = sort(abs(event_error_output_cycles));
probability = 100 * (1:numel(absolute_error)).' / numel(absolute_error);
plot(ax, absolute_error, probability, '-', ...
    'Color', cdf_color, 'LineWidth', 1.2);
hold(ax, 'on');
xline(ax, 1, ':', '1点目标', 'Color', [0.20 0.45 0.25]);
xline(ax, summary.reference_event_rms_output_cycles, '--', ...
    sprintf('RMS %.2f点', summary.reference_event_rms_output_cycles), ...
    'Color', error_color);
xlabel(ax, '|reference-event误差|（等效输出点）');
ylabel(ax, '累计区间比例（%）');
ylim(ax, [0 100]);
within_one_percent = 100 * mean(abs(event_error_output_cycles) <= 1);
p95 = scalar_percentile(abs(event_error_output_cycles), 95);
title(ax, sprintf('误差≤1点：%.1f%%；P95 %.2f点', ...
    within_one_percent, p95));
grid(ax, 'on');

files = dpll.export_paper_figure(fig, base_path, [10.2 10.0], ...
    'Microsoft YaHei', ["png", "fig"]);
if ~options.show_figure, close(fig); end

result.schema_version = 1;
result.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
result.dataset_label = char(label);
result.study_path = char(study_path);
result.figure_files = files;
result.valid_interval_count = height(plot_table);
result.within_one_point_percent = within_one_percent;
result.p95_abs_output_cycles = p95;
result.reference_event_rms_output_cycles = ...
    summary.reference_event_rms_output_cycles;
result.reference_event_rms_mrad = summary.reference_event_rms_mrad;
result.posterior_peak_diagnostic_only = true;
result.controller_data_used = false;
result.future_peak_used = false;
if options.export_data
    mat_path = fullfile(output_dir, 'direct_reference_pulse_data.mat');
    if isfile(mat_path)
        error('reference_analysis:OutputExists', ...
            'Refusing to overwrite direct comparison data: %s', mat_path);
    end
    save(mat_path, 'plot_table', 'result', '-v7.3');
    result.mat_path = char(mat_path);
end
end

function value = scalar_percentile(values, percentile)
values = sort(double(values(isfinite(values))));
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
