function record = run_dpll_fm_case(case_info, cfg, input_data, truth, ...
    output_file, save_full_result)
%RUN_DPLL_FM_CASE Run and freeze one posterior-free DPLL investigation case.

arguments
    case_info (1,1) struct
    cfg (1,1) struct
    input_data (1,1) struct
    truth (1,1) struct
    output_file (1,1) string
    save_full_result (1,1) logical = false
end

result = simulate_dpll(input_data, cfg);
measurement = extract_measurement(result, truth, ...
    case_info.measurement_start_s, case_info.measurement_end_s);
[fits, response] = fit_response(measurement, truth);
spectrum = analyze_spectrum(measurement, truth);
row = collect_row(case_info, cfg, result, truth, measurement, ...
    fits, response, spectrum);

record.schema_version = 1;
record.case_info = case_info;
record.config = cfg;
record.truth = truth;
record.measurement = measurement;
record.fits = fits;
record.response = response;
record.spectrum = spectrum;
record.row = row;
record.metadata = result.metadata;
record.status = result.status;
record.word_history = result.word_history;
record.nco_word_history = result.nco_word_history;
record.posterior_peak_data_loaded = false;
record.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
if save_full_result
    record.full_result = result;
end

[folder, ~, ~] = fileparts(output_file);
if ~isfolder(folder), mkdir(folder); end
save(output_file, 'record', '-v7.3');
end

function measurement = extract_measurement(result, truth, start_s, end_s)
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
phase_scale = pi / 2^(result.config.phase_width - 1);
phase_tau = trace_time_s - truth.carrier_lead_s;

measurement.start_s = start_s;
measurement.end_s = end_s;
measurement.word_time_s = word_time_s;
measurement.input_frequency_hz = input_frequency_hz;
measurement.output_frequency_hz = word_frequency_hz;
measurement.frequency_error_hz = input_frequency_hz - word_frequency_hz;
measurement.trace_time_s = trace_time_s;
measurement.input_phase_modulation_rad = truth.phase_modulation_rad * sin( ...
    2 * pi * truth.modulation_frequency_hz * phase_tau);
measurement.phase_error_rad = double(result.trace.phase_error(trace_keep)) * ...
    phase_scale;
measurement.control_phase_error_rad = double( ...
    result.trace.control_phase_error(trace_keep)) * phase_scale;
measurement.freq_detector_error_hz = double( ...
    result.trace.freq_error(trace_keep)) * ...
    result.config.input_sample_rate_hz / 2^26;
word_to_hz = result.config.fabric_clock_hz / 2^result.config.word_width;
measurement.p_term_hz = double(result.trace.p_term(trace_keep)) * word_to_hz;
measurement.i_term_hz = double(result.trace.i_term(trace_keep)) * word_to_hz;
measurement.fll_term_hz = double(result.trace.fll_term(trace_keep)) * word_to_hz;
measurement.ff_term_hz = double(result.trace.ff_term(trace_keep)) * word_to_hz;
measurement.cic_saturated = result.trace.cic_saturated(trace_keep);
measurement.cordic_out_of_range = ...
    result.trace.cordic_out_of_range(trace_keep);
measurement.controller_saturated = ...
    result.trace.controller_saturated_high(trace_keep) | ...
    result.trace.controller_saturated_low(trace_keep);
measurement.controller_updated = result.trace.controller_updated(trace_keep);
measurement.fll_integral_applied = ...
    result.trace.fll_integral_applied(trace_keep);
measurement.fll_feedforward_applied = ...
    result.trace.fll_feedforward_applied(trace_keep);
measurement.loop_state = result.trace.loop_state(trace_keep);
end

function [fits, response] = fit_response(measurement, truth)
fits = struct();
response = empty_response();
if truth.phase_modulation_rad == 0 || truth.frequency_deviation_hz == 0
    return;
end
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
closed_loop = fits.output_frequency.phasor / fits.input_frequency.phasor;
frequency_residual = fits.frequency_error.phasor / ...
    fits.input_frequency.phasor;
phase_residual = fits.phase_error.phasor / fits.input_phase.phasor;
response.closed_loop_gain = abs(closed_loop);
response.closed_loop_gain_db = ratio_db(response.closed_loop_gain);
response.closed_loop_phase_deg = rad2deg(angle(closed_loop));
response.frequency_residual_gain = abs(frequency_residual);
response.frequency_residual_gain_db = ratio_db( ...
    response.frequency_residual_gain);
response.phase_residual_gain = abs(phase_residual);
response.phase_residual_gain_db = ratio_db(response.phase_residual_gain);
response.output_fit_r_squared = fits.output_frequency.r_squared;
response.phase_fit_r_squared = fits.phase_error.r_squared;
response.output_tone_amplitude_hz = fits.output_frequency.amplitude;
response.output_fit_residual_rms_hz = fits.output_frequency.rms_residual;
response.non_tone_to_tone_db = ratio_db( ...
    fits.output_frequency.rms_residual / ...
    max(fits.output_frequency.amplitude / sqrt(2), realmin));
end

function response = empty_response()
response.closed_loop_gain = NaN;
response.closed_loop_gain_db = NaN;
response.closed_loop_phase_deg = NaN;
response.frequency_residual_gain = NaN;
response.frequency_residual_gain_db = NaN;
response.phase_residual_gain = NaN;
response.phase_residual_gain_db = NaN;
response.output_fit_r_squared = NaN;
response.phase_fit_r_squared = NaN;
response.output_tone_amplitude_hz = NaN;
response.output_fit_residual_rms_hz = NaN;
response.non_tone_to_tone_db = NaN;
end

function spectrum = analyze_spectrum(measurement, truth)
word_rate_hz = 1 / median(diff(measurement.word_time_s));
[frequency_hz, output_psd] = dpll.welch_psd( ...
    measurement.output_frequency_hz, word_rate_hz);
trace_rate_hz = 1 / median(diff(measurement.trace_time_s));
[phase_frequency_hz, phase_psd] = dpll.welch_psd( ...
    measurement.phase_error_rad, trace_rate_hz);
keep_output = frequency_hz <= 500;
keep_phase = phase_frequency_hz <= 500;
spectrum.output_frequency_hz = frequency_hz(keep_output);
spectrum.output_hz2_per_hz = output_psd(keep_output);
spectrum.phase_frequency_hz = phase_frequency_hz(keep_phase);
spectrum.phase_rad2_per_hz = phase_psd(keep_phase);

analysis_band = spectrum.output_frequency_hz >= 1 & ...
    spectrum.output_frequency_hz <= 150;
[spectrum.dominant_output_peak_hz, dominant_power] = strongest_peak( ...
    spectrum.output_frequency_hz, spectrum.output_hz2_per_hz, analysis_band);
phase_band = spectrum.phase_frequency_hz >= 1 & ...
    spectrum.phase_frequency_hz <= 150;
[spectrum.dominant_phase_peak_hz, ~] = strongest_peak( ...
    spectrum.phase_frequency_hz, spectrum.phase_rad2_per_hz, phase_band);

if truth.phase_modulation_rad == 0
    spectrum.spurious_output_peak_hz = spectrum.dominant_output_peak_hz;
    spectrum.spurious_to_fundamental_db = NaN;
else
    resolution_hz = median(diff(spectrum.output_frequency_hz));
    fundamental_mask = abs(spectrum.output_frequency_hz - ...
        truth.modulation_frequency_hz) <= max(2 * resolution_hz, 1);
    spur_band = analysis_band & ~fundamental_mask;
    [spectrum.spurious_output_peak_hz, spur_power] = strongest_peak( ...
        spectrum.output_frequency_hz, spectrum.output_hz2_per_hz, spur_band);
    fundamental_power = max(spectrum.output_hz2_per_hz(fundamental_mask));
    spectrum.spurious_to_fundamental_db = 10 * log10( ...
        max(spur_power, realmin) / max(fundamental_power, realmin));
end
spectrum.dominant_output_peak_power = dominant_power;
end

function [frequency, power] = strongest_peak(frequency_hz, psd_value, mask)
indices = find(mask);
if isempty(indices)
    frequency = NaN;
    power = NaN;
    return;
end
[power, local_index] = max(psd_value(indices));
frequency = frequency_hz(indices(local_index));
end

function row = collect_row(case_info, cfg, result, truth, measurement, ...
    fits, response, spectrum) %#ok<INUSD>
row.case_id = string(case_info.case_id);
row.layer = string(case_info.layer);
row.config_id = string(case_info.config_id);
row.modulation_frequency_hz = truth.modulation_frequency_hz;
row.phase_modulation_rad = truth.phase_modulation_rad;
row.frequency_deviation_hz = truth.frequency_deviation_hz;
row.measurement_duration_s = measurement.end_s - measurement.start_s;
row.kp_track = double(cfg.gains.kp_track);
row.ki_track = double(cfg.gains.ki_track);
row.kf_track = double(cfg.gains.kf_track);
row.p_product_shift = cfg.shifts.p_product;
row.i_product_shift = cfg.shifts.i_product;
row.controller_update_mode = string(cfg.architecture.controller_update_mode);
row.phase_lead_samples = cfg.architecture.phase_lead_samples;
row.fll_feedforward_enable = cfg.architecture.fll_feedforward_enable;
row.kff_track = double(cfg.gains.kff_track);
row.closed_loop_gain_db = response.closed_loop_gain_db;
row.closed_loop_phase_deg = response.closed_loop_phase_deg;
row.frequency_residual_gain_db = response.frequency_residual_gain_db;
row.phase_residual_gain_db = response.phase_residual_gain_db;
row.output_fit_r_squared = response.output_fit_r_squared;
row.phase_fit_r_squared = response.phase_fit_r_squared;
row.non_tone_to_tone_db = response.non_tone_to_tone_db;
row.phase_error_rms_rad = rms_plain(measurement.phase_error_rad);
row.phase_error_std_rad = std(measurement.phase_error_rad);
row.frequency_error_rms_hz = rms_plain(measurement.frequency_error_hz);
row.output_frequency_std_hz = std(measurement.output_frequency_hz);
row.freq_detector_error_rms_hz = rms_plain(measurement.freq_detector_error_hz);
row.p_term_rms_hz = rms_plain(measurement.p_term_hz);
row.i_term_rms_hz = rms_plain(measurement.i_term_hz);
row.fll_term_rms_hz = rms_plain(measurement.fll_term_hz);
row.ff_term_rms_hz = rms_plain(measurement.ff_term_hz);
row.dominant_output_peak_hz = spectrum.dominant_output_peak_hz;
row.spurious_output_peak_hz = spectrum.spurious_output_peak_hz;
row.spurious_to_fundamental_db = spectrum.spurious_to_fundamental_db;
row.dominant_phase_peak_hz = spectrum.dominant_phase_peak_hz;
row.cic_saturation_rate = mean(measurement.cic_saturated);
row.cordic_out_of_range_rate = mean(measurement.cordic_out_of_range);
row.controller_saturation_rate = mean(measurement.controller_saturated);
row.controller_update_rate = mean(measurement.controller_updated);
row.fll_integral_application_rate = mean(measurement.fll_integral_applied);
row.fll_feedforward_application_rate = ...
    mean(measurement.fll_feedforward_applied);
row.track_fraction = mean(measurement.loop_state == 6);
row.initial_frequency_hz = result.metadata.initial_frequency_hz;
row.posterior_data_used = result.metadata.posterior_interval_data_used;
end

function value = rms_plain(values)
values = double(values(:));
if isempty(values), value = NaN; else, value = sqrt(mean(values.^2)); end
end

function value = ratio_db(ratio)
value = 20 * log10(max(double(ratio), realmin));
end
