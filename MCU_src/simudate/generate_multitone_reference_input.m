function [input_data, truth] = generate_multitone_reference_input(spec)
%GENERATE_MULTITONE_REFERENCE_INPUT Deterministic PM/AM reference test waveform.

required = {'sample_rate_hz', 'carrier_frequency_hz', 'duration_s', ...
    'amplitude_codes', 'phase_tone_hz', 'phase_tone_rad'};
if ~isstruct(spec) || ~all(isfield(spec, required))
    error('dpll:InvalidMultitoneSpec', ...
        'Multitone reference specification is incomplete.');
end
frequencies = double(spec.phase_tone_hz(:));
phase_amplitudes = double(spec.phase_tone_rad(:));
if numel(frequencies) ~= numel(phase_amplitudes)
    error('dpll:InvalidMultitoneSpec', ...
        'phase_tone_hz and phase_tone_rad must have equal lengths.');
end
if ~isfield(spec, 'am_tone_hz'), spec.am_tone_hz = []; end
if ~isfield(spec, 'am_depth'), spec.am_depth = []; end
if ~isfield(spec, 'second_harmonic_ratio')
    spec.second_harmonic_ratio = 0;
end
if ~isfield(spec, 'third_harmonic_ratio')
    spec.third_harmonic_ratio = 0;
end
if ~isfield(spec, 'noise_rms_codes'), spec.noise_rms_codes = 0; end
if ~isfield(spec, 'random_seed'), spec.random_seed = 1; end

am_frequencies = double(spec.am_tone_hz(:));
am_depths = double(spec.am_depth(:));
if numel(am_frequencies) ~= numel(am_depths)
    error('dpll:InvalidMultitoneSpec', ...
        'am_tone_hz and am_depth must have equal lengths.');
end

sample_count = floor(spec.duration_s * spec.sample_rate_hz);
time_s = (0:sample_count - 1).' / spec.sample_rate_hz;
phase_modulation_rad = zeros(sample_count, 1);
for k = 1:numel(frequencies)
    phase_modulation_rad = phase_modulation_rad + ...
        phase_amplitudes(k) * sin(2 * pi * frequencies(k) * time_s);
end
amplitude_scale = ones(sample_count, 1);
for k = 1:numel(am_frequencies)
    amplitude_scale = amplitude_scale + ...
        am_depths(k) * sin(2 * pi * am_frequencies(k) * time_s);
end

carrier_phase_rad = 2 * pi * spec.carrier_frequency_hz * time_s;
total_phase_rad = carrier_phase_rad + phase_modulation_rad;
analog = spec.amplitude_codes * amplitude_scale .* sin(total_phase_rad);
if spec.second_harmonic_ratio ~= 0
    analog = analog + spec.amplitude_codes * spec.second_harmonic_ratio * ...
        sin(2 * total_phase_rad + 0.37);
end
if spec.third_harmonic_ratio ~= 0
    analog = analog + spec.amplitude_codes * spec.third_harmonic_ratio * ...
        sin(3 * total_phase_rad - 0.29);
end
if spec.noise_rms_codes > 0
    previous_rng = rng;
    cleanup = onCleanup(@() rng(previous_rng)); %#ok<NASGU>
    rng(spec.random_seed, 'twister');
    analog = analog + spec.noise_rms_codes * randn(size(analog));
end
quantized = sign(analog) .* floor(abs(analog) + 0.5);
quantized = min(max(quantized, -32768), 32767);

input_data.pll_input_codes = int16(quantized);
input_data.sample_rate_hz = double(spec.sample_rate_hz);
input_data.source_file = '<synthetic-multitone-reference>';
input_data.format = 'synthetic_multitone_reference';
input_data.input_start_index = 1;
input_data.input_end_index = sample_count;
input_data.source_raw_sample_rate_hz = double(spec.sample_rate_hz);
input_data.source_samples_per_input = 1;
input_data.source_raw_start_index = 1;
input_data.source_raw_total_count = sample_count;

truth.time_s = time_s;
truth.carrier_phase_rad = carrier_phase_rad;
truth.phase_modulation_rad = phase_modulation_rad;
truth.total_phase_rad = total_phase_rad;
truth.total_phase_cycles = total_phase_rad / (2 * pi);
truth.amplitude_scale = amplitude_scale;
truth.phase_tone_hz = frequencies;
truth.phase_tone_rad = phase_amplitudes;
truth.am_tone_hz = am_frequencies;
truth.am_depth = am_depths;
truth.spec = spec;
end
