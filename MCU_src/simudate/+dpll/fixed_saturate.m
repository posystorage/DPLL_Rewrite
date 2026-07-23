function [y, saturated_high, saturated_low] = fixed_saturate(x, width)
%FIXED_SATURATE Saturate signed values to the requested width.

validateattributes(width, {'numeric'}, {'scalar', 'integer', '>=', 2, '<=', 62});
x = int64(x);
high = bitshift(int64(1), width - 1) - 1;
low = -bitshift(int64(1), width - 1);
saturated_high = x > high;
saturated_low = x < low;
y = min(max(x, low), high);
end
