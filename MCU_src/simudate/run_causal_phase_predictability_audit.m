function audit = run_causal_phase_predictability_audit( ...
    replay_mat_path, input_mat_path, output_dir, options)
%RUN_CAUSAL_PHASE_PREDICTABILITY_AUDIT Past-only reference prediction floor.

arguments
    replay_mat_path (1,1) string
    input_mat_path (1,1) string
    output_dir (1,1) string
    options.horizon_us (:,1) double = ...
        [0 50 100 150 200 238.35 300 400 500].'
    options.train_fraction (1,1) double = 0.60
    options.analytic_half_bandwidth_hz (1,1) double = 500
    options.edge_margin_s (1,1) double = 0.03
    options.output_multiplier (1,1) double = 2000
end

if ~isfile(replay_mat_path)
    error('dpll:ReplayNotFound', 'Replay not found: %s', replay_mat_path);
end
if ~isfile(input_mat_path)
    error('dpll:InputNotFound', 'Reference input not found: %s', input_mat_path);
end
if ~isfolder(output_dir), mkdir(output_dir); end
raw_dir = fullfile(output_dir, 'raw');
table_dir = fullfile(output_dir, 'tables');
figure_dir = fullfile(output_dir, 'figures');
make_dirs(raw_dir, table_dir, figure_dir);

frozen = load(replay_mat_path, 'result');
if ~isfield(frozen, 'result')
    error('dpll:MissingReplayResult', 'Replay MAT does not contain result.');
end
result = frozen.result;
if result.metadata.posterior_interval_data_used
    error('dpll:PosteriorContamination', ...
        'Causal audit requires a posterior-free frozen replay.');
end
first_input = result.metadata.input_start_index;
last_input = first_input + result.metadata.input_sample_count - 1;
input_data = load_input_mat(input_mat_path, [first_input last_input]);

trace_use = result.trace.analysis_valid;
trace_time = result.trace.time_s;
first_time = trace_time(find(trace_use, 1, 'first')) + options.edge_margin_s;
last_time = trace_time(find(trace_use, 1, 'last')) - options.edge_margin_s;
trace_use = trace_use & trace_time >= first_time & trace_time <= last_time;
query_global = double(result.trace.input_index(trace_use));
query_local = query_global - first_input + 1;
time_s = (query_global - 1) / input_data.sample_rate_hz;
phase_scale = pi / 2^(result.config.phase_width - 1);
phase_error_rad = double(result.trace.phase_error(trace_use)) * phase_scale;
setpoint_rad = double(result.config.phase_setpoint) * phase_scale;
detector_phase_rad = unwrap(phase_error_rad + setpoint_rad);
nco_phase_rad = double(result.trace.tracking_phase_rad(trace_use));
causal_phase_cycles = (nco_phase_rad + detector_phase_rad) / (2 * pi);
carrier_hz = result.metadata.initial_frequency_hz;
analytic = dpll.estimate_fft_analytic_phase(input_data.pll_input_codes, ...
    query_local, input_data.sample_rate_hz, carrier_hz, ...
    options.analytic_half_bandwidth_hz);
valid = analytic.coverage & isfinite(analytic.phase_cycles);
time_s = time_s(valid);
phase_cycles = analytic.phase_cycles(valid);
causal_phase_cycles = causal_phase_cycles(valid);
if numel(time_s) < 1000
    error('dpll:InsufficientPredictorData', ...
        'Fewer than 1000 analytic phase observations are available.');
end

sample_period_s = median(diff(time_s));
train_end = floor(options.train_fraction * numel(time_s));
if train_end < 500 || numel(time_s) - train_end < 500
    error('dpll:InvalidPredictorSplit', ...
        'Training and validation partitions must each contain 500 samples.');
end
carrier_fit = polyfit(time_s(1:train_end), phase_cycles(1:train_end), 1);
causal_carrier_fit = polyfit(time_s(1:train_end), ...
    causal_phase_cycles(1:train_end), 1);
phase_fluctuation = phase_cycles - polyval(carrier_fit, time_s);
causal_fluctuation = causal_phase_cycles - ...
    polyval(causal_carrier_fit, time_s);
calibration = [ones(train_end, 1), causal_fluctuation(1:train_end)] \ ...
    phase_fluctuation(1:train_end);
causal_fluctuation = calibration(1) + calibration(2) * causal_fluctuation;

[metrics, selected] = evaluate_all_predictors(time_s, phase_cycles, ...
    phase_fluctuation, causal_fluctuation, train_end, sample_period_s, options);
writetable(metrics, fullfile(table_dir, 'causal_predictor_metrics.csv'));
writetable(selected.parameters, fullfile(table_dir, ...
    'causal_predictor_parameters.csv'));

[psd_frequency_hz, phase_psd] = dpll.welch_psd(phase_fluctuation, ...
    1 / sample_period_s);
psd_table = table(psd_frequency_hz, phase_psd, ...
    'VariableNames', {'frequency_hz', 'phase_cycles2_per_hz'});
psd_table = psd_table(psd_table.frequency_hz <= 500, :);
writetable(psd_table, fullfile(table_dir, 'reference_phase_psd.csv'));

figure_files = make_figures(metrics, selected, time_s, ...
    phase_fluctuation, causal_fluctuation, train_end, ...
    psd_table, figure_dir, options);
provenance = table(["replay"; "reference_input"], ...
    [replay_mat_path; input_mat_path], ...
    [dpll.file_sha256(replay_mat_path); dpll.file_sha256(input_mat_path)], ...
    'VariableNames', {'role', 'path', 'sha256'});
writetable(provenance, fullfile(table_dir, 'source_provenance.csv'));

audit.schema_version = 1;
audit.created_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
audit.posterior_peak_data_loaded = false;
audit.replay_mat_path = replay_mat_path;
audit.input_mat_path = input_mat_path;
audit.options = options;
audit.sample_period_s = sample_period_s;
audit.effective_sample_rate_hz = 1 / sample_period_s;
audit.train_end_index = train_end;
audit.carrier_fit_cycles = carrier_fit;
audit.causal_carrier_fit_cycles = causal_carrier_fit;
audit.causal_to_truth_calibration = calibration;
audit.time_s = time_s;
audit.phase_cycles = phase_cycles;
audit.phase_fluctuation_cycles = phase_fluctuation;
audit.causal_detector_phase_cycles = causal_phase_cycles;
audit.causal_detector_fluctuation_cycles = causal_fluctuation;
audit.metrics = metrics;
audit.selected = selected;
audit.psd = psd_table;
audit.provenance = provenance;
audit.figure_files = figure_files;
audit.report_path = fullfile(output_dir, ...
    'causal_phase_predictability_report.md');
write_report(audit.report_path, audit);
save(fullfile(raw_dir, 'causal_phase_predictability_raw.mat'), ...
    'audit', '-v7.3');
save(fullfile(output_dir, 'causal_phase_predictability_audit.mat'), ...
    'audit', '-v7.3');
end

function [metrics, selected] = evaluate_all_predictors(time_s, ...
    phase_cycles, truth_fluctuation, causal_observation, ...
    train_end, sample_period_s, options)
horizon_steps = max(0, round(options.horizon_us * 1e-6 / sample_period_s));
horizon_steps = unique(horizon_steps, 'stable');
horizon_us = horizon_steps * sample_period_s * 1e6;
methods = ["hold"; "constant_velocity"; "constant_acceleration"; ...
    "alpha_beta"; "fir_phase_increment"];
rows = repmat(empty_metric_row(), numel(horizon_steps) * numel(methods), 1);
prediction_store = cell(numel(horizon_steps), numel(methods));
parameter_rows = repmat(empty_parameter_row(), ...
    numel(horizon_steps) * numel(methods), 1);
row_index = 0;

velocity_windows = [4 8 16 32 64 128];
alpha_values = [0.05 0.1 0.2 0.4 0.8];
beta_values = [0.001 0.005 0.01 0.02 0.05 0.1];
fir_orders = [2 4 8 16];

for h_index = 1:numel(horizon_steps)
    h = horizon_steps(h_index);
    predictions = cell(numel(methods), 1);
    details = strings(numel(methods), 1);
    coefficients = cell(numel(methods), 1);

    predictions{1} = delayed_hold(causal_observation, h);
    details(1) = "no extrapolation";

    [predictions{2}, window] = select_window_predictor( ...
        causal_observation, truth_fluctuation, h, train_end, ...
        velocity_windows, false);
    details(2) = "window=" + window;

    [predictions{3}, window] = select_window_predictor( ...
        causal_observation, truth_fluctuation, h, train_end, ...
        velocity_windows, true);
    details(3) = "window=" + window;

    [predictions{4}, alpha, beta] = select_alpha_beta( ...
        causal_observation, truth_fluctuation, h, train_end, ...
        alpha_values, beta_values);
    details(4) = sprintf('alpha=%.6g beta=%.6g', alpha, beta);
    coefficients{4} = [alpha beta];

    [predictions{5}, order, coeff] = select_fir_predictor( ...
        causal_observation, truth_fluctuation, h, train_end, fir_orders);
    details(5) = "order=" + order + " qfrac=18";
    coefficients{5} = coeff;

    for method_index = 1:numel(methods)
        row_index = row_index + 1;
        prediction = predictions{method_index};
        [row, event_data] = score_prediction(time_s, phase_cycles, ...
            truth_fluctuation, prediction, h, train_end, ...
            options.output_multiplier);
        row.method = methods(method_index);
        row.parameter_detail = details(method_index);
        row.horizon_steps = h;
        row.horizon_us = horizon_us(h_index);
        rows(row_index) = row;
        prediction_store{h_index, method_index} = event_data;
        parameter_rows(row_index).method = methods(method_index);
        parameter_rows(row_index).horizon_us = horizon_us(h_index);
        parameter_rows(row_index).parameter_detail = details(method_index);
        if isempty(coefficients{method_index})
            parameter_rows(row_index).coefficients = "";
        else
            parameter_rows(row_index).coefficients = ...
                join(string(coefficients{method_index}), ';');
        end
    end
end

metrics = struct2table(rows);
parameter_table = struct2table(parameter_rows);
[~, target_horizon_index] = min(abs(horizon_us - 238.35));
target_rows = (target_horizon_index - 1) * numel(methods) + (1:numel(methods));
[~, current_horizon_index] = min(abs(horizon_us));
current_rows = (current_horizon_index - 1) * numel(methods) + (1:numel(methods));
selected.horizon_index = target_horizon_index;
selected.horizon_us = horizon_us(target_horizon_index);
selected.methods = methods;
selected.metrics = metrics(target_rows, :);
selected.predictions = prediction_store(target_horizon_index, :);
selected.current_horizon_index = current_horizon_index;
selected.current_horizon_us = horizon_us(current_horizon_index);
selected.current_metrics = metrics(current_rows, :);
selected.current_predictions = prediction_store(current_horizon_index, :);
selected.parameters = parameter_table;
end

function prediction = delayed_hold(values, horizon)
prediction = nan(size(values));
prediction(1 + horizon:end) = values(1:end - horizon);
end

function [best_prediction, best_window] = select_window_predictor( ...
    values, truth, horizon, train_end, windows, use_acceleration)
best_error = Inf;
best_prediction = nan(size(values));
best_window = NaN;
for window = windows
    prediction = window_prediction(values, horizon, window, use_acceleration);
    error_value = centered_rms(truth(1:train_end) - prediction(1:train_end));
    if error_value < best_error
        best_error = error_value;
        best_prediction = prediction;
        best_window = window;
    end
end
end

function prediction = window_prediction(values, horizon, window, use_acceleration)
count = numel(values);
prediction = nan(count, 1);
if use_acceleration
    observation = (2 * window + 1):(count - horizon);
    velocity = (values(observation) - values(observation - window)) / window;
    previous_velocity = (values(observation - window) - ...
        values(observation - 2 * window)) / window;
    acceleration = (velocity - previous_velocity) / window;
    prediction(observation + horizon) = values(observation) + ...
        horizon * velocity + 0.5 * horizon^2 * acceleration;
else
    observation = (window + 1):(count - horizon);
    velocity = (values(observation) - values(observation - window)) / window;
    prediction(observation + horizon) = ...
        values(observation) + horizon * velocity;
end
end

function [best_prediction, best_alpha, best_beta] = select_alpha_beta( ...
    values, truth, horizon, train_end, alpha_values, beta_values)
best_error = Inf;
best_prediction = nan(size(values));
best_alpha = NaN;
best_beta = NaN;
for alpha = alpha_values
    for beta = beta_values
        [state_phase, state_velocity] = alpha_beta_state(values, alpha, beta);
        prediction = nan(size(values));
        observation = 1:(numel(values) - horizon);
        prediction(observation + horizon) = state_phase(observation) + ...
            horizon * state_velocity(observation);
        error_value = centered_rms( ...
            truth(1:train_end) - prediction(1:train_end));
        if error_value < best_error
            best_error = error_value;
            best_prediction = prediction;
            best_alpha = alpha;
            best_beta = beta;
        end
    end
end
end

function [phase_state, velocity_state] = alpha_beta_state(values, alpha, beta)
count = numel(values);
phase_state = zeros(count, 1);
velocity_state = zeros(count, 1);
phase_state(1) = values(1);
for k = 2:count
    predicted_phase = phase_state(k - 1) + velocity_state(k - 1);
    innovation = values(k) - predicted_phase;
    phase_state(k) = predicted_phase + alpha * innovation;
    velocity_state(k) = velocity_state(k - 1) + beta * innovation;
end
end

function [best_prediction, best_order, best_coeff] = select_fir_predictor( ...
    values, truth, horizon, train_end, orders)
increments = [0; diff(values)];
best_error = Inf;
best_prediction = nan(size(values));
best_order = NaN;
best_coeff = [];
for order = orders
    observation_train = (order + 1):(train_end - horizon);
    features = build_increment_features(increments, observation_train, order);
    target = truth(observation_train + horizon) - values(observation_train);
    coeff = fit_quantized_ridge(features, target, 18);
    observation_all = (order + 1):(numel(values) - horizon);
    features_all = build_increment_features(increments, observation_all, order);
    design_all = [ones(numel(observation_all), 1), features_all];
    prediction = nan(size(values));
    prediction(observation_all + horizon) = values(observation_all) + ...
        design_all * coeff;
    error_value = centered_rms( ...
        truth(1:train_end) - prediction(1:train_end));
    if error_value < best_error
        best_error = error_value;
        best_prediction = prediction;
        best_order = order;
        best_coeff = coeff;
    end
end
end

function features = build_increment_features(increments, observation, order)
features = zeros(numel(observation), order);
for lag = 0:order - 1
    features(:, lag + 1) = increments(observation - lag);
end
end

function coeff = fit_quantized_ridge(features, target, fractional_bits)
feature_mean = mean(features, 1);
feature_scale = std(features, 0, 1);
feature_scale(feature_scale < eps) = 1;
normalized = (features - feature_mean) ./ feature_scale;
design = [ones(size(normalized, 1), 1), normalized];
gram = design.' * design;
ridge = 1e-6 * trace(gram) / size(gram, 1);
penalty = eye(size(gram));
penalty(1, 1) = 0;
normalized_coeff = (gram + ridge * penalty) \ (design.' * target);
raw_coeff = zeros(size(normalized_coeff));
raw_coeff(2:end) = normalized_coeff(2:end) ./ feature_scale.';
raw_coeff(1) = normalized_coeff(1) - ...
    sum(normalized_coeff(2:end).' .* feature_mean ./ feature_scale);
scale = 2^fractional_bits;
positive_limit = (2^5 * scale - 1) / scale;
negative_limit = -2^5;
coeff = round(raw_coeff * scale) / scale;
coeff = min(max(coeff, negative_limit), positive_limit);
end

function [row, event_data] = score_prediction(time_s, phase_cycles, ...
    fluctuation, prediction, horizon, train_end, multiplier)
error_value = prediction - fluctuation;
training = (1:numel(error_value)).' <= train_end & isfinite(error_value);
validation = (1:numel(error_value)).' > train_end & isfinite(error_value);
training_error = error_value(training);
validation_error = error_value(validation);

row = empty_metric_row();
row.training_phase_rms_output_cycles = ...
    multiplier * centered_rms(training_error);
row.validation_phase_rms_output_cycles = ...
    multiplier * centered_rms(validation_error);
row.validation_phase_peak_output_cycles = ...
    multiplier * max(abs(validation_error - mean(validation_error)));
row.validation_bias_output_cycles = multiplier * mean(validation_error);

event_time = exact_event_times(time_s, phase_cycles, train_end);
target_time = time_s(validation);
target_error = error_value(validation);
event_error = interp1(target_time, target_error, event_time, 'linear', NaN);
event_error = event_error(isfinite(event_error));
if numel(event_error) >= 3
    event_interval_error = multiplier * diff(event_error);
    row.exact113_prediction_floor_rms_cycles = ...
        sqrt(mean(event_interval_error.^2));
    row.exact113_prediction_floor_std_cycles = std(event_interval_error);
else
    event_interval_error = zeros(0, 1);
end
row.validation_sample_count = nnz(validation);
row.event_interval_count = numel(event_interval_error);

event_data.horizon_steps = horizon;
event_data.time_s = time_s;
event_data.prediction_cycles = prediction;
event_data.error_cycles = error_value;
event_data.validation_mask = validation;
event_data.event_time_s = event_time;
event_data.event_error_cycles = event_error;
event_data.event_interval_error_output_cycles = event_interval_error;
end

function event_time = exact_event_times(time_s, phase_cycles, train_end)
start_time = time_s(train_end + 1);
start_cycle = interp1(time_s, phase_cycles, start_time, 'linear');
last_cycle = phase_cycles(end);
targets = (ceil(start_cycle / 113) * 113:113:floor(last_cycle / 113) * 113).';
if numel(targets) < 3
    event_time = zeros(0, 1);
else
    event_time = interp1(phase_cycles, time_s, targets, 'linear');
end
end

function row = empty_metric_row()
row.method = "";
row.parameter_detail = "";
row.horizon_steps = NaN;
row.horizon_us = NaN;
row.training_phase_rms_output_cycles = NaN;
row.validation_phase_rms_output_cycles = NaN;
row.validation_phase_peak_output_cycles = NaN;
row.validation_bias_output_cycles = NaN;
row.exact113_prediction_floor_rms_cycles = NaN;
row.exact113_prediction_floor_std_cycles = NaN;
row.validation_sample_count = 0;
row.event_interval_count = 0;
end

function row = empty_parameter_row()
row.method = "";
row.horizon_us = NaN;
row.parameter_detail = "";
row.coefficients = "";
end

function value = centered_rms(values)
values = double(values(:));
values = values(isfinite(values));
if isempty(values)
    value = Inf;
else
    values = values - mean(values);
    value = sqrt(mean(values.^2));
end
end

function files = make_figures(metrics, selected, time_s, fluctuation, ...
    causal_observation, train_end, psd_table, figure_dir, options)
files = struct();
methods = unique(metrics.method, 'stable');
fig = figure('Visible', 'off', 'Color', 'w');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(layout); hold on;
for k = 1:numel(methods)
    use = metrics.method == methods(k);
    plot(metrics.horizon_us(use), ...
        metrics.validation_phase_rms_output_cycles(use), '.-', ...
        'LineWidth', 1.0, 'MarkerSize', 10, ...
        'DisplayName', strrep(methods(k), '_', ' '));
end
xlabel('Additional future horizon after detector timestamp (us)');
ylabel('Phase prediction RMS (output cycles)');
grid on; legend('Location', 'northwest');
nexttile(layout); hold on;
for k = 1:numel(methods)
    use = metrics.method == methods(k);
    plot(metrics.horizon_us(use), ...
        metrics.exact113_prediction_floor_rms_cycles(use), '.-', ...
        'LineWidth', 1.0, 'MarkerSize', 10, ...
        'DisplayName', strrep(methods(k), '_', ' '));
end
xlabel('Additional future horizon after detector timestamp (us)');
ylabel('Exact-113 interval floor (cycles RMS)');
grid on;
title(layout, 'Past-only prediction floor of the measured reference');
files.horizon = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'causal_prediction_horizon'), [7.6 6.2]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
target_start = time_s(train_end + 1) + 0.03;
target_end = min(target_start + 0.08, time_s(end));
nexttile(layout); hold on;
truth_use = time_s >= target_start & time_s <= target_end;
plot(time_s(truth_use), options.output_multiplier * fluctuation(truth_use), ...
    'k', 'LineWidth', 1.1, 'DisplayName', 'offline phase truth');
plot(time_s(truth_use), ...
    options.output_multiplier * causal_observation(truth_use), ...
    'Color', [0.45 0.45 0.45], 'DisplayName', 'causal detector phase');
for k = 1:numel(selected.methods)
    data = selected.predictions{k};
    use = truth_use & isfinite(data.prediction_cycles);
    plot(time_s(use), options.output_multiplier * data.prediction_cycles(use), ...
        'DisplayName', strrep(selected.methods(k), '_', ' '));
end
ylabel('Phase fluctuation (output cycles)'); grid on;
legend('Location', 'eastoutside');
nexttile(layout); hold on;
for k = 1:numel(selected.methods)
    data = selected.predictions{k};
    use = truth_use & isfinite(data.error_cycles);
    plot(time_s(use), options.output_multiplier * data.error_cycles(use), ...
        'DisplayName', strrep(selected.methods(k), '_', ' '));
end
xlabel('Time (s)'); ylabel('Prediction error (output cycles)'); grid on;
title(layout, sprintf('Causal predictions at %.2f us horizon', ...
    selected.horizon_us));
files.trace = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'causal_prediction_trace'), [9.0 6.2]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w');
loglog(psd_table.frequency_hz(2:end), ...
    psd_table.phase_cycles2_per_hz(2:end), 'LineWidth', 1.1);
xlabel('Frequency (Hz)'); ylabel('Phase PSD (cycles^2/Hz)');
grid on; xlim([1 500]);
title('Measured reference phase-fluctuation spectrum');
files.psd = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'reference_phase_psd'), [7.2 4.8]);
close(fig);
end

function write_report(path, audit)
file_id = fopen(path, 'w');
if file_id < 0, error('dpll:ReportOpenFailed', 'Cannot write %s.', path); end
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>
fprintf(file_id, '# Causal phase predictability audit\n\n');
fprintf(file_id, 'Posterior peak data loaded: **false**.\n\n');
fprintf(file_id, ['The offline analytic phase is used only as truth. Every ' ...
    'candidate prediction uses the causal FPGA detector phase at or before ' ...
    'the observation time. Horizon zero predicts current truth from the ' ...
    'already delayed detector output.\n\n']);
fprintf(file_id, 'Effective phase sample rate: **%.6f Hz**.\n\n', ...
    audit.effective_sample_rate_hz);
fprintf(file_id, '## Current-time reconstruction (%.3f us)\n\n', ...
    audit.selected.current_horizon_us);
fprintf(file_id, ['| Method | Parameters | Phase RMS (cycles) | ' ...
    'Exact-113 floor (cycles) |\n']);
fprintf(file_id, '|---|---|---:|---:|\n');
for k = 1:height(audit.selected.current_metrics)
    row = audit.selected.current_metrics(k, :);
    fprintf(file_id, '| %s | %s | %.6f | %.6f |\n', ...
        strrep(row.method, '_', ' '), row.parameter_detail, ...
        row.validation_phase_rms_output_cycles, ...
        row.exact113_prediction_floor_rms_cycles);
end
fprintf(file_id, '\n');
fprintf(file_id, '## Additional future horizon (%.3f us)\n\n', ...
    audit.selected.horizon_us);
fprintf(file_id, ['| Method | Parameters | Phase RMS (cycles) | ' ...
    'Exact-113 floor (cycles) |\n']);
fprintf(file_id, '|---|---|---:|---:|\n');
for k = 1:height(audit.selected.metrics)
    row = audit.selected.metrics(k, :);
    fprintf(file_id, '| %s | %s | %.6f | %.6f |\n', ...
        strrep(row.method, '_', ' '), row.parameter_detail, ...
        row.validation_phase_rms_output_cycles, ...
        row.exact113_prediction_floor_rms_cycles);
end
end

function make_dirs(varargin)
for k = 1:nargin
    if ~isfolder(varargin{k}), mkdir(varargin{k}); end
end
end
