function audit = run_posterior_event_causality_audit( ...
    replay_mat_path, peak_mat_path, causal_audit_mat_path, output_dir, options)
%RUN_POSTERIOR_EVENT_CAUSALITY_AUDIT Frozen peak-event decomposition.

arguments
    replay_mat_path (1,1) string
    peak_mat_path (1,1) string
    causal_audit_mat_path (1,1) string
    output_dir (1,1) string
    options.slow_window_pulses (1,1) double = 21
    options.max_lag_pulses (1,1) double = 20
end

require_file(replay_mat_path, 'Replay');
require_file(peak_mat_path, 'Peak event');
require_file(causal_audit_mat_path, 'Causal audit');
if ~isfolder(output_dir), mkdir(output_dir); end
raw_dir = fullfile(output_dir, 'raw');
table_dir = fullfile(output_dir, 'tables');
figure_dir = fullfile(output_dir, 'figures');
make_dirs(raw_dir, table_dir, figure_dir);

frozen = load(replay_mat_path, 'result');
causal_file = load(causal_audit_mat_path, 'audit');
if ~isfield(frozen, 'result') || ~isfield(causal_file, 'audit')
    error('dpll:MissingAuditInput', ...
        'Replay or causal audit MAT is missing its top-level variable.');
end
result = frozen.result;
causal = causal_file.audit;
if result.metadata.posterior_interval_data_used || ...
        causal.posterior_peak_data_loaded
    error('dpll:PosteriorContamination', ...
        'The frozen candidate or causal predictor used posterior peak data.');
end

validation = validate_peak_alignment(result, peak_mat_path, false);
peak_time_all = validation.peak_time_s(:);
coverage = peak_time_all >= causal.time_s(1) & ...
    peak_time_all <= causal.time_s(end);
indices = find(coverage);
if numel(indices) < 20 || any(diff(indices) ~= 1)
    error('dpll:InsufficientPosteriorCoverage', ...
        'Causal phase truth does not cover one contiguous 20-peak interval.');
end
first_peak = indices(1);
last_peak = indices(end);
peak_time = peak_time_all(first_peak:last_peak);
interval_index = first_peak:(last_peak - 1);

analytic_at_peak = interp1(causal.time_s, causal.phase_cycles, ...
    peak_time, 'linear');
causal_at_peak = interp1(causal.time_s, ...
    causal.causal_detector_phase_cycles, peak_time, 'linear');
multiplier = result.config.pulse.output_multiplier;
ratio = result.config.pulse.reference_cycles_per_pulse;
ideal = multiplier * ratio;
analytic_reference_error = diff(analytic_at_peak) * multiplier - ideal;
causal_reference_error = diff(causal_at_peak) * multiplier - ideal;
pll_error = validation.recovered_interval_error(interval_index);
fixed_error = validation.uncompensated_interval_error_output_cycles(interval_index);
loop_only_error = pll_error - analytic_reference_error;

event_phase_unwrapped = analytic_at_peak - ...
    (analytic_at_peak(1) + ratio * (0:numel(peak_time)-1).');
event_phase_wrapped = mod(event_phase_unwrapped + 0.5, 1) - 0.5;
integer_cycle_count = round(diff(analytic_at_peak));

[best_prediction, best_method, best_metric] = ...
    select_best_causal_prediction(causal);
prediction_error_at_peak = interp1(causal.time_s, ...
    best_prediction.error_cycles, peak_time, 'linear', NaN);
causal_prediction_floor = multiplier * diff(prediction_error_at_peak);

series_names = ["fixed_clock"; "analytic_reference_event"; ...
    "causal_detector_event"; "pll_output"; "loop_only"; ...
    "causal_predictor_floor"];
series_values = {fixed_error; analytic_reference_error; ...
    causal_reference_error; pll_error; loop_only_error; ...
    causal_prediction_floor};
metrics = build_metric_table(series_names, series_values, ...
    options.slow_window_pulses);
correlation = build_correlation_table(series_names, series_values, ...
    options.max_lag_pulses);
psd = build_psd_table(series_names, series_values, peak_time);
[posterior_predictor, posterior_predictor_table] = ...
    fit_posterior_interval_predictor(analytic_reference_error);

interval_table = table(peak_time(2:end), fixed_error, ...
    analytic_reference_error, causal_reference_error, pll_error, ...
    loop_only_error, causal_prediction_floor, ...
    'VariableNames', {'time_s', 'fixed_clock_error_cycles', ...
    'analytic_reference_event_error_cycles', ...
    'causal_detector_event_error_cycles', 'pll_output_error_cycles', ...
    'loop_only_error_cycles', 'causal_prediction_floor_cycles'});
event_table = table(peak_time, analytic_at_peak, causal_at_peak, ...
    event_phase_unwrapped, event_phase_wrapped, ...
    'VariableNames', {'time_s', 'analytic_reference_phase_cycles', ...
    'causal_detector_phase_cycles', 'event_phase_unwrapped_cycles', ...
    'event_phase_wrapped_cycles'});
writetable(metrics, fullfile(table_dir, 'posterior_series_metrics.csv'));
writetable(correlation, fullfile(table_dir, ...
    'posterior_lag_correlation.csv'));
writetable(psd, fullfile(table_dir, 'posterior_series_psd.csv'));
writetable(interval_table, fullfile(table_dir, ...
    'posterior_interval_decomposition.csv'));
writetable(event_table, fullfile(table_dir, ...
    'reference_phase_at_pulse_events.csv'));
writetable(posterior_predictor_table, fullfile(table_dir, ...
    'posterior_only_predictability.csv'));

figure_files = make_figures(peak_time, fixed_error, ...
    analytic_reference_error, pll_error, loop_only_error, ...
    event_phase_unwrapped, event_phase_wrapped, correlation, psd, figure_dir);
provenance = table(["replay"; "peak_events"; "causal_audit"], ...
    [replay_mat_path; peak_mat_path; causal_audit_mat_path], ...
    [dpll.file_sha256(replay_mat_path); dpll.file_sha256(peak_mat_path); ...
    dpll.file_sha256(causal_audit_mat_path)], ...
    'VariableNames', {'role', 'path', 'sha256'});
writetable(provenance, fullfile(table_dir, 'source_provenance.csv'));

audit.schema_version = 1;
audit.created_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
audit.posterior_peak_data_loaded = true;
audit.candidate_frozen_before_posterior = true;
audit.causal_predictor_frozen_before_posterior = true;
audit.options = options;
audit.config = result.config;
audit.validation = validation;
audit.peak_time_s = peak_time;
audit.analytic_reference_phase_at_peak_cycles = analytic_at_peak;
audit.causal_detector_phase_at_peak_cycles = causal_at_peak;
audit.event_phase_unwrapped_cycles = event_phase_unwrapped;
audit.event_phase_wrapped_cycles = event_phase_wrapped;
audit.integer_reference_cycle_count = integer_cycle_count;
audit.series_names = series_names;
audit.series_values = series_values;
audit.metrics = metrics;
audit.correlation = correlation;
audit.psd = psd;
audit.best_causal_predictor_method = best_method;
audit.best_causal_predictor_metric = best_metric;
audit.posterior_only_predictor = posterior_predictor;
audit.posterior_only_predictor_table = posterior_predictor_table;
audit.interval_table = interval_table;
audit.event_table = event_table;
audit.provenance = provenance;
audit.figure_files = figure_files;
audit.decision = build_decision(audit);
audit.report_path = fullfile(output_dir, ...
    'posterior_event_causality_report.md');
write_report(audit.report_path, audit);
save(fullfile(raw_dir, 'posterior_event_causality_raw.mat'), ...
    'audit', '-v7.3');
save(fullfile(output_dir, 'posterior_event_causality_audit.mat'), ...
    'audit', '-v7.3');
end

function [prediction, method, metric] = select_best_causal_prediction(causal)
metrics = causal.selected.current_metrics;
[~, index] = min(metrics.exact113_prediction_floor_rms_cycles);
method = metrics.method(index);
metric = metrics(index, :);
prediction = causal.selected.current_predictions{index};
end

function table_value = build_metric_table(names, values, slow_window)
rows = repmat(struct('series', "", 'count', 0, 'mean_cycles', NaN, ...
    'std_cycles', NaN, 'rms_cycles', NaN, 'peak_to_peak_cycles', NaN, ...
    'slow_std_cycles', NaN, 'fast_std_cycles', NaN, ...
    'lag1_correlation', NaN), numel(names), 1);
for k = 1:numel(names)
    value = double(values{k}(:));
    valid = isfinite(value);
    value = value(valid);
    window = min(max(3, slow_window), numel(value));
    slow = movmean(value, window, 'Endpoints', 'shrink');
    fast = value - slow;
    rows(k).series = names(k);
    rows(k).count = numel(value);
    rows(k).mean_cycles = mean(value);
    rows(k).std_cycles = std(value);
    rows(k).rms_cycles = sqrt(mean(value.^2));
    rows(k).peak_to_peak_cycles = max(value) - min(value);
    rows(k).slow_std_cycles = std(slow);
    rows(k).fast_std_cycles = std(fast);
    if numel(value) > 2
        rows(k).lag1_correlation = corr(value(1:end-1), value(2:end));
    end
end
table_value = struct2table(rows);
end

function table_value = build_correlation_table(names, values, max_lag)
rows = repmat(struct('source', "", 'target', "", 'lag_pulses', 0, ...
    'correlation', NaN, 'positive_lag_means', ...
    "source leads target"), 0, 1);
target_names = ["fixed_clock", "pll_output"];
source_names = ["analytic_reference_event", "causal_detector_event", ...
    "causal_predictor_floor"];
for source_name = source_names
    source = values{find(names == source_name, 1)};
    for target_name = target_names
        target = values{find(names == target_name, 1)};
        for lag = -max_lag:max_lag
            [x, y] = lag_pair(source, target, lag);
            row.source = source_name;
            row.target = target_name;
            row.lag_pulses = lag;
            if numel(x) > 3, row.correlation = corr(x, y); else, row.correlation = NaN; end
            row.positive_lag_means = "source leads target";
            rows(end + 1, 1) = row; %#ok<AGROW>
        end
    end
end
table_value = struct2table(rows);
end

function [source, target] = lag_pair(source, target, lag)
source = double(source(:));
target = double(target(:));
count = min(numel(source), numel(target));
source = source(1:count);
target = target(1:count);
if lag > 0
    source = source(1:end-lag);
    target = target(1+lag:end);
elseif lag < 0
    source = source(1-lag:end);
    target = target(1:end+lag);
end
valid = isfinite(source) & isfinite(target);
source = source(valid);
target = target(valid);
end

function table_value = build_psd_table(names, values, peak_time)
sample_rate_hz = 1 / median(diff(peak_time));
rows = repmat(struct('series', "", 'frequency_hz', NaN, ...
    'power_cycles2_per_hz', NaN), 0, 1);
for k = 1:numel(names)
    value = double(values{k}(:));
    value = value(isfinite(value));
    [frequency, power] = dpll.welch_psd(value, sample_rate_hz);
    for n = 1:numel(frequency)
        row.series = names(k);
        row.frequency_hz = frequency(n);
        row.power_cycles2_per_hz = power(n);
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end
table_value = struct2table(rows);
end

function [model, table_value] = fit_posterior_interval_predictor(values)
values = double(values(:));
train_end = floor(0.60 * numel(values));
orders = (1:8).';
train_rms = nan(size(orders));
validation_rms = nan(size(orders));
coefficients = strings(size(orders));
for k = 1:numel(orders)
    order = orders(k);
    train_target = (order + 1):train_end;
    design = lag_design(values, train_target, order);
    coeff = [ones(numel(train_target), 1), design] \ values(train_target);
    train_error = [ones(numel(train_target), 1), design] * coeff - ...
        values(train_target);
    validation_target = max(train_end + 1, order + 1):numel(values);
    validation_design = lag_design(values, validation_target, order);
    validation_error = [ones(numel(validation_target), 1), ...
        validation_design] * coeff - values(validation_target);
    train_rms(k) = sqrt(mean(train_error.^2));
    validation_rms(k) = sqrt(mean(validation_error.^2));
    coefficients(k) = join(string(coeff), ';');
end
[~, best] = min(validation_rms);
model.best_order = orders(best);
model.validation_rms_cycles = validation_rms(best);
model.zero_predictor_validation_rms_cycles = ...
    sqrt(mean(values(train_end + 1:end).^2));
model.coefficients = coefficients(best);
table_value = table(orders, train_rms, validation_rms, coefficients);
end

function design = lag_design(values, target, order)
design = zeros(numel(target), order);
for lag = 1:order
    design(:, lag) = values(target - lag);
end
end

function decision = build_decision(audit)
metric = audit.metrics;
reference_rms = metric.rms_cycles(metric.series == ...
    "analytic_reference_event");
loop_rms = metric.rms_cycles(metric.series == "loop_only");
pll_rms = metric.rms_cycles(metric.series == "pll_output");
zero_lag = audit.correlation.correlation( ...
    audit.correlation.source == "analytic_reference_event" & ...
    audit.correlation.target == "pll_output" & ...
    audit.correlation.lag_pulses == 0);
decision.reference_event_variation_dominates = reference_rms > 3 * loop_rms;
decision.pll_residual_tracks_reference_event_variation = zero_lag > 0.9;
decision.reference_rms_cycles = reference_rms;
decision.loop_only_rms_cycles = loop_rms;
decision.pll_rms_cycles = pll_rms;
decision.zero_lag_reference_pll_correlation = zero_lag;
decision.all_intervals_round_to_113_reference_cycles = ...
    all(audit.integer_reference_cycle_count == ...
    audit.config.pulse.reference_cycles_per_pulse);
end

function files = make_figures(peak_time, fixed_error, reference_error, ...
    pll_error, loop_error, event_unwrapped, event_wrapped, correlation, ...
    psd, figure_dir)
interval_time = peak_time(2:end);
files = struct();
fig = figure('Visible', 'off', 'Color', 'w');
layout = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(layout); plot(interval_time, fixed_error, '.-');
yline(0, '--k'); ylabel('Fixed (cycles)'); grid on;
nexttile(layout); plot(interval_time, reference_error, '.-');
yline(0, '--k'); ylabel('Ref/event (cycles)'); grid on;
nexttile(layout); plot(interval_time, pll_error, '.-');
yline(0, '--k'); ylabel('PLL (cycles)'); grid on;
nexttile(layout); plot(interval_time, loop_error, '.-');
yline(0, '--k'); ylabel('PLL - ref (cycles)'); grid on;
xlabel('Time (s)');
title(layout, 'Frozen posterior interval decomposition');
files.decomposition = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'posterior_interval_decomposition'), [8.4 7.2]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(layout); plot(peak_time, 2000 * event_unwrapped, '.-');
ylabel('Unwrapped event phase (output cycles)'); grid on;
nexttile(layout); histogram(2000 * event_wrapped, 20);
xlabel('Wrapped event phase (output cycles)'); ylabel('Event count'); grid on;
title(layout, 'Measured reference phase at pulse event timestamps');
files.event_phase = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'reference_phase_at_pulse_events'), [8.0 5.8]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w'); hold on;
sources = unique(correlation.source, 'stable');
for k = 1:numel(sources)
    use = correlation.source == sources(k) & correlation.target == "pll_output";
    plot(correlation.lag_pulses(use), correlation.correlation(use), '.-', ...
        'DisplayName', strrep(sources(k), '_', ' '));
end
xline(0, '--k', 'HandleVisibility', 'off');
xlabel('Lag (pulses, positive means source leads PLL)');
ylabel('Correlation'); grid on; legend('Location', 'best');
title('Posterior lag correlation with PLL residual');
files.correlation = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'posterior_lag_correlation'), [7.4 4.8]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w'); hold on;
selected = ["analytic_reference_event", "pll_output", "loop_only"];
for k = 1:numel(selected)
    use = psd.series == selected(k) & psd.frequency_hz > 0;
    semilogy(psd.frequency_hz(use), psd.power_cycles2_per_hz(use), ...
        'LineWidth', 1.0, 'DisplayName', strrep(selected(k), '_', ' '));
end
xlabel('Event-domain frequency (Hz)');
ylabel('PSD (cycles^2/Hz)'); grid on; legend('Location', 'best');
title('Posterior residual spectra');
files.psd = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'posterior_residual_psd'), [7.4 4.8]);
close(fig);
end

function write_report(path, audit)
file_id = fopen(path, 'w');
if file_id < 0, error('dpll:ReportOpenFailed', 'Cannot write %s.', path); end
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>
fprintf(file_id, '# Posterior pulse-event causality audit\n\n');
fprintf(file_id, ['Candidate and causal predictor frozen before posterior: ' ...
    '**true**. Original pulse waveform required: **false**.\n\n']);
fprintf(file_id, '| Series | RMS (cycles) | Fast std | Lag-1 corr |\n');
fprintf(file_id, '|---|---:|---:|---:|\n');
for k = 1:height(audit.metrics)
    row = audit.metrics(k, :);
    fprintf(file_id, '| %s | %.6f | %.6f | %.6f |\n', ...
        strrep(row.series, '_', ' '), row.rms_cycles, ...
        row.fast_std_cycles, row.lag1_correlation);
end
fprintf(file_id, '\n## Decision\n\n');
fprintf(file_id, '- All covered intervals round to 113 cycles: **%s**.\n', ...
    string(audit.decision.all_intervals_round_to_113_reference_cycles));
fprintf(file_id, '- Reference/event variation dominates loop-only error: **%s**.\n', ...
    string(audit.decision.reference_event_variation_dominates));
fprintf(file_id, '- Reference/event versus PLL zero-lag correlation: **%.6f**.\n', ...
    audit.decision.zero_lag_reference_pll_correlation);
fprintf(file_id, ['- Posterior-only AR(%d) validation RMS: **%.6f cycles**, ' ...
    'zero-predictor RMS: **%.6f cycles**.\n'], ...
    audit.posterior_only_predictor.best_order, ...
    audit.posterior_only_predictor.validation_rms_cycles, ...
    audit.posterior_only_predictor.zero_predictor_validation_rms_cycles);
fprintf(file_id, '\nThe posterior-only predictor is diagnostic and was not used to tune the PLL.\n');
end

function require_file(path, role)
if ~isfile(path), error('dpll:InputNotFound', '%s file not found: %s', role, path); end
end

function make_dirs(varargin)
for k = 1:nargin
    if ~isfolder(varargin{k}), mkdir(varargin{k}); end
end
end
