function estimate = estimate_fft_analytic_phase( ...
    codes, query_index, sample_rate_hz, carrier_frequency_hz, half_bandwidth_hz)
%ESTIMATE_FFT_ANALYTIC_PHASE Zero-phase positive-frequency band extraction.

if nargin < 5, half_bandwidth_hz = 500; end
codes = double(codes(:));
query_index = double(query_index(:));
validateattributes(half_bandwidth_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
if carrier_frequency_hz - 1.25 * half_bandwidth_hz <= 0 || ...
        carrier_frequency_hz + 1.25 * half_bandwidth_hz >= sample_rate_hz / 2
    error('dpll:InvalidAnalyticBand', ...
        'The analytic band must remain inside (0, Nyquist).');
end

sample_count = numel(codes);
centered = codes - mean(codes);
spectrum = fft(centered);
frequency_hz = (0:sample_count - 1).' * sample_rate_hz / sample_count;
distance = abs(frequency_hz - carrier_frequency_hz);
transition = max(25, 0.25 * half_bandwidth_hz);
weight = zeros(sample_count, 1);
weight(distance <= half_bandwidth_hz) = 1;
taper = distance > half_bandwidth_hz & ...
    distance < half_bandwidth_hz + transition;
weight(taper) = 0.5 * (1 + cos(pi * ...
    (distance(taper) - half_bandwidth_hz) / transition));
analytic = ifft(spectrum .* (2 * weight));
clear spectrum weight

phase_cycles_all = unwrap(angle(analytic)) / (2 * pi);
phase_cycles = interp1((1:sample_count).', phase_cycles_all, ...
    query_index, 'linear', NaN);
amplitude = interp1((1:sample_count).', abs(analytic), ...
    query_index, 'linear', NaN);
valid = isfinite(phase_cycles);
if nnz(valid) >= 3
    fit_value = polyfit((query_index(valid) - 1) / sample_rate_hz, ...
        phase_cycles(valid), 1);
    estimated_frequency_hz = fit_value(1);
else
    estimated_frequency_hz = NaN;
end

estimate.method = 'zero-phase FFT analytic band';
estimate.query_index = query_index;
estimate.phase_cycles = phase_cycles;
estimate.phase_rad = 2 * pi * phase_cycles;
estimate.amplitude_codes = amplitude;
estimate.coverage = valid;
estimate.carrier_frequency_hz = estimated_frequency_hz;
estimate.band_center_hz = carrier_frequency_hz;
estimate.half_bandwidth_hz = half_bandwidth_hz;
estimate.transition_hz = transition;
end
