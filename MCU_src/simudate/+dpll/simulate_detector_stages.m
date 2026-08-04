function trace = simulate_detector_stages(codes, carrier_frequency_hz, cfg)
%SIMULATE_DETECTOR_STAGES Fixed-NCO mixer/CIC/IIR/CORDIC detector replay.

codes = int16(codes(:));
sample_count = numel(codes);
max_output = ceil(sample_count / cfg.cic.rate) + 8;
sample_index = zeros(max_output, 1);
i_cic_trace = zeros(max_output, 1, 'int64');
q_cic_trace = zeros(max_output, 1, 'int64');
i_iir_trace = zeros(max_output, 1, 'int64');
q_iir_trace = zeros(max_output, 1, 'int64');
cordic_word_trace = zeros(max_output, 1, 'int64');
magnitude_trace = zeros(max_output, 1, 'int64');
cic_saturated = false(max_output, 1);
iir_saturated = false(max_output, 1);
cordic_out_of_range = false(max_output, 1);

word = uint64(round(carrier_frequency_hz / cfg.fabric_clock_hz * ...
    2^cfg.word_width));
increment_per_input = word * uint64(cfg.fabric_clocks_per_input);
phase_accumulator = uint64(0);
modulus = uint64(2^cfg.word_width);
cic_state = [];
iir_state = [];
count = 0;

for n = 1:sample_count
    nco_phase = double(phase_accumulator) / 2^cfg.word_width * (2 * pi);
    lo_cos = int64(round_away(32767 * cos(nco_phase)));
    lo_sin = int64(round_away(-32767 * sin(nco_phase)));
    i_mixer = mixer_truncate(int64(codes(n)) * lo_cos);
    q_mixer = mixer_truncate(int64(codes(n)) * lo_sin);
    [cic_state, valid, i_cic, q_cic, cic_sat] = ...
        dpll.post_cic_step(cic_state, i_mixer, q_mixer, cfg.cic);
    if valid
        [iir_state, i_iir, q_iir, iir_sat] = dpll.post_iir_step( ...
            iir_state, i_cic, q_cic, cfg.iir.track, cfg.iir);
        [phase_word, magnitude, range_error] = ...
            dpll.cordic_quantize(i_iir, q_iir, cfg);
        count = count + 1;
        sample_index(count) = n;
        i_cic_trace(count) = i_cic;
        q_cic_trace(count) = q_cic;
        i_iir_trace(count) = i_iir;
        q_iir_trace(count) = q_iir;
        cordic_word_trace(count) = phase_word;
        magnitude_trace(count) = magnitude;
        cic_saturated(count) = cic_sat;
        iir_saturated(count) = iir_sat;
        cordic_out_of_range(count) = range_error;
    end
    phase_accumulator = mod(phase_accumulator + increment_per_input, modulus);
end

sample_index = sample_index(1:count);
i_cic_trace = i_cic_trace(1:count);
q_cic_trace = q_cic_trace(1:count);
i_iir_trace = i_iir_trace(1:count);
q_iir_trace = q_iir_trace(1:count);
cordic_word_trace = cordic_word_trace(1:count);
magnitude_trace = magnitude_trace(1:count);
cic_saturated = cic_saturated(1:count);
iir_saturated = iir_saturated(1:count);
cordic_out_of_range = cordic_out_of_range(1:count);

phase_cic_rad = unwrap(atan2(double(q_cic_trace), double(i_cic_trace)));
phase_iir_rad = unwrap(atan2(double(q_iir_trace), double(i_iir_trace)));
phase_cordic_rad = unwrap(double(cordic_word_trace) * pi / ...
    2^(cfg.phase_width - 1));

trace.sample_index = sample_index;
trace.time_s = (sample_index - 1) / cfg.input_sample_rate_hz;
trace.i_cic = i_cic_trace;
trace.q_cic = q_cic_trace;
trace.i_iir = i_iir_trace;
trace.q_iir = q_iir_trace;
trace.phase_cic_rad = phase_cic_rad;
trace.phase_iir_rad = phase_iir_rad;
trace.phase_cordic_rad = phase_cordic_rad;
trace.magnitude = magnitude_trace;
trace.cic_saturated = cic_saturated;
trace.iir_saturated = iir_saturated;
trace.cordic_out_of_range = cordic_out_of_range;
trace.carrier_frequency_hz = carrier_frequency_hz;
trace.nco_word = word;
end

function y = round_away(x)
y = sign(x) .* floor(abs(x) + 0.5);
end

function y = mixer_truncate(product)
shifted = dpll.arshift(product, 13);
if shifted == 131072
    y = int64(131071);
else
    y = dpll.fixed_wrap(shifted, 18);
end
end
