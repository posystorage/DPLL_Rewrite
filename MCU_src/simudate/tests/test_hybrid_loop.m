function test_hybrid_loop()
cfg = dpll_current_config(20000);
control.enable_fll = false;
control.enable_pll_i = true;
control.enable_pll_p = true;
control.kf = int64(0);
control.ki = int64(2500000);
control.kp = int64(6000000);
[state, output] = dpll.hybrid_loop_step([], int64(1000), int64(0), control, cfg);
assert(output.i_term == dpll.arshift(int64(1000) * control.ki, 18));
assert(output.p_term == dpll.arshift(int64(1000) * control.kp, 12));
assert(state.freq_state > 0);
assert(output.tracking_word > cfg.center_word);
end
