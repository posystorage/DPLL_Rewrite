function calibration = run_reference_estimator_calibration(cfg, output_dir, options)
%RUN_REFERENCE_ESTIMATOR_CALIBRATION Calibrate phase estimators without peaks.

arguments
    cfg (1,1) struct
    output_dir (1,1) string
    options.phase_tone_hz (:,1) double = [1 2 5 10 20 40 60 80 90].'
    options.phase_tone_rad (1,1) double = 0.01
    options.carrier_frequency_hz (1,1) double = 20000
    options.amplitude_codes (1,1) double = 6000
    options.pm_duration_s (1,1) double = 1.2
    options.measurement_start_s (1,1) double = 0.1
    options.measurement_duration_s (1,1) double = 1.0
    options.query_rate_hz (1,1) double = 2000
    options.local_window_cycles (1,1) double = 8
    options.analytic_half_bandwidth_hz (1,1) double = 500
end

if ~isfolder(output_dir), mkdir(output_dir); end
raw_dir = fullfile(output_dir, 'raw');
if ~isfolder(raw_dir), mkdir(raw_dir); end

pm_spec.sample_rate_hz = cfg.input_sample_rate_hz;
pm_spec.carrier_frequency_hz = options.carrier_frequency_hz;
pm_spec.duration_s = options.pm_duration_s;
pm_spec.amplitude_codes = options.amplitude_codes;
pm_spec.phase_tone_hz = options.phase_tone_hz;
pm_spec.phase_tone_rad = repmat(options.phase_tone_rad, ...
    numel(options.phase_tone_hz), 1);
pm_spec.am_tone_hz = [];
pm_spec.am_depth = [];
pm_spec.second_harmonic_ratio = 0;
pm_spec.third_harmonic_ratio = 0;
pm_spec.noise_rms_codes = 0;
pm_spec.random_seed = 1;
[pm_input, pm_truth] = generate_multitone_reference_input(pm_spec);

query_time_s = (options.measurement_start_s:1 / options.query_rate_hz: ...
    options.measurement_start_s + options.measurement_duration_s).';
query_time_s = query_time_s(query_time_s < options.pm_duration_s);
query_index = 1 + query_time_s * cfg.input_sample_rate_hz;
zero = dpll.estimate_zero_crossing_phase(pm_input.pll_input_codes, ...
    query_index, cfg.input_sample_rate_hz);
local = dpll.estimate_local_sinusoid_phase(pm_input.pll_input_codes, ...
    query_index, cfg.input_sample_rate_hz, zero.carrier_frequency_hz, ...
    options.local_window_cycles);
analytic = dpll.estimate_fft_analytic_phase(pm_input.pll_input_codes, ...
    query_index, cfg.input_sample_rate_hz, zero.carrier_frequency_hz, ...
    options.analytic_half_bandwidth_hz);
detector = dpll.simulate_detector_stages(pm_input.pll_input_codes, ...
    options.carrier_frequency_hz, cfg);

truth_query_cycles = interp1(pm_truth.time_s, ...
    pm_truth.total_phase_cycles, query_time_s, 'linear');
truth_query_mod_cycles = interp1(pm_truth.time_s, ...
    pm_truth.phase_modulation_rad / (2 * pi), query_time_s, 'linear');
detector_truth_mod_cycles = interp1(pm_truth.time_s, ...
    pm_truth.phase_modulation_rad / (2 * pi), detector.time_s, 'linear');

methods = build_method_set(query_time_s, zero, local, analytic, ...
    detector, truth_query_cycles, truth_query_mod_cycles, ...
    detector_truth_mod_cycles, options.measurement_start_s, ...
    options.measurement_start_s + options.measurement_duration_s);
response = build_response_table(methods, options.phase_tone_hz);
accuracy = build_accuracy_table(methods, cfg.pulse.output_multiplier);

am_spec = pm_spec;
am_spec.duration_s = 0.6;
am_spec.phase_tone_hz = [];
am_spec.phase_tone_rad = [];
am_spec.am_tone_hz = 50;
am_spec.am_depth = 0.35;
am_spec.second_harmonic_ratio = 0.08;
am_spec.third_harmonic_ratio = 0.04;
[am_input, am_truth] = generate_multitone_reference_input(am_spec);
am_query_time_s = (0.1:1 / options.query_rate_hz:0.55).';
am_query_index = 1 + am_query_time_s * cfg.input_sample_rate_hz;
am_zero = dpll.estimate_zero_crossing_phase(am_input.pll_input_codes, ...
    am_query_index, cfg.input_sample_rate_hz);
am_local = dpll.estimate_local_sinusoid_phase(am_input.pll_input_codes, ...
    am_query_index, cfg.input_sample_rate_hz, ...
    am_zero.carrier_frequency_hz, options.local_window_cycles);
am_analytic = dpll.estimate_fft_analytic_phase(am_input.pll_input_codes, ...
    am_query_index, cfg.input_sample_rate_hz, ...
    am_zero.carrier_frequency_hz, options.analytic_half_bandwidth_hz);
am_detector = dpll.simulate_detector_stages(am_input.pll_input_codes, ...
    options.carrier_frequency_hz, cfg);
am_to_pm = build_am_to_pm_table(am_query_time_s, am_zero, am_local, ...
    am_analytic, am_detector, 50, cfg.pulse.output_multiplier);

calibration.schema_version = 1;
calibration.posterior_peak_data_loaded = false;
calibration.options = options;
calibration.pm_spec = pm_spec;
calibration.am_spec = am_spec;
calibration.response = response;
calibration.accuracy = accuracy;
calibration.am_to_pm = am_to_pm;
calibration.methods = methods;
calibration.detector = detector;
calibration.pm_query_time_s = query_time_s;
calibration.pm_truth_query_cycles = truth_query_cycles;
calibration.pm_truth_query_mod_cycles = truth_query_mod_cycles;
calibration.am_query_time_s = am_query_time_s;
calibration.am_truth = rmfield(am_truth, {'time_s', 'carrier_phase_rad', ...
    'phase_modulation_rad', 'total_phase_rad', 'total_phase_cycles', ...
    'amplitude_scale'});

writetable(response, fullfile(output_dir, ...
    'phase_estimator_and_detector_response.csv'));
writetable(accuracy, fullfile(output_dir, ...
    'phase_estimator_accuracy.csv'));
writetable(am_to_pm, fullfile(output_dir, 'am_to_pm_response.csv'));
save(fullfile(raw_dir, 'pm_calibration_input.mat'), ...
    'pm_input', 'pm_spec', '-v7.3');
save(fullfile(raw_dir, 'am_calibration_input.mat'), ...
    'am_input', 'am_spec', '-v7.3');
save(fullfile(output_dir, 'reference_estimator_calibration.mat'), ...
    'calibration', '-v7.3');
end

function methods = build_method_set(query_time_s, zero, local, analytic, ...
    detector, truth_query_cycles, truth_query_mod_cycles, detector_truth_mod, ...
    measurement_start_s, measurement_end_s)
methods = make_method('zero_crossing', query_time_s, ...
    zero.phase_cycles, truth_query_cycles);
methods(2) = make_method('local_sinusoid', query_time_s, ...
    local.phase_cycles, truth_query_cycles);
methods(3) = make_method('fft_analytic', query_time_s, ...
    analytic.phase_cycles, truth_query_cycles);
detector_use = detector.time_s >= measurement_start_s & ...
    detector.time_s <= measurement_end_s;
methods(4) = make_method('fpga_post_cic', detector.time_s(detector_use), ...
    detector.phase_cic_rad(detector_use) / (2 * pi), ...
    detector_truth_mod(detector_use));
methods(5) = make_method('fpga_post_iir', detector.time_s(detector_use), ...
    detector.phase_iir_rad(detector_use) / (2 * pi), ...
    detector_truth_mod(detector_use));
methods(6) = make_method('fpga_cordic', detector.time_s(detector_use), ...
    detector.phase_cordic_rad(detector_use) / (2 * pi), ...
    detector_truth_mod(detector_use));
methods(1).truth_mod_cycles = truth_query_mod_cycles;
methods(2).truth_mod_cycles = truth_query_mod_cycles;
methods(3).truth_mod_cycles = truth_query_mod_cycles;
end

function method = make_method(name, time_s, phase_cycles, truth_cycles)
valid = isfinite(time_s) & isfinite(phase_cycles) & isfinite(truth_cycles);
method.name = string(name);
method.time_s = double(time_s(valid));
method.phase_cycles = double(phase_cycles(valid));
method.truth_cycles = double(truth_cycles(valid));
method.truth_mod_cycles = [];
end

function response = build_response_table(methods, frequencies)
rows = repmat(empty_response_row(), 0, 1);
for method_index = 1:numel(methods)
    method = methods(method_index);
    for frequency_index = 1:numel(frequencies)
        frequency = frequencies(frequency_index);
        truth_fit = dpll.fit_tone(method.time_s, method.truth_cycles, frequency);
        output_fit = dpll.fit_tone(method.time_s, method.phase_cycles, frequency);
        transfer = output_fit.phasor / truth_fit.phasor;
        row = empty_response_row();
        row.method = method.name;
        row.frequency_hz = frequency;
        row.gain = abs(transfer);
        row.gain_db = 20 * log10(max(abs(transfer), realmin));
        row.phase_deg = angle(transfer) * 180 / pi;
        row.equivalent_delay_us = -angle(transfer) / ...
            (2 * pi * frequency) * 1e6;
        row.output_tone_amplitude_cycles = output_fit.amplitude;
        row.truth_tone_amplitude_cycles = truth_fit.amplitude;
        row.output_fit_r_squared = output_fit.r_squared;
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end
response = struct2table(rows);
end

function row = empty_response_row()
row.method = "";
row.frequency_hz = NaN;
row.gain = NaN;
row.gain_db = NaN;
row.phase_deg = NaN;
row.equivalent_delay_us = NaN;
row.output_tone_amplitude_cycles = NaN;
row.truth_tone_amplitude_cycles = NaN;
row.output_fit_r_squared = NaN;
end

function accuracy = build_accuracy_table(methods, multiplier)
rows = repmat(struct('method', "", 'phase_error_rms_cycles', NaN, ...
    'phase_error_rms_output_cycles', NaN, 'phase_error_peak_cycles', NaN), ...
    numel(methods), 1);
for k = 1:numel(methods)
    delta = methods(k).phase_cycles - methods(k).truth_cycles;
    centered_time = methods(k).time_s - mean(methods(k).time_s);
    design = [ones(size(centered_time)), centered_time];
    delta = delta - design * (design \ delta);
    rows(k).method = methods(k).name;
    rows(k).phase_error_rms_cycles = sqrt(mean(delta.^2));
    rows(k).phase_error_rms_output_cycles = ...
        multiplier * rows(k).phase_error_rms_cycles;
    rows(k).phase_error_peak_cycles = max(abs(delta));
end
accuracy = struct2table(rows);
end

function table_value = build_am_to_pm_table(query_time, zero, local, analytic, ...
    detector, am_frequency_hz, multiplier)
names = ["zero_crossing"; "local_sinusoid"; "fft_analytic"; ...
    "fpga_post_cic"; "fpga_post_iir"; "fpga_cordic"];
times = {query_time; query_time; query_time; detector.time_s; ...
    detector.time_s; detector.time_s};
phases = {zero.phase_cycles; local.phase_cycles; analytic.phase_cycles; ...
    detector.phase_cic_rad / (2 * pi); ...
    detector.phase_iir_rad / (2 * pi); ...
    detector.phase_cordic_rad / (2 * pi)};
tone_amplitude_cycles = nan(numel(names), 1);
false_phase_output_cycles = nan(numel(names), 1);
fit_r_squared = nan(numel(names), 1);
for k = 1:numel(names)
    valid = isfinite(times{k}) & isfinite(phases{k});
    fit_value = dpll.fit_tone(times{k}(valid), phases{k}(valid), ...
        am_frequency_hz);
    tone_amplitude_cycles(k) = fit_value.amplitude;
    false_phase_output_cycles(k) = multiplier * fit_value.amplitude;
    fit_r_squared(k) = fit_value.r_squared;
end
method = names;
table_value = table(method, tone_amplitude_cycles, ...
    false_phase_output_cycles, fit_r_squared);
end
