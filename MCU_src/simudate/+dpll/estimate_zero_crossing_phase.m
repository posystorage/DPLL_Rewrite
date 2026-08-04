function estimate = estimate_zero_crossing_phase(codes, query_index, sample_rate_hz)
%ESTIMATE_ZERO_CROSSING_PHASE Interpolate a monotonic phase from positive crossings.

codes = double(codes(:));
query_index = double(query_index(:));
validateattributes(sample_rate_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
if numel(codes) < 16
    error('dpll:InsufficientPhaseInput', ...
        'At least 16 samples are required for zero-crossing phase.');
end

centered = codes - median(codes);
left = find(centered(1:end-1) <= 0 & centered(2:end) > 0);
denominator = centered(left + 1) - centered(left);
valid = denominator > 0;
left = left(valid);
fraction = -centered(left) ./ denominator(valid);
crossing_index = double(left) + fraction;
if numel(crossing_index) < 8
    error('dpll:InsufficientZeroCrossings', ...
        'Fewer than eight positive zero crossings were detected.');
end

crossing_cycle = (0:numel(crossing_index) - 1).';
phase_cycles = interp1(crossing_index, crossing_cycle, ...
    query_index, 'pchip', NaN);
fit_value = polyfit(crossing_cycle, crossing_index, 1);
spacing = diff(crossing_index);

estimate.method = 'positive zero-crossing interpolation';
estimate.query_index = query_index;
estimate.phase_cycles = phase_cycles;
estimate.phase_rad = 2 * pi * phase_cycles;
estimate.crossing_index = crossing_index;
estimate.crossing_cycle = crossing_cycle;
estimate.period_samples = fit_value(1);
estimate.carrier_frequency_hz = sample_rate_hz / fit_value(1);
estimate.crossing_spacing_mean = mean(spacing);
estimate.crossing_spacing_std = std(spacing);
estimate.coverage = isfinite(phase_cycles);
end
