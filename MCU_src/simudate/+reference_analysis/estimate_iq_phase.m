function dense = estimate_iq_phase(codes, sample_rate_hz, options)
%ESTIMATE_IQ_PHASE Reference-only fixed-window IQ phase reconstruction.
%
% This is an offline, symmetric-window estimator. It deliberately has no
% controller, replay, or peak-event input. Frequency is obtained from a
% fixed phase-accumulation aperture on the reconstructed phase series.

arguments
    codes {mustBeNumeric, mustBeReal}
    sample_rate_hz (1,1) double {mustBeFinite, mustBePositive}
    options.carrier_frequency_hz (1,1) double = NaN
    options.observation_rate_hz (1,1) double = 4000
    options.iq_window_s (1,1) double = 0.001
    options.frequency_aperture_s (1,1) double = 0.001
    options.source_start_time_s (1,1) double = 0
end

codes = double(codes(:));
if numel(codes) < 64 || any(~isfinite(codes))
    error('reference_analysis:InvalidReferenceCodes', ...
        'Reference input must contain at least 64 finite real samples.');
end
validateattributes(options.observation_rate_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<=', sample_rate_hz});
validateattributes(options.iq_window_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(options.frequency_aperture_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(options.source_start_time_s, {'numeric'}, ...
    {'scalar', 'real', 'finite'});

centered = codes - median(codes);
if all(centered == 0)
    error('reference_analysis:ConstantReferenceInput', ...
        'Reference input is constant after median removal.');
end

[crossing_index, crossing_cycle, crossing_frequency_hz, spacing_std] = ...
    positive_crossing_clock(centered, sample_rate_hz);
carrier_frequency_hz = options.carrier_frequency_hz;
if isnan(carrier_frequency_hz)
    carrier_frequency_hz = crossing_frequency_hz;
else
    validateattributes(carrier_frequency_hz, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive', '<', sample_rate_hz / 2});
end

window_samples = max(9, round(options.iq_window_s * sample_rate_hz));
if mod(window_samples, 2) == 0
    window_samples = window_samples + 1;
end
if window_samples >= numel(centered)
    error('reference_analysis:IQWindowTooLong', ...
        'The fixed IQ window must be shorter than the reference input.');
end
half_window = floor(window_samples / 2);
observation_step = max(1, round(sample_rate_hz / ...
    options.observation_rate_hz));
center_index = (1 + half_window:observation_step: ...
    numel(centered) - half_window).';
if numel(center_index) < 5
    error('reference_analysis:InsufficientIQObservations', ...
        'The input and IQ settings produce fewer than five observations.');
end

sample_number = (0:numel(centered) - 1).';
oscillator = exp(-1i * 2 * pi * carrier_frequency_hz * ...
    sample_number / sample_rate_hz);
mixed = 2 * centered .* oscillator;
clear centered oscillator sample_number

% A Hann-weighted fixed window strongly rejects the image at twice the
% carrier while retaining a deterministic, zero-delay offline aperture.
window_offset = (0:window_samples - 1).';
window_weight = 0.5 - 0.5 * cos(2 * pi * window_offset / ...
    (window_samples - 1));
window_weight = window_weight / sum(window_weight);
iq = complex(zeros(size(center_index)));
for k = 1:numel(center_index)
    index = center_index(k) + (-half_window:half_window).';
    iq(k) = sum(mixed(index) .* window_weight);
end
clear mixed

local_time_s = (double(center_index) - 1) / sample_rate_hz;
time_s = local_time_s + options.source_start_time_s;
phase_residual_cycles = unwrap(angle(iq)) / (2 * pi);
phase_cycles = carrier_frequency_hz * local_time_s + ...
    phase_residual_cycles;
if any(diff(phase_cycles) <= 0)
    error('reference_analysis:NonmonotonicReferencePhase', ...
        'Reconstructed reference phase is not strictly increasing.');
end

observation_dt_s = median(diff(time_s));
half_aperture_steps = max(1, round(0.5 * ...
    options.frequency_aperture_s / observation_dt_s));
frequency_hz = nan(size(phase_cycles));
first_frequency_index = 1 + half_aperture_steps;
last_frequency_index = numel(phase_cycles) - half_aperture_steps;
if first_frequency_index <= last_frequency_index
    use = (first_frequency_index:last_frequency_index).';
    left = use - half_aperture_steps;
    right = use + half_aperture_steps;
    frequency_hz(use) = (phase_cycles(right) - phase_cycles(left)) ./ ...
        (time_s(right) - time_s(left));
end

dense.schema_version = 1;
dense.method = 'symmetric Hann-window IQ with phase accumulation';
dense.reference_only = true;
dense.offline_zero_delay_window = true;
dense.posterior_peak_data_loaded = false;
dense.sample_rate_hz = sample_rate_hz;
dense.source_start_time_s = options.source_start_time_s;
dense.carrier_frequency_hz = carrier_frequency_hz;
dense.crossing_frequency_hz = crossing_frequency_hz;
dense.crossing_index = crossing_index;
dense.crossing_cycle = crossing_cycle;
dense.crossing_spacing_std_samples = spacing_std;
dense.observation_index = double(center_index);
dense.time_s = time_s;
dense.phase_cycles = phase_cycles;
dense.phase_residual_cycles = phase_residual_cycles;
dense.iq = iq;
dense.amplitude_codes = abs(iq);
dense.frequency_hz = frequency_hz;
dense.phase_coverage = isfinite(phase_cycles);
dense.frequency_coverage = isfinite(frequency_hz);
dense.observation_rate_hz = 1 / observation_dt_s;
dense.observation_step_samples = observation_step;
dense.iq_window_samples = window_samples;
dense.iq_window_s = window_samples / sample_rate_hz;
dense.frequency_aperture_steps = 2 * half_aperture_steps;
dense.frequency_aperture_s = 2 * half_aperture_steps * observation_dt_s;
end

function [crossing_index, crossing_cycle, frequency_hz, spacing_std] = ...
    positive_crossing_clock(centered, sample_rate_hz)
left = find(centered(1:end-1) <= 0 & centered(2:end) > 0);
denominator = centered(left + 1) - centered(left);
valid = denominator > 0;
left = left(valid);
fraction = -centered(left) ./ denominator(valid);
crossing_index = double(left) + fraction;
if numel(crossing_index) < 8
    error('reference_analysis:InsufficientZeroCrossings', ...
        'Fewer than eight positive reference crossings were detected.');
end
crossing_cycle = (0:numel(crossing_index) - 1).';
fit_value = polyfit(crossing_cycle, crossing_index, 1);
frequency_hz = sample_rate_hz / fit_value(1);
spacing_std = std(diff(crossing_index));
end
