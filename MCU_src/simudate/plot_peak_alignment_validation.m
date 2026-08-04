function figures = plot_peak_alignment_validation(validation, visibility)
%PLOT_PEAK_ALIGNMENT_VALIDATION Plot posterior errors with causal separation.

if nargin < 2, visibility = 'on'; end
interval_time = validation.peak_time_s(2:end);
has_reference = isfield(validation, 'reference_event_error') && ...
    isfield(validation, 'loop_only_error');

figures.posterior = figure('Visible', visibility, ...
    'Name', 'DPLL 62.5 MHz posterior validation', 'Color', 'w');
layout = tiledlayout(figures.posterior, 4, 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf([ ...
    'Posterior validation; fixed-clock scale from supplied mean prior; ' ...
    'events %.3f--%.3f s'], validation.peak_time_s(1), ...
    validation.peak_time_s(end)));

nexttile;
plot(interval_time, validation.fixed_interval_centered, '.-', ...
    'Color', [0.00 0.45 0.74]);
yline(0, '--k');
ylabel('62.5M interval - prior'); grid on;

nexttile;
plot(interval_time, validation.uncompensated_interval_error_output_cycles, ...
    '.-', 'DisplayName', 'Fixed-clock equivalent'); hold on;
plot(interval_time, validation.recovered_interval_error, '.-', ...
    'DisplayName', 'PLL recovered total');
yline(0, '--k', 'HandleVisibility', 'off');
ylabel('Interval error (cycles)'); grid on;
legend('Location', 'best');

nexttile;
if has_reference
    plot(interval_time, validation.recovered_interval_error, '.-', ...
        'DisplayName', 'PLL recovered total'); hold on;
    plot(interval_time, validation.reference_event_error, '-', ...
        'LineWidth', 1.0, 'DisplayName', 'Independent reference-event');
    ylabel('Total and event (cycles)');
else
    plot(interval_time, validation.compensated_component_output_cycles, '.-');
    ylabel('Removed error (cycles)');
end
yline(0, '--k', 'HandleVisibility', 'off'); grid on;
if has_reference, legend('Location', 'best'); end

nexttile;
if has_reference
    plot(interval_time, validation.loop_only_error, '.-', ...
        'Color', [0.47 0.67 0.19]);
    ylabel('Loop-only (cycles)');
else
    plot(validation.peak_time_s, ...
        validation.unwrapped_sampling_phase_error_cycles, '.-');
    ylabel('Cumulative error (cycles)');
end
yline(0, '--k'); grid on;
xlabel('Time (s)');

figures.slow_fast = figure('Visible', visibility, ...
    'Name', 'DPLL slow and fast tracking decomposition', 'Color', 'w');
layout = tiledlayout(figures.slow_fast, 3, 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('Validation-only moving mean: %d pulses', ...
    validation.slow.window_pulses));
nexttile;
plot(interval_time, validation.slow.uncompensated_error, ...
    'DisplayName', 'Uncompensated'); hold on;
plot(interval_time, validation.slow.recovered_error, ...
    'DisplayName', 'Recovered');
ylabel('Slow error (cycles)'); grid on; legend('Location', 'best');
nexttile;
plot(interval_time, validation.fast.uncompensated_error, ...
    'DisplayName', 'Uncompensated'); hold on;
plot(interval_time, validation.fast.recovered_error, ...
    'DisplayName', 'Recovered');
ylabel('Fast error (cycles)'); grid on; legend('Location', 'best');
nexttile;
if has_reference
    plot(interval_time, validation.loop_only_error, '.-');
    ylabel('Loop-only (cycles)');
else
    plot(validation.peak_time_s, validation.sampling_phase_error_cycles, '.-');
    ylabel('Wrapped phase (cycles)');
end
yline(0, '--k'); xlabel('Time (s)'); grid on;
end
