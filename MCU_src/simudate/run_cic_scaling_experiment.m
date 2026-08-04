function experiment = run_cic_scaling_experiment(cfg, output_shifts, output_dir)
%RUN_CIC_SCALING_EXPERIMENT Compare detector scaling on frozen real input.
%
% No peak-position file is opened. Each replay is saved in full before the
% comparison table and figures are generated.

arguments
    cfg (1,1) struct
    output_shifts (1,:) double
    output_dir (1,1) string
end
if ~isfolder(output_dir), mkdir(output_dir); end
raw_dir = fullfile(output_dir, 'raw');
figure_dir = fullfile(output_dir, 'figures');
if ~isfolder(raw_dir), mkdir(raw_dir); end
if ~isfolder(figure_dir), mkdir(figure_dir); end

input_data = load_input_mat(string(cfg.files.pll_input_mat), ...
    cfg.io.input_sample_range);
source_info = dir(cfg.files.pll_input_mat);
provenance.source_file = char(cfg.files.pll_input_mat);
provenance.source_sha256 = dpll.file_sha256(cfg.files.pll_input_mat);
provenance.source_bytes = source_info.bytes;
provenance.source_modified = source_info.date;
provenance.input_sample_range = cfg.io.input_sample_range;
provenance.input_sample_rate_hz = input_data.sample_rate_hz;
provenance.posterior_peak_data_loaded = false;
provenance.created_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));

metric_rows = repmat(empty_metric_row(), numel(output_shifts), 1);
psd_frequency_hz = [];
phase_psd_rad2_per_hz = [];
time_traces = cell(numel(output_shifts), 1);

for k = 1:numel(output_shifts)
    shift = output_shifts(k);
    run_cfg = cfg;
    run_cfg.cic.output_shift = shift;
    run_cfg.files.replay_output_mat = '';
    run_cfg.options.warn_on_saturation = false;
    fprintf('\nCIC scaling replay %d/%d: output_shift=%d\n', ...
        k, numel(output_shifts), shift);
    result = simulate_dpll(input_data, run_cfg);
    summary = analyze_dpll_result(result, false);
    metric_rows(k) = collect_metrics(result, summary, shift);

    valid = result.trace.analysis_valid;
    if ~any(valid), valid = result.trace.loop_state == 6; end
    phase_rad = double(result.trace.phase_error(valid)) * pi / ...
        2^(run_cfg.phase_width - 1);
    time_s = result.trace.time_s(valid);
    trace_rate_hz = 1 / median(diff(time_s));
    [frequency_hz, psd_values] = dpll.welch_psd(phase_rad, trace_rate_hz);
    if isempty(psd_frequency_hz)
        psd_frequency_hz = frequency_hz;
        phase_psd_rad2_per_hz = zeros(numel(frequency_hz), numel(output_shifts));
    elseif ~isequal(size(frequency_hz), size(psd_frequency_hz)) || ...
            any(abs(frequency_hz - psd_frequency_hz) > eps(max(frequency_hz)))
        psd_values = interp1(frequency_hz, psd_values, psd_frequency_hz, ...
            'linear', NaN);
    end
    phase_psd_rad2_per_hz(:, k) = psd_values; %#ok<AGROW>
    time_traces{k} = reduce_time_trace(time_s, phase_rad, 0.20, 6000);

    raw_file = fullfile(raw_dir, sprintf('cic_shift_%02d_replay.mat', shift));
    save(raw_file, 'result', 'summary', 'provenance', '-v7.3');
    fprintf('  frozen raw replay: %s\n', raw_file);
end

metrics = struct2table(metric_rows);
recommended_shift = select_shift(metrics);
experiment.kind = 'post-IQ CIC detector-scaling experiment';
experiment.output_shifts = output_shifts;
experiment.recommended_shift = recommended_shift;
experiment.selection_rule = ['Smallest shift with CIC and CORDIC violation ' ...
    'rates <=1e-5; otherwise minimum combined violation rate.'];
experiment.metrics = metrics;
experiment.psd.frequency_hz = psd_frequency_hz;
experiment.psd.phase_rad2_per_hz = phase_psd_rad2_per_hz;
experiment.provenance = provenance;
experiment.raw_directory = raw_dir;
experiment.figure_directory = figure_dir;

writetable(metrics, fullfile(output_dir, 'cic_scaling_metrics.csv'));
psd_table = array2table([psd_frequency_hz, phase_psd_rad2_per_hz]);
psd_table.Properties.VariableNames = [{'frequency_hz'}, ...
    arrayfun(@(x) sprintf('shift_%d_rad2_per_hz', x), output_shifts, ...
    'UniformOutput', false)];
writetable(psd_table, fullfile(output_dir, 'cic_phase_psd.csv'));
save(fullfile(output_dir, 'cic_scaling_experiment.mat'), ...
    'experiment', 'time_traces', '-v7.3');

fig1 = plot_scaling_metrics(metrics, recommended_shift);
experiment.figure_files.metrics = dpll.export_paper_figure(fig1, ...
    fullfile(figure_dir, 'cic_scaling_metrics'));
close(fig1);
fig2 = plot_phase_comparison(output_shifts, time_traces, ...
    psd_frequency_hz, phase_psd_rad2_per_hz);
experiment.figure_files.phase = dpll.export_paper_figure(fig2, ...
    fullfile(figure_dir, 'cic_phase_residual_comparison'));
close(fig2);
save(fullfile(output_dir, 'cic_scaling_experiment.mat'), ...
    'experiment', 'time_traces', '-v7.3');

fprintf('CIC scaling experiment complete. Recommended output_shift=%d.\n', ...
    recommended_shift);
end

function row = empty_metric_row()
row.output_shift = NaN;
row.analysis_events = NaN;
row.cic_saturation_count = NaN;
row.cic_saturation_rate = NaN;
row.cordic_out_of_range_count = NaN;
row.cordic_out_of_range_rate = NaN;
row.iir_saturation_count = NaN;
row.controller_saturation_count = NaN;
row.phase_mean_rad = NaN;
row.phase_std_rad = NaN;
row.phase_rms_rad = NaN;
row.phase_peak_rad = NaN;
row.freq_error_rms_hz = NaN;
row.tracking_frequency_mean_hz = NaN;
row.tracking_frequency_std_hz = NaN;
row.iq_component_p99_codes = NaN;
row.iq_component_max_codes = NaN;
row.magnitude_p50_codes = NaN;
row.magnitude_p99_codes = NaN;
row.track_fraction = NaN;
end

function row = collect_metrics(result, summary, shift)
valid = result.trace.analysis_valid;
if ~any(valid), valid = result.trace.loop_state == 6; end
phase_rad = double(result.trace.phase_error(valid)) * pi / ...
    2^(result.config.phase_width - 1);
component = max(abs(double(result.trace.i_baseband(valid))), ...
    abs(double(result.trace.q_baseband(valid))));
magnitude = double(result.trace.magnitude(valid));
tracking_hz = result.trace.tracking_frequency_hz(valid);
row = empty_metric_row();
row.output_shift = shift;
row.analysis_events = nnz(valid);
row.cic_saturation_count = summary.analysis_cic_saturation_count;
row.cic_saturation_rate = summary.analysis_cic_saturation_rate;
row.cordic_out_of_range_count = summary.analysis_cordic_out_of_range_count;
row.cordic_out_of_range_rate = summary.analysis_cordic_out_of_range_rate;
row.iir_saturation_count = summary.analysis_iir_saturation_count;
row.controller_saturation_count = summary.controller_saturation_count;
row.phase_mean_rad = mean(phase_rad);
row.phase_std_rad = std(phase_rad);
row.phase_rms_rad = summary.phase_rms_rad;
row.phase_peak_rad = summary.phase_peak_rad;
row.freq_error_rms_hz = summary.freq_error_rms_hz;
row.tracking_frequency_mean_hz = mean(tracking_hz);
row.tracking_frequency_std_hz = std(tracking_hz);
row.iq_component_p99_codes = percentile_plain(component, 99);
row.iq_component_max_codes = max(component);
row.magnitude_p50_codes = percentile_plain(magnitude, 50);
row.magnitude_p99_codes = percentile_plain(magnitude, 99);
row.track_fraction = summary.track_fraction;
end

function shift = select_shift(metrics)
healthy = metrics.cic_saturation_rate <= 1e-5 & ...
    metrics.cordic_out_of_range_rate <= 1e-5;
if any(healthy)
    shift = min(metrics.output_shift(healthy));
else
    cost = metrics.cic_saturation_rate + metrics.cordic_out_of_range_rate;
    best = find(cost == min(cost), 1, 'last');
    shift = metrics.output_shift(best);
end
end

function trace = reduce_time_trace(time_s, phase_rad, duration_s, max_points)
start_time = time_s(1);
keep = time_s <= start_time + duration_s;
time_s = time_s(keep);
phase_rad = phase_rad(keep);
stride = max(1, ceil(numel(time_s) / max_points));
trace.time_s = time_s(1:stride:end) - start_time;
trace.phase_rad = phase_rad(1:stride:end);
end

function fig = plot_scaling_metrics(metrics, recommended_shift)
colors = [0.00 0.45 0.70; 0.90 0.62 0.00; 0.00 0.62 0.45];
fig = figure('Visible', 'off', 'Name', 'CIC scaling metrics');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Post-IQ CIC scaling: detector range and residual metrics');
x = 1:height(metrics);
x_labels = compose('Shift %d', metrics.output_shift);

nexttile;
rates = [metrics.cic_saturation_rate, metrics.cordic_out_of_range_rate];
floor_rate = 0.5 ./ max(metrics.analysis_events, 1);
rates_for_plot = max(rates, floor_rate);
bar(x, rates_for_plot, 'grouped');
xticks(x); xticklabels(x_labels);
set(gca, 'YScale', 'log');
ylabel('Event fraction');
legend('CIC saturation', 'CORDIC range violation', 'Location', 'best');
grid on;

nexttile;
bar(x, metrics.iq_component_p99_codes, 'FaceColor', colors(1, :)); hold on;
yline(262144, '--');
text(x(1), 262144, '  CORDIC component limit', ...
    'VerticalAlignment', 'bottom');
xticks(x); xticklabels(x_labels);
ylabel('Absolute I/Q code');
title('99th-percentile detector component');
grid on;

nexttile;
bar(x, metrics.phase_rms_rad, 'FaceColor', colors(2, :));
xticks(x); xticklabels(x_labels);
ylabel('Phase residual RMS (rad)');
grid on;

nexttile;
bar(x, metrics.freq_error_rms_hz, 'FaceColor', colors(3, :));
xticks(x); xticklabels(x_labels);
ylabel('FLL error RMS (Hz)');
title(sprintf('Selection rule recommends shift %d', recommended_shift));
grid on;
end

function fig = plot_phase_comparison(shifts, traces, frequency_hz, psd_values)
colors = [0.00 0.45 0.70; 0.90 0.62 0.00; 0.00 0.62 0.45];
fig = figure('Visible', 'off', 'Name', 'CIC phase residual comparison');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Phase residual under alternative post-IQ CIC output shifts');
nexttile;
hold on;
for k = 1:numel(shifts)
    plot(traces{k}.time_s, traces{k}.phase_rad, 'LineWidth', 0.8, ...
        'Color', colors(1 + mod(k - 1, size(colors, 1)), :), ...
        'DisplayName', sprintf('Shift %d', shifts(k)));
end
ylabel('Phase error (rad)');
xlabel('Analysis time (s)');
legend('Location', 'best');
grid on;

nexttile;
hold on;
plot_mask = frequency_hz >= 0.5 & frequency_hz <= 1000;
for k = 1:numel(shifts)
    semilogy(frequency_hz(plot_mask), psd_values(plot_mask, k), ...
        'LineWidth', 1.0, ...
        'Color', colors(1 + mod(k - 1, size(colors, 1)), :), ...
        'DisplayName', sprintf('Shift %d', shifts(k)));
end
xlabel('Frequency (Hz)');
ylabel('Phase-error PSD (rad^2/Hz)');
legend('Location', 'best');
grid on;
end

function value = percentile_plain(values, percentile)
values = sort(double(values(:)));
if isempty(values), value = NaN; return; end
position = 1 + (numel(values) - 1) * percentile / 100;
lower_index = floor(position);
upper_index = ceil(position);
if lower_index == upper_index
    value = values(lower_index);
else
    fraction = position - lower_index;
    value = values(lower_index) * (1 - fraction) + ...
        values(upper_index) * fraction;
end
end
