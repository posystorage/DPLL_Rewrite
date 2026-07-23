function [state, out_valid, i_out, q_out, saturated] = post_cic_step(state, i_in, q_in, cfg)
%POST_CIC_STEP Three-stage CIC update at one 3.125 MSPS input event.

if isempty(state)
    state.i_int = zeros(1, 3, 'int64');
    state.q_int = zeros(1, 3, 'int64');
    state.i_delay = zeros(1, 3, 'int64');
    state.q_delay = zeros(1, 3, 'int64');
    state.sample_count = 0;
    state.output_count = 0;
end

old_i = state.i_int;
old_q = state.q_int;
state.i_int(1) = dpll.fixed_wrap(old_i(1) + int64(i_in), cfg.acc_width);
state.i_int(2) = dpll.fixed_wrap(old_i(2) + old_i(1), cfg.acc_width);
state.i_int(3) = dpll.fixed_wrap(old_i(3) + old_i(2), cfg.acc_width);
state.q_int(1) = dpll.fixed_wrap(old_q(1) + int64(q_in), cfg.acc_width);
state.q_int(2) = dpll.fixed_wrap(old_q(2) + old_q(1), cfg.acc_width);
state.q_int(3) = dpll.fixed_wrap(old_q(3) + old_q(2), cfg.acc_width);

out_valid = false;
i_out = int64(0);
q_out = int64(0);
saturated = false;
if state.sample_count < cfg.rate - 1
    state.sample_count = state.sample_count + 1;
    return;
end
state.sample_count = 0;

% The RTL decimation register captures the pre-edge third integrator value.
i_comb1 = dpll.fixed_wrap(old_i(3) - state.i_delay(1), cfg.acc_width);
i_comb2 = dpll.fixed_wrap(i_comb1 - state.i_delay(2), cfg.acc_width);
i_comb3 = dpll.fixed_wrap(i_comb2 - state.i_delay(3), cfg.acc_width);
q_comb1 = dpll.fixed_wrap(old_q(3) - state.q_delay(1), cfg.acc_width);
q_comb2 = dpll.fixed_wrap(q_comb1 - state.q_delay(2), cfg.acc_width);
q_comb3 = dpll.fixed_wrap(q_comb2 - state.q_delay(3), cfg.acc_width);
state.i_delay = [old_i(3), i_comb1, i_comb2];
state.q_delay = [old_q(3), q_comb1, q_comb2];
state.output_count = state.output_count + 1;
if state.output_count <= cfg.warmup_outputs
    return;
end

i_shifted = round_shift(i_comb3, cfg.output_shift);
q_shifted = round_shift(q_comb3, cfg.output_shift);
[i_out, hi_i, lo_i] = dpll.fixed_saturate(i_shifted, cfg.output_width);
[q_out, hi_q, lo_q] = dpll.fixed_saturate(q_shifted, cfg.output_width);
saturated = hi_i || lo_i || hi_q || lo_q;
out_valid = true;
end

function y = round_shift(x, shift)
if shift == 0
    y = x;
    return;
end
bias = bitshift(int64(1), shift - 1);
if x < 0
    bias = bias - 1;
end
y = dpll.arshift(x + bias, shift);
end
