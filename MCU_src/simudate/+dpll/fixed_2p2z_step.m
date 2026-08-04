function [state, output] = fixed_2p2z_step(state, input_value, cfg)
%FIXED_2P2Z_STEP One saturating direct-form-I 2P2Z controller update.
%
% y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2]
%        - a1*y[n-1] - a2*y[n-2]
% All coefficients share cfg.coefficient_frac fractional bits.

if isempty(state)
    state.x1 = int64(0);
    state.x2 = int64(0);
    state.y1 = int64(0);
    state.y2 = int64(0);
end

[x, input_high, input_low] = saturate_known_width( ...
    int64(input_value), cfg.input_width);
raw_accumulator = int64(cfg.b0) * x + ...
    int64(cfg.b1) * state.x1 + int64(cfg.b2) * state.x2 - ...
    int64(cfg.a1) * state.y1 - int64(cfg.a2) * state.y2;
[accumulator, accumulator_high, accumulator_low] = ...
    saturate_known_width(raw_accumulator, cfg.accumulator_width);
scaled_output = arithmetic_shift_known(accumulator, cfg.coefficient_frac);
[y, output_high, output_low] = saturate_known_width( ...
    scaled_output, cfg.output_width);

state.x2 = state.x1;
state.x1 = x;
state.y2 = state.y1;
state.y1 = y;

output.value = y;
output.input_value = x;
output.accumulator = accumulator;
output.scaled_output = scaled_output;
output.input_saturated_high = input_high;
output.input_saturated_low = input_low;
output.accumulator_saturated_high = accumulator_high;
output.accumulator_saturated_low = accumulator_low;
output.output_saturated_high = output_high;
output.output_saturated_low = output_low;
output.saturated_high = input_high || accumulator_high || output_high;
output.saturated_low = input_low || accumulator_low || output_low;
end

function [value, saturated_high, saturated_low] = ...
    saturate_known_width(value, width)
% Widths are validated once when the candidate coefficients are frozen.
high = bitshift(int64(1), width - 1) - 1;
low = -bitshift(int64(1), width - 1);
saturated_high = value > high;
saturated_low = value < low;
value = min(max(value, low), high);
end

function value = arithmetic_shift_known(value, shift)
if shift > 0
    value = idivide(value, bitshift(int64(1), shift), 'floor');
end
end
