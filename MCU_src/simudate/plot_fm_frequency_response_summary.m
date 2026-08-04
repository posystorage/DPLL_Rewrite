function fig = plot_fm_frequency_response_summary(response, bandwidth_hz)
%PLOT_FM_FREQUENCY_RESPONSE_SUMMARY Plot response and fit credibility.

blue = [0.00 0.45 0.70];
orange = [0.90 0.62 0.00];
green = [0.00 0.62 0.45];
red = [0.80 0.20 0.20];
fig = figure('Visible', 'off', 'Name', 'DPLL FM frequency response');
layout = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Sinusoidal FM response of the FPGA-equivalent DPLL');
frequency_hz = response.modulation_frequency_hz;
low_fit = response.output_fit_r_squared < 0.90;

nexttile;
semilogx(frequency_hz, response.closed_loop_gain_db, ...
    'o-', 'Color', blue, 'LineWidth', 1.2, 'MarkerFaceColor', blue, ...
    'DisplayName', 'Tracking output / input'); hold on;
semilogx(frequency_hz, response.frequency_residual_gain_db, ...
    's--', 'Color', orange, 'LineWidth', 1.0, ...
    'DisplayName', 'Frequency residual / input');
semilogx(frequency_hz(low_fit), response.closed_loop_gain_db(low_fit), ...
    'x', 'Color', red, 'LineWidth', 1.5, 'MarkerSize', 9, ...
    'DisplayName', 'Output fit R^2 < 0.90');
yline(-3, ':', 'HandleVisibility', 'off');
if isfinite(bandwidth_hz)
    xline(bandwidth_hz, ':', sprintf('%.1f Hz', bandwidth_hz), ...
        'HandleVisibility', 'off');
end
ylabel('Magnitude (dB)');
legend('Location', 'southwest');
grid on;

nexttile;
semilogx(frequency_hz, response.closed_loop_phase_deg, ...
    'o-', 'Color', blue, 'LineWidth', 1.2, 'MarkerFaceColor', blue); hold on;
semilogx(frequency_hz(low_fit), response.closed_loop_phase_deg(low_fit), ...
    'x', 'Color', red, 'LineWidth', 1.5, 'MarkerSize', 9);
yline(0, ':');
ylabel('Tracking phase (deg)');
grid on;

nexttile;
semilogx(frequency_hz, response.phase_residual_gain_db, ...
    'd-', 'Color', green, 'LineWidth', 1.2, 'MarkerFaceColor', green);
yline(0, ':');
ylabel('Phase residual / input (dB)');
grid on;

nexttile;
semilogx(frequency_hz, response.output_fit_r_squared, ...
    'o-', 'Color', blue, 'LineWidth', 1.1, ...
    'MarkerFaceColor', blue, 'DisplayName', 'Tracking output'); hold on;
semilogx(frequency_hz, response.phase_error_fit_r_squared, ...
    'd--', 'Color', green, 'LineWidth', 1.0, ...
    'DisplayName', 'Phase residual');
yline(0.90, ':', 'R^2 = 0.90', 'HandleVisibility', 'off');
ylim([0 1.05]);
xlabel('Modulation frequency (Hz)');
ylabel('Single-tone fit R^2');
legend('Location', 'southwest');
grid on;
end
