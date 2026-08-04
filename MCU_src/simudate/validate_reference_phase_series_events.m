function validation = validate_reference_phase_series_events( ...
    result, reference_time_s, reference_phase_cycles, margin_s)
%VALIDATE_REFERENCE_PHASE_SERIES_EVENTS Exact events from phase time series.

if nargin < 4, margin_s = 0.01; end
reference_time_s = double(reference_time_s(:));
reference_phase_cycles = double(reference_phase_cycles(:));
if numel(reference_time_s) ~= numel(reference_phase_cycles) || ...
        numel(reference_time_s) < 3 || ...
        any(~isfinite(reference_time_s)) || ...
        any(~isfinite(reference_phase_cycles)) || ...
        any(diff(reference_time_s) <= 0) || ...
        any(diff(reference_phase_cycles) <= 0)
    error('dpll:InvalidReferencePhaseSeries', ...
        'Reference time and phase must be equal-length monotonic vectors.');
end

analysis_time = result.trace.time_s(result.trace.analysis_valid);
if isempty(analysis_time)
    error('dpll:NoAnalysisWindow', 'Replay contains no TRACK analysis window.');
end
first_time = max(reference_time_s(1), analysis_time(1) + margin_s);
last_time = min(reference_time_s(end), analysis_time(end) - margin_s);
first_cycle = interp1(reference_time_s, reference_phase_cycles, ...
    first_time, 'linear');
last_cycle = interp1(reference_time_s, reference_phase_cycles, ...
    last_time, 'linear');
ratio = result.config.pulse.reference_cycles_per_pulse;
multiplier = result.config.pulse.output_multiplier;
targets = (ceil(first_cycle / ratio) * ratio:ratio: ...
    floor(last_cycle / ratio) * ratio).';
if numel(targets) < 3
    error('dpll:InsufficientReferenceEvents', ...
        'Reference phase series contains fewer than three exact events.');
end
event_time = interp1(reference_phase_cycles, reference_time_s, ...
    targets, 'linear');
event_tick = event_time * result.config.fabric_clock_hz;
output_cycles = integrate_history(result.word_history, event_tick, ...
    multiplier, result.config.word_width);
residual = diff(output_cycles) - ratio * multiplier;

validation.posterior_peak_data_loaded = false;
validation.event_time_s = event_time;
validation.reference_target_cycles = targets;
validation.output_cycles_at_event = output_cycles;
validation.pll_residual_error = residual;
validation.summary.event_count = numel(event_time);
validation.summary.rms_cycles = sqrt(mean(residual.^2));
validation.summary.std_cycles = std(residual);
validation.summary.mean_cycles = mean(residual);
validation.summary.peak_to_peak_cycles = max(residual) - min(residual);
end

function cycles = integrate_history(history, query_tick, multiplier, word_width)
ticks = double(history.fabric_tick(:));
words = double(history.tracking_word(:));
[ticks, last_index] = unique(ticks, 'last');
words = words(last_index);
if isempty(ticks) || ticks(1) > min(query_tick)
    error('dpll:WordHistoryCoverage', ...
        'Tracking-word history does not cover reference events.');
end
segments = diff(ticks) .* words(1:end-1) * multiplier / 2^word_width;
cumulative = [0; cumsum(segments)];
cycles = zeros(size(query_tick));
for k = 1:numel(query_tick)
    index = find(ticks <= query_tick(k), 1, 'last');
    cycles(k) = cumulative(index) + ...
        (query_tick(k) - ticks(index)) * words(index) * ...
        multiplier / 2^word_width;
end
end
