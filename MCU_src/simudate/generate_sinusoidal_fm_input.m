function [input_data, truth] = generate_sinusoidal_fm_input(spec)
%GENERATE_SINUSOIDAL_FM_INPUT Create a deterministic 3.125 MSPS PM/FM test.
%
% The phase modulation amplitude is held constant across modulation
% frequencies. Consequently, the sinusoidal frequency-deviation amplitude is
% phase_modulation_rad * modulation_frequency_hz. This keeps the phase-detector
% excitation comparable at every response-curve point.

required = {'sample_rate_hz', 'carrier_frequency_hz', ...
    'modulation_frequency_hz', 'phase_modulation_rad', ...
    'carrier_lead_s', 'duration_s', 'amplitude_codes'};
if ~isstruct(spec) || ~all(isfield(spec, required))
    error('dpll:InvalidSyntheticSpec', ...
        'Synthetic FM specification is incomplete.');
end
validateattributes(spec.sample_rate_hz, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(spec.modulation_frequency_hz, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(spec.duration_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});

sample_count = floor(spec.duration_s * spec.sample_rate_hz);
time_s = (0:sample_count-1).' / spec.sample_rate_hz;
tau = max(time_s - spec.carrier_lead_s, 0);
active = time_s >= spec.carrier_lead_s;
phase_modulation = zeros(sample_count, 1);
phase_modulation(active) = spec.phase_modulation_rad * sin( ...
    2 * pi * spec.modulation_frequency_hz * tau(active));
phase_rad = 2 * pi * spec.carrier_frequency_hz * time_s + ...
    phase_modulation;
analog_codes = spec.amplitude_codes * sin(phase_rad);
quantized_codes = sign(analog_codes) .* floor(abs(analog_codes) + 0.5);

input_data.pll_input_codes = int16(quantized_codes);
input_data.sample_rate_hz = double(spec.sample_rate_hz);
input_data.source_file = sprintf('<synthetic-fm-%.6g-Hz>', ...
    spec.modulation_frequency_hz);
input_data.format = 'synthetic_sinusoidal_fm';
input_data.input_start_index = 1;
input_data.input_end_index = sample_count;
input_data.source_raw_sample_rate_hz = double(spec.sample_rate_hz);
input_data.source_samples_per_input = 1;
input_data.source_raw_start_index = 1;
input_data.source_raw_total_count = sample_count;
input_data.oracle_reference_phase_rad = phase_rad;

truth.sample_rate_hz = double(spec.sample_rate_hz);
truth.sample_count = sample_count;
truth.carrier_frequency_hz = double(spec.carrier_frequency_hz);
truth.modulation_frequency_hz = double(spec.modulation_frequency_hz);
truth.phase_modulation_rad = double(spec.phase_modulation_rad);
truth.frequency_deviation_hz = double(spec.phase_modulation_rad * ...
    spec.modulation_frequency_hz);
truth.carrier_lead_s = double(spec.carrier_lead_s);
truth.duration_s = double(spec.duration_s);
truth.phase_definition = ...
    'phi=2*pi*fc*t+beta*sin(2*pi*fm*(t-carrier_lead)), after carrier_lead';
end
