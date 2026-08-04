function figures = plot_dpll_investigation_layer2(case_set, output_dir)
%PLOT_DPLL_INVESTIGATION_LAYER2 Paper figures for PI/FLL isolation.

figure_dir = fullfile(output_dir, 'figures');
if ~isfolder(figure_dir), mkdir(figure_dir); end
metrics = case_set.metrics;
configs = unique(metrics.config_id, 'stable');
colors = [0.00 0.45 0.70; 0.90 0.62 0.00; 0.00 0.62 0.45; ...
    0.80 0.47 0.65; 0.35 0.35 0.35];
markers = {'o', 's', 'd', '^', 'v'};

fig = figure('Visible', 'off', 'Name', 'Layer 2 PI FLL isolation');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Layer 2: isolation of PI and FLL contributions');
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
        plot(subset.modulation_frequency_hz, values, ...
            [markers{k} '-'], 'Color', colors(k, :), 'LineWidth', 1.0, ...
            'MarkerFaceColor', colors(k, :), ...
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
    fullfile(figure_dir, 'layer2_pi_fll_isolation_response'));
close(fig);

at_80 = metrics(metrics.modulation_frequency_hz == 80, :);
at_80 = sortrows(at_80, 'config_id');
fig = figure('Visible', 'off', 'Name', 'Layer 2 controller terms');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Layer 2: controller activity at 80 Hz');
nexttile;
bar(categorical(strrep(at_80.config_id, '_', ' ')), ...
    [at_80.p_term_rms_hz, at_80.i_term_rms_hz, at_80.fll_term_rms_hz], ...
    'grouped');
ylabel('Term RMS (equivalent Hz)'); grid on;
legend('P', 'I', 'Integrated FLL', 'Location', 'best');
nexttile;
bar(categorical(strrep(at_80.config_id, '_', ' ')), ...
    [at_80.closed_loop_gain_db, at_80.frequency_residual_gain_db], ...
    'grouped');
ylabel('Magnitude (dB)'); grid on; yline(0, ':');
legend('Tracking gain', 'Residual gain', 'Location', 'best');
figures.terms = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'layer2_controller_terms_80hz'));
close(fig);
end
