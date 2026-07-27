function input_data = generate_synthetic_input(duration_s, frequency_hz, amplitude_codes)
%GENERATE_SYNTHETIC_INPUT Create deterministic FPGA-code sine input.

if nargin < 1, duration_s = 0.08; end
if nargin < 2, frequency_hz = 20000; end
if nargin < 3, amplitude_codes = 6000; end
sample_rate_hz = 3125000;
sample_count = floor(duration_s * sample_rate_hz);
t = (0:sample_count-1).' / sample_rate_hz;
% A small, synchronous frequency fluctuation exercises tracking behavior.
phase = 2 * pi * frequency_hz * t + 0.18 * sin(2 * pi * 17 * t);
codes = sign(amplitude_codes * sin(phase)) .* ...
    floor(abs(amplitude_codes * sin(phase)) + 0.5);
input_data.pll_input_codes = int16(codes);
input_data.sample_rate_hz = sample_rate_hz;
input_data.source_file = '<synthetic>';
input_data.format = 'synthetic';
input_data.input_start_index = 1;
input_data.input_end_index = sample_count;
input_data.source_raw_sample_rate_hz = sample_rate_hz;
input_data.source_samples_per_input = 1;
input_data.source_raw_start_index = 1;
input_data.source_raw_total_count = sample_count;
end
