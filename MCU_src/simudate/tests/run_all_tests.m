function run_all_tests()
%RUN_ALL_TESTS Run unit and closed-loop smoke tests without toolboxes.

test_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(test_dir);
addpath(root_dir, test_dir);
test_fixed_helpers();
test_hybrid_loop();
test_real_data_interface();
result = test_replay_smoke();
test_peak_validation_boundary(result);
fprintf('PASS: DPLL MATLAB replay tests (%d IQ samples, final state %d).\n', ...
    numel(result.phase_error), result.loop_state(end));
end
