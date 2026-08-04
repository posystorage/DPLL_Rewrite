function comparison = run_real_candidate_comparison(candidates, output_dir)
%RUN_REAL_CANDIDATE_COMPARISON Freeze real-reference replays without peaks.

arguments
    candidates (:,1) struct
    output_dir (1,1) string
end
raw_dir = fullfile(output_dir, 'raw');
figure_dir = fullfile(output_dir, 'figures');
if ~isfolder(raw_dir), mkdir(raw_dir); end
if ~isfolder(figure_dir), mkdir(figure_dir); end

source_cfg = candidates(1).cfg;
input_data = load_input_mat(string(source_cfg.files.pll_input_mat), ...
    source_cfg.io.input_sample_range);
source_info = dir(source_cfg.files.pll_input_mat);
provenance.source_file = source_cfg.files.pll_input_mat;
provenance.source_sha256 = dpll.file_sha256(source_cfg.files.pll_input_mat);
provenance.source_bytes = source_info.bytes;
provenance.input_sample_range = source_cfg.io.input_sample_range;
provenance.posterior_peak_data_loaded = false;
rows = repmat(struct(), 0, 1);
raw_files = strings(numel(candidates), 1);
phase_psd = cell(numel(candidates), 1);
frequency_psd = cell(numel(candidates), 1);

for k = 1:numel(candidates)
    raw_file = fullfile(raw_dir, sprintf('%s_replay.mat', candidates(k).id));
    raw_files(k) = string(raw_file);
    if isfile(raw_file)
        frozen = load(raw_file, 'row', 'phase_spectrum', ...
            'frequency_spectrum');
        row = frozen.row;
        phase_spectrum = frozen.phase_spectrum;
        frequency_spectrum = frozen.frequency_spectrum;
        fprintf('Real candidate %d/%d resumed: %s\n', ...
            k, numel(candidates), candidates(k).id);
    else
        fprintf('Real candidate %d/%d: %s\n', ...
            k, numel(candidates), candidates(k).id);
        result = simulate_dpll(input_data, candidates(k).cfg);
        summary = analyze_dpll_result(result, false);
        [row, phase_spectrum, frequency_spectrum] = ...
            analyze_real_candidate(candidates(k).id, result, summary);
        if result.metadata.posterior_interval_data_used
            error('dpll:PosteriorContamination', ...
                'Real candidate replay used posterior peak data.');
        end
        save(raw_file, 'result', 'summary', 'row', 'phase_spectrum', ...
            'frequency_spectrum', 'provenance', '-v7.3');
    end
    if isempty(rows), rows = row; else, rows(end + 1, 1) = row; end %#ok<AGROW>
    phase_psd{k} = phase_spectrum;
    frequency_psd{k} = frequency_spectrum;
    partial = struct2table(rows);
    writetable(partial, fullfile(output_dir, 'real_candidate_metrics.csv'));
end

metrics = struct2table(rows);
comparison.schema_version = 1;
comparison.candidate_ids = string({candidates.id}).';
comparison.candidates = candidates;
comparison.metrics = metrics;
comparison.raw_files = raw_files;
comparison.phase_spectra = phase_psd;
comparison.frequency_spectra = frequency_psd;
comparison.provenance = provenance;
comparison.posterior_peak_data_loaded = false;
comparison.candidates_frozen_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
writetable(metrics, fullfile(output_dir, 'real_candidate_metrics.csv'));
save(fullfile(output_dir, 'real_candidate_comparison.mat'), ...
    'comparison', '-v7.3');

fig = plot_real_candidate_comparison(comparison);
comparison.figure_files = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'real_reference_candidate_comparison'), [7.2 8.0]);
close(fig);
save(fullfile(output_dir, 'real_candidate_comparison.mat'), ...
    'comparison', '-v7.3');
end

function [row, phase_spectrum, frequency_spectrum] = ...
    analyze_real_candidate(id, result, summary)
valid = result.trace.analysis_valid;
time_s = result.trace.time_s(valid);
phase_rad = double(result.trace.phase_error(valid)) * pi / ...
    2^(result.config.phase_width - 1);
tracking_hz = result.trace.tracking_frequency_hz(valid);
sample_rate_hz = 1 / median(diff(time_s));
[phase_frequency_hz, phase_psd] = dpll.welch_psd(phase_rad, sample_rate_hz);
[tracking_frequency_hz, tracking_psd] = dpll.welch_psd( ...
    tracking_hz, sample_rate_hz);
keep_phase = phase_frequency_hz <= 1000;
keep_tracking = tracking_frequency_hz <= 1000;
phase_spectrum.frequency_hz = phase_frequency_hz(keep_phase);
phase_spectrum.rad2_per_hz = phase_psd(keep_phase);
frequency_spectrum.frequency_hz = tracking_frequency_hz(keep_tracking);
frequency_spectrum.hz2_per_hz = tracking_psd(keep_tracking);

row.candidate_id = string(id);
row.p_product_shift = result.config.shifts.p_product;
row.kp_track = double(result.config.gains.kp_track);
row.ki_track = double(result.config.gains.ki_track);
row.phase_rms_rad = summary.phase_rms_rad;
row.phase_peak_rad = summary.phase_peak_rad;
row.freq_error_rms_hz = summary.freq_error_rms_hz;
row.tracking_frequency_mean_hz = mean(tracking_hz);
row.tracking_frequency_std_hz = std(tracking_hz);
row.phase_band_0p8_5_rms_rad = band_rms(phase_frequency_hz, phase_psd, 0.8, 5);
row.phase_band_5_20_rms_rad = band_rms(phase_frequency_hz, phase_psd, 5, 20);
row.phase_band_20_40_rms_rad = band_rms(phase_frequency_hz, phase_psd, 20, 40);
row.phase_band_40_100_rms_rad = band_rms(phase_frequency_hz, phase_psd, 40, 100);
row.tracking_band_40_100_rms_hz = band_rms( ...
    tracking_frequency_hz, tracking_psd, 40, 100);
row.cic_saturation_rate = summary.analysis_cic_saturation_rate;
row.cordic_out_of_range_rate = summary.analysis_cordic_out_of_range_rate;
row.controller_saturation_count = summary.controller_saturation_count;
row.track_fraction = summary.track_fraction;
row.posterior_data_used = summary.posterior_interval_data_used;
end

function value = band_rms(frequency_hz, psd_value, low_hz, high_hz)
select = frequency_hz >= low_hz & frequency_hz < high_hz;
if nnz(select) < 2
    value = NaN;
else
    value = sqrt(trapz(frequency_hz(select), psd_value(select)));
end
end

function fig = plot_real_candidate_comparison(comparison)
metrics = comparison.metrics;
colors = lines(height(metrics));
fig = figure('Visible', 'off', 'Name', 'Real reference candidates');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Frozen candidates on the same real 3.125 MHz reference waveform');
labels = strrep(metrics.candidate_id, '_', ' ');
nexttile;
bar(1:height(metrics), metrics.phase_rms_rad);
xticks(1:height(metrics)); xticklabels(labels); xtickangle(20);
ylabel('Phase residual RMS (rad)'); grid on;
nexttile;
bar(1:height(metrics), metrics.tracking_frequency_std_hz);
xticks(1:height(metrics)); xticklabels(labels); xtickangle(20);
ylabel('Tracking-frequency std (Hz)'); grid on;
nexttile; hold on;
for k = 1:height(metrics)
    spectrum = comparison.phase_spectra{k};
    select = spectrum.frequency_hz >= 0.8 & spectrum.frequency_hz <= 200;
    semilogy(spectrum.frequency_hz(select), spectrum.rad2_per_hz(select), ...
        'Color', colors(k, :), 'LineWidth', 1.0, ...
        'DisplayName', labels(k));
end
xlabel('Frequency (Hz)'); ylabel('Phase PSD (rad^2/Hz)'); grid on;
legend('Location', 'best');
nexttile; hold on;
for k = 1:height(metrics)
    spectrum = comparison.frequency_spectra{k};
    select = spectrum.frequency_hz >= 0.8 & spectrum.frequency_hz <= 200;
    semilogy(spectrum.frequency_hz(select), spectrum.hz2_per_hz(select), ...
        'Color', colors(k, :), 'LineWidth', 1.0, ...
        'DisplayName', labels(k));
end
xlabel('Frequency (Hz)'); ylabel('Tracking-frequency PSD (Hz^2/Hz)'); grid on;
end
