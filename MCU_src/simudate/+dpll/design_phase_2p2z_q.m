function cfg = design_phase_2p2z_q(sample_rate_hz, center_hz, ...
    quality_factor, peak_gain, coefficient_frac, input_width)
%DESIGN_PHASE_2P2Z_Q Quantize a parallel phase-error band-pass compensator.
%
% The section is the RBJ constant-peak-gain band-pass biquad. It has zeros
% at DC and Nyquist, so it does not change the PI integrator's steady-state
% authority. The two poles provide a broad, causal gain increase around the
% requested disturbance band.

if nargin < 5, coefficient_frac = 22; end
if nargin < 6, input_width = 18; end
validateattributes(sample_rate_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(center_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', sample_rate_hz / 2});
validateattributes(quality_factor, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(peak_gain, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(coefficient_frac, {'numeric'}, ...
    {'scalar', 'integer', '>=', 8, '<=', 30});
validateattributes(input_width, {'numeric'}, ...
    {'scalar', 'integer', '>=', 2, '<=', 32});

omega = 2 * pi * center_hz / sample_rate_hz;
alpha = sin(omega) / (2 * quality_factor);
a0 = 1 + alpha;
floating_b = peak_gain * [alpha, 0, -alpha] / a0;
floating_a = [-2 * cos(omega) / a0, (1 - alpha) / a0];
scale = 2^coefficient_frac;

cfg.enabled = true;
cfg.topology = 'parallel_constant_peak_bandpass';
cfg.sample_rate_hz = double(sample_rate_hz);
cfg.center_frequency_hz = double(center_hz);
cfg.quality_factor = double(quality_factor);
cfg.requested_peak_gain_word_per_phase_code = double(peak_gain);
cfg.coefficient_frac = double(coefficient_frac);
cfg.input_width = double(input_width);
cfg.output_width = 36;
cfg.accumulator_width = 62;
cfg.b0 = int64(round_away(floating_b(1) * scale));
cfg.b1 = int64(0);
cfg.b2 = -cfg.b0; % Preserve both designed zeros exactly after quantization.
cfg.a1 = int64(round_away(floating_a(1) * scale));
cfg.a2 = int64(round_away(floating_a(2) * scale));
cfg.reset_when_disabled = true;
cfg.update_scope = 'track_controller_event';

quantized_b = double([cfg.b0 cfg.b1 cfg.b2]) / scale;
quantized_a = [1 double(cfg.a1) / scale double(cfg.a2) / scale];
poles = roots(quantized_a);
if any(abs(poles) >= 1)
    error('dpll:Unstable2P2Z', ...
        'Quantized 2P2Z poles must remain strictly inside the unit circle.');
end
z = exp(1j * omega);
response = polyval(quantized_b, z) / polyval(quantized_a, z);
cfg.quantized_peak_gain_word_per_phase_code = abs(response);
cfg.quantized_peak_phase_deg = rad2deg(angle(response));
cfg.maximum_pole_radius = max(abs(poles));
cfg.coefficient_width = signed_width([cfg.b0 cfg.b1 cfg.b2 cfg.a1 cfg.a2]);
end

function value = round_away(value)
value = sign(value) .* floor(abs(value) + 0.5);
end

function width = signed_width(values)
maximum = max(abs(double(values(:))));
if maximum == 0
    width = 2;
else
    width = ceil(log2(maximum + 1)) + 1;
end
end
