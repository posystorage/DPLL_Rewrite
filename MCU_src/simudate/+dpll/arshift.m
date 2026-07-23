function y = arshift(x, shift)
%ARSHIFT RTL-style arithmetic right shift (floor for negative values).

x = int64(x);
validateattributes(shift, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 62});
if shift == 0
    y = x;
else
    y = idivide(x, bitshift(int64(1), shift), 'floor');
end
end
