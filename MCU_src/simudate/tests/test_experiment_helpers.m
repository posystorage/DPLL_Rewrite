function test_experiment_helpers()
sample_rate_hz = 10000;
time_s = (0:sample_rate_hz-1).' / sample_rate_hz;
frequency_hz = 37;
amplitude = 2.75;
phase_rad = 0.63;
values = 4.2 + 0.03 * time_s + ...
    amplitude * cos(2 * pi * frequency_hz * time_s + phase_rad);
fit = dpll.fit_tone(time_s, values, frequency_hz);
assert(abs(fit.amplitude - amplitude) < 1e-10);
assert(abs(angle(exp(1i * (fit.phase_rad - phase_rad)))) < 1e-10);
assert(fit.r_squared > 1 - 1e-12);

spec.sample_rate_hz = 3125000;
spec.carrier_frequency_hz = 20000;
spec.modulation_frequency_hz = 40;
spec.phase_modulation_rad = 0.15;
spec.carrier_lead_s = 0.01;
spec.duration_s = 0.02;
spec.amplitude_codes = 6000;
[input_data, truth] = generate_sinusoidal_fm_input(spec);
assert(isa(input_data.pll_input_codes, 'int16'));
assert(numel(input_data.pll_input_codes) == 62500);
assert(truth.frequency_deviation_hz == 6);
assert(strcmp(input_data.format, 'synthetic_sinusoidal_fm'));
assert(numel(input_data.oracle_reference_phase_rad) == 62500);

coeff = dpll.design_biquad_q30(2000, 3125000 / 16);
assert(all(isfield(coeff, {'b0', 'b1', 'b2', 'a1', 'a2'})));

[frequency, psd_value] = dpll.welch_psd(values, sample_rate_hz);
[~, peak_index] = max(psd_value(2:end));
peak_index = peak_index + 1;
assert(abs(frequency(peak_index) - frequency_hz) < 2);

optimized = dpll_optimized_config(20000);
assert(optimized.cic.output_shift == 9);
assert(optimized.shifts.p_product == 9);
assert(optimized.gains.kp_track == 6000000);
assert(optimized.gains.ki_track == 2500000);
assert(optimized.gains.kp_blend == 750000);
assert(optimized.iir.sections == 2);

recommended = dpll_recommended_config(20000);
assert(recommended.shifts.p_product == 8);
assert(recommended.gains.kp_blend == 375000);
assert(recommended.iir.track_cutoff_hz == 8000);

matrix_base = dpll_current_config(20000);
matrix_base.cic.output_shift = 9;
matrix_base.gains.kp_track = int64(6000000);
matrix_base.gains.ki_track = int64(2500000);
matrix = build_p_shift_iir_matrix(matrix_base);
assert(numel(matrix) == 4);
assert(isequal(arrayfun(@(x) x.cfg.shifts.p_product, matrix), ...
    [9; 9; 8; 8]));
assert(isequal(arrayfun(@(x) x.cfg.iir.track_cutoff_hz, matrix), ...
    [2000; 8000; 2000; 8000]));
assert(isequal(arrayfun(@(x) double(x.cfg.gains.kp_blend), matrix), ...
    [750000; 750000; 375000; 375000]));
reference_cfg = matrix(1).cfg;
for k = 1:numel(matrix)
    cfg = matrix(k).cfg;
    cfg.model_name = reference_cfg.model_name;
    cfg.shifts.p_product = reference_cfg.shifts.p_product;
    cfg.gains.kp_blend = reference_cfg.gains.kp_blend;
    cfg.iir.track_cutoff_hz = reference_cfg.iir.track_cutoff_hz;
    cfg.iir.track = reference_cfg.iir.track;
    assert(isequaln(cfg, reference_cfg));
end
end
