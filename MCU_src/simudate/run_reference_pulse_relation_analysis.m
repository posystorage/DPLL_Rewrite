function study = run_reference_pulse_relation_analysis( ...
    reference_mat, peak_mat, output_root, options)
%RUN_REFERENCE_PULSE_RELATION_ANALYSIS Loop-free reference/pulse study.
%
% Only the captured reference waveform and fixed-clock pulse timestamps are
% used. No DPLL replay, controller state, or candidate configuration is read.

arguments
    reference_mat (1,1) string
    peak_mat (1,1) string
    output_root (1,1) string
    options.dataset_id (1,1) string = "dataset"
    options.reference_cycles_per_pulse (1,1) double = 113
    options.output_multiplier (1,1) double = 2000
    options.observation_rate_hz (1,1) double = 4000
    options.iq_window_s (1,1) double = 0.001
    options.frequency_aperture_s (1,1) double = 0.001
    options.reference_guard_s (1,1) double = 0.050
    options.minimum_observations_per_interval (1,1) double = 16
    options.normalized_interval_bins (1,1) double = 24
    options.delay_scan_half_range_s (1,1) double = 0.003
    options.delay_scan_step_s (1,1) double = 1e-6
    options.train_fraction (1,1) double = 0.60
    options.show_figures (1,1) logical = true
    options.export_figures (1,1) logical = true
end

require_file(reference_mat, "Reference");
require_file(peak_mat, "Peak event");
if isfolder(output_root)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite reference/pulse result: %s', output_root);
end
validateattributes(options.normalized_interval_bins, {'numeric'}, ...
    {'integer', '>=', 8});
validateattributes(options.train_fraction, {'numeric'}, ...
    {'scalar', '>', 0.2, '<', 0.8});
mkdir(output_root);
raw_dir = fullfile(output_root, 'raw');
table_dir = fullfile(output_root, 'tables');
figure_dir = fullfile(output_root, 'figures');
mkdir(raw_dir); mkdir(table_dir); mkdir(figure_dir);

peaks = reference_analysis.load_peak_events(peak_mat);
probe = load_input_mat(reference_mat, [1 1]);
if abs(probe.source_raw_sample_rate_hz - peaks.raw_sample_rate_hz) > 1e-6
    error('reference_analysis:ReferencePeakTimebaseMismatch', ...
        'Reference and pulse-event raw timebases do not match.');
end
last_peak_input = 1 + (peaks.raw_index(end) - ...
    probe.source_raw_start_index) / probe.source_samples_per_input;
guard_samples = ceil(options.reference_guard_s * probe.sample_rate_hz);
last_input = ceil(last_peak_input) + guard_samples;
input_data = load_input_mat(reference_mat, [1 last_input]);

dense = reference_analysis.estimate_iq_phase( ...
    input_data.pll_input_codes, input_data.sample_rate_hz, ...
    observation_rate_hz=options.observation_rate_hz, ...
    iq_window_s=options.iq_window_s, ...
    frequency_aperture_s=options.frequency_aperture_s, ...
    source_start_time_s=(input_data.source_raw_start_index - 1) / ...
        input_data.source_raw_sample_rate_hz);
relation = reference_analysis.build_interval_relation(dense, peaks, ...
    reference_cycles_per_pulse=options.reference_cycles_per_pulse, ...
    output_multiplier=options.output_multiplier, ...
    minimum_observations_per_interval= ...
        options.minimum_observations_per_interval);
crosscheck = build_phase_method_crosscheck(dense, peaks, options);
delay_scan = build_delay_scan(dense, peaks, options);
normalized = build_normalized_interval_frequency(dense, relation, options);
segments = build_segment_metrics(relation, 4);
summary = build_summary(relation, crosscheck, delay_scan, segments, options);

interval_table = build_interval_table(relation.interval);
event_table = build_event_table(relation.event);
dense_table = table(dense.time_s, dense.phase_cycles, ...
    dense.frequency_hz, dense.amplitude_codes, ...
    'VariableNames', {'time_s', 'reference_phase_cycles', ...
    'reference_frequency_hz', 'iq_amplitude_codes'});
method_table = struct2table(crosscheck.metrics);
summary_table = struct2table(summary);
writetable(interval_table, fullfile(table_dir, ...
    'reference_pulse_interval_relation.csv'));
writetable(event_table, fullfile(table_dir, ...
    'reference_phase_at_pulse_events.csv'));
writetable(dense_table, fullfile(table_dir, ...
    'dense_reference_phase_frequency.csv'));
writetable(method_table, fullfile(table_dir, ...
    'phase_method_crosscheck.csv'));
writetable(delay_scan.table, fullfile(table_dir, ...
    'posterior_fixed_delay_scan.csv'));
writetable(segments, fullfile(table_dir, 'segment_metrics.csv'));
writetable(summary_table, fullfile(table_dir, 'summary_metrics.csv'));
writetable(build_normalized_table(normalized), fullfile(table_dir, ...
    'normalized_interval_frequency.csv'));

provenance = table( ...
    ["reference_waveform"; "fixed_clock_peak_events"], ...
    [reference_mat; peak_mat], ...
    [string(dpll.file_sha256(reference_mat)); ...
     string(dpll.file_sha256(peak_mat))], ...
    'VariableNames', {'role', 'path', 'sha256'});
writetable(provenance, fullfile(table_dir, 'source_provenance.csv'));

figure_files = struct();
if options.export_figures
    figure_files = make_figures(relation, normalized, delay_scan, ...
        segments, summary, options, figure_dir);
end

study.schema_version = 1;
study.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
study.dataset_id = char(options.dataset_id);
study.method = ['Reference-only symmetric IQ phase accumulation and ' ...
    'posterior fixed-clock event comparison'];
study.options = options;
study.reference_mat = char(reference_mat);
study.peak_mat = char(peak_mat);
study.output_root = char(output_root);
study.reference_input = rmfield(input_data, 'pll_input_codes');
study.dense = dense;
study.relation = relation;
study.crosscheck = crosscheck;
study.delay_scan = delay_scan;
study.normalized = normalized;
study.segment_metrics = segments;
study.summary = summary;
study.provenance = provenance;
study.figure_files = figure_files;
study.simulated_loop_data_loaded = false;
study.controller_configuration_used = false;
study.posterior_peak_data_used_for_controller = false;
study.posterior_peak_data_used_for_training = false;
study.frontend_group_delay_calibrated = false;
study.report_path = fullfile(output_root, ...
    'reference_pulse_relation_report_cn.md');
write_report(study.report_path, study);

save(fullfile(raw_dir, 'reference_pulse_relation_raw.mat'), ...
    'study', '-v7.3');
save(fullfile(output_root, 'reference_pulse_relation_study.mat'), ...
    'study', '-v7.3');

fprintf('\n独立参考—脉冲关系分析完成：%s\n', options.dataset_id);
fprintf('  载频                    : %.9f Hz\n', ...
    summary.reference_carrier_hz);
fprintf('  每峰间隔最少频率观测点  : %d\n', ...
    summary.minimum_observations_per_interval);
fprintf('  reference-event RMS     : %.6f output cycles\n', ...
    summary.reference_event_rms_output_cycles);
fprintf('  参考/脉冲频率差 RMS      : %.6f Hz\n', ...
    summary.frequency_mismatch_rms_hz);
fprintf('  最佳训练延迟/验证改善     : %.3f us / %.3f %%\n', ...
    1e6 * summary.best_train_delay_s, ...
    summary.validation_delay_improvement_percent);
fprintf('  报告                     : %s\n', study.report_path);
end

function crosscheck = build_phase_method_crosscheck(dense, peaks, options)
crossing_time_s = (double(dense.crossing_index(:)) - 1) / ...
    dense.sample_rate_hz + dense.source_start_time_s;
crossing_phase_cycles = double(dense.crossing_cycle(:));
peak_time = double(peaks.time_s(:));
zero_phase = interp1(crossing_time_s, crossing_phase_cycles, ...
    peak_time, 'pchip', NaN);
iq_phase = interp1(dense.time_s, dense.phase_cycles, peak_time, ...
    'pchip', NaN);
ratio = options.reference_cycles_per_pulse;
multiplier = options.output_multiplier;
iq_error = multiplier * (diff(iq_phase) - ratio);
zero_error = multiplier * (diff(zero_phase) - ratio);
valid = isfinite(iq_error) & isfinite(zero_error);
iq_error = iq_error(valid);
zero_error = zero_error(valid);
delta = iq_error - zero_error;

metric_template = struct('method', "", 'count', 0, ...
    'rms_output_cycles', NaN, 'peak_abs_output_cycles', NaN, ...
    'mean_output_cycles', NaN);
metrics = repmat(metric_template, 3, 1);
metrics(1) = method_metric("symmetric_iq", iq_error);
metrics(2) = method_metric("positive_zero_crossing", zero_error);
metrics(3) = method_metric("iq_minus_zero_crossing", delta);

correlation_matrix = corrcoef(iq_error, zero_error);
crosscheck.metrics = metrics;
crosscheck.valid_interval = valid;
crosscheck.iq_error_output_cycles = iq_error;
crosscheck.zero_crossing_error_output_cycles = zero_error;
crosscheck.delta_output_cycles = delta;
crosscheck.iq_zero_correlation = correlation_matrix(1, 2);
end

function metric = method_metric(name, value)
metric.method = name;
metric.count = numel(value);
metric.rms_output_cycles = rms_plain(value);
metric.peak_abs_output_cycles = max(abs(value));
metric.mean_output_cycles = mean(value);
end

function scan = build_delay_scan(dense, peaks, options)
half_range = options.delay_scan_half_range_s;
step = options.delay_scan_step_s;
shift_s = (-half_range:step:half_range).';
if isempty(shift_s) || ~any(abs(shift_s) < step / 2)
    shift_s = sort([shift_s; 0]);
end
peak_time = double(peaks.time_s(:));
coverage = peak_time >= dense.time_s(1) + half_range & ...
    peak_time <= dense.time_s(end) - half_range;
indices = find(coverage);
if numel(indices) < 20 || any(diff(indices) ~= 1)
    error('reference_analysis:InsufficientDelayCoverage', ...
        'Delay scan does not contain one contiguous 20-event region.');
end
peak_time = peak_time(indices(1):indices(end));
interval_count = numel(peak_time) - 1;
train_end = floor(options.train_fraction * interval_count);
train_end = max(8, min(interval_count - 8, train_end));

train_rms = nan(size(shift_s));
validation_rms = nan(size(shift_s));
all_rms = nan(size(shift_s));
ratio = options.reference_cycles_per_pulse;
multiplier = options.output_multiplier;
for k = 1:numel(shift_s)
    phase = interp1(dense.time_s, dense.phase_cycles, ...
        peak_time + shift_s(k), 'pchip', NaN);
    error_cycles = multiplier * (diff(phase) - ratio);
    train_rms(k) = rms_plain(error_cycles(1:train_end));
    validation_rms(k) = rms_plain(error_cycles(train_end + 1:end));
    all_rms(k) = rms_plain(error_cycles);
end
[~, best_index] = min(train_rms);
[~, zero_index] = min(abs(shift_s));
zero_validation = validation_rms(zero_index);
best_validation = validation_rms(best_index);

scan.table = table(shift_s, 1e6 * shift_s, train_rms, ...
    validation_rms, all_rms, ...
    'VariableNames', {'delay_s', 'delay_us', 'train_rms_output_cycles', ...
    'validation_rms_output_cycles', 'all_rms_output_cycles'});
scan.covered_peak_indices = (indices(1):indices(end)).';
scan.train_interval_count = train_end;
scan.validation_interval_count = interval_count - train_end;
scan.best_train_index = best_index;
scan.best_train_delay_s = shift_s(best_index);
scan.best_train_rms_output_cycles = train_rms(best_index);
scan.best_train_validation_rms_output_cycles = best_validation;
scan.zero_delay_validation_rms_output_cycles = zero_validation;
scan.validation_improvement_percent = 100 * ...
    (zero_validation - best_validation) / zero_validation;
scan.posterior_oracle_diagnostic = true;
scan.delay_used_for_controller = false;
end

function normalized = build_normalized_interval_frequency( ...
    dense, relation, options)
use = find(relation.interval.valid);
normalized_phase = linspace(0, 1, ...
    options.normalized_interval_bins).';
frequency = nan(numel(use), numel(normalized_phase));
frequency_valid = isfinite(dense.frequency_hz);
frequency_time = dense.time_s(frequency_valid);
frequency_value = dense.frequency_hz(frequency_valid);
for k = 1:numel(use)
    index = use(k);
    time = relation.interval.start_time_s(index) + ...
        normalized_phase * relation.interval.duration_s(index);
    frequency(k, :) = interp1(frequency_time, frequency_value, ...
        time, 'pchip', NaN).';
end
interval_mean = relation.interval.reference_average_frequency_hz(use);
deviation = frequency - interval_mean;
normalized.interval_index = use;
normalized.interval_mid_time_s = relation.interval.mid_time_s(use);
normalized.normalized_phase = normalized_phase;
normalized.frequency_hz = frequency;
normalized.deviation_from_interval_mean_hz = deviation;
normalized.median_deviation_hz = column_percentile(deviation, 50);
normalized.p10_deviation_hz = column_percentile(deviation, 10);
normalized.p90_deviation_hz = column_percentile(deviation, 90);
end

function table_value = build_interval_table(interval)
table_value = table(interval.index, interval.start_time_s, ...
    interval.end_time_s, interval.mid_time_s, interval.duration_s, ...
    interval.raw_samples_62m5, interval.reference_observation_count, ...
    interval.phase_increment_cycles, ...
    interval.pulse_equivalent_frequency_hz, ...
    interval.reference_average_frequency_hz, ...
    interval.frequency_mismatch_hz, ...
    interval.reference_event_error_output_cycles, ...
    interval.reference_event_error_mrad, ...
    interval.identity_rhs_output_cycles, ...
    interval.identity_residual_output_cycles, ...
    interval.predicted_next_time_s, interval.timing_residual_s, ...
    interval.timing_residual_raw_samples_62m5, interval.valid, ...
    'VariableNames', {'interval_index', 'start_time_s', 'end_time_s', ...
    'mid_time_s', 'duration_s', 'raw_samples_62m5', ...
    'reference_observation_count', 'phase_increment_cycles', ...
    'pulse_equivalent_frequency_hz', 'reference_average_frequency_hz', ...
    'frequency_mismatch_hz', 'reference_event_error_output_cycles', ...
    'reference_event_error_mrad', 'identity_rhs_output_cycles', ...
    'identity_residual_output_cycles', 'predicted_next_time_s', ...
    'timing_residual_s', 'timing_residual_raw_samples_62m5', 'valid'});
end

function table_value = build_event_table(event)
anchor = repmat(event.free_run_anchor_index, numel(event.index), 1);
table_value = table(event.index, event.raw_index, event.time_s, ...
    event.reference_phase_cycles, event.coverage, anchor, ...
    event.free_run_target_phase_cycles, event.free_run_predicted_time_s, ...
    event.phase_residual_cycles, event.phase_wrapped_cycles, ...
    'VariableNames', {'event_index', 'raw_index_62m5', 'time_s', ...
    'reference_phase_cycles', 'coverage', 'free_run_anchor_index', ...
    'free_run_target_phase_cycles', 'free_run_predicted_time_s', ...
    'phase_residual_cycles', 'phase_wrapped_cycles'});
end

function table_value = build_normalized_table(normalized)
[interval_grid, phase_grid] = ndgrid(normalized.interval_index, ...
    normalized.normalized_phase);
time_grid = repmat(normalized.interval_mid_time_s(:), 1, ...
    numel(normalized.normalized_phase));
table_value = table(interval_grid(:), time_grid(:), phase_grid(:), ...
    normalized.frequency_hz(:), ...
    normalized.deviation_from_interval_mean_hz(:), ...
    'VariableNames', {'interval_index', 'interval_mid_time_s', ...
    'normalized_interval_phase', 'reference_frequency_hz', ...
    'deviation_from_interval_mean_hz'});
end

function segments = build_segment_metrics(relation, segment_count)
valid_index = find(relation.interval.valid);
edges = round(linspace(1, numel(valid_index) + 1, segment_count + 1));
rows = repmat(struct(), segment_count, 1);
for k = 1:segment_count
    selected = valid_index(edges(k):edges(k + 1) - 1);
    error_cycles = relation.interval.reference_event_error_output_cycles(selected);
    mismatch = relation.interval.frequency_mismatch_hz(selected);
    rows(k).segment = k;
    rows(k).first_interval_index = selected(1);
    rows(k).last_interval_index = selected(end);
    rows(k).start_time_s = relation.interval.start_time_s(selected(1));
    rows(k).end_time_s = relation.interval.end_time_s(selected(end));
    rows(k).interval_count = numel(selected);
    rows(k).reference_event_rms_output_cycles = rms_plain(error_cycles);
    rows(k).reference_event_peak_abs_output_cycles = max(abs(error_cycles));
    rows(k).frequency_mismatch_rms_hz = rms_plain(mismatch);
end
segments = struct2table(rows);
end

function summary = build_summary(relation, crosscheck, delay_scan, ...
    segments, options)
valid = relation.interval.valid;
reference_frequency = ...
    relation.interval.reference_average_frequency_hz(valid);
pulse_frequency = relation.interval.pulse_equivalent_frequency_hz(valid);
frequency_delta = reference_frequency - pulse_frequency;
correlation_matrix = corrcoef(reference_frequency, pulse_frequency);
fit_value = polyfit(pulse_frequency, reference_frequency, 1);
fitted = polyval(fit_value, pulse_frequency);

summary.dataset_id = options.dataset_id;
summary.reference_carrier_hz = relation.dense.carrier_frequency_hz;
summary.peak_event_count = relation.peaks.event_count;
summary.valid_interval_count = relation.summary.valid_interval_count;
summary.fractional_peak_distance_count = ...
    relation.peaks.fractional_distance_count;
summary.minimum_observations_per_interval = ...
    relation.summary.minimum_observations_per_valid_interval;
summary.median_observations_per_interval = ...
    relation.summary.median_observations_per_valid_interval;
summary.reference_frequency_mean_hz = mean(reference_frequency);
summary.reference_frequency_std_hz = std(reference_frequency);
summary.pulse_equivalent_frequency_mean_hz = mean(pulse_frequency);
summary.pulse_equivalent_frequency_std_hz = std(pulse_frequency);
summary.reference_pulse_frequency_correlation = correlation_matrix(1, 2);
summary.reference_from_pulse_fit_slope = fit_value(1);
summary.reference_from_pulse_fit_intercept_hz = fit_value(2);
summary.reference_from_pulse_fit_rms_hz = rms_plain(reference_frequency - fitted);
summary.frequency_mismatch_mean_hz = mean(frequency_delta);
summary.frequency_mismatch_rms_hz = rms_plain(frequency_delta);
summary.frequency_mismatch_peak_abs_hz = max(abs(frequency_delta));
summary.reference_event_rms_output_cycles = ...
    relation.summary.reference_event_rms_output_cycles;
summary.reference_event_peak_abs_output_cycles = ...
    relation.summary.reference_event_peak_abs_output_cycles;
summary.reference_event_rms_mrad = relation.summary.reference_event_rms_mrad;
summary.timing_residual_rms_raw_samples_62m5 = ...
    relation.summary.timing_residual_rms_raw_samples_62m5;
summary.timing_residual_rms_ns = 1e9 * ...
    summary.timing_residual_rms_raw_samples_62m5 / ...
    relation.peaks.raw_sample_rate_hz;
summary.phase_identity_max_abs_output_cycles = ...
    relation.summary.identity_max_abs_output_cycles;
summary.iq_zero_event_delta_rms_output_cycles = ...
    crosscheck.metrics(3).rms_output_cycles;
summary.iq_zero_event_correlation = crosscheck.iq_zero_correlation;
summary.best_train_delay_s = delay_scan.best_train_delay_s;
summary.best_train_rms_output_cycles = ...
    delay_scan.best_train_rms_output_cycles;
summary.best_delay_validation_rms_output_cycles = ...
    delay_scan.best_train_validation_rms_output_cycles;
summary.zero_delay_validation_rms_output_cycles = ...
    delay_scan.zero_delay_validation_rms_output_cycles;
summary.validation_delay_improvement_percent = ...
    delay_scan.validation_improvement_percent;
summary.segment_rms_min_output_cycles = ...
    min(segments.reference_event_rms_output_cycles);
summary.segment_rms_max_output_cycles = ...
    max(segments.reference_event_rms_output_cycles);
summary.simulated_loop_data_loaded = false;
summary.posterior_peak_data_used_for_controller = false;
summary.posterior_peak_data_used_for_training = false;
summary.frontend_group_delay_calibrated = false;
end

function files = make_figures(relation, normalized, delay_scan, ...
    segments, summary, options, figure_dir)
visibility = 'off';
if options.show_figures, visibility = 'on'; end
files = struct();
files.figure1 = make_frequency_figure(relation, summary, options, ...
    figure_dir, visibility);
files.figure2 = make_prediction_figure(relation, summary, options, ...
    figure_dir, visibility);
files.figure3 = make_phase_figure(relation, normalized, summary, options, ...
    figure_dir, visibility);
files.figure4 = make_delay_figure(relation, delay_scan, segments, ...
    summary, options, figure_dir, visibility);
end

function files = make_frequency_figure(relation, summary, options, ...
    figure_dir, visibility)
fig = figure('Visible', visibility, 'Color', 'w', ...
    'Name', '输入参考与固定时钟脉冲频率关系');
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, sprintf('%s：输入参考频率与固定时钟脉冲变化关系（无锁相环）', ...
    options.dataset_id), 'Interpreter', 'none');
valid = relation.interval.valid;

nexttile;
plot(relation.dense.time_s, relation.dense.frequency_hz, '-', ...
    'Color', [0.10 0.42 0.72], 'LineWidth', 0.65, ...
    'DisplayName', 'IQ累计相位参考频率'); hold on;
plot(relation.interval.mid_time_s(valid), ...
    relation.interval.pulse_equivalent_frequency_hz(valid), '.', ...
    'Color', [0.88 0.30 0.12], 'MarkerSize', 7, ...
    'DisplayName', '固定时钟脉冲等效频率 113/T');
ylabel('等效参考频率（Hz）'); grid on; legend('Location', 'best');
title(sprintf('全时段：频率相关系数 %.3f', ...
    summary.reference_pulse_frequency_correlation));

nexttile;
plot(relation.interval.mid_time_s(valid), ...
    relation.interval.frequency_mismatch_hz(valid), '-', ...
    'Color', [0.55 0.20 0.65], 'LineWidth', 0.9); hold on;
yline(0, ':k', 'HandleVisibility', 'off');
ylabel('参考－脉冲等效频差（Hz）'); grid on;
title(sprintf('RMS %.3f Hz，最大 %.3f Hz', ...
    summary.frequency_mismatch_rms_hz, ...
    summary.frequency_mismatch_peak_abs_hz));

valid_index = find(valid);
center = valid_index(max(1, round(numel(valid_index) / 2)));
selected = max(valid_index(1), center - 3):min(valid_index(end), center + 3);
left_time = relation.interval.start_time_s(selected(1));
right_time = relation.interval.end_time_s(selected(end));
nexttile;
use_dense = relation.dense.time_s >= left_time & ...
    relation.dense.time_s <= right_time;
plot(relation.dense.time_s(use_dense), ...
    relation.dense.frequency_hz(use_dense), '-', ...
    'Color', [0.10 0.42 0.72], 'LineWidth', 1.0); hold on;
stairs(relation.interval.start_time_s(selected), ...
    relation.interval.pulse_equivalent_frequency_hz(selected), '-', ...
    'Color', [0.88 0.30 0.12], 'LineWidth', 1.0);
for k = selected
    xline(relation.interval.start_time_s(k), ':', ...
        'Color', [0.65 0.65 0.65], 'HandleVisibility', 'off');
end
xlabel('时间（s）'); ylabel('频率（Hz）'); grid on;
title(sprintf('局部放大：每个峰间隔至少 %d 个参考频率观测点', ...
    summary.minimum_observations_per_interval));
files = dpll.export_paper_figure(fig, fullfile(figure_dir, ...
    'figure1_reference_pulse_frequency_cn'), [10.0 7.4], ...
    'Microsoft YaHei');
if strcmp(visibility, 'off'), close(fig); end
end

function files = make_prediction_figure(relation, summary, options, ...
    figure_dir, visibility)
fig = figure('Visible', visibility, 'Color', 'w', ...
    'Name', '参考预测脉冲间距');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, sprintf('%s：参考累计相位对下一真实峰的直接预测', ...
    options.dataset_id), 'Interpreter', 'none');
valid = relation.interval.valid & ...
    isfinite(relation.interval.predicted_next_time_s);
actual = relation.interval.raw_samples_62m5(valid);
predicted = (relation.interval.predicted_next_time_s(valid) - ...
    relation.interval.start_time_s(valid)) * ...
    relation.peaks.raw_sample_rate_hz;
time = relation.interval.mid_time_s(valid);
center = mean(actual);

nexttile([1 2]);
plot(time, actual - center, '-', 'Color', [0.16 0.36 0.68], ...
    'LineWidth', 0.9, 'DisplayName', '实测固定时钟峰间距'); hold on;
plot(time, predicted - center, '-', 'Color', [0.86 0.32 0.13], ...
    'LineWidth', 0.9, 'DisplayName', '参考相位预测间距');
yline(0, ':k', 'HandleVisibility', 'off');
ylabel('相对共同中心（62.5 MHz点）'); grid on;
legend('Location', 'best');

nexttile;
residual = actual - predicted;
plot(time, residual, '-', 'Color', [0.52 0.22 0.62], ...
    'LineWidth', 0.9); hold on;
yline(0, ':k'); ylabel('实测－参考预测（原始点）'); grid on;
title(sprintf('RMS %.2f 点 = %.1f ns', ...
    summary.timing_residual_rms_raw_samples_62m5, ...
    summary.timing_residual_rms_ns));

nexttile;
x = relation.interval.pulse_equivalent_frequency_hz(valid);
y = relation.interval.reference_average_frequency_hz(valid);
plot(x, y, '.', 'Color', [0.20 0.47 0.68], 'MarkerSize', 7); hold on;
limit = [min([x; y]), max([x; y])];
plot(limit, limit, '--k', 'LineWidth', 0.8);
xlim(limit); ylim(limit); axis square; grid on;
xlabel('固定峰间距等效参考频率 113/T（Hz）');
ylabel('输入参考区间平均频率（Hz）');
title(sprintf('频率变化相关系数 %.3f', ...
    summary.reference_pulse_frequency_correlation));
files = dpll.export_paper_figure(fig, fullfile(figure_dir, ...
    'figure2_reference_predicted_spacing_cn'), [10.0 7.2], ...
    'Microsoft YaHei');
if strcmp(visibility, 'off'), close(fig); end
end

function files = make_phase_figure(relation, ~, summary, options, ...
    figure_dir, visibility)
% The normalized heatmap remains in the MAT/CSV for supplemental analysis.
% The primary figure uses only direct quantities that share each real peak
% interval, so reference and pulse semantics stay visually consistent.
source.relation = relation;
source.summary = summary;
source.dataset_id = char(options.dataset_id);
files = export_direct_reference_pulse_figure(source, figure_dir, ...
    dataset_label=options.dataset_id, ...
    base_name="figure3_reference_event_phase_cn", ...
    show_figure=strcmp(visibility, 'on'), export_data=false);
end

function files = make_delay_figure(relation, delay_scan, segments, ...
    summary, options, figure_dir, visibility)
fig = figure('Visible', visibility, 'Color', 'w', ...
    'Name', '固定延迟与同步诊断');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, sprintf('%s：固定延迟、频率一致性与分段稳定性诊断', ...
    options.dataset_id), 'Interpreter', 'none');

nexttile;
plot(delay_scan.table.delay_us, ...
    delay_scan.table.train_rms_output_cycles, '-', ...
    'Color', [0.14 0.42 0.72], 'DisplayName', '训练段'); hold on;
plot(delay_scan.table.delay_us, ...
    delay_scan.table.validation_rms_output_cycles, '-', ...
    'Color', [0.86 0.30 0.12], 'DisplayName', '验证段');
xline(1e6 * delay_scan.best_train_delay_s, '--k', ...
    'DisplayName', '训练最优延迟');
xlabel('统一查询延迟（\mus）'); ylabel('参考事件项RMS（点）');
grid on; legend('Location', 'best'); title('±3 ms后验固定延迟扫描');

nexttile;
local = abs(delay_scan.table.delay_us) <= 50;
plot(delay_scan.table.delay_us(local), ...
    delay_scan.table.train_rms_output_cycles(local), '-', ...
    'Color', [0.14 0.42 0.72]); hold on;
plot(delay_scan.table.delay_us(local), ...
    delay_scan.table.validation_rms_output_cycles(local), '-', ...
    'Color', [0.86 0.30 0.12]);
xline(0, ':k'); grid on; xlabel('载频亚周期局部延迟（\mus）');
ylabel('RMS（点）'); title('±50 \mus局部放大');

nexttile;
valid = relation.interval.valid;
x = 0.5 * (relation.interval.reference_average_frequency_hz(valid) + ...
    relation.interval.pulse_equivalent_frequency_hz(valid));
y = relation.interval.frequency_mismatch_hz(valid);
plot(x, y, '.', 'Color', [0.48 0.25 0.62], 'MarkerSize', 7); hold on;
yline(0, ':k'); grid on; xlabel('两种等效参考频率均值（Hz）');
ylabel('参考－脉冲频差（Hz）'); title('频率一致性差值图');

nexttile;
plot(segments.segment, segments.reference_event_rms_output_cycles, ...
    'o-', 'Color', [0.15 0.48 0.40], 'LineWidth', 1.0, ...
    'MarkerFaceColor', [0.15 0.48 0.40]); hold on;
yline(summary.reference_event_rms_output_cycles, '--k', ...
    'DisplayName', '全局RMS');
xlim([0.5 height(segments) + 0.5]); xticks(segments.segment);
xlabel('连续时间分段'); ylabel('参考事件项RMS（点）'); grid on;
title(sprintf('验证改善 %.2f%%；分段范围 %.2f–%.2f点', ...
    summary.validation_delay_improvement_percent, ...
    summary.segment_rms_min_output_cycles, ...
    summary.segment_rms_max_output_cycles));
files = dpll.export_paper_figure(fig, fullfile(figure_dir, ...
    'figure4_delay_and_synchrony_diagnostics_cn'), [10.2 7.5], ...
    'Microsoft YaHei');
if strcmp(visibility, 'off'), close(fig); end
end

function write_report(path, study)
file_id = fopen(path, 'w', 'n', 'UTF-8');
if file_id < 0
    error('reference_analysis:ReportOpenFailed', ...
        'Cannot create report: %s', path);
end
cleanup = onCleanup(@() fclose(file_id));
s = study.summary;
fprintf(file_id, '# 输入参考与固定时钟脉冲关系分析\n\n');
fprintf(file_id, '数据集：`%s`。生成时间：%s。\n\n', ...
    study.dataset_id, study.created_at);
fprintf(file_id, ['本实验完全不加载DPLL replay、PI/FLL状态或控制器配置。' ...
    '真实峰时间戳只用于posterior关系诊断，未用于控制器或训练。\n\n']);
fprintf(file_id, '## 核心结果\n\n');
fprintf(file_id, '| 指标 | 数值 |\n|---|---:|\n');
fprintf(file_id, '| 输入参考载频 | %.9f Hz |\n', s.reference_carrier_hz);
fprintf(file_id, '| 每个峰间隔最少参考观测点 | %d |\n', ...
    s.minimum_observations_per_interval);
fprintf(file_id, '| 参考/脉冲等效频率相关系数 | %.6f |\n', ...
    s.reference_pulse_frequency_correlation);
fprintf(file_id, '| 频率不匹配RMS | %.6f Hz |\n', ...
    s.frequency_mismatch_rms_hz);
fprintf(file_id, '| reference-event RMS | %.6f output cycles |\n', ...
    s.reference_event_rms_output_cycles);
fprintf(file_id, '| reference-event RMS | %.6f mrad |\n', ...
    s.reference_event_rms_mrad);
fprintf(file_id, '| 下一峰时间预测残差RMS | %.6f raw samples |\n', ...
    s.timing_residual_rms_raw_samples_62m5);
fprintf(file_id, '| 下一峰时间预测残差RMS | %.3f ns |\n', ...
    s.timing_residual_rms_ns);
fprintf(file_id, '| IQ/零交叉事件项差异RMS | %.6f output cycles |\n', ...
    s.iq_zero_event_delta_rms_output_cycles);
fprintf(file_id, '| 频率—相位恒等式最大残差 | %.3g output cycles |\n', ...
    s.phase_identity_max_abs_output_cycles);

fprintf(file_id, '\n## 固定延迟诊断\n\n');
fprintf(file_id, ['训练段最优固定延迟为 %.3f us；零延迟验证RMS %.6f点，' ...
    '冻结该延迟后的验证RMS %.6f点，改善 %.3f%%。\n\n'], ...
    1e6 * s.best_train_delay_s, ...
    s.zero_delay_validation_rms_output_cycles, ...
    s.best_delay_validation_rms_output_cycles, ...
    s.validation_delay_improvement_percent);
fprintf(file_id, ['延迟扫描是posterior/oracle诊断，不能作为reference-only ' ...
    '控制器使用真实峰位置的授权。\n\n']);

fprintf(file_id, '## 数学关系\n\n');
fprintf(file_id, ['对峰间隔 T_k，脉冲等效参考频率为 113/T_k，参考区间平均' ...
    '频率为 ΔΦ_k/T_k，并逐区间满足：\n\n']);
fprintf(file_id, ['```text\nreference-event = 2000*(ΔΦ_k-113)' ...
    ' = 2000*T_k*(f_ref_bar-113/T_k)\n```\n\n']);

fprintf(file_id, '## 限制\n\n');
fprintf(file_id, ['- IQ采用对称窗口，属于离线零延迟表征，不是因果控制器。\n' ...
    '- 峰文件中有 %d 个小数间距；若为0，则峰位仍只有整数采样精度。\n' ...
    '- 3.125 MHz前端metadata未标定CIC/DC blocker的绝对群延迟；' ...
    '区间误差有效，但绝对亚周期物理延迟仍需原始CH2交叉校准。\n' ...
    '- 未提供或未使用未来峰来优化任何锁相环参数。\n'], ...
    s.fractional_peak_distance_count);
end

function value = column_percentile(values, percentile)
value = nan(size(values, 2), 1);
for k = 1:size(values, 2)
    column = sort(values(isfinite(values(:, k)), k));
    if isempty(column), continue; end
    position = 1 + (numel(column) - 1) * percentile / 100;
    left = floor(position);
    right = ceil(position);
    if left == right
        value(k) = column(left);
    else
        fraction = position - left;
        value(k) = column(left) * (1 - fraction) + column(right) * fraction;
    end
end
end

function value = rms_plain(values)
values = double(values(:));
values = values(isfinite(values));
if isempty(values), value = NaN; else, value = sqrt(mean(values.^2)); end
end

function require_file(path, role)
if ~isfile(path)
    error('reference_analysis:InputNotFound', ...
        '%s file not found: %s', role, path);
end
end
