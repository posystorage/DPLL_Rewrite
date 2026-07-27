function summary = analyze_dpll_result(result, make_plot)
%ANALYZE_DPLL_RESULT Summarize internal PLL behavior without peak posterior.

if nargin < 2, make_plot = true; end
trace = result.trace;
cfg = result.config;
phase_rad = double(trace.phase_error) * pi / 2^(cfg.phase_width - 1);
valid = trace.analysis_valid;
if ~any(valid), valid = trace.loop_state == 6; end
if ~any(valid), valid = true(size(trace.loop_state)); end

summary.trace_samples = numel(trace.input_index);
summary.analysis_trace_samples = nnz(valid);
summary.reached_track = any(trace.loop_state == 6);
summary.track_fraction = mean(trace.loop_state == 6);
summary.phase_rms_rad = rms_plain(phase_rad(valid));
summary.phase_peak_rad = max(abs(phase_rad(valid)));
summary.phase_mean_rad = mean(phase_rad(valid));
summary.freq_error_rms_hz = rms_plain(double(trace.freq_error(valid)) ...
    * cfg.input_sample_rate_hz / 2^26);
summary.final_tracking_frequency_hz = trace.tracking_frequency_hz(end);
summary.cic_saturation_count = result.status.cic_saturation_count;
summary.iir_saturation_count = result.status.iir_saturation_count;
summary.analysis_cic_saturation_count = nnz(trace.cic_saturated & valid);
summary.analysis_cic_saturation_rate = ...
    summary.analysis_cic_saturation_count / max(1, nnz(valid));
summary.analysis_iir_saturation_count = nnz(trace.iir_saturated & valid);
summary.cordic_out_of_range_count = result.status.cordic_out_of_range_count;
summary.analysis_cordic_out_of_range_count = ...
    nnz(trace.cordic_out_of_range & valid);
summary.analysis_cordic_out_of_range_rate = ...
    summary.analysis_cordic_out_of_range_count / max(1, nnz(valid));
summary.controller_saturation_count = ...
    result.status.controller_saturation_high_count + ...
    result.status.controller_saturation_low_count;
summary.posterior_interval_data_used = result.metadata.posterior_interval_data_used;

if make_plot
    figure('Name', 'DPLL replay diagnostics (no peak posterior)', 'Color', 'w');
    tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    nexttile;
    plot(trace.time_s, phase_rad, 'LineWidth', 0.8); hold on;
    yline(double(cfg.phase_threshold) * pi / 2^(cfg.phase_width - 1), '--');
    yline(-double(cfg.phase_threshold) * pi / 2^(cfg.phase_width - 1), '--');
    xline(double(result.metadata.analysis_start_raw_index - 1) / ...
        result.metadata.source_raw_sample_rate_hz, ':');
    ylabel('phase error (rad)'); grid on;
    title(sprintf('DPLL replay: %s startup, peak posterior not loaded', ...
        result.metadata.startup_mode));

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
    plot(trace.time_s, double(trace.p_term), 'DisplayName', 'P'); hold on;
    plot(trace.time_s, double(trace.i_term), 'DisplayName', 'I');
    plot(trace.time_s, double(trace.fll_term), 'DisplayName', 'FLL');
    xlabel('time (s)'); ylabel('word increment'); grid on; legend('Location', 'best');
end
end

function value = rms_plain(x)
if isempty(x), value = NaN; else, value = sqrt(mean(double(x).^2)); end
end
