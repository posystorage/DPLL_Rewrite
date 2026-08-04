function estimate = estimate_local_sinusoid_phase( ...
    codes, query_index, sample_rate_hz, carrier_frequency_hz, window_cycles)
%ESTIMATE_LOCAL_SINUSOID_PHASE Symmetric weighted local sine/cosine phase fit.

if nargin < 5, window_cycles = 8; end
codes = double(codes(:));
query_index = double(query_index(:));
validateattributes(sample_rate_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(carrier_frequency_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(window_cycles, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 2});

half_window = max(8, round(0.5 * window_cycles * ...
    sample_rate_hz / carrier_frequency_hz));
phase_wrapped_cycles = nan(size(query_index));
amplitude = nan(size(query_index));
fit_rms = nan(size(query_index));
valid = false(size(query_index));

for k = 1:numel(query_index)
    query = query_index(k);
    center = round(query);
    first = center - half_window;
    last = center + half_window;
    if first < 1 || last > numel(codes)
        continue;
    end
    index = (first:last).';
    relative_time = (index - query) / sample_rate_hz;
    normalized = relative_time / max(abs(relative_time));
    weight = 0.5 + 0.5 * cos(pi * normalized);
    cosine = cos(2 * pi * carrier_frequency_hz * relative_time);
    sine = sin(2 * pi * carrier_frequency_hz * relative_time);
    design = [cosine, sine, ones(size(index)), relative_time];
    root_weight = sqrt(weight);
    weighted_design = design .* root_weight;
    weighted_codes = codes(index) .* root_weight;
    coefficient = weighted_design \ weighted_codes;
    fitted = design * coefficient;
    residual = codes(index) - fitted;

    phase_wrapped_cycles(k) = atan2(-coefficient(2), coefficient(1)) / ...
        (2 * pi);
    amplitude(k) = hypot(coefficient(1), coefficient(2));
    fit_rms(k) = sqrt(sum(weight .* residual.^2) / sum(weight));
    valid(k) = true;
end

base_cycles = carrier_frequency_hz * (query_index - 1) / sample_rate_hz;
wrapped_residual = mod(phase_wrapped_cycles - base_cycles + 0.5, 1) - 0.5;
phase_cycles = nan(size(query_index));
valid_index = find(valid);
if ~isempty(valid_index)
    [~, order] = sort(query_index(valid_index));
    ordered_index = valid_index(order);
    unwrapped = unwrap(2 * pi * wrapped_residual(ordered_index)) / (2 * pi);
    phase_cycles(ordered_index) = base_cycles(ordered_index) + unwrapped;
end

estimate.method = 'symmetric local sinusoid least-squares fit';
estimate.query_index = query_index;
estimate.phase_cycles = phase_cycles;
estimate.phase_rad = 2 * pi * phase_cycles;
estimate.amplitude_codes = amplitude;
estimate.fit_rms_codes = fit_rms;
estimate.coverage = valid & isfinite(phase_cycles);
estimate.carrier_frequency_hz = carrier_frequency_hz;
estimate.window_cycles = window_cycles;
estimate.window_samples = 2 * half_window + 1;
end
