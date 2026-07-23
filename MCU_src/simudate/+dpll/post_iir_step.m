function [state, i_out, q_out, saturated] = post_iir_step(state, i_in, q_in, coeff, cfg)
%POST_IIR_STEP Two cascaded identical fixed-point Q2.30 biquads.

if isempty(state)
    state.i = zeros(2, 4, 'int64'); % [x1 x2 y1 y2] per section
    state.q = zeros(2, 4, 'int64');
end
[state.i, i_out, sat_i] = channel_step(state.i, int64(i_in), coeff, cfg);
[state.q, q_out, sat_q] = channel_step(state.q, int64(q_in), coeff, cfg);
saturated = sat_i || sat_q;
end

function [history, y, saturated] = channel_step(history, x, coeff, cfg)
saturated = false;
for section = 1:2
    h = history(section, :);
    accumulator = coeff.b0 * x + coeff.b1 * h(1) + coeff.b2 * h(2) ...
        - coeff.a1 * h(3) - coeff.a2 * h(4);
    bias = bitshift(int64(1), cfg.coeff_frac - 1);
    if accumulator < 0
        bias = bias - 1;
    end
    shifted = dpll.arshift(accumulator + bias, cfg.coeff_frac);
    [y, sat_high, sat_low] = dpll.fixed_saturate(shifted, cfg.data_width);
    saturated = saturated || sat_high || sat_low;
    history(section, :) = [x, h(1), y, h(3)];
    x = y;
end
end
