function test_reference_phase_estimators()
cfg = dpll_optimized_config(20000);
sample_rate_hz = cfg.input_sample_rate_hz;
time_s = (0:round(0.04 * sample_rate_hz) - 1).' / sample_rate_hz;
truth_cycles = 20000 * time_s + 0.03 / (2 * pi) * ...
    sin(2 * pi * 80 * time_s);
codes = int16(round(6000 * sin(2 * pi * truth_cycles)));
query_time_s = (0.005:0.0005:0.035).';
query_index = 1 + query_time_s * sample_rate_hz;
truth_query = interp1(time_s, truth_cycles, query_time_s);

zero = dpll.estimate_zero_crossing_phase(codes, query_index, ...
    sample_rate_hz);
local = dpll.estimate_local_sinusoid_phase(codes, query_index, ...
    sample_rate_hz, 20000, 8);
analytic = dpll.estimate_fft_analytic_phase(codes, query_index, ...
    sample_rate_hz, 20000, 500);
estimates = {zero.phase_cycles, local.phase_cycles, analytic.phase_cycles};
for k = 1:numel(estimates)
    delta = estimates{k} - truth_query;
    design = [ones(size(query_time_s)), query_time_s];
    delta = delta - design * (design \ delta);
    assert(sqrt(mean(delta.^2)) < 2e-5);
end

detector = dpll.simulate_detector_stages(codes, 20000, cfg);
use = detector.time_s >= 0.005 & detector.time_s <= 0.035;
truth_mod = interp1(time_s, ...
    0.03 / (2 * pi) * sin(2 * pi * 80 * time_s), ...
    detector.time_s(use));
truth_fit = dpll.fit_tone(detector.time_s(use), truth_mod, 80);
iir_fit = dpll.fit_tone(detector.time_s(use), ...
    detector.phase_iir_rad(use) / (2 * pi), 80);
transfer = iir_fit.phasor / truth_fit.phasor;
assert(abs(abs(transfer) - 1) < 0.03);
assert(angle(transfer) < 0);
assert(angle(transfer) > -0.2);
end
