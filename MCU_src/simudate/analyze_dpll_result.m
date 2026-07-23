function summary = analyze_dpll_result(result, make_plot)
%ANALYZE_DPLL_RESULT Summarize phase tracking and pulse interval prediction.

if nargin < 2
    make_plot = true;
end
trace = result.trace;
cfg = result.config;
phase_rad = double(trace.phase_error) * pi / 2^(cfg.phase_width - 1);
track_mask = trace.loop_state == 6;
if any(track_mask)
    tracked_phase = phase_rad(track_mask);
else
    tracked_phase = phase_rad;
end

summary.trace_samples = numel(trace.input_index);
summary.reached_track = any(track_mask);
summary.track_fraction = mean(track_mask);
summary.phase_rms_rad = rms_plain(tracked_phase);
summary.phase_peak_rad = max_abs_or_nan(tracked_phase);
summary.phase_mean_rad = mean_or_nan(tracked_phase);
summary.freq_error_rms_hz = rms_plain(double(trace.freq_error(track_mask_or_all(track_mask))) ...
    * cfg.input_sample_rate_hz / 2^26);
summary.final_tracking_frequency_hz = last_or_nan(trace.tracking_frequency_hz);
summary.cic_saturation_count = result.status.cic_saturation_count;
summary.iir_saturation_count = result.status.iir_saturation_count;
summary.controller_saturation_count = ...
    result.status.controller_saturation_high_count + ...
    result.status.controller_saturation_low_count;
summary.posterior_interval_data_used = result.metadata.posterior_interval_data_used;
if isempty(result.events.identity_error_samples)
    summary.pulse_event_count = numel(result.events.event_time_s);
    summary.interval_identity_max_error_samples = NaN;
    summary.predicted_interval_error_rms_samples = NaN;
else
    summary.pulse_event_count = numel(result.events.event_time_s);
    summary.interval_identity_max_error_samples = ...
        max(abs(result.events.identity_error_samples));
    summary.predicted_interval_error_rms_samples = ...
        rms_plain(result.events.predicted_interval_error);
end

if make_plot
    figure('Name', 'DPLL replay diagnostics', 'Color', 'w');
    tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    nexttile;
    plot(trace.time_s, phase_rad, 'LineWidth', 0.8);
    hold on;
    yline(double(cfg.phase_threshold) * pi / 2^(cfg.phase_width - 1), '--');
    yline(-double(cfg.phase_threshold) * pi / 2^(cfg.phase_width - 1), '--');
    ylabel('phase error (rad)'); grid on;
    title('DPLL replay: phase residual and control behavior');

    nexttile;
    plot(trace.time_s, double(trace.freq_error) * cfg.input_sample_rate_hz / 2^26);
    ylabel('freq error (Hz)'); grid on;

    nexttile;
    yyaxis left;
    plot(trace.time_s, trace.tracking_frequency_hz);
    ylabel('tracking f (Hz)');
    yyaxis right;
    stairs(trace.time_s, double(trace.loop_state));
    ylabel('loop state'); grid on;

    nexttile;
    if isempty(result.events.predicted_interval_error)
        plot(NaN, NaN);
    else
        plot(result.events.event_time_s(2:end), ...
            result.events.predicted_interval_error, 'o-', 'MarkerSize', 3);
    end
    xlabel('time (s)'); ylabel('interval error (samples)'); grid on;
end
end

function value = rms_plain(x)
if isempty(x)
    value = NaN;
else
    value = sqrt(mean(double(x).^2));
end
end

function mask = track_mask_or_all(track_mask)
if any(track_mask)
    mask = track_mask;
else
    mask = true(size(track_mask));
end
end

function value = max_abs_or_nan(x)
if isempty(x), value = NaN; else, value = max(abs(x)); end
end

function value = mean_or_nan(x)
if isempty(x), value = NaN; else, value = mean(x); end
end

function value = last_or_nan(x)
if isempty(x), value = NaN; else, value = x(end); end
end
