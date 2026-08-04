function study = run_reference_phase_ceiling_validation( ...
    replay_mat_path, peak_mat_path, output_dir, options)
%RUN_REFERENCE_PHASE_CEILING_VALIDATION Separate loop error from peak mismatch.
%
% The replay is frozen before this posterior-only analysis. The detector-side
% reference phase is reconstructed as NCO phase plus detector residual phase.
% A second validation uses synthetic events placed exactly 113 reconstructed
% reference cycles apart, so it tests the PLL without real-peak localization.

arguments
    replay_mat_path (1,1) string
    peak_mat_path (1,1) string
    output_dir (1,1) string
    options.shift_scan_s (:,1) double = (-0.003:0.00001:0.003).'
    options.slow_window_pulses (1,1) double = 21
    options.show_figures (1,1) logical = true
end

if ~isfile(replay_mat_path)
    error('dpll:ReplayNotFound', 'Replay MAT file does not exist: %s', ...
        replay_mat_path);
end
if ~isfile(peak_mat_path)
    error('dpll:PeakFileNotFound', 'Peak MAT file does not exist: %s', ...
        peak_mat_path);
end
if isempty(options.shift_scan_s) || any(~isfinite(options.shift_scan_s))
    error('dpll:InvalidShiftScan', 'shift_scan_s must be finite and nonempty.');
end
validateattributes(options.slow_window_pulses, {'numeric'}, ...
    {'scalar', 'integer', '>=', 3});

raw_dir = fullfile(output_dir, 'raw');
table_dir = fullfile(output_dir, 'tables');
figure_dir = fullfile(output_dir, 'figures');
if ~isfolder(raw_dir), mkdir(raw_dir); end
if ~isfolder(table_dir), mkdir(table_dir); end
if ~isfolder(figure_dir), mkdir(figure_dir); end

frozen = load(replay_mat_path, 'result', 'summary');
if ~isfield(frozen, 'result')
    error('dpll:MissingReplayResult', ...
        'Replay MAT file does not contain result.');
end
result = frozen.result;
if result.metadata.posterior_interval_data_used
    error('dpll:PosteriorContamination', ...
        'The frozen DPLL replay already used posterior interval data.');
end

validation = validate_peak_alignment(result, peak_mat_path, false);
reference = reconstruct_reference_phase(result);
real_case = build_real_case(result, validation, reference, ...
    options.slow_window_pulses);
lag_scan = build_lag_scan(result, validation, reference, ...
    options.shift_scan_s);
synthetic_case = build_exact_cycle_case(result, validation, reference, ...
    options.slow_window_pulses);

metrics = build_metrics_table(real_case, synthetic_case);
autocorrelation = build_autocorrelation_table(real_case, 12);
real_intervals = build_real_interval_table(real_case);
synthetic_intervals = build_synthetic_interval_table(synthetic_case);
psd = build_psd_table(real_case, synthetic_case);

study.schema_version = 1;
study.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
study.method = ['Frozen posterior decomposition using detector-observable ' ...
    'reference phase, followed by exact-113-cycle synthetic events.'];
study.config = result.config;
study.reference = reference;
study.real = real_case;
study.synthetic = synthetic_case;
study.metrics = metrics;
study.lag_scan = lag_scan;
study.autocorrelation = autocorrelation;
study.psd = psd;
study.metadata.posterior_data_used = true;
study.metadata.posterior_used_for_gain_selection = false;
study.metadata.shift_scan_applied_to_pll = false;
study.metadata.replay_mat = char(replay_mat_path);
study.metadata.peak_mat = char(peak_mat_path);
study.metadata.reference_source_mat = result.metadata.source_file;
study.metadata.replay_sha256 = dpll.file_sha256(replay_mat_path);
study.metadata.peak_sha256 = dpll.file_sha256(peak_mat_path);
study.metadata.reference_source_sha256 = ...
    dpll.file_sha256(string(result.metadata.source_file));

writetable(metrics, fullfile(table_dir, 'summary_metrics.csv'));
writetable(lag_scan, fullfile(table_dir, 'fixed_delay_scan.csv'));
writetable(autocorrelation, ...
    fullfile(table_dir, 'residual_autocorrelation.csv'));
writetable(real_intervals, ...
    fullfile(table_dir, 'real_peak_interval_decomposition.csv'));
writetable(synthetic_intervals, ...
    fullfile(table_dir, 'synthetic_exact113_intervals.csv'));
writetable(psd, fullfile(table_dir, 'residual_psd.csv'));

provenance = table( ...
    string({'frozen_replay'; 'peak_posterior'; 'reference_source'}), ...
    string({study.metadata.replay_mat; study.metadata.peak_mat; ...
    study.metadata.reference_source_mat}), ...
    string({study.metadata.replay_sha256; study.metadata.peak_sha256; ...
    study.metadata.reference_source_sha256}), ...
    'VariableNames', {'role', 'path', 'sha256'});
writetable(provenance, fullfile(table_dir, 'source_provenance.csv'));

study.figure_files = make_figures(study, figure_dir, ...
    options.show_figures);
study.report_path = write_report(study, output_dir);

save(fullfile(raw_dir, 'reference_phase_ceiling_validation.mat'), ...
    'study', 'validation', '-v7.3');
save(fullfile(output_dir, 'reference_phase_validation_complete.mat'), ...
    'study', '-v7.3');

fprintf('\nReference-phase ceiling validation complete.\n');
fprintf('  Output: %s\n', output_dir);
fprintf('  Real PLL residual RMS       : %.6f cycles\n', ...
    rms_plain(real_case.pll_residual_error));
fprintf('  Reference-phase ceiling RMS : %.6f cycles\n', ...
    rms_plain(real_case.reference_ceiling_error));
fprintf('  PLL minus reference RMS     : %.6f cycles\n', ...
    rms_plain(real_case.pll_minus_reference_error));
fprintf('  Exact-113 synthetic PLL RMS : %.6f cycles\n', ...
    rms_plain(synthetic_case.pll_residual_error));
fprintf('  Report: %s\n', study.report_path);
end

function reference = reconstruct_reference_phase(result)
trace = result.trace;
keep = trace.analysis_valid & isfinite(trace.tracking_phase_rad) & ...
    isfinite(double(trace.phase_error));
if nnz(keep) < 3
    error('dpll:InsufficientReferencePhase', ...
        'Too few analysis-valid detector samples reconstruct reference phase.');
end

raw_index = double(result.metadata.source_raw_start_index) + ...
    (double(trace.input_index(keep)) - ...
    double(result.metadata.input_start_index)) * ...
    double(result.metadata.source_samples_per_input);
phase_error_rad = double(trace.phase_error(keep)) * pi / ...
    2^(result.config.phase_width - 1);
phase_setpoint_rad = double(result.config.phase_setpoint) * pi / ...
    2^(result.config.phase_width - 1);
detector_phase_rad = unwrap(phase_error_rad + phase_setpoint_rad);
nco_phase_rad = double(trace.tracking_phase_rad(keep));
reference_phase_rad = nco_phase_rad + detector_phase_rad;

[raw_index, last_index] = unique(raw_index, 'last');
phase_error_rad = phase_error_rad(last_index);
detector_phase_rad = detector_phase_rad(last_index);
nco_phase_rad = nco_phase_rad(last_index);
reference_phase_rad = reference_phase_rad(last_index);
reference_phase_cycles = reference_phase_rad / (2 * pi);
if any(diff(reference_phase_cycles) <= 0)
    error('dpll:NonmonotonicReferencePhase', ...
        'Reconstructed reference phase is not strictly increasing.');
end

reference.raw_index = raw_index;
reference.time_s = (raw_index - 1) / ...
    result.metadata.source_raw_sample_rate_hz;
reference.phase_error_rad = phase_error_rad;
reference.detector_phase_rad = detector_phase_rad;
reference.nco_phase_rad = nco_phase_rad;
reference.reference_phase_rad = reference_phase_rad;
reference.reference_phase_cycles = reference_phase_cycles;
reference.sample_count = numel(raw_index);
reference.minimum_cycle_increment = min(diff(reference_phase_cycles));
end

function real_case = build_real_case(result, validation, reference, slow_window)
peak_raw = double(validation.peak_raw_index(:));
reference_phase_at_peak = interp1(reference.raw_index, ...
    reference.reference_phase_cycles, peak_raw, 'linear', NaN);
phase_error_at_peak = interp1(reference.raw_index, ...
    reference.phase_error_rad, peak_raw, 'linear', NaN);
if any(~isfinite(reference_phase_at_peak)) || ...
        any(~isfinite(phase_error_at_peak))
    error('dpll:ReferencePhaseCoverage', ...
        'Reference phase does not cover all real validation peaks.');
end

multiplier = result.config.pulse.output_multiplier;
ideal = result.config.pulse.ideal_interval_samples;
reference_interval = diff(reference_phase_at_peak) * multiplier;
reference_ceiling_error = reference_interval - ideal;
pll_residual_error = validation.recovered_interval_error(:);
fixed_error = validation.uncompensated_interval_error_output_cycles(:);
pll_minus_reference = pll_residual_error - reference_ceiling_error;
endpoint_prediction = -diff(phase_error_at_peak) / (2 * pi) * multiplier;
removed_error = fixed_error - pll_residual_error;

real_case.peak_raw_index = peak_raw;
real_case.peak_time_s = validation.peak_time_s(:);
real_case.interval_time_s = validation.peak_time_s(2:end);
real_case.fixed_clock_error = fixed_error;
real_case.reference_ceiling_error = reference_ceiling_error;
real_case.pll_residual_error = pll_residual_error;
real_case.pll_minus_reference_error = pll_minus_reference;
real_case.endpoint_phase_prediction = endpoint_prediction;
real_case.removed_error = removed_error;
real_case.reference_phase_at_peak_cycles = reference_phase_at_peak;
real_case.phase_error_at_peak_rad = phase_error_at_peak;
real_case.fixed_to_output_scale = validation.fixed_to_output_scale;
real_case.slow_window_pulses = min(slow_window, numel(fixed_error));
real_case.decomposition = decompose_series(real_case, ...
    {'fixed_clock_error', 'reference_ceiling_error', ...
    'pll_residual_error', 'pll_minus_reference_error'}, ...
    real_case.slow_window_pulses);
real_case.correlations.pll_vs_reference = ...
    corr(pll_residual_error, reference_ceiling_error);
real_case.correlations.reference_vs_fixed = ...
    corr(reference_ceiling_error, fixed_error);
real_case.correlations.removed_vs_fixed = corr(removed_error, fixed_error);
real_case.correlations.controller_vs_endpoint_prediction = ...
    corr(pll_minus_reference, endpoint_prediction);
real_case.cumulative.reference_ceiling = ...
    [0; cumsum(reference_ceiling_error)];
real_case.cumulative.pll_residual = [0; cumsum(pll_residual_error)];
real_case.cumulative.pll_minus_reference = ...
    [0; cumsum(pll_minus_reference)];
end

function lag_scan = build_lag_scan(result, validation, reference, shifts_s)
peak_raw = double(validation.peak_raw_index(:));
fixed_error = validation.uncompensated_interval_error_output_cycles(:);
pll_error = validation.recovered_interval_error(:);
compensation = fixed_error - pll_error;
interval_time = validation.peak_time_s(2:end);
raw_rate = result.metadata.source_raw_sample_rate_hz;
multiplier = result.config.pulse.output_multiplier;
ideal = result.config.pulse.ideal_interval_samples;

count = numel(shifts_s);
oracle_std = nan(count, 1);
oracle_rms = nan(count, 1);
oracle_pll_corr = nan(count, 1);
oracle_fixed_corr = nan(count, 1);
fit_scale = nan(count, 1);
fit_residual_std = nan(count, 1);
fit_corr = nan(count, 1);
for k = 1:count
    shifted_peak = peak_raw + shifts_s(k) * raw_rate;
    phase_at_peak = interp1(reference.raw_index, ...
        reference.reference_phase_cycles, shifted_peak, 'linear', NaN);
    oracle = diff(phase_at_peak) * multiplier - ideal;
    valid = isfinite(oracle);
    if nnz(valid) >= 3
        oracle_std(k) = std(oracle(valid));
        oracle_rms(k) = rms_plain(oracle(valid));
        oracle_pll_corr(k) = corr(oracle(valid), pll_error(valid));
        oracle_fixed_corr(k) = corr(oracle(valid), fixed_error(valid));
    end

    shifted_compensation = interp1(interval_time, compensation, ...
        interval_time + shifts_s(k), 'pchip', NaN);
    valid = isfinite(shifted_compensation);
    if nnz(valid) >= 3
        design = [ones(nnz(valid), 1), shifted_compensation(valid)];
        coefficient = design \ fixed_error(valid);
        fit_error = fixed_error(valid) - design * coefficient;
        fit_scale(k) = coefficient(2);
        fit_residual_std(k) = std(fit_error);
        fit_corr(k) = corr(fixed_error(valid), shifted_compensation(valid));
    end
end
lag_scan = table(shifts_s, oracle_std, oracle_rms, oracle_pll_corr, ...
    oracle_fixed_corr, fit_scale, fit_residual_std, fit_corr, ...
    'VariableNames', {'shift_s', 'reference_ceiling_std_cycles', ...
    'reference_ceiling_rms_cycles', 'reference_pll_correlation', ...
    'reference_fixed_correlation', 'compensation_fit_scale', ...
    'compensation_fit_residual_std_cycles', ...
    'compensation_fixed_correlation'});
end

function synthetic = build_exact_cycle_case(result, validation, reference, slow_window)
ratio = result.config.pulse.reference_cycles_per_pulse;
multiplier = result.config.pulse.output_multiplier;
ideal = ratio * multiplier;
raw_start = max(reference.raw_index(1), validation.peak_raw_index(1));
raw_end = min(reference.raw_index(end), validation.peak_raw_index(end));
cycle_start = interp1(reference.raw_index, ...
    reference.reference_phase_cycles, raw_start, 'linear');
cycle_end = interp1(reference.raw_index, ...
    reference.reference_phase_cycles, raw_end, 'linear');
first_target = ceil(cycle_start / ratio) * ratio;
last_target = floor(cycle_end / ratio) * ratio;
target_cycles = (first_target:ratio:last_target).';
if numel(target_cycles) < 3
    error('dpll:InsufficientSyntheticEvents', ...
        'Fewer than three exact-cycle events fit the validation range.');
end

synthetic_raw = interp1(reference.reference_phase_cycles, ...
    reference.raw_index, target_cycles, 'linear');
synthetic_tick = (synthetic_raw - 1) * result.config.fabric_clock_hz / ...
    result.metadata.source_raw_sample_rate_hz;
output_cycles = integrate_word_history(result.word_history, ...
    synthetic_tick, multiplier, result.config.word_width);
pll_interval = diff(output_cycles);
pll_error = pll_interval - ideal;
reference_interval = diff(target_cycles) * multiplier;
reference_error = reference_interval - ideal;
fixed_interval = diff(synthetic_raw);
fixed_scale = ideal / mean(fixed_interval);
fixed_error = fixed_interval * fixed_scale - ideal;
phase_error_at_event = interp1(reference.raw_index, ...
    reference.phase_error_rad, synthetic_raw, 'linear');
endpoint_prediction = -diff(phase_error_at_event) / (2 * pi) * multiplier;

synthetic.target_reference_cycles = target_cycles;
synthetic.peak_raw_index = synthetic_raw;
synthetic.peak_time_s = (synthetic_raw - 1) / ...
    result.metadata.source_raw_sample_rate_hz;
synthetic.interval_time_s = synthetic.peak_time_s(2:end);
synthetic.output_cycles_at_peak = output_cycles;
synthetic.fixed_clock_error = fixed_error;
synthetic.reference_error = reference_error;
synthetic.pll_residual_error = pll_error;
synthetic.endpoint_phase_prediction = endpoint_prediction;
synthetic.phase_error_at_peak_rad = phase_error_at_event;
synthetic.fixed_to_output_scale = fixed_scale;
synthetic.slow_window_pulses = min(slow_window, numel(pll_error));
synthetic.decomposition = decompose_series(synthetic, ...
    {'fixed_clock_error', 'pll_residual_error'}, ...
    synthetic.slow_window_pulses);
synthetic.correlations.pll_vs_endpoint_prediction = ...
    corr(pll_error, endpoint_prediction);
synthetic.cumulative.pll_residual = [0; cumsum(pll_error)];
end

function output = decompose_series(input, field_names, window)
output = struct();
for k = 1:numel(field_names)
    name = field_names{k};
    values = input.(name)(:);
    slow = movmean(values, window, 'Endpoints', 'shrink');
    output.(name).slow = slow;
    output.(name).fast = values - slow;
end
end

function metrics = build_metrics_table(real_case, synthetic)
rows = repmat(empty_metric_row(), 0, 1);
rows(end + 1, 1) = metric_row('real', 'fixed_clock', ...
    real_case.fixed_clock_error, ...
    real_case.decomposition.fixed_clock_error); %#ok<AGROW>
rows(end + 1, 1) = metric_row('real', 'reference_phase_ceiling', ...
    real_case.reference_ceiling_error, ...
    real_case.decomposition.reference_ceiling_error); %#ok<AGROW>
rows(end + 1, 1) = metric_row('real', 'pll_output_residual', ...
    real_case.pll_residual_error, ...
    real_case.decomposition.pll_residual_error); %#ok<AGROW>
rows(end + 1, 1) = metric_row('real', 'pll_minus_reference', ...
    real_case.pll_minus_reference_error, ...
    real_case.decomposition.pll_minus_reference_error); %#ok<AGROW>
rows(end + 1, 1) = metric_row('synthetic_exact113', 'fixed_clock', ...
    synthetic.fixed_clock_error, ...
    synthetic.decomposition.fixed_clock_error); %#ok<AGROW>
rows(end + 1, 1) = metric_row('synthetic_exact113', ...
    'reference_phase_truth', synthetic.reference_error, []); %#ok<AGROW>
rows(end + 1, 1) = metric_row('synthetic_exact113', ...
    'pll_output_residual', synthetic.pll_residual_error, ...
    synthetic.decomposition.pll_residual_error); %#ok<AGROW>
metrics = struct2table(rows);
end

function row = empty_metric_row()
row.domain = "";
row.series = "";
row.count = 0;
row.mean_cycles = NaN;
row.std_cycles = NaN;
row.rms_cycles = NaN;
row.peak_to_peak_cycles = NaN;
row.slow_std_cycles = NaN;
row.fast_std_cycles = NaN;
row.lag1_correlation = NaN;
end

function row = metric_row(domain, series, values, decomposition)
values = double(values(:));
row = empty_metric_row();
row.domain = string(domain);
row.series = string(series);
row.count = numel(values);
row.mean_cycles = mean(values);
row.std_cycles = std(values);
row.rms_cycles = rms_plain(values);
row.peak_to_peak_cycles = max(values) - min(values);
if ~isempty(decomposition)
    row.slow_std_cycles = std(decomposition.slow);
    row.fast_std_cycles = std(decomposition.fast);
end
if numel(values) >= 3 && std(values(1:end-1)) > 0 && ...
        std(values(2:end)) > 0
    row.lag1_correlation = corr(values(1:end-1), values(2:end));
end
end

function table_value = build_autocorrelation_table(real_case, max_lag)
names = ["real_fixed_clock"; "real_reference_phase_ceiling"; ...
    "real_pll_residual"; "real_pll_minus_reference"];
values = {real_case.fixed_clock_error; ...
    real_case.reference_ceiling_error; real_case.pll_residual_error; ...
    real_case.pll_minus_reference_error};
series = strings(numel(names) * max_lag, 1);
lag_pulses = zeros(numel(series), 1);
correlation = nan(numel(series), 1);
index = 0;
for k = 1:numel(names)
    x = double(values{k}(:));
    x = x - mean(x);
    for lag = 1:max_lag
        index = index + 1;
        series(index) = names(k);
        lag_pulses(index) = lag;
        correlation(index) = corr(x(1:end-lag), x(1+lag:end));
    end
end
table_value = table(series, lag_pulses, correlation);
end

function table_value = build_real_interval_table(real_case)
count = numel(real_case.pll_residual_error);
interval_index = (1:count).';
interval_end_time_s = real_case.interval_time_s(:);
interval_end_peak_raw_index = real_case.peak_raw_index(2:end);
fixed_clock_error_cycles = real_case.fixed_clock_error;
reference_phase_ceiling_error_cycles = ...
    real_case.reference_ceiling_error;
pll_residual_error_cycles = real_case.pll_residual_error;
pll_minus_reference_error_cycles = ...
    real_case.pll_minus_reference_error;
endpoint_phase_prediction_cycles = real_case.endpoint_phase_prediction;
removed_error_cycles = real_case.removed_error;
fixed_fast_cycles = real_case.decomposition.fixed_clock_error.fast;
reference_fast_cycles = ...
    real_case.decomposition.reference_ceiling_error.fast;
pll_fast_cycles = real_case.decomposition.pll_residual_error.fast;
table_value = table(interval_index, interval_end_time_s, ...
    interval_end_peak_raw_index, fixed_clock_error_cycles, ...
    reference_phase_ceiling_error_cycles, pll_residual_error_cycles, ...
    pll_minus_reference_error_cycles, endpoint_phase_prediction_cycles, ...
    removed_error_cycles, fixed_fast_cycles, reference_fast_cycles, ...
    pll_fast_cycles);
end

function table_value = build_synthetic_interval_table(synthetic)
count = numel(synthetic.pll_residual_error);
interval_index = (1:count).';
interval_end_time_s = synthetic.interval_time_s(:);
interval_start_raw_index = synthetic.peak_raw_index(1:end-1);
interval_end_raw_index = synthetic.peak_raw_index(2:end);
target_start_reference_cycles = ...
    synthetic.target_reference_cycles(1:end-1);
target_end_reference_cycles = ...
    synthetic.target_reference_cycles(2:end);
fixed_clock_error_cycles = synthetic.fixed_clock_error;
reference_truth_error_cycles = synthetic.reference_error;
pll_residual_error_cycles = synthetic.pll_residual_error;
endpoint_phase_prediction_cycles = synthetic.endpoint_phase_prediction;
pll_fast_cycles = synthetic.decomposition.pll_residual_error.fast;
table_value = table(interval_index, interval_end_time_s, ...
    interval_start_raw_index, interval_end_raw_index, ...
    target_start_reference_cycles, target_end_reference_cycles, ...
    fixed_clock_error_cycles, reference_truth_error_cycles, ...
    pll_residual_error_cycles, endpoint_phase_prediction_cycles, ...
    pll_fast_cycles);
end

function psd_table = build_psd_table(real_case, synthetic)
real_rate = 1 / median(diff(real_case.interval_time_s));
synthetic_rate = 1 / median(diff(synthetic.interval_time_s));
real_series = {real_case.fixed_clock_error, ...
    real_case.reference_ceiling_error, real_case.pll_residual_error, ...
    real_case.pll_minus_reference_error};
real_names = ["real_fixed_clock", "real_reference_phase_ceiling", ...
    "real_pll_residual", "real_pll_minus_reference"];
synthetic_series = {synthetic.fixed_clock_error, ...
    synthetic.pll_residual_error};
synthetic_names = ["synthetic_fixed_clock", "synthetic_pll_residual"];

series = strings(0, 1);
frequency_hz = zeros(0, 1);
cycles2_per_hz = zeros(0, 1);
for k = 1:numel(real_series)
    [point_frequency_hz, density] = ...
        dpll.welch_psd(real_series{k}, real_rate);
    series = [series; repmat(real_names(k), ...
        numel(point_frequency_hz), 1)]; %#ok<AGROW>
    frequency_hz = [frequency_hz; point_frequency_hz]; %#ok<AGROW>
    cycles2_per_hz = [cycles2_per_hz; density]; %#ok<AGROW>
end
for k = 1:numel(synthetic_series)
    [point_frequency_hz, density] = ...
        dpll.welch_psd(synthetic_series{k}, synthetic_rate);
    series = [series; repmat(synthetic_names(k), ...
        numel(point_frequency_hz), 1)]; %#ok<AGROW>
    frequency_hz = [frequency_hz; point_frequency_hz]; %#ok<AGROW>
    cycles2_per_hz = [cycles2_per_hz; density]; %#ok<AGROW>
end
psd_table = table(series, frequency_hz, cycles2_per_hz);
end

function files = make_figures(study, figure_dir, show_figures)
visibility = 'off';
if show_figures, visibility = 'on'; end
files.real = make_real_figure(study, figure_dir, visibility);
files.synthetic = make_synthetic_figure(study, figure_dir, visibility);
files.diagnostics = make_diagnostic_figure(study, figure_dir, visibility);
end

function files = make_real_figure(study, figure_dir, visibility)
r = study.real;
t = r.interval_time_s;
fig = figure('Visible', visibility, 'Name', ...
    'Real-pulse reference-phase ceiling decomposition', 'Color', 'w');
layout = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, ['Real pulse validation: detector-observable reference ' ...
    'ceiling versus frozen PLL']);

nexttile;
plot(t, r.fixed_clock_error, '.-', 'Color', [0.12 0.42 0.72], ...
    'DisplayName', 'Fixed-clock equivalent');
yline(0, '--k', 'HandleVisibility', 'off');
ylabel('Error (cycles)'); grid on;
legend('Location', 'best');

nexttile;
plot(t, r.reference_ceiling_error, 'o-', 'MarkerSize', 2.5, ...
    'Color', [0.82 0.33 0.16], 'DisplayName', 'Reference-phase ceiling');
hold on;
plot(t, r.pll_residual_error, '.-', 'Color', [0.10 0.55 0.32], ...
    'DisplayName', 'PLL residual after correction');
yline(0, '--k', 'HandleVisibility', 'off');
ylabel('Residual (cycles)'); grid on;
legend('Location', 'best');

nexttile;
plot(t, r.pll_minus_reference_error, '.-', ...
    'Color', [0.49 0.27 0.67], 'DisplayName', 'PLL minus reference');
hold on;
plot(t, r.endpoint_phase_prediction, '-', 'LineWidth', 0.8, ...
    'Color', [0.35 0.35 0.35], ...
    'DisplayName', 'Endpoint residual-phase prediction');
yline(0, '--k', 'HandleVisibility', 'off');
ylabel('Loop-only (cycles)'); grid on;
legend('Location', 'best');

nexttile;
plot(r.peak_time_s, r.cumulative.reference_ceiling, '-', ...
    'Color', [0.82 0.33 0.16], ...
    'DisplayName', 'Reference-phase ceiling');
hold on;
plot(r.peak_time_s, r.cumulative.pll_residual, '-', ...
    'Color', [0.10 0.55 0.32], 'DisplayName', 'PLL residual');
yline(0, '--k', 'HandleVisibility', 'off');
xlabel('Time (s)'); ylabel('Cumulative (cycles)'); grid on;
legend('Location', 'best');

files = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'real_peak_reference_phase_decomposition'), ...
    [7.2 8.0]);
if strcmp(visibility, 'off'), close(fig); end
end

function files = make_synthetic_figure(study, figure_dir, visibility)
s = study.synthetic;
t = s.interval_time_s;
fig = figure('Visible', visibility, 'Name', ...
    'Exact-113-cycle synthetic event validation', 'Color', 'w');
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, ['Synthetic events exactly 113 detector-observable ' ...
    'reference cycles apart']);

nexttile;
plot(t, s.fixed_clock_error, '.-', 'Color', [0.12 0.42 0.72], ...
    'DisplayName', 'Fixed-clock equivalent');
hold on;
plot(t, s.pll_residual_error, '.-', 'Color', [0.10 0.55 0.32], ...
    'DisplayName', 'PLL residual');
yline(0, '--k', 'HandleVisibility', 'off');
ylabel('Error (cycles)'); grid on;
legend('Location', 'best');

nexttile;
plot(t, s.decomposition.fixed_clock_error.fast, '.-', ...
    'Color', [0.12 0.42 0.72], 'DisplayName', 'Fixed-clock fast');
hold on;
plot(t, s.decomposition.pll_residual_error.fast, '.-', ...
    'Color', [0.10 0.55 0.32], 'DisplayName', 'PLL fast residual');
yline(0, '--k', 'HandleVisibility', 'off');
ylabel('Fast error (cycles)'); grid on;
legend('Location', 'best');

nexttile;
plot(s.peak_time_s, s.cumulative.pll_residual, '-', ...
    'Color', [0.49 0.27 0.67]);
yline(0, '--k');
xlabel('Time (s)'); ylabel('Cumulative PLL error (cycles)'); grid on;

files = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'synthetic_exact113_cycle_validation'), ...
    [7.2 6.6]);
if strcmp(visibility, 'off'), close(fig); end
end

function files = make_diagnostic_figure(study, figure_dir, visibility)
fig = figure('Visible', visibility, 'Name', ...
    'Reference-pulse causality diagnostics', 'Color', 'w');
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, 'Delay, spectrum, and differenced-position-noise diagnostics');

nexttile;
plot(1e3 * study.lag_scan.shift_s, ...
    study.lag_scan.reference_ceiling_std_cycles, 'LineWidth', 1.0, ...
    'Color', [0.82 0.33 0.16]);
xlabel('Reference time shift (ms)'); ylabel('Residual std (cycles)');
grid on;

nexttile; hold on;
selected = ["real_fixed_clock", "real_reference_phase_ceiling", ...
    "real_pll_residual"];
colors = [0.12 0.42 0.72; 0.82 0.33 0.16; 0.10 0.55 0.32];
for k = 1:numel(selected)
    use = study.psd.series == selected(k);
    semilogy(study.psd.frequency_hz(use), ...
        study.psd.cycles2_per_hz(use), 'LineWidth', 1.0, ...
        'Color', colors(k, :), ...
        'DisplayName', strrep(selected(k), '_', ' '));
end
xlabel('Pulse-domain frequency (Hz)');
ylabel('PSD (cycles^2/Hz)'); grid on;
legend('Location', 'best');

nexttile; hold on;
selected = ["real_reference_phase_ceiling", "real_pll_residual", ...
    "real_pll_minus_reference"];
colors = [0.82 0.33 0.16; 0.10 0.55 0.32; 0.49 0.27 0.67];
for k = 1:numel(selected)
    use = study.autocorrelation.series == selected(k);
    plot(study.autocorrelation.lag_pulses(use), ...
        study.autocorrelation.correlation(use), 'o-', ...
        'MarkerSize', 3, 'Color', colors(k, :), ...
        'DisplayName', strrep(selected(k), '_', ' '));
end
yline(0, '--k', 'HandleVisibility', 'off');
xlabel('Lag (pulses)'); ylabel('Autocorrelation'); grid on;
legend('Location', 'best');

files = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'reference_pulse_causality_diagnostics'), ...
    [7.2 7.2]);
if strcmp(visibility, 'off'), close(fig); end
end

function report_path = write_report(study, output_dir)
report_path = fullfile(output_dir, ...
    'reference_phase_validation_report.md');
file_id = fopen(report_path, 'w');
if file_id < 0
    error('dpll:ReportOpenFailed', 'Cannot create report: %s', report_path);
end
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>

real_metric = study.metrics(study.metrics.domain == "real", :);
synthetic_metric = study.metrics( ...
    study.metrics.domain == "synthetic_exact113", :);
[best_oracle_std, best_index] = min( ...
    study.lag_scan.reference_ceiling_std_cycles);
[best_fit_std, fit_index] = min( ...
    study.lag_scan.compensation_fit_residual_std_cycles);

fprintf(file_id, '# Reference-phase ceiling validation\n\n');
fprintf(file_id, 'Generated: %s\n\n', study.created_at);
fprintf(file_id, ['The frozen replay was produced before loading true peak ' ...
    'intervals. Posterior peak positions are used only for validation and ' ...
    'are not used to fit PLL gains or alter the replay.\n\n']);
fprintf(file_id, '## Frozen configuration\n\n');
fprintf(file_id, '- Post-IQ CIC shift: **%d**\n', ...
    study.config.cic.output_shift);
fprintf(file_id, '- P product shift: **%d**\n', ...
    study.config.shifts.p_product);
fprintf(file_id, '- TRACK Kp/Ki: **%d / %d**\n', ...
    study.config.gains.kp_track, study.config.gains.ki_track);
fprintf(file_id, '- TRACK Kf: **%d**\n\n', study.config.gains.kf_track);

fprintf(file_id, '## Real-pulse decomposition\n\n');
write_metric_table(file_id, real_metric);
fprintf(file_id, ['\nThe detector-observable reference ceiling and the ' ...
    'actual PLL residual have correlation **%.6f**. Their difference has ' ...
    'RMS **%.6f cycles**, which is the loop-only contribution under this ' ...
    'decomposition.\n\n'], study.real.correlations.pll_vs_reference, ...
    rms_plain(study.real.pll_minus_reference_error));
fprintf(file_id, ['The endpoint residual-phase prediction correlates with ' ...
    'the loop-only contribution at **%.6f**.\n\n'], ...
    study.real.correlations.controller_vs_endpoint_prediction);

fprintf(file_id, '## Exact-113-cycle synthetic events\n\n');
write_metric_table(file_id, synthetic_metric);
fprintf(file_id, ['\nSynthetic event positions are generated from the same ' ...
    'real reconstructed reference phase, exactly 113 cycles apart. No real ' ...
    'peak position enters this event generation.\n\n']);

fprintf(file_id, '## Delay and gain diagnostics\n\n');
fprintf(file_id, ['- Minimum reference-ceiling std: **%.6f cycles** at ' ...
    '**%+.6f ms**.\n'], best_oracle_std, ...
    1e3 * study.lag_scan.shift_s(best_index));
fprintf(file_id, ['- Best posterior affine compensation residual std: ' ...
    '**%.6f cycles** at **%+.6f ms**, scale **%.6f**.\n'], ...
    best_fit_std, 1e3 * study.lag_scan.shift_s(fit_index), ...
    study.lag_scan.compensation_fit_scale(fit_index));
fprintf(file_id, ['- Reference-ceiling lag-1 correlation: **%.6f**. ' ...
    'A value near -0.5 is consistent with independent peak-position noise ' ...
    'appearing after adjacent-interval differencing.\n\n'], ...
    lag_one(study.autocorrelation, "real_reference_phase_ceiling"));

fprintf(file_id, '## Interpretation\n\n');
fprintf(file_id, ['The exact-cycle synthetic result quantifies the error ' ...
    'that remains when pulse events are perfectly tied to the reference. ' ...
    'The gap between the real reference ceiling and the exact-cycle result ' ...
    'quantifies real-peak/reference inconsistency visible to this dataset. ' ...
    'Increasing controller bandwidth cannot remove a component absent from ' ...
    'the detector-observable reference phase.\n']);
end

function write_metric_table(file_id, metrics)
fprintf(file_id, ['| Series | Mean (cycles) | Std (cycles) | RMS (cycles) ' ...
    '| Fast std (cycles) | Lag-1 corr |\n']);
fprintf(file_id, '|---|---:|---:|---:|---:|---:|\n');
for k = 1:height(metrics)
    fprintf(file_id, '| %s | %.6f | %.6f | %.6f | %.6f | %.6f |\n', ...
        strrep(metrics.series(k), '_', ' '), metrics.mean_cycles(k), ...
        metrics.std_cycles(k), metrics.rms_cycles(k), ...
        metrics.fast_std_cycles(k), metrics.lag1_correlation(k));
end
end

function value = lag_one(table_value, name)
use = table_value.series == name & table_value.lag_pulses == 1;
value = table_value.correlation(use);
end

function cycles = integrate_word_history(history, query_tick, multiplier, word_width)
ticks = double(history.fabric_tick(:));
words = double(history.tracking_word(:));
if isempty(ticks) || ticks(1) > min(query_tick)
    error('dpll:WordHistoryCoverage', ...
        'Tracking-word history does not cover synthetic events.');
end
[ticks, last_index] = unique(ticks, 'last');
words = words(last_index);
segment_cycles = diff(ticks) .* words(1:end-1) * multiplier / 2^word_width;
cumulative = [0; cumsum(segment_cycles)];
cycles = zeros(size(query_tick));
for k = 1:numel(query_tick)
    index = find(ticks <= query_tick(k), 1, 'last');
    if isempty(index)
        error('dpll:WordHistoryCoverage', ...
            'Synthetic event precedes tracking-word history.');
    end
    cycles(k) = cumulative(index) + ...
        (query_tick(k) - ticks(index)) * words(index) * ...
        multiplier / 2^word_width;
end
end

function value = rms_plain(values)
values = double(values(:));
value = sqrt(mean(values.^2));
end
