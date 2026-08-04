function figures = plot_dpll_final_investigation_summary(root_dir)
%PLOT_DPLL_FINAL_INVESTIGATION_SUMMARY Consolidated paper-level figures.

figure_dir = fullfile(root_dir, 'figures');
if ~isfolder(figure_dir), mkdir(figure_dir); end
p_data = load(fullfile(root_dir, 'layer3p', 'layer3p_complete.mat'), 'layer3p');
i_data = load(fullfile(root_dir, 'layer3i', 'layer3i_complete.mat'), 'layer3i');
final_data = load(fullfile(root_dir, 'final_response', ...
    'final_response_complete.mat'), 'final_response');
posterior_data = load(fullfile(root_dir, 'posterior_validation', ...
    'posterior_candidate_comparison.mat'), 'comparison');

baseline = p_data.layer3p.metrics( ...
    p_data.layer3p.metrics.config_id == "p1_baseline", :);
optimized = final_data.final_response.response;
optimized = optimized(ismember(optimized.modulation_frequency_hz, ...
    baseline.modulation_frequency_hz), :);
optimized = sortrows(optimized, 'modulation_frequency_hz');
baseline = sortrows(baseline, 'modulation_frequency_hz');

fig = figure('Visible', 'off', 'Name', 'Baseline versus optimized response');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Small-signal response before and after loop-damping correction');
blue = [0.00 0.45 0.70];
orange = [0.90 0.62 0.00];
for panel = 1:4
    nexttile; hold on;
    switch panel
        case 1
            base_values = baseline.closed_loop_gain_db;
            optimized_values = optimized.closed_loop_gain_db;
            label_text = 'Tracking gain (dB)';
        case 2
            base_values = baseline.closed_loop_phase_deg;
            optimized_values = optimized.closed_loop_phase_deg;
            label_text = 'Tracking phase (deg)';
        case 3
            base_values = baseline.frequency_residual_gain_db;
            optimized_values = optimized.frequency_residual_gain_db;
            label_text = 'Frequency residual / input (dB)';
        otherwise
            base_values = baseline.phase_error_rms_rad;
            optimized_values = optimized.phase_error_rms_rad;
            label_text = 'Phase residual RMS (rad)';
    end
    plot(baseline.modulation_frequency_hz, base_values, 'o-', ...
        'Color', blue, 'MarkerFaceColor', blue, 'LineWidth', 1.1, ...
        'DisplayName', 'Baseline: P shift 12');
    plot(optimized.modulation_frequency_hz, optimized_values, 's-', ...
        'Color', orange, 'MarkerFaceColor', orange, 'LineWidth', 1.1, ...
        'DisplayName', 'Optimized: P shift 9');
    xlabel('Modulation frequency (Hz)'); ylabel(label_text); grid on;
    if panel == 1, legend('Location', 'best'); end
    if panel == 3, yline(0, ':'); end
end
figures.response = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'final_baseline_vs_optimized_response'));
close(fig);

p80 = p_data.layer3p.metrics( ...
    p_data.layer3p.metrics.modulation_frequency_hz == 80, :);
p_ratio = (p80.kp_track / 6000000) .* 2.^(12 - p80.p_product_shift);
i80 = i_data.layer3i.metrics( ...
    i_data.layer3i.metrics.modulation_frequency_hz == 80, :);
fig = figure('Visible', 'off', 'Name', 'Parameter causality');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Causal parameter sweep at 80 Hz');
nexttile;
semilogx(p_ratio, p80.closed_loop_gain_db, 'o-', 'Color', blue, ...
    'MarkerFaceColor', blue, 'LineWidth', 1.1); grid on;
xlabel('Effective P / baseline P'); ylabel('Tracking gain (dB)'); yline(1, ':');
nexttile;
semilogx(p_ratio, p80.frequency_residual_gain_db, 'o-', 'Color', orange, ...
    'MarkerFaceColor', orange, 'LineWidth', 1.1); grid on;
xlabel('Effective P / baseline P'); ylabel('Residual gain (dB)'); yline(0, ':');
nexttile;
plot(i80.ki_track / 1e6, i80.closed_loop_gain_db, 's-', ...
    'Color', blue, 'MarkerFaceColor', blue, 'LineWidth', 1.1); grid on;
xlabel('Ki track (million)'); ylabel('Tracking gain (dB)'); yline(1, ':');
nexttile;
plot(i80.ki_track / 1e6, i80.frequency_residual_gain_db, 's-', ...
    'Color', orange, 'MarkerFaceColor', orange, 'LineWidth', 1.1); grid on;
xlabel('Ki track (million)'); ylabel('Residual gain (dB)'); yline(0, ':');
figures.parameters = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'final_parameter_causality_80hz'));
close(fig);

posterior = posterior_data.comparison.metrics;
fig = figure('Visible', 'off', 'Name', 'Final posterior comparison');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Frozen-candidate validation on measured pulse positions');
labels = strrep(posterior.candidate_id, '_', ' ');
nexttile;
bar(1:height(posterior), [posterior.recovered_interval_rms_error_cycles, ...
    posterior.fast_recovered_std_cycles], 'grouped');
xticks(1:height(posterior)); xticklabels(labels); xtickangle(20);
ylabel('Error (output cycles)'); grid on;
legend('Interval RMS', 'Fast-component std', 'Location', 'best');
nexttile;
bar(1:height(posterior), [posterior.slow_suppression_db, ...
    posterior.fast_suppression_db], 'grouped');
xticks(1:height(posterior)); xticklabels(labels); xtickangle(20);
ylabel('Suppression (dB)'); grid on;
legend('Slow component', 'Fast component', 'Location', 'best');
figures.posterior = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'final_frozen_candidate_posterior'));
close(fig);
end
