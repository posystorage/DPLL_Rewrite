function validation = validate_truth_reference_cycle_events( ...
    result, reference_phase_rad, sample_rate_hz, margin_s)
%VALIDATE_TRUTH_REFERENCE_CYCLE_EVENTS Exact-cycle events from known phase.

if nargin < 4, margin_s = 0.01; end
reference_phase_rad = double(reference_phase_rad(:));
validateattributes(sample_rate_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(margin_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
if any(~isfinite(reference_phase_rad)) || numel(reference_phase_rad) < 3
    error('dpll:InvalidTruthPhase', ...
        'Known reference phase must contain at least three finite samples.');
end

reference_cycles = unwrap(reference_phase_rad) / (2 * pi);
if any(diff(reference_cycles) <= 0)
    error('dpll:NonmonotonicTruthPhase', ...
        'Known reference phase must increase monotonically.');
end
time_s = (0:numel(reference_cycles)-1).' / sample_rate_hz;
analysis_time = result.trace.time_s(result.trace.analysis_valid);
if isempty(analysis_time)
    error('dpll:NoAnalysisWindow', 'Replay contains no TRACK analysis window.');
end
first_time = max(time_s(1), analysis_time(1) + margin_s);
last_time = min(time_s(end), analysis_time(end) - margin_s);
if last_time <= first_time
    error('dpll:InsufficientTruthCoverage', ...
        'Known phase does not cover the replay analysis window.');
end

first_cycle = interp1(time_s, reference_cycles, first_time, 'linear');
last_cycle = interp1(time_s, reference_cycles, last_time, 'linear');
ratio = result.config.pulse.reference_cycles_per_pulse;
multiplier = result.config.pulse.output_multiplier;
target_cycles = (ceil(first_cycle / ratio) * ratio:ratio: ...
    floor(last_cycle / ratio) * ratio).';
if numel(target_cycles) < 3
    error('dpll:InsufficientTruthEvents', ...
        'Known phase coverage contains fewer than three exact events.');
end

event_time_s = interp1(reference_cycles, time_s, target_cycles, 'linear');
event_tick = event_time_s * result.config.fabric_clock_hz;
output_cycles = integrate_word_history(result.word_history, event_tick, ...
    multiplier, result.config.word_width);
ideal_interval = ratio * multiplier;
output_interval = diff(output_cycles);
residual = output_interval - ideal_interval;

validation.schema_version = 1;
validation.posterior_peak_data_loaded = false;
validation.event_time_s = event_time_s;
validation.event_fabric_tick = event_tick;
validation.reference_target_cycles = target_cycles;
validation.output_cycles_at_event = output_cycles;
validation.output_interval_cycles = output_interval;
validation.pll_residual_error = residual;
validation.summary.event_count = numel(event_time_s);
validation.summary.interval_count = numel(residual);
validation.summary.rms_cycles = sqrt(mean(residual.^2));
validation.summary.std_cycles = std(residual);
validation.summary.peak_to_peak_cycles = max(residual) - min(residual);
validation.summary.mean_cycles = mean(residual);
end

function cycles = integrate_word_history(history, query_tick, multiplier, word_width)
ticks = double(history.fabric_tick(:));
words = double(history.tracking_word(:));
if isempty(ticks) || ticks(1) > min(query_tick)
    error('dpll:WordHistoryCoverage', ...
        'Tracking-word history does not cover exact truth events.');
end
[ticks, last_index] = unique(ticks, 'last');
words = words(last_index);
segment_cycles = diff(ticks) .* words(1:end-1) * multiplier / 2^word_width;
cumulative = [0; cumsum(segment_cycles)];
cycles = zeros(size(query_tick));
for k = 1:numel(query_tick)
    index = find(ticks <= query_tick(k), 1, 'last');
    if isempty(index)
        error('dpll:WordHistoryCoverage', ...
            'Exact truth event precedes tracking-word history.');
    end
    cycles(k) = cumulative(index) + ...
        (query_tick(k) - ticks(index)) * words(index) * ...
        multiplier / 2^word_width;
end
end
