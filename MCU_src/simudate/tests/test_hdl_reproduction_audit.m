function test_hdl_reproduction_audit()
%TEST_HDL_REPRODUCTION_AUDIT Freeze negative controls and isolation guards.

candidates = build_hdl_reproduction_candidates(20000);
assert(numel(candidates) == 4);
assert(strcmp(candidates(1).id, 'rtl_reset_detector_p12'));
assert(strcmp(candidates(2).id, 'arm_operating_profile_p12'));
assert(strcmp(candidates(3).id, 'register_optimized_p12'));
assert(strcmp(candidates(4).id, 'optimized_p8_no_2p2z'));
assert(all(arrayfun(@(x) ...
    ~x.cfg.architecture.phase_2p2z_enable, candidates)));

literal = candidates(1).cfg;
assert(literal.cic.rate == 31 && literal.cic.output_shift == 10);
assert(literal.shifts.p_product == 12);
assert(literal.iir.track_cutoff_hz == 8000);
assert(literal.iir.track.b0 == 48851600);
assert(literal.iir.track.a1 == -1409400772);

arm = candidates(2).cfg;
assert(arm.cic.rate == 16 && arm.cic.output_shift == 8);
assert(arm.iir.track_cutoff_hz == 2000);
assert(arm.shifts.p_product == 12);
assert(arm.gains.kp_track == 6000000);
assert(arm.gains.ki_track == 180000);

p12 = candidates(3).cfg;
p8 = candidates(4).cfg;
assert(p12.cic.rate == 16 && p8.cic.rate == 16);
assert(p12.cic.output_shift == 9 && p8.cic.output_shift == 9);
assert(p12.iir.track_cutoff_hz == 8000 && ...
    p8.iir.track_cutoff_hz == 8000);
assert(p12.gains.kp_track == p8.gains.kp_track);
assert(p12.gains.ki_track == p8.gains.ki_track);
assert(p12.shifts.p_product == 12 && p8.shifts.p_product == 8);
assert(p12.gains.kp_blend == 6000000);
assert(p8.gains.kp_blend == 375000);

root = fileparts(fileparts(mfilename('fullpath')));
audit_source = fileread(fullfile(root, 'run_hdl_reproduction_audit.m'));
launcher_source = fileread(fullfile(root, ...
    'start_dpll_hdl_reproduction_audit.m'));
simulate_position = strfind(audit_source, 'result = simulate_dpll');
posterior_position = strfind(audit_source, 'run_peak_validation');
freeze_position = strfind(audit_source, 'hdl_audit_freeze.mat');
assert(~isempty(simulate_position) && ~isempty(posterior_position));
assert(simulate_position(1) < posterior_position(1));
assert(freeze_position(1) < posterior_position(1));
assert(~contains(audit_source, 'run_real_data_replay'));
assert(~contains(audit_source, 'bar('));
assert(contains(audit_source, ...
    'posterior_peak_data_used_for_control = false'));
assert(contains(audit_source, ...
    'posterior_peak_data_used_for_selection = false'));
assert(contains(audit_source, 'preregistered_hypotheses'));
assert(contains(launcher_source, 'run_hdl_reproduction_audit'));
assert(contains(launcher_source, "'hdl_reproduction_audit', resultTag"));
end
