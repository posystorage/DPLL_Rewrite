function [result, summary] = run_dpll_replay(input_mat_path, output_mat_path, cfg)
%RUN_DPLL_REPLAY Load, simulate, analyze, and optionally save a replay.
%
% Example:
%   cfg = dpll_current_config(20000);
%   [result, summary] = run_dpll_replay("capture.mat", "replay.mat", cfg);

arguments
    input_mat_path (1,1) string
    output_mat_path (1,1) string = ""
    cfg struct = dpll_current_config()
end

input_data = load_input_mat(input_mat_path);
result = simulate_dpll(input_data, cfg);
summary = analyze_dpll_result(result, true);
if strlength(output_mat_path) > 0
    save(output_mat_path, 'result', 'summary', '-v7.3');
end

fprintf('DPLL replay complete: %d IQ events, TRACK=%d, phase RMS=%.6g rad\n', ...
    summary.trace_samples, summary.reached_track, summary.phase_rms_rad);
fprintf('Pulse events=%d, interval identity max error=%.6g samples\n', ...
    summary.pulse_event_count, summary.interval_identity_max_error_samples);
end
