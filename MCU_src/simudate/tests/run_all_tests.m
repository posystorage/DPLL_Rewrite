function run_all_tests()
%RUN_ALL_TESTS Run unit and closed-loop smoke tests without toolboxes.

test_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(test_dir);
addpath(root_dir, test_dir);
test_fixed_helpers();
test_hybrid_loop();
test_phase_2p2z();
test_experiment_helpers();
test_reference_phase_estimators();
test_real_data_interface();
result = test_replay_smoke();
exact_cycle = validate_exact_reference_cycle_events(result, 0.005);
assert(~exact_cycle.posterior_peak_data_loaded);
assert(all(isfinite(exact_cycle.pll_residual_error)));
assert(max(abs(exact_cycle.pll_residual_error - ...
    exact_cycle.equivalent_interval_error_cycles)) < 0.01);
assert(height(exact_cycle.segment_metrics) == ...
    min(4, numel(exact_cycle.pll_residual_error)));
test_peak_validation_boundary(result);
fprintf('PASS: DPLL MATLAB replay tests (%d IQ samples, final state %d).\n', ...
    numel(result.phase_error), result.loop_state(end));
end
