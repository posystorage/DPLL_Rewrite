function comparison = run_frozen_candidate_peak_validation( ...
    real_comparison_file, peak_mat_path, output_dir)
%RUN_FROZEN_CANDIDATE_PEAK_VALIDATION Posterior validation after freezing.

frozen = load(real_comparison_file, 'comparison');
real_comparison = frozen.comparison;
if real_comparison.posterior_peak_data_loaded
    error('dpll:PosteriorContamination', 'Candidate comparison is contaminated.');
end
raw_dir = fullfile(output_dir, 'raw');
figure_dir = fullfile(output_dir, 'figures');
if ~isfolder(raw_dir), mkdir(raw_dir); end
if ~isfolder(figure_dir), mkdir(figure_dir); end
rows = repmat(struct(), 0, 1);
validations = cell(numel(real_comparison.raw_files), 1);
independent_reference = [];

for k = 1:numel(real_comparison.raw_files)
    replay = load(real_comparison.raw_files(k), 'result');
    validation = validate_peak_alignment(replay.result, peak_mat_path, false);
    if isempty(independent_reference) || ~isequal( ...
            independent_reference.peak_raw_index, validation.peak_raw_index)
        independent_reference = estimate_independent_peak_reference( ...
            replay.result, validation.peak_raw_index);
    end
    validation = attach_peak_reference_decomposition( ...
        validation, independent_reference);
    validations{k} = validation;
    row = validation_row(real_comparison.candidate_ids(k), validation);
    if isempty(rows), rows = row; else, rows(end + 1, 1) = row; end %#ok<AGROW>
    save(fullfile(raw_dir, sprintf('%s_validation.mat', ...
        real_comparison.candidate_ids(k))), 'validation', '-v7.3');
end

metrics = struct2table(rows);
comparison.schema_version = 1;
comparison.candidate_ids = real_comparison.candidate_ids;
comparison.metrics = metrics;
comparison.validations = validations;
comparison.independent_reference = independent_reference;
comparison.posterior_peak_data_loaded = true;
comparison.candidate_freeze_time = real_comparison.candidates_frozen_at;
comparison.validation_time = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
writetable(metrics, fullfile(output_dir, 'posterior_candidate_metrics.csv'));
write_interval_series(comparison, output_dir);
save(fullfile(output_dir, 'posterior_candidate_comparison.mat'), ...
    'comparison', '-v7.3');
fig = plot_peak_comparison(comparison);
comparison.figure_files = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'frozen_candidate_peak_validation'), [7.2 7.2]);
close(fig);
save(fullfile(output_dir, 'posterior_candidate_comparison.mat'), ...
    'comparison', '-v7.3');
end

function row = validation_row(id, validation)
s = validation.summary;
row.candidate_id = string(id);
row.recovered_interval_rms_error_cycles = s.recovered_interval_rms_error;
row.recovered_interval_std_cycles = s.recovered_interval_std;
row.recovered_peak_to_peak_cycles = s.recovered_interval_peak_to_peak;
row.sampling_phase_rms_cycles = s.sampling_phase_rms_cycles;
row.slow_recovered_std_cycles = s.slow_recovered_std;
row.slow_residual_ratio = s.slow_residual_ratio;
row.slow_suppression_db = s.slow_suppression_db;
row.fast_recovered_std_cycles = s.fast_recovered_std;
row.fast_residual_ratio = s.fast_residual_ratio;
row.fast_suppression_db = s.fast_suppression_db;
row.recovered_trend_per_pulse = s.recovered_trend_per_pulse;
row.trend_residual_ratio = s.trend_residual_ratio;
row.reference_event_rms_cycles = s.reference_event_rms_error;
row.loop_only_rms_cycles = s.loop_only_rms_error;
row.total_vs_reference_correlation = ...
    s.total_vs_reference_event_correlation;
row.reference_estimator_delta_rms_cycles = ...
    s.reference_estimator_delta_rms_error;
end

function fig = plot_peak_comparison(comparison)
metrics = comparison.metrics;
labels = strrep(metrics.candidate_id, '_', ' ');
colors = lines(height(metrics));
fig = figure('Visible', 'off', 'Name', 'Frozen candidate peak validation');
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Posterior-only peak validation of frozen candidates');
nexttile;
bar(1:height(metrics), [metrics.recovered_interval_rms_error_cycles, ...
    metrics.reference_event_rms_cycles, metrics.loop_only_rms_cycles], 'grouped');
xticks(1:height(metrics)); xticklabels(labels); xtickangle(20);
ylabel('RMS (cycles)'); grid on;
legend('PLL total', 'Independent reference-event', 'Loop-only', ...
    'Location', 'best');
nexttile;
bar(1:height(metrics), [metrics.slow_recovered_std_cycles, ...
    metrics.fast_recovered_std_cycles], 'grouped');
xticks(1:height(metrics)); xticklabels(labels); xtickangle(20);
ylabel('Recovered std (cycles)'); grid on;
legend('Slow component', 'Fast component', 'Location', 'best');
nexttile; hold on;
for k = 1:numel(comparison.validations)
    validation = comparison.validations{k};
    plot(validation.peak_time_s(2:end), validation.loop_only_error, ...
        'Color', colors(k, :), 'LineWidth', 0.9, ...
        'DisplayName', labels(k));
end
xlabel('Time (s)'); ylabel('Loop-only error (cycles)'); grid on;
legend('Location', 'best');
end

function write_interval_series(comparison, output_dir)
count = numel(comparison.validations{1}.recovered_interval_error);
time_s = comparison.validations{1}.peak_time_s(2:end);
table_value = table((1:count).', time_s, ...
    'VariableNames', {'interval_index', 'interval_end_time_s'});
for k = 1:numel(comparison.validations)
    id = matlab.lang.makeValidName(char(comparison.candidate_ids(k)));
    validation = comparison.validations{k};
    table_value.([id '_total_cycles']) = ...
        validation.recovered_interval_error(:);
    table_value.([id '_reference_event_cycles']) = ...
        validation.reference_event_error(:);
    table_value.([id '_loop_only_cycles']) = ...
        validation.loop_only_error(:);
end
writetable(table_value, fullfile(output_dir, ...
    'posterior_interval_series.csv'));
end
