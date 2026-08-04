function validation = validate_peak_alignment(result, peak_mat_path, make_plot)
%VALIDATE_PEAK_ALIGNMENT Posterior-only 62.5 MHz peak validation.
%
% This function is deliberately separate from simulate_dpll. Calling it
% loads the hidden samplingPeakDistance vector and must happen only after
% PLL parameters and the replay result have been frozen.

if nargin < 3, make_plot = true; end
if result.metadata.posterior_interval_data_used
    error('dpll:PosteriorContamination', ...
        'Replay result is already marked as posterior-contaminated.');
end
raw = load(peak_mat_path, 'channel1SampleRate', ...
    'samplingPeakFirstLocation', 'samplingPeakMeanDistance', ...
    'samplingPeakDistance');
required = {'channel1SampleRate', 'samplingPeakFirstLocation', ...
    'samplingPeakMeanDistance', 'samplingPeakDistance'};
if ~all(isfield(raw, required))
    error('dpll:MissingPeakValidation', 'Peak validation file is incomplete.');
end
if double(raw.channel1SampleRate) ~= result.metadata.source_raw_sample_rate_hz
    error('dpll:PeakTimebaseMismatch', 'Peak validation timebase does not match replay.');
end
distances = double(raw.samplingPeakDistance(:));
if any(~isfinite(distances) | distances <= 0)
    error('dpll:InvalidPeakDistance', 'samplingPeakDistance must be positive and finite.');
end
peak_raw = double(raw.samplingPeakFirstLocation) + [0; cumsum(distances)];
coverage = peak_raw >= result.metadata.analysis_start_raw_index & ...
    peak_raw <= result.metadata.source_raw_last_mapped_index;
peak_raw = peak_raw(coverage);
if numel(peak_raw) < 3
    error('dpll:InsufficientValidationPeaks', ...
        'Fewer than three posterior peaks remain in the replay analysis range.');
end

peak_tick = (peak_raw - 1) * ...
    (result.config.fabric_clock_hz / result.metadata.source_raw_sample_rate_hz);
output_cycles = integrate_word_history(result.word_history, peak_tick, ...
    result.config.pulse.output_multiplier, result.config.word_width);
recovered_interval = diff(output_cycles);
fixed_interval = diff(peak_raw);
ideal_interval = result.config.pulse.reference_cycles_per_pulse * ...
    result.config.pulse.output_multiplier;
recovered_error = recovered_interval - ideal_interval;
prior_mean_interval = double(raw.samplingPeakMeanDistance);
fixed_to_output_scale = ideal_interval / prior_mean_interval;
uncompensated_error = fixed_interval * fixed_to_output_scale - ideal_interval;
compensated_component = uncompensated_error - recovered_error;
unwrapped_sampling_phase_error = [0; cumsum(recovered_error)];
relative_cycles = output_cycles - output_cycles(1);
sampling_phase_error_cycles = mod(relative_cycles + 0.5, 1) - 0.5;

if isfield(result.config, 'validation') && ...
        isfield(result.config.validation, 'slow_window_pulses')
    configured_slow_window = result.config.validation.slow_window_pulses;
else
    configured_slow_window = 21;
end
slow_window = min(configured_slow_window, numel(recovered_error));
slow_window = max(3, slow_window);
slow_uncompensated = movmean(uncompensated_error, slow_window, ...
    'Endpoints', 'shrink');
slow_recovered = movmean(recovered_error, slow_window, 'Endpoints', 'shrink');
fast_uncompensated = uncompensated_error - slow_uncompensated;
fast_recovered = recovered_error - slow_recovered;

validation.metadata.posterior_data_used = true;
validation.metadata.replay_source_file = result.metadata.source_file;
validation.metadata.peak_source_file = char(peak_mat_path);
validation.metadata.raw_sample_rate_hz = double(raw.channel1SampleRate);
validation.metadata.output_multiplier = result.config.pulse.output_multiplier;
validation.metadata.reference_cycles_per_pulse = ...
    result.config.pulse.reference_cycles_per_pulse;
validation.metadata.ideal_output_interval = ideal_interval;
validation.metadata.fixed_clock_scale_source = ...
    'supplied samplingPeakMeanDistance prior';
validation.metadata.prior_mean_interval_raw_samples = prior_mean_interval;
validation.peak_raw_index = peak_raw;
validation.peak_time_s = (peak_raw - 1) / double(raw.channel1SampleRate);
validation.fixed_interval_raw_samples = fixed_interval;
validation.fixed_interval_centered = fixed_interval - prior_mean_interval;
validation.fixed_to_output_scale = fixed_to_output_scale;
validation.uncompensated_interval_error_output_cycles = uncompensated_error;
validation.output_cycles_at_peak = output_cycles;
validation.recovered_interval_output_cycles = recovered_interval;
validation.recovered_interval_error = recovered_error;
validation.compensated_component_output_cycles = compensated_component;
validation.recovered_minus_uncompensated = ...
    recovered_error - uncompensated_error;
validation.unwrapped_sampling_phase_error_cycles = ...
    unwrapped_sampling_phase_error;
validation.sampling_phase_error_cycles = sampling_phase_error_cycles;
validation.slow.window_pulses = slow_window;
validation.slow.uncompensated_error = slow_uncompensated;
validation.slow.recovered_error = slow_recovered;
validation.fast.uncompensated_error = fast_uncompensated;
validation.fast.recovered_error = fast_recovered;
validation.summary.peak_count = numel(peak_raw);
validation.summary.interval_count = numel(recovered_interval);
validation.summary.fixed_interval_std_samples = std(fixed_interval);
validation.summary.fixed_interval_mean_samples = mean(fixed_interval);
validation.summary.prior_mean_interval_samples = prior_mean_interval;
validation.summary.covered_mean_minus_prior_samples = ...
    mean(fixed_interval) - prior_mean_interval;
validation.summary.recovered_interval_mean = mean(recovered_interval);
validation.summary.recovered_interval_rms_error = rms_plain(recovered_error);
validation.summary.recovered_interval_std = std(recovered_interval);
validation.summary.recovered_interval_peak_to_peak = ...
    max(recovered_interval) - min(recovered_interval);
validation.summary.sampling_phase_rms_cycles = rms_plain(sampling_phase_error_cycles);
validation.summary.uncompensated_error_std = std(uncompensated_error);
validation.summary.total_error_std_ratio = ...
    safe_ratio(std(recovered_error), std(uncompensated_error));
validation.summary.slow_window_pulses = slow_window;
validation.summary.slow_uncompensated_std = std(slow_uncompensated);
validation.summary.slow_recovered_std = std(slow_recovered);
validation.summary.slow_residual_ratio = ...
    safe_ratio(std(slow_recovered), std(slow_uncompensated));
validation.summary.slow_suppression_db = ...
    ratio_to_db(validation.summary.slow_residual_ratio);
validation.summary.fast_uncompensated_std = std(fast_uncompensated);
validation.summary.fast_recovered_std = std(fast_recovered);
validation.summary.fast_residual_ratio = ...
    safe_ratio(std(fast_recovered), std(fast_uncompensated));
validation.summary.fast_suppression_db = ...
    ratio_to_db(validation.summary.fast_residual_ratio);
index = (1:numel(recovered_error)).';
uncompensated_trend = polyfit(index, uncompensated_error, 1);
recovered_trend = polyfit(index, recovered_error, 1);
validation.summary.uncompensated_trend_per_pulse = uncompensated_trend(1);
validation.summary.recovered_trend_per_pulse = recovered_trend(1);
validation.summary.trend_residual_ratio = ...
    safe_ratio(abs(recovered_trend(1)), abs(uncompensated_trend(1)));

if make_plot
    plot_peak_alignment_validation(validation, 'on');
end
end

function cycles = integrate_word_history(history, query_tick, multiplier, word_width)
ticks = double(history.fabric_tick(:));
words = double(history.tracking_word(:));
if isempty(ticks) || ticks(1) > min(query_tick)
    error('dpll:WordHistoryCoverage', 'Tracking-word history does not cover peaks.');
end
% Collapse same-tick commands; the last assignment wins as in RTL registers.
[unique_ticks, last_index] = unique(ticks, 'last');
words = words(last_index);
ticks = unique_ticks;
segment_cycles = diff(ticks) .* words(1:end-1) * multiplier / 2^word_width;
cumulative = [0; cumsum(segment_cycles)];
cycles = zeros(size(query_tick));
for k = 1:numel(query_tick)
    index = find(ticks <= query_tick(k), 1, 'last');
    if isempty(index)
        error('dpll:WordHistoryCoverage', 'Peak precedes tracking-word history.');
    end
    cycles(k) = cumulative(index) + ...
        (query_tick(k) - ticks(index)) * words(index) * multiplier / 2^word_width;
end
end

function value = rms_plain(x)
value = sqrt(mean(double(x).^2));
end

function value = safe_ratio(numerator, denominator)
if denominator == 0, value = NaN; else, value = numerator / denominator; end
end

function value = ratio_to_db(ratio)
if ~isfinite(ratio) || ratio <= 0, value = NaN; ...
else, value = 20 * log10(ratio); end
end
