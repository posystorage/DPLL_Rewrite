function initial = estimate_prelock(codes, sample_rate_hz, cfg)
%ESTIMATE_PRELOCK Estimate only the initial NCO frequency and phase.
%
% This uses the PLL reference channel only. No pulse data is accepted.

estimate_count = min(numel(codes), max(1000, ...
    round(cfg.startup.frequency_estimation_duration_s * sample_rate_hz)));
x = double(codes(1:estimate_count));
x = x - mean(x);
crossing_left = find(x(1:end-1) <= 0 & x(2:end) > 0);
if numel(crossing_left) < 8
    error('dpll:PrelockEstimateFailed', ...
        'Too few positive reference zero crossings in the estimation prefix.');
end
fraction = -x(crossing_left) ./ ...
    (x(crossing_left + 1) - x(crossing_left));
crossing = double(crossing_left) + fraction;
cycle_number = (0:numel(crossing)-1).';
fit_coeff = polyfit(cycle_number, crossing, 1);
period_samples = fit_coeff(1);
frequency_hz = sample_rate_hz / period_samples;

% Positive sine zero crossing corresponds to phase zero. Fit the crossing
% sequence back to cycle zero to reduce sensitivity to the first crossing.
crossing_cycle_zero = fit_coeff(2);
phase_rad = mod(-2 * pi * (crossing_cycle_zero - 1) / period_samples, 2 * pi);
tracking_word = uint64(round(frequency_hz / cfg.fabric_clock_hz * 2^cfg.word_width));
phase_accumulator = uint64(round(phase_rad / (2 * pi) * 2^cfg.word_width));
phase_accumulator = mod(phase_accumulator, uint64(2^cfg.word_width));
freq_state = int64(tracking_word) - int64(cfg.center_word);
if freq_state > cfg.positive_limit || freq_state < cfg.negative_limit
    error('dpll:PrelockOutsideCorrectionLimit', ...
        'Estimated %.6f Hz lies outside the configured correction range.', frequency_hz);
end

initial.frequency_hz = frequency_hz;
initial.period_samples = period_samples;
initial.phase_rad = phase_rad;
initial.phase_accumulator = phase_accumulator;
initial.tracking_word = tracking_word;
initial.freq_state = freq_state;
initial.estimation_sample_count = estimate_count;
initial.zero_crossing_count = numel(crossing);
end
