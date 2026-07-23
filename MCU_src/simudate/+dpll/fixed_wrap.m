function y = fixed_wrap(x, width)
%FIXED_WRAP Explicit signed two's-complement wrapping for widths <= 62.

validateattributes(width, {'numeric'}, {'scalar', 'integer', '>=', 2, '<=', 62});
x = int64(x);
modulus = bitshift(int64(1), width);
half = bitshift(int64(1), width - 1);
y = mod(x, modulus);
mask = y >= half;
y(mask) = y(mask) - modulus;
end
