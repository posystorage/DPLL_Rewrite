function [frequency_hz, psd_per_hz] = welch_psd(values, sample_rate_hz)
%WELCH_PSD Toolbox-free one-sided Welch power spectral density estimate.

values = double(values(:));
values = values(isfinite(values));
if numel(values) < 32
    error('dpll:InsufficientPsdSamples', ...
        'At least 32 finite samples are required for a PSD estimate.');
end

segment_length = min(131072, 2^floor(log2(numel(values))));
segment_length = max(32, segment_length);
step = max(1, floor(segment_length / 2));
nfft = segment_length;
n = (0:segment_length-1).';
window = 0.5 - 0.5 * cos(2 * pi * n / segment_length);
window_power = sum(window.^2);
starts = 1:step:(numel(values) - segment_length + 1);
accumulator = zeros(nfft / 2 + 1, 1);

for k = 1:numel(starts)
    segment = values(starts(k):starts(k) + segment_length - 1);
    segment = segment - mean(segment);
    spectrum = fft(segment .* window, nfft);
    periodogram = abs(spectrum(1:nfft / 2 + 1)).^2 / ...
        (sample_rate_hz * window_power);
    if nfft > 2
        periodogram(2:end-1) = 2 * periodogram(2:end-1);
    end
    accumulator = accumulator + periodogram;
end

psd_per_hz = accumulator / numel(starts);
frequency_hz = (0:nfft / 2).' * sample_rate_hz / nfft;
end
