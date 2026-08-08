function relation = build_interval_relation(dense, peaks, options)
%BUILD_INTERVAL_RELATION Reference/pulse relation without a simulated loop.
%
% Peak positions are posterior query events only. The exact identity is
%   e_event = M * (delta_phase - R) = M * T * (f_ref_bar - R/T).

arguments
    dense (1,1) struct
    peaks (1,1) struct
    options.reference_cycles_per_pulse (1,1) double = 113
    options.output_multiplier (1,1) double = 2000
    options.minimum_observations_per_interval (1,1) double = 16
end

required_dense = {'time_s', 'phase_cycles', 'frequency_hz', ...
    'frequency_coverage'};
required_peaks = {'time_s', 'raw_index', 'raw_sample_rate_hz'};
if ~all(isfield(dense, required_dense)) || ...
        ~all(isfield(peaks, required_peaks))
    error('reference_analysis:IncompleteRelationInput', ...
        'Dense reference or peak-event structure is incomplete.');
end
validateattributes(options.reference_cycles_per_pulse, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(options.output_multiplier, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(options.minimum_observations_per_interval, {'numeric'}, ...
    {'scalar', 'integer', '>=', 5});

reference_time_s = double(dense.time_s(:));
reference_phase_cycles = double(dense.phase_cycles(:));
frequency_coverage = logical(dense.frequency_coverage(:)) & ...
    isfinite(double(dense.frequency_hz(:)));
peak_time_s = double(peaks.time_s(:));
peak_raw_index = double(peaks.raw_index(:));
if numel(reference_time_s) ~= numel(reference_phase_cycles) || ...
        numel(reference_time_s) ~= numel(frequency_coverage) || ...
        numel(reference_time_s) < 5 || any(diff(reference_time_s) <= 0) || ...
        any(diff(reference_phase_cycles) <= 0)
    error('reference_analysis:InvalidDenseReference', ...
        'Dense reference time and phase must be equal-length monotonic vectors.');
end
if numel(peak_time_s) < 3 || numel(peak_time_s) ~= numel(peak_raw_index) || ...
        any(diff(peak_time_s) <= 0) || any(diff(peak_raw_index) <= 0)
    error('reference_analysis:InvalidPeakEvents', ...
        'At least three monotonic peak events are required.');
end

phase_at_peak = interp1(reference_time_s, reference_phase_cycles, ...
    peak_time_s, 'pchip', NaN);
event_coverage = isfinite(phase_at_peak);
interval_count = numel(peak_time_s) - 1;
interval_duration_s = diff(peak_time_s);
interval_raw_samples = diff(peak_raw_index);
phase_increment_cycles = diff(phase_at_peak);

observation_count = zeros(interval_count, 1);
for k = 1:interval_count
    observation_count(k) = nnz(frequency_coverage & ...
        reference_time_s >= peak_time_s(k) & ...
        reference_time_s < peak_time_s(k + 1));
end

ratio = options.reference_cycles_per_pulse;
multiplier = options.output_multiplier;
pulse_equivalent_frequency_hz = ratio ./ interval_duration_s;
reference_average_frequency_hz = ...
    phase_increment_cycles ./ interval_duration_s;
frequency_mismatch_hz = reference_average_frequency_hz - ...
    pulse_equivalent_frequency_hz;
reference_event_error_output_cycles = multiplier * ...
    (phase_increment_cycles - ratio);
reference_event_error_mrad = 2 * pi * 1000 * ...
    (phase_increment_cycles - ratio);
identity_rhs_output_cycles = multiplier * interval_duration_s .* ...
    frequency_mismatch_hz;
identity_residual_output_cycles = reference_event_error_output_cycles - ...
    identity_rhs_output_cycles;

frequency_time = reference_time_s(frequency_coverage);
inside_frequency_span = peak_time_s(1:end-1) >= frequency_time(1) & ...
    peak_time_s(2:end) <= frequency_time(end);
valid_interval = event_coverage(1:end-1) & event_coverage(2:end) & ...
    inside_frequency_span & observation_count >= ...
    options.minimum_observations_per_interval;
if ~any(valid_interval)
    error('reference_analysis:NoCoveredIntervals', ...
        'No pulse interval has complete phase and frequency coverage.');
end
covered_but_sparse = event_coverage(1:end-1) & ...
    event_coverage(2:end) & inside_frequency_span & ...
    observation_count < options.minimum_observations_per_interval;
if any(covered_but_sparse)
    error('reference_analysis:InsufficientObservationDensity', ...
        ['At least one otherwise-covered interval has fewer than %d ' ...
        'reference-frequency observations.'], ...
        options.minimum_observations_per_interval);
end

% One-step ideal-reference prediction, anchored only at the current event.
target_next_phase = phase_at_peak(1:end-1) + ratio;
predicted_next_time_s = interp1(reference_phase_cycles, ...
    reference_time_s, target_next_phase, 'linear', NaN);
timing_residual_s = peak_time_s(2:end) - predicted_next_time_s;
timing_residual_raw_samples = timing_residual_s * ...
    double(peaks.raw_sample_rate_hz);

% Free-running ideal-reference event grid, initialized once at the first
% covered real event. Later real peaks do not re-anchor this prediction.
anchor = find(event_coverage, 1, 'first');
event_index = (1:numel(peak_time_s)).';
free_run_target_phase = phase_at_peak(anchor) + ratio * ...
    (event_index - anchor);
free_run_predicted_time_s = interp1(reference_phase_cycles, ...
    reference_time_s, free_run_target_phase, 'linear', NaN);
event_phase_residual_cycles = phase_at_peak - free_run_target_phase;
event_phase_wrapped_cycles = mod(event_phase_residual_cycles + 0.5, 1) - 0.5;

interval.index = (1:interval_count).';
interval.start_time_s = peak_time_s(1:end-1);
interval.end_time_s = peak_time_s(2:end);
interval.mid_time_s = 0.5 * (interval.start_time_s + interval.end_time_s);
interval.duration_s = interval_duration_s;
interval.raw_samples_62m5 = interval_raw_samples;
interval.reference_observation_count = observation_count;
interval.phase_increment_cycles = phase_increment_cycles;
interval.pulse_equivalent_frequency_hz = pulse_equivalent_frequency_hz;
interval.reference_average_frequency_hz = reference_average_frequency_hz;
interval.frequency_mismatch_hz = frequency_mismatch_hz;
interval.reference_event_error_output_cycles = ...
    reference_event_error_output_cycles;
interval.reference_event_error_mrad = reference_event_error_mrad;
interval.identity_rhs_output_cycles = identity_rhs_output_cycles;
interval.identity_residual_output_cycles = identity_residual_output_cycles;
interval.predicted_next_time_s = predicted_next_time_s;
interval.timing_residual_s = timing_residual_s;
interval.timing_residual_raw_samples_62m5 = timing_residual_raw_samples;
interval.valid = valid_interval;

event.index = event_index;
event.raw_index = peak_raw_index;
event.time_s = peak_time_s;
event.reference_phase_cycles = phase_at_peak;
event.coverage = event_coverage;
event.free_run_anchor_index = anchor;
event.free_run_target_phase_cycles = free_run_target_phase;
event.free_run_predicted_time_s = free_run_predicted_time_s;
event.phase_residual_cycles = event_phase_residual_cycles;
event.phase_wrapped_cycles = event_phase_wrapped_cycles;

valid_error = reference_event_error_output_cycles(valid_interval);
valid_frequency_error = frequency_mismatch_hz(valid_interval);
valid_identity = identity_residual_output_cycles(valid_interval);
valid_timing = timing_residual_raw_samples(valid_interval & ...
    isfinite(timing_residual_raw_samples));

summary.event_count = numel(peak_time_s);
summary.interval_count = interval_count;
summary.valid_interval_count = nnz(valid_interval);
summary.reference_cycles_per_pulse = ratio;
summary.output_multiplier = multiplier;
summary.minimum_required_observations_per_interval = ...
    options.minimum_observations_per_interval;
summary.minimum_observations_per_valid_interval = ...
    min(observation_count(valid_interval));
summary.median_observations_per_valid_interval = ...
    median(observation_count(valid_interval));
summary.reference_event_rms_output_cycles = rms_plain(valid_error);
summary.reference_event_peak_abs_output_cycles = max(abs(valid_error));
summary.reference_event_rms_mrad = rms_plain( ...
    reference_event_error_mrad(valid_interval));
summary.frequency_mismatch_rms_hz = rms_plain(valid_frequency_error);
summary.identity_max_abs_output_cycles = max(abs(valid_identity));
summary.identity_passed = summary.identity_max_abs_output_cycles < 1e-9;
if isempty(valid_timing)
    summary.timing_residual_rms_raw_samples_62m5 = NaN;
else
    summary.timing_residual_rms_raw_samples_62m5 = rms_plain(valid_timing);
end

relation.schema_version = 1;
relation.method = ['Direct reference IQ phase versus posterior fixed-clock ' ...
    'pulse events; no simulated loop.'];
relation.dense = dense;
relation.peaks = peaks;
relation.event = event;
relation.interval = interval;
relation.summary = summary;
relation.posterior_peak_data_loaded = true;
relation.posterior_role = 'oracle diagnostic only';
relation.posterior_peak_data_used_for_controller = false;
relation.posterior_peak_data_used_for_training = false;
relation.simulated_loop_data_loaded = false;
relation.controller_configuration_used = false;
end

function value = rms_plain(values)
values = double(values(:));
value = sqrt(mean(values.^2));
end
