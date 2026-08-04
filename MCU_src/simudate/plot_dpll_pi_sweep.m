function figures = plot_dpll_pi_sweep(case_set, output_dir, title_text, stem)
%PLOT_DPLL_PI_SWEEP Paper figures for controller-parameter comparisons.

figure_dir = fullfile(output_dir, 'figures');
if ~isfolder(figure_dir), mkdir(figure_dir); end
metrics = case_set.metrics;
configs = unique(metrics.config_id, 'stable');
colors = [0.00 0.45 0.70; 0.90 0.62 0.00; 0.00 0.62 0.45; ...
    0.80 0.47 0.65; 0.35 0.35 0.35; 0.34 0.71 0.91; ...
    0.84 0.37 0.00; 0.50 0.50 0.00];
markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p'};

fig = figure('Visible', 'off', 'Name', title_text);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, title_text);
for panel = 1:4
    nexttile; hold on;
    for k = 1:numel(configs)
        subset = sortrows(metrics(metrics.config_id == configs(k), :), ...
            'modulation_frequency_hz');
        switch panel
            case 1, values = subset.closed_loop_gain_db;
            case 2, values = subset.closed_loop_phase_deg;
            case 3, values = subset.frequency_residual_gain_db;
            otherwise, values = subset.output_fit_r_squared;
        end
        color_index = 1 + mod(k - 1, size(colors, 1));
        marker_index = 1 + mod(k - 1, numel(markers));
        plot(subset.modulation_frequency_hz, values, ...
            [markers{marker_index} '-'], ...
            'Color', colors(color_index, :), 'LineWidth', 1.0, ...
            'MarkerFaceColor', colors(color_index, :), ...
            'DisplayName', strrep(configs(k), '_', ' '));
    end
    grid on; xlabel('Modulation frequency (Hz)');
    if panel == 1, ylabel('Tracking gain (dB)'); legend('Location', 'best'); end
    if panel == 2, ylabel('Tracking phase (deg)'); end
    if panel == 3, ylabel('Frequency residual / input (dB)'); yline(0, ':'); end
    if panel == 4
        ylabel('Single-tone fit R^2'); ylim([0 1.05]); yline(0.9, ':');
    end
end
figures.response = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, [stem '_response']));
close(fig);

at_80 = metrics(metrics.modulation_frequency_hz == 80, :);
fig = figure('Visible', 'off', 'Name', [title_text ' 80 Hz']);
bar(1:height(at_80), ...
    [at_80.closed_loop_gain_db, at_80.frequency_residual_gain_db], 'grouped');
xticks(1:height(at_80));
xticklabels(strrep(at_80.config_id, '_', ' '));
xtickangle(20);
yline(0, ':'); grid on;
ylabel('Magnitude (dB)');
legend('Tracking gain', 'Residual gain', 'Location', 'best');
title([title_text ': 80 Hz comparison']);
figures.at_80hz = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, [stem '_80hz_comparison']), [7.2 4.8]);
close(fig);
end
