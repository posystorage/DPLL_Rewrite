function [state, output] = hybrid_loop_step(state, phase_error, freq_error, control, cfg)
%HYBRID_LOOP_STEP Fixed-point FLL+PI update on one usable FLL replay.

if isempty(state)
    state.freq_state = int64(0);
end
if ~isfield(state, 'phase_2p2z')
    state.phase_2p2z = [];
end
fll_term = int64(0);
i_term = int64(0);
p_term = int64(0);
ff_term = int64(0);
phase_2p2z_term = int64(0);
phase_2p2z_output = empty_2p2z_output();
if control.enable_fll
    fll_term = dpll.arshift(int64(freq_error) * control.kf, cfg.shifts.fll_product);
end
if control.enable_pll_i
    i_term = dpll.arshift(int64(phase_error) * control.ki, cfg.shifts.i_product);
end
if control.enable_pll_p
    p_term = dpll.arshift(int64(phase_error) * control.kp, cfg.shifts.p_product);
end
if control.enable_fll_feedforward
    ff_term = dpll.arshift(int64(freq_error) * control.kff, cfg.shifts.ff_product);
end
if isfield(control, 'enable_phase_2p2z') && control.enable_phase_2p2z
    [state.phase_2p2z, phase_2p2z_output] = dpll.fixed_2p2z_step( ...
        state.phase_2p2z, phase_error, cfg.phase_2p2z);
    phase_2p2z_term = phase_2p2z_output.value;
elseif cfg.phase_2p2z.reset_when_disabled
    state.phase_2p2z = [];
end

state_sum = state.freq_state + fll_term + i_term;
new_state = min(max(state_sum, cfg.negative_limit), cfg.positive_limit);
push_high = state.freq_state >= cfg.positive_limit && (fll_term + i_term) > 0;
push_low = state.freq_state <= cfg.negative_limit && (fll_term + i_term) < 0;
if ~(push_high || push_low)
    state.freq_state = new_state;
end
correction_sum = state.freq_state + p_term + ff_term + phase_2p2z_term;
freq_correction = min(max(correction_sum, cfg.negative_limit), cfg.positive_limit);
tracking_signed = int64(cfg.center_word) + freq_correction;
tracking_signed = min(max(tracking_signed, int64(0)), int64(2^48 - 1));

output.freq_state = state.freq_state;
output.freq_correction = freq_correction;
output.tracking_word = uint64(tracking_signed);
output.fll_term = fll_term;
output.i_term = i_term;
output.p_term = p_term;
output.ff_term = ff_term;
output.phase_2p2z_term = phase_2p2z_term;
output.phase_2p2z_accumulator = phase_2p2z_output.accumulator;
output.phase_2p2z_saturated_high = phase_2p2z_output.saturated_high;
output.phase_2p2z_saturated_low = phase_2p2z_output.saturated_low;
output.saturated_high = state_sum > cfg.positive_limit || ...
    correction_sum > cfg.positive_limit || phase_2p2z_output.saturated_high;
output.saturated_low = state_sum < cfg.negative_limit || ...
    correction_sum < cfg.negative_limit || phase_2p2z_output.saturated_low;
end

function output = empty_2p2z_output()
output.value = int64(0);
output.accumulator = int64(0);
output.saturated_high = false;
output.saturated_low = false;
end
