function experiment = run_fm_frequency_response_experiment( ...
    cfg, modulation_frequencies_hz, output_dir, options)
%RUN_FM_FREQUENCY_RESPONSE_EXPERIMENT Measure the closed-loop response.
%
% Every point is a separate, fixed modulation-frequency experiment with a
% known phase/frequency truth. No measured pulse positions are loaded.

arguments
    cfg (1,1) struct
    modulation_frequencies_hz (1,:) double
    output_dir (1,1) string
    options (1,1) struct = struct()
end
options = apply_option_defaults(options);
if ~isfolder(output_dir), mkdir(output_dir); end
raw_dir = fullfile(output_dir, 'raw');
figure_dir = fullfile(output_dir, 'figures');
if ~isfolder(raw_dir), mkdir(raw_dir); end
if ~isfolder(figure_dir), mkdir(figure_dir); end

frequencies = sort(unique(double(modulation_frequencies_hz(:))));
if any(~isfinite(frequencies) | frequencies <= 0)
    error('dpll:InvalidModulationFrequencies', ...
        'All modulation frequencies must be positive and finite.');
end

rows = repmat(empty_response_row(), numel(frequencies), 1);
point_files = strings(numel(frequencies), 1);
example_target_hz = [2 20 80];
example_traces = cell(numel(example_target_hz), 1);
example_distance = inf(size(example_target_hz));

for k = 1:numel(frequencies)
    fm = frequencies(k);
    settle_s = options.settle_cycles / fm;
    measurement_s = max(options.measurement_cycles / fm, ...
        options.minimum_measurement_s);
    duration_s = options.carrier_lead_s + settle_s + measurement_s;
    spec.sample_rate_hz = cfg.input_sample_rate_hz;
    spec.carrier_frequency_hz = cfg.center_frequency_hz;
    spec.modulation_frequency_hz = fm;
    spec.phase_modulation_rad = options.phase_modulation_rad;
    spec.carrier_lead_s = options.carrier_lead_s;
    spec.duration_s = duration_s;
    spec.amplitude_codes = options.amplitude_codes;

    fprintf('\nFM response point %d/%d: fm=%.6g Hz, duration=%.3f s\n', ...
        k, numel(frequencies), fm, duration_s);
    [input_data, truth] = generate_sinusoidal_fm_input(spec);
    run_cfg = cfg;
    run_cfg.files.replay_output_mat = '';
    run_cfg.options.warn_on_saturation = false;
    result = simulate_dpll(input_data, run_cfg);

    measurement_start_s = options.carrier_lead_s + settle_s;
    measurement_end_s = duration_s;
    measurement = collect_measurement(result, truth, ...
        measurement_start_s, measurement_end_s);
    fits = fit_response(measurement, truth);
    rows(k) = collect_response_row(result, truth, measurement, fits);

    token = frequency_token(fm);
    point_file = fullfile(raw_dir, sprintf('fm_%s_raw.mat', token));
    point_files(k) = string(point_file);
    if options.save_full_raw
        save(point_file, 'input_data', 'truth', 'spec', 'result', ...
            'measurement', 'fits', '-v7.3');
    else
        save(point_file, 'truth', 'spec', 'measurement', 'fits', '-v7.3');
    end
    fprintf('  frozen raw point: %s\n', point_file);

    for target_index = 1:numel(example_target_hz)
        distance = abs(log(fm / example_target_hz(target_index)));
        if distance < example_distance(target_index)
            example_distance(target_index) = distance;
            example_traces{target_index} = reduce_example_trace( ...
                measurement, truth, fits);
        end
    end
end

response = struct2table(rows);
response.closed_loop_phase_deg = rad2deg(unwrap( ...
    deg2rad(response.closed_loop_phase_deg)));
response.tracking_lag_deg = -response.closed_loop_phase_deg;
bandwidth_hz = estimate_bandwidth(response.modulation_frequency_hz, ...
    response.closed_loop_gain_db, -3);

experiment.kind = 'fixed-frequency sinusoidal FM closed-loop response';
experiment.response = response;
experiment.modulation_frequencies_hz = frequencies;
experiment.cic_output_shift = cfg.cic.output_shift;
experiment.options = options;
experiment.point_files = point_files;
experiment.estimated_minus3db_bandwidth_hz = bandwidth_hz;
experiment.posterior_peak_data_loaded = false;
experiment.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
experiment.raw_directory = raw_dir;
experiment.figure_directory = figure_dir;

writetable(response, fullfile(output_dir, 'fm_frequency_response.csv'));
save(fullfile(output_dir, 'fm_frequency_response_experiment.mat'), ...
    'experiment', 'example_traces', '-v7.3');

fig1 = plot_fm_frequency_response_summary(response, bandwidth_hz);
experiment.figure_files.response = dpll.export_paper_figure(fig1, ...
    fullfile(figure_dir, 'fm_closed_loop_frequency_response'), [7.2 8.0]);
close(fig1);
fig2 = plot_time_examples(example_traces);
experiment.figure_files.examples = dpll.export_paper_figure(fig2, ...
    fullfile(figure_dir, 'fm_tracking_time_domain_examples'));
close(fig2);
save(fullfile(output_dir, 'fm_frequency_response_experiment.mat'), ...
    'experiment', 'example_traces', '-v7.3');

fprintf('FM response experiment complete. Estimated -3 dB bandwidth: %.6g Hz.\n', ...
    bandwidth_hz);
end

function measurement = collect_measurement(result, truth, start_s, end_s)
word_time_s = double(result.word_history.fabric_tick(:)) / ...
    result.config.fabric_clock_hz;
word_frequency_hz = double(result.word_history.tracking_word(:)) * ...
    result.config.fabric_clock_hz / 2^result.config.word_width;
word_keep = word_time_s >= start_s & word_time_s <= end_s;
word_time_s = word_time_s(word_keep);
word_frequency_hz = word_frequency_hz(word_keep);

tau = word_time_s - truth.carrier_lead_s;
input_frequency_hz = truth.carrier_frequency_hz + ...
    truth.frequency_deviation_hz * cos( ...
    2 * pi * truth.modulation_frequency_hz * tau);

trace_keep = result.trace.time_s >= start_s & ...
    result.trace.time_s <= end_s & result.trace.analysis_valid;
trace_time_s = result.trace.time_s(trace_keep);
phase_error_rad = double(result.trace.phase_error(trace_keep)) * pi / ...
    2^(result.config.phase_width - 1);
phase_tau = trace_time_s - truth.carrier_lead_s;
input_phase_modulation_rad = truth.phase_modulation_rad * sin( ...
    2 * pi * truth.modulation_frequency_hz * phase_tau);

measurement.start_s = start_s;
measurement.end_s = end_s;
measurement.word_time_s = word_time_s;
measurement.input_frequency_hz = input_frequency_hz;
measurement.output_frequency_hz = word_frequency_hz;
measurement.frequency_error_hz = input_frequency_hz - word_frequency_hz;
measurement.trace_time_s = trace_time_s;
measurement.input_phase_modulation_rad = input_phase_modulation_rad;
measurement.phase_error_rad = phase_error_rad;
measurement.cic_saturated = result.trace.cic_saturated(trace_keep);
measurement.cordic_out_of_range = ...
    result.trace.cordic_out_of_range(trace_keep);
measurement.controller_saturated = ...
    result.trace.controller_saturated_high(trace_keep) | ...
    result.trace.controller_saturated_low(trace_keep);
end

function fits = fit_response(measurement, truth)
fm = truth.modulation_frequency_hz;
fits.input_frequency = dpll.fit_tone(measurement.word_time_s, ...
    measurement.input_frequency_hz, fm);
fits.output_frequency = dpll.fit_tone(measurement.word_time_s, ...
    measurement.output_frequency_hz, fm);
fits.frequency_error = dpll.fit_tone(measurement.word_time_s, ...
    measurement.frequency_error_hz, fm);
fits.input_phase = dpll.fit_tone(measurement.trace_time_s, ...
    measurement.input_phase_modulation_rad, fm);
fits.phase_error = dpll.fit_tone(measurement.trace_time_s, ...
    measurement.phase_error_rad, fm);
fits.closed_loop_frequency = fits.output_frequency.phasor / ...
    fits.input_frequency.phasor;
fits.frequency_residual = fits.frequency_error.phasor / ...
    fits.input_frequency.phasor;
fits.phase_residual = fits.phase_error.phasor / fits.input_phase.phasor;
end

function row = empty_response_row()
row.modulation_frequency_hz = NaN;
row.phase_modulation_rad = NaN;
row.frequency_deviation_hz = NaN;
row.measurement_duration_s = NaN;
row.closed_loop_gain = NaN;
row.closed_loop_gain_db = NaN;
row.closed_loop_phase_deg = NaN;
row.tracking_lag_deg = NaN;
row.frequency_residual_gain = NaN;
row.frequency_residual_gain_db = NaN;
row.phase_residual_gain = NaN;
row.phase_residual_gain_db = NaN;
row.output_fit_r_squared = NaN;
row.phase_error_fit_r_squared = NaN;
row.output_tone_amplitude_hz = NaN;
row.phase_error_tone_amplitude_rad = NaN;
row.phase_error_rms_rad = NaN;
row.cic_saturation_rate = NaN;
row.cordic_out_of_range_rate = NaN;
row.controller_saturation_rate = NaN;
row.initial_frequency_hz = NaN;
end

function row = collect_response_row(result, truth, measurement, fits)
row = empty_response_row();
row.modulation_frequency_hz = truth.modulation_frequency_hz;
row.phase_modulation_rad = truth.phase_modulation_rad;
row.frequency_deviation_hz = truth.frequency_deviation_hz;
row.measurement_duration_s = measurement.end_s - measurement.start_s;
row.closed_loop_gain = abs(fits.closed_loop_frequency);
row.closed_loop_gain_db = 20 * log10(max(row.closed_loop_gain, realmin));
row.closed_loop_phase_deg = rad2deg(angle(fits.closed_loop_frequency));
row.tracking_lag_deg = -row.closed_loop_phase_deg;
row.frequency_residual_gain = abs(fits.frequency_residual);
row.frequency_residual_gain_db = 20 * log10(max( ...
    row.frequency_residual_gain, realmin));
row.phase_residual_gain = abs(fits.phase_residual);
row.phase_residual_gain_db = 20 * log10(max(row.phase_residual_gain, realmin));
row.output_fit_r_squared = fits.output_frequency.r_squared;
row.phase_error_fit_r_squared = fits.phase_error.r_squared;
row.output_tone_amplitude_hz = fits.output_frequency.amplitude;
row.phase_error_tone_amplitude_rad = fits.phase_error.amplitude;
row.phase_error_rms_rad = sqrt(mean(measurement.phase_error_rad.^2));
row.cic_saturation_rate = mean(measurement.cic_saturated);
row.cordic_out_of_range_rate = mean(measurement.cordic_out_of_range);
row.controller_saturation_rate = mean(measurement.controller_saturated);
row.initial_frequency_hz = result.metadata.initial_frequency_hz;
end

function trace = reduce_example_trace(measurement, truth, fits)
max_points = 5000;
stride = max(1, ceil(numel(measurement.word_time_s) / max_points));
indices = 1:stride:numel(measurement.word_time_s);
trace.modulation_frequency_hz = truth.modulation_frequency_hz;
trace.time_s = measurement.word_time_s(indices) - measurement.start_s;
trace.input_normalized = (measurement.input_frequency_hz(indices) - ...
    truth.carrier_frequency_hz) / truth.frequency_deviation_hz;
trace.output_normalized = (measurement.output_frequency_hz(indices) - ...
    fits.output_frequency.offset) / truth.frequency_deviation_hz;
trace.closed_loop_gain_db = 20 * log10(abs(fits.closed_loop_frequency));
trace.closed_loop_phase_deg = rad2deg(angle(fits.closed_loop_frequency));
end

function bandwidth_hz = estimate_bandwidth(frequency_hz, gain_db, level_db)
frequency_hz = double(frequency_hz(:));
gain_db = double(gain_db(:));
crossing = find(gain_db(1:end-1) > level_db & ...
    gain_db(2:end) <= level_db, 1, 'first');
if isempty(crossing)
    bandwidth_hz = NaN;
    return;
end
x1 = log10(frequency_hz(crossing));
x2 = log10(frequency_hz(crossing + 1));
y1 = gain_db(crossing);
y2 = gain_db(crossing + 1);
fraction = (level_db - y1) / (y2 - y1);
bandwidth_hz = 10^(x1 + fraction * (x2 - x1));
end

function fig = plot_time_examples(example_traces)
blue = [0.00 0.45 0.70];
orange = [0.90 0.62 0.00];
fig = figure('Visible', 'off', 'Name', 'FM tracking examples');
layout = tiledlayout(fig, numel(example_traces), 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'Normalized frequency tracking at representative modulation rates');
for k = 1:numel(example_traces)
    trace = example_traces{k};
    nexttile;
    plot(trace.time_s, trace.input_normalized, 'Color', blue, ...
        'LineWidth', 1.0, 'DisplayName', 'Input truth'); hold on;
    plot(trace.time_s, trace.output_normalized, 'Color', orange, ...
        'LineWidth', 1.0, 'DisplayName', 'DPLL output');
    ylabel(sprintf('%.0f Hz\nnormalized', trace.modulation_frequency_hz));
    grid on;
    if k == 1, legend('Location', 'best'); end
end
xlabel(layout, 'Measurement time (s)');
end

function token = frequency_token(frequency_hz)
token = strrep(sprintf('%08.3fHz', frequency_hz), '.', 'p');
end

function options = apply_option_defaults(options)
defaults.phase_modulation_rad = 0.15;
defaults.amplitude_codes = 6000;
defaults.carrier_lead_s = 0.10;
defaults.settle_cycles = 1;
defaults.measurement_cycles = 2;
defaults.minimum_measurement_s = 0.25;
defaults.save_full_raw = true;
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options, names{k})
        options.(names{k}) = defaults.(names{k});
    end
end
end
