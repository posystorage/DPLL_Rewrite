function events = predict_pulse_events(trace, cfg)
%PREDICT_PULSE_EVENTS Generate reference-cycle events without posterior data.

events = empty_events();
if numel(trace.input_index) < 2
    return;
end

phase_scale = pi / 2^(cfg.phase_width - 1);
error_unwrapped_codes = zeros(size(trace.phase_error), 'double');
error_unwrapped_codes(1) = double(trace.phase_error(1));
for k = 2:numel(trace.phase_error)
    delta = dpll.fixed_wrap(int64(trace.phase_error(k)) - ...
        int64(trace.phase_error(k - 1)), cfg.phase_width);
    error_unwrapped_codes(k) = error_unwrapped_codes(k - 1) + double(delta);
end
error_unwrapped = error_unwrapped_codes * phase_scale;
tracking_phase = trace.tracking_phase_rad;
reference_phase = tracking_phase + error_unwrapped;

events.reference_phase = reference_phase;
events.tracking_phase = tracking_phase;
events.reference_input_index = trace.input_index;
events.phase_error_unwrapped = error_unwrapped;

cycles_per_event = cfg.pulse.reference_cycles_per_pulse;
phase_step = 2 * pi * cycles_per_event;
anchor_index = cfg.pulse.first_pulse_sample_index;
if isempty(anchor_index)
    anchor_trace = find(trace.loop_state == 6, 1, 'first');
    if isempty(anchor_trace)
        anchor_trace = 1;
    end
    anchor_phase = reference_phase(anchor_trace);
    first_target = anchor_phase + phase_step;
    events.anchor_used = false;
    events.anchor_input_index = NaN;
else
    validateattributes(anchor_index, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 1, '<=', trace.input_index(end)});
    anchor_phase = interp1(trace.input_index, reference_phase, ...
        double(anchor_index), 'linear');
    first_target = anchor_phase;
    events.anchor_used = true;
    events.anchor_input_index = double(anchor_index);
end

if reference_phase(end) < first_target
    return;
end
target_phase = (first_target:phase_step:reference_phase(end)).';
keep = target_phase >= reference_phase(1);
target_phase = target_phase(keep);
if isempty(target_phase)
    return;
end

% The reference is physically monotonic near 20 kHz. Retain a strictly
% increasing subsequence if detector quantization produces a duplicate or a
% one-sample reversal.
unique_idx = zeros(numel(reference_phase), 1);
unique_count = 0;
last_phase = -Inf;
for k = 1:numel(reference_phase)
    if reference_phase(k) > last_phase
        unique_count = unique_count + 1;
        unique_idx(unique_count) = k;
        last_phase = reference_phase(k);
    end
end
unique_idx = unique_idx(1:unique_count);
reference_unique = reference_phase(unique_idx);
target_phase = target_phase(target_phase >= reference_unique(1) & ...
    target_phase <= reference_unique(end));
if isempty(target_phase)
    return;
end

event_input_index = interp1(reference_unique, ...
    trace.input_index(unique_idx), target_phase, 'linear');
tracking_at_event = interp1(trace.input_index, tracking_phase, ...
    event_input_index, 'linear');
error_at_event = target_phase - tracking_at_event;
multiplier = cfg.pulse.output_multiplier;
interval_samples = multiplier / (2 * pi) * diff(tracking_at_event);
interval_error = interval_samples - cfg.pulse.ideal_interval_samples;
interval_error_from_phase = -multiplier / (2 * pi) * diff(error_at_event);

events.event_time_s = (event_input_index - 1) / cfg.input_sample_rate_hz;
events.event_input_index = event_input_index;
events.phase_error_at_event = error_at_event;
events.tracking_phase_at_event = tracking_at_event;
events.predicted_interval_samples = interval_samples;
events.predicted_interval_error = interval_error;
events.predicted_interval_error_from_phase = interval_error_from_phase;
events.identity_error_samples = interval_error - interval_error_from_phase;
end

function events = empty_events()
events.reference_phase = zeros(0, 1);
events.tracking_phase = zeros(0, 1);
events.reference_input_index = zeros(0, 1);
events.phase_error_unwrapped = zeros(0, 1);
events.event_time_s = zeros(0, 1);
events.event_input_index = zeros(0, 1);
events.phase_error_at_event = zeros(0, 1);
events.tracking_phase_at_event = zeros(0, 1);
events.predicted_interval_samples = zeros(0, 1);
events.predicted_interval_error = zeros(0, 1);
events.predicted_interval_error_from_phase = zeros(0, 1);
events.identity_error_samples = zeros(0, 1);
events.anchor_used = false;
events.anchor_input_index = NaN;
end
