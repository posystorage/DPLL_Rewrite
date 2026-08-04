function test_hybrid_loop()
cfg = dpll_current_config(20000);
control.enable_fll = false;
control.enable_fll_feedforward = false;
control.enable_phase_2p2z = false;
control.enable_pll_i = true;
control.enable_pll_p = true;
control.kf = int64(0);
control.kff = int64(0);
control.ki = int64(2500000);
control.kp = int64(6000000);
[state, output] = dpll.hybrid_loop_step([], int64(1000), int64(0), control, cfg);
assert(output.i_term == dpll.arshift(int64(1000) * control.ki, 18));
assert(output.p_term == dpll.arshift(int64(1000) * control.kp, 12));
assert(state.freq_state > 0);
assert(output.tracking_word > cfg.center_word);

control.enable_pll_i = false;
control.enable_pll_p = false;
control.enable_fll_feedforward = true;
control.kff = cfg.gains.kff_track;
[~, feedforward] = dpll.hybrid_loop_step([], int64(0), int64(100), control, cfg);
expected_ff = dpll.arshift(int64(100) * control.kff, cfg.shifts.ff_product);
assert(feedforward.ff_term == expected_ff);
assert(feedforward.freq_state == 0, ...
    'Direct FLL feedforward must not enter the integral state.');
assert(feedforward.freq_correction == expected_ff);

cfg.architecture.phase_lead_samples = 8;
predicted = dpll.phase_lead_predict(int64(1000), int64(160), cfg);
assert(predicted == 1080);
end
