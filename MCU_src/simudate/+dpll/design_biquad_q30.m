function coeff = design_biquad_q30(cutoff_hz, sample_rate_hz)
%DESIGN_BIQUAD_Q30 Match the ARM low-pass coefficient calculation.

validateattributes(cutoff_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(sample_rate_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
if cutoff_hz >= sample_rate_hz / 2
    error('dpll:InvalidIirCutoff', 'IIR cutoff must be below Nyquist.');
end

% Keep the same finite Taylor tan approximation as dpll_profile.c.
x = pi * cutoff_hz / sample_rate_hz;
x2 = x * x;
k = x + x * x2 / 3 + 2 * x * x2^2 / 15 + ...
    17 * x * x2^3 / 315 + 62 * x * x2^4 / 2835;
k2 = k * k;
norm_value = 1 / (1 + sqrt(2) * k + k2);
values = [k2 * norm_value, 2 * k2 * norm_value, k2 * norm_value, ...
    2 * (k2 - 1) * norm_value, ...
    (1 - sqrt(2) * k + k2) * norm_value];
q30 = round_away(values * 2^30);
coeff.b0 = int64(q30(1));
coeff.b1 = int64(q30(2));
coeff.b2 = int64(q30(3));
coeff.a1 = int64(q30(4));
coeff.a2 = int64(q30(5));
end

function y = round_away(x)
y = sign(x) .* floor(abs(x) + 0.5);
end
