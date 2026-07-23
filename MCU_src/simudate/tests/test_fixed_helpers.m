function test_fixed_helpers()
assert(dpll.fixed_wrap(int64(8), 4) == -8);
assert(dpll.fixed_wrap(int64(-9), 4) == 7);
assert(dpll.arshift(int64(-3), 1) == -2);
[value, high, low] = dpll.fixed_saturate(int64(200), 8);
assert(value == 127 && high && ~low);
[value, high, low] = dpll.fixed_saturate(int64(-200), 8);
assert(value == -128 && ~high && low);
end
