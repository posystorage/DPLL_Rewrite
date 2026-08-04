function validation = validate_exact_reference_cycle_events(result, margin_s)
%VALIDATE_EXACT_REFERENCE_CYCLE_EVENTS Reference-only synthetic event test.

if nargin < 2, margin_s = 0.02; end
if result.metadata.posterior_interval_data_used
    error('dpll:PosteriorContamination', ...
        'Exact-cycle validation requires a posterior-free replay.');
end
keep = result.trace.analysis_valid;
raw_index = double(result.metadata.source_raw_start_index) + ...
    (double(result.trace.input_index(keep)) - ...
    double(result.metadata.input_start_index)) * ...
    double(result.metadata.source_samples_per_input);
phase_error_rad = double(result.trace.phase_error(keep)) * pi / ...
    2^(result.config.phase_width - 1);
setpoint_rad = double(result.config.phase_setpoint) * pi / ...
    2^(result.config.phase_width - 1);
reference_cycles = (double(result.trace.tracking_phase_rad(keep)) + ...
    unwrap(phase_error_rad + setpoint_rad)) / (2 * pi);
[raw_index, last_index] = unique(raw_index, 'last');
reference_cycles = reference_cycles(last_index);
phase_error_rad = phase_error_rad(last_index);

margin_raw = margin_s * result.metadata.source_raw_sample_rate_hz;
first_raw = raw_index(1) + margin_raw;
last_raw = raw_index(end) - margin_raw;
first_cycle = interp1(raw_index, reference_cycles, first_raw, 'linear');
last_cycle = interp1(raw_index, reference_cycles, last_raw, 'linear');
ratio = result.config.pulse.reference_cycles_per_pulse;
multiplier = result.config.pulse.output_multiplier;
ideal = ratio * multiplier;
target_cycles = (ceil(first_cycle / ratio) * ratio:ratio: ...
    floor(last_cycle / ratio) * ratio).';
if numel(target_cycles) < 3
    error('dpll:InsufficientSyntheticEvents', ...
        'Reference-only coverage contains fewer than three exact events.');
end
event_raw = interp1(reference_cycles, raw_index, target_cycles, 'linear');
event_tick = (event_raw - 1) * result.config.fabric_clock_hz / ...
    result.metadata.source_raw_sample_rate_hz;
output_cycles = integrate_history(result.word_history, event_tick, ...
    multiplier, result.config.word_width);
pll_error = diff(output_cycles) - ideal;
fixed_interval = diff(event_raw);
fixed_scale = ideal / mean(fixed_interval);
fixed_error = fixed_interval * fixed_scale - ideal;
phase_error_event = interp1(raw_index, phase_error_rad, event_raw, 'linear');
delta_phase_113_rad = diff(phase_error_event);
endpoint_prediction = -delta_phase_113_rad / (2 * pi) * multiplier;
slow_window = min(21, numel(pll_error));
slow = movmean(pll_error, slow_window, 'Endpoints', 'shrink');
fast = pll_error - slow;
interval_time_s = (event_raw(2:end) - 1) / ...
    result.metadata.source_raw_sample_rate_hz;
segment_metrics = build_segment_metrics(interval_time_s, pll_error, ...
    delta_phase_113_rad, endpoint_prediction, slow, fast);
event_rate_hz = 1 / median(diff(validation_time(event_raw, result)));
if numel(pll_error) >= 32
    [event_frequency_hz, event_psd] = dpll.welch_psd(pll_error, event_rate_hz);
    spectral_keep = event_frequency_hz >= 1 & ...
        event_frequency_hz <= event_rate_hz / 2;
    if any(spectral_keep)
        spectral_indices = find(spectral_keep);
        [~, local_peak] = max(event_psd(spectral_indices));
        dominant_event_frequency_hz = event_frequency_hz( ...
            spectral_indices(local_peak));
    else
        dominant_event_frequency_hz = NaN;
    end
else
    event_frequency_hz = zeros(0, 1);
    event_psd = zeros(0, 1);
    dominant_event_frequency_hz = NaN;
end

validation.posterior_peak_data_loaded = false;
validation.target_reference_cycles = target_cycles;
validation.event_raw_index = event_raw;
validation.event_time_s = (event_raw - 1) / ...
    result.metadata.source_raw_sample_rate_hz;
validation.output_cycles_at_event = output_cycles;
validation.fixed_clock_error = fixed_error;
validation.pll_residual_error = pll_error;
validation.endpoint_phase_prediction = endpoint_prediction;
validation.phase_error_at_event_rad = phase_error_event;
validation.delta_phase_113_rad = delta_phase_113_rad;
validation.equivalent_interval_error_cycles = endpoint_prediction;
validation.slow_error = slow;
validation.fast_error = fast;
validation.segment_metrics = segment_metrics;
validation.event_spectrum.frequency_hz = event_frequency_hz;
validation.event_spectrum.cycles2_per_hz = event_psd;
validation.summary.event_count = numel(event_raw);
validation.summary.interval_count = numel(pll_error);
validation.summary.fixed_rms_cycles = sqrt(mean(fixed_error.^2));
validation.summary.pll_rms_cycles = sqrt(mean(pll_error.^2));
validation.summary.pll_std_cycles = std(pll_error);
validation.summary.pll_fast_std_cycles = std(fast);
validation.summary.pll_peak_to_peak_cycles = range(pll_error);
validation.summary.delta_phase_113_rms_rad = rms_plain(delta_phase_113_rad);
validation.summary.delta_phase_113_rms_mrad = ...
    1e3 * validation.summary.delta_phase_113_rms_rad;
validation.summary.delta_phase_113_peak_to_peak_mrad = ...
    1e3 * range(delta_phase_113_rad);
absolute_delta_mrad = 1e3 * abs(delta_phase_113_rad);
validation.summary.delta_phase_113_peak_abs_mrad = max(absolute_delta_mrad);
validation.summary.delta_phase_113_p95_abs_mrad = ...
    percentile_plain(absolute_delta_mrad, 95);
validation.summary.delta_phase_over_3mrad_fraction = ...
    mean(absolute_delta_mrad > 3);
validation.summary.equivalent_interval_rms_cycles = ...
    rms_plain(endpoint_prediction);
validation.summary.equivalent_interval_peak_abs_cycles = ...
    max(abs(endpoint_prediction));
validation.summary.equivalent_interval_over_1cycle_fraction = ...
    mean(abs(endpoint_prediction) > 1);
validation.summary.endpoint_identity_rms_cycles = ...
    rms_plain(pll_error - endpoint_prediction);
validation.summary.endpoint_identity_max_abs_cycles = ...
    max(abs(pll_error - endpoint_prediction));
validation.summary.slow_rms_cycles = rms_plain(slow);
validation.summary.fast_rms_cycles = rms_plain(fast);
validation.summary.event_rate_hz = event_rate_hz;
validation.summary.event_domain_nyquist_hz = event_rate_hz / 2;
validation.summary.dominant_event_frequency_hz = dominant_event_frequency_hz;
validation.summary.endpoint_prediction_correlation = ...
    corr(pll_error, endpoint_prediction);
end

function time_s = validation_time(event_raw, result)
time_s = (event_raw - 1) / result.metadata.source_raw_sample_rate_hz;
end

function metrics = build_segment_metrics(time_s, pll_error, delta_phase, ...
    equivalent_error, slow, fast)
count = numel(pll_error);
segment_count = min(4, count);
edges = round(linspace(1, count + 1, segment_count + 1));
rows = repmat(struct(), segment_count, 1);
for quarter = 1:segment_count
    indices = edges(quarter):(edges(quarter + 1) - 1);
    rows(quarter).segment = quarter;
    rows(quarter).start_time_s = time_s(indices(1));
    rows(quarter).end_time_s = time_s(indices(end));
    rows(quarter).interval_count = numel(indices);
    rows(quarter).pll_rms_cycles = rms_plain(pll_error(indices));
    rows(quarter).delta_phase_rms_mrad = ...
        1e3 * rms_plain(delta_phase(indices));
    rows(quarter).equivalent_rms_cycles = ...
        rms_plain(equivalent_error(indices));
    rows(quarter).slow_rms_cycles = rms_plain(slow(indices));
    rows(quarter).fast_rms_cycles = rms_plain(fast(indices));
    rows(quarter).identity_rms_cycles = ...
        rms_plain(pll_error(indices) - equivalent_error(indices));
end
metrics = struct2table(rows);
end

function value = rms_plain(values)
values = double(values(:));
if isempty(values), value = NaN; else, value = sqrt(mean(values.^2)); end
end


function value = percentile_plain(values, percentile)
values = sort(double(values(:)));
if isempty(values)
    value = NaN;
    return;
end
position = 1 + (numel(values) - 1) * percentile / 100;
lower_index = floor(position);
upper_index = ceil(position);
fraction = position - lower_index;
value = values(lower_index) + fraction * ...
    (values(upper_index) - values(lower_index));
end

function cycles = integrate_history(history, query_tick, multiplier, word_width)
ticks = double(history.fabric_tick(:));
words = double(history.tracking_word(:));
[ticks, last_index] = unique(ticks, 'last');
words = words(last_index);
segment_cycles = diff(ticks) .* words(1:end-1) * multiplier / 2^word_width;
cumulative = [0; cumsum(segment_cycles)];
cycles = zeros(size(query_tick));
for k = 1:numel(query_tick)
    index = find(ticks <= query_tick(k), 1, 'last');
    if isempty(index)
        error('dpll:WordHistoryCoverage', ...
            'Exact-cycle event precedes tracking-word history.');
    end
    cycles(k) = cumulative(index) + ...
        (query_tick(k) - ticks(index)) * words(index) * ...
        multiplier / 2^word_width;
end
end
