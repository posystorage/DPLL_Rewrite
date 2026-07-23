function [state, output] = hybrid_loop_step(state, phase_error, freq_error, control, cfg)
%HYBRID_LOOP_STEP Fixed-point FLL+PI update on one usable FLL replay.

if isempty(state)
    state.freq_state = int64(0);
end
fll_term = int64(0);
i_term = int64(0);
p_term = int64(0);
if control.enable_fll
    fll_term = dpll.arshift(int64(freq_error) * control.kf, cfg.shifts.fll_product);
end
if control.enable_pll_i
    i_term = dpll.arshift(int64(phase_error) * control.ki, cfg.shifts.i_product);
end
if control.enable_pll_p
    p_term = dpll.arshift(int64(phase_error) * control.kp, cfg.shifts.p_product);
end

state_sum = state.freq_state + fll_term + i_term;
new_state = min(max(state_sum, cfg.negative_limit), cfg.positive_limit);
push_high = state.freq_state >= cfg.positive_limit && (fll_term + i_term) > 0;
push_low = state.freq_state <= cfg.negative_limit && (fll_term + i_term) < 0;
if ~(push_high || push_low)
    state.freq_state = new_state;
end
correction_sum = state.freq_state + p_term;
freq_correction = min(max(correction_sum, cfg.negative_limit), cfg.positive_limit);
tracking_signed = int64(cfg.center_word) + freq_correction;
tracking_signed = min(max(tracking_signed, int64(0)), int64(2^48 - 1));

output.freq_state = state.freq_state;
output.freq_correction = freq_correction;
output.tracking_word = uint64(tracking_signed);
output.fll_term = fll_term;
output.i_term = i_term;
output.p_term = p_term;
output.saturated_high = state_sum > cfg.positive_limit || correction_sum > cfg.positive_limit;
output.saturated_low = state_sum < cfg.negative_limit || correction_sum < cfg.negative_limit;
end
