function figures = plot_dpll_investigation_layer1(case_set, output_dir)
%PLOT_DPLL_INVESTIGATION_LAYER1 Paper figures for linearity and self-motion.

figure_dir = fullfile(output_dir, 'figures');
if ~isfolder(figure_dir), mkdir(figure_dir); end
metrics = case_set.metrics;
response = metrics.phase_modulation_rad > 0;
frequencies = unique(metrics.modulation_frequency_hz(response));
colors = [0.00 0.45 0.70; 0.90 0.62 0.00; 0.00 0.62 0.45];

fig = figure('Visible', 'off', 'Name', 'Layer 1 amplitude linearity');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Layer 1: amplitude linearity of the high-frequency response');
labels = compose('%g Hz', frequencies);
for panel = 1:4
    nexttile; hold on;
    for k = 1:numel(frequencies)
        select = response & metrics.modulation_frequency_hz == frequencies(k);
        subset = sortrows(metrics(select, :), 'phase_modulation_rad');
        switch panel
            case 1, values = subset.closed_loop_gain_db;
            case 2, values = subset.closed_loop_phase_deg;
            case 3, values = subset.output_fit_r_squared;
            otherwise, values = subset.non_tone_to_tone_db;
        end
        plot(subset.phase_modulation_rad, values, 'o-', ...
            'Color', colors(k, :), 'LineWidth', 1.1, ...
            'MarkerFaceColor', colors(k, :), 'DisplayName', labels{k});
    end
    grid on;
    xlabel('Injected phase amplitude (rad)');
    if panel == 1, ylabel('Tracking gain (dB)'); legend('Location', 'best'); end
    if panel == 2, ylabel('Tracking phase (deg)'); end
    if panel == 3
        ylabel('Single-tone fit R^2'); ylim([0 1.05]); yline(0.9, ':');
    end
    if panel == 4, ylabel('Non-tone / tone RMS (dB)'); yline(0, ':'); end
end
figures.linearity = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'layer1_amplitude_linearity'));
close(fig);

pure_index = find(metrics.phase_modulation_rad == 0, 1, 'first');
pure = load(case_set.raw_files(pure_index), 'record');
fig = figure('Visible', 'off', 'Name', 'Layer 1 autonomous spectrum');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Layer 1: unmodulated-carrier autonomous output');
nexttile;
semilogy(pure.record.spectrum.output_frequency_hz, ...
    pure.record.spectrum.output_hz2_per_hz, 'Color', colors(1, :), ...
    'LineWidth', 1.0);
xlim([1 150]); grid on;
ylabel('Output-frequency PSD (Hz^2/Hz)');
xline(pure.record.spectrum.dominant_output_peak_hz, ':', ...
    sprintf('%.1f Hz', pure.record.spectrum.dominant_output_peak_hz));
nexttile;
semilogy(pure.record.spectrum.phase_frequency_hz, ...
    pure.record.spectrum.phase_rad2_per_hz, 'Color', colors(3, :), ...
    'LineWidth', 1.0);
xlim([1 150]); grid on;
xlabel('Frequency (Hz)'); ylabel('Phase-error PSD (rad^2/Hz)');
xline(pure.record.spectrum.dominant_phase_peak_hz, ':', ...
    sprintf('%.1f Hz', pure.record.spectrum.dominant_phase_peak_hz));
figures.autonomous = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'layer1_autonomous_spectrum'));
close(fig);

fig = plot_80hz_time_traces(case_set);
figures.time_domain = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'layer1_80hz_amplitude_time_domain'));
close(fig);
end

function fig = plot_80hz_time_traces(case_set)
metrics = case_set.metrics;
indices = find(metrics.modulation_frequency_hz == 80 & ...
    metrics.phase_modulation_rad > 0);
[~, order] = sort(metrics.phase_modulation_rad(indices));
indices = indices(order);
blue = [0.00 0.45 0.70];
orange = [0.90 0.62 0.00];
fig = figure('Visible', 'off', 'Name', 'Layer 1 80 Hz time traces');
layout = tiledlayout(fig, numel(indices), 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Layer 1: 80 Hz normalized tracking versus injected amplitude');
for k = 1:numel(indices)
    frozen = load(case_set.raw_files(indices(k)), 'record');
    record = frozen.record;
    measurement = record.measurement;
    stride = max(1, ceil(numel(measurement.word_time_s) / 5000));
    use = 1:stride:numel(measurement.word_time_s);
    center_hz = record.truth.carrier_frequency_hz;
    deviation_hz = record.truth.frequency_deviation_hz;
    nexttile;
    plot(measurement.word_time_s(use) - measurement.start_s, ...
        (measurement.input_frequency_hz(use) - center_hz) / deviation_hz, ...
        'Color', blue, 'LineWidth', 0.9, 'DisplayName', 'Input truth'); hold on;
    plot(measurement.word_time_s(use) - measurement.start_s, ...
        (measurement.output_frequency_hz(use) - center_hz) / deviation_hz, ...
        'Color', orange, 'LineWidth', 0.9, 'DisplayName', 'DPLL output');
    ylabel(sprintf('beta %.3f\nnormalized', ...
        record.truth.phase_modulation_rad)); grid on;
    if k == 1, legend('Location', 'best'); end
end
xlabel(layout, 'Measurement time (s)');
end
