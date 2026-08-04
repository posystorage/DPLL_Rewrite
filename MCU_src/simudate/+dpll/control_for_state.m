function control = control_for_state(state, cfg)
%CONTROL_FOR_STATE Decode loop-state enables and active gains.

control.enable_fll = false;
control.enable_fll_feedforward = false;
control.enable_phase_2p2z = false;
control.enable_pll_i = false;
control.enable_pll_p = false;
control.kf = int64(0);
control.kff = int64(0);
control.ki = int64(0);
control.kp = int64(0);
switch double(state.loop_state)
    case {4, 8}
        control.enable_fll = true;
        control.kf = cfg.gains.kf_acquire;
    case 5
        control.enable_fll = true;
        control.enable_pll_i = true;
        control.enable_pll_p = true;
        control.kf = cfg.gains.kf_blend;
        control.ki = cfg.gains.ki_blend;
        control.kp = cfg.gains.kp_blend;
    case 6
        control.enable_fll = true;
        control.enable_fll_feedforward = cfg.architecture.fll_feedforward_enable;
        control.enable_phase_2p2z = cfg.architecture.phase_2p2z_enable;
        control.enable_pll_i = true;
        control.enable_pll_p = true;
        control.kf = cfg.gains.kf_track;
        control.kff = cfg.gains.kff_track;
        control.ki = cfg.gains.ki_track;
        control.kp = cfg.gains.kp_track;
end
end
