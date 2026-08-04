function regression = run_cold_start_candidate_regression( ...
    baseline_cfg, candidate_cfg, output_dir)
%RUN_COLD_START_CANDIDATE_REGRESSION Compare acquisition on real reference.

figure_dir = fullfile(output_dir, 'figures');
raw_dir = fullfile(output_dir, 'raw');
if ~isfolder(figure_dir), mkdir(figure_dir); end
if ~isfolder(raw_dir), mkdir(raw_dir); end
baseline_cfg.startup.mode = 'cold';
candidate_cfg.startup.mode = 'cold';
baseline_cfg.io.input_sample_range = [1 1500000];
candidate_cfg.io.input_sample_range = baseline_cfg.io.input_sample_range;
input_data = load_input_mat(string(baseline_cfg.files.pll_input_mat), ...
    baseline_cfg.io.input_sample_range);
configs = {baseline_cfg, candidate_cfg};
ids = ["baseline", "optimized"];
results = cell(2, 1);
rows = repmat(struct(), 0, 1);

for k = 1:2
    raw_file = fullfile(raw_dir, sprintf('%s_cold_start.mat', ids(k)));
    if isfile(raw_file)
        frozen = load(raw_file, 'result', 'row');
        result = frozen.result;
        row = frozen.row;
    else
        result = simulate_dpll(input_data, configs{k});
        row = summarize_cold_start(ids(k), result);
        save(raw_file, 'result', 'row', '-v7.3');
    end
    results{k} = result;
    if isempty(rows), rows = row; else, rows(end + 1, 1) = row; end %#ok<AGROW>
end

metrics = struct2table(rows);
regression.metrics = metrics;
regression.results = results;
regression.posterior_peak_data_loaded = false;
writetable(metrics, fullfile(output_dir, 'cold_start_metrics.csv'));
save(fullfile(output_dir, 'cold_start_regression.mat'), ...
    'regression', '-v7.3');

fig = figure('Visible', 'off', 'Name', 'Cold start regression');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Cold-start regression on the same real reference prefix');
colors = [0.00 0.45 0.70; 0.90 0.62 0.00];
nexttile; hold on;
for k = 1:2
    stairs(results{k}.trace.time_s, double(results{k}.trace.loop_state), ...
        'Color', colors(k, :), 'LineWidth', 1.0, ...
        'DisplayName', ids(k));
end
ylabel('Loop state'); grid on; legend('Location', 'best');
nexttile; hold on;
for k = 1:2
    plot(results{k}.trace.time_s, results{k}.trace.tracking_frequency_hz, ...
        'Color', colors(k, :), 'LineWidth', 0.9, ...
        'DisplayName', ids(k));
end
xlabel('Time (s)'); ylabel('Tracking frequency (Hz)'); grid on;
regression.figure_files = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'cold_start_baseline_vs_optimized'));
close(fig);
save(fullfile(output_dir, 'cold_start_regression.mat'), ...
    'regression', '-v7.3');
end

function row = summarize_cold_start(id, result)
track_index = find(result.trace.loop_state == 6, 1, 'first');
if isempty(track_index)
    lock_time_s = NaN;
    track_after_lock = false;
else
    lock_time_s = result.trace.time_s(track_index);
    track_after_lock = all(result.trace.loop_state(track_index:end) == 6);
end
row.config_id = string(id);
row.reached_track = ~isempty(track_index);
row.first_track_time_s = lock_time_s;
row.remained_in_track = track_after_lock;
row.final_frequency_hz = result.trace.tracking_frequency_hz(end);
row.controller_saturation_count = ...
    result.status.controller_saturation_high_count + ...
    result.status.controller_saturation_low_count;
row.cic_saturation_count = result.status.cic_saturation_count;
row.cordic_out_of_range_count = result.status.cordic_out_of_range_count;
row.posterior_data_used = result.metadata.posterior_interval_data_used;
end
