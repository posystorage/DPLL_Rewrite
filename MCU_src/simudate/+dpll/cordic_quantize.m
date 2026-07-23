function [phase_word, magnitude, out_of_range] = cordic_quantize(i_in, q_in, cfg)
%CORDIC_QUANTIZE Behavioral CORDIC phase/magnitude output quantization.

i_value = int64(i_in);
q_value = int64(q_in);
out_of_range = abs(i_value) > 262144 || abs(q_value) > 262144;
angle_rad = atan2(double(q_value), double(i_value));
scaled = sign(angle_rad) * floor(abs(angle_rad) / pi * 2^(cfg.phase_width - 1) + 0.5);
phase_word = dpll.fixed_wrap(int64(scaled), cfg.phase_width);
magnitude_value = floor(hypot(double(i_value), double(q_value)) + 0.5);
magnitude = int64(min(magnitude_value, 2^20 - 1));
end
