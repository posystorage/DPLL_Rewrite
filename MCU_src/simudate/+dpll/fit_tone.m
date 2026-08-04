function fit = fit_tone(time_s, values, frequency_hz)
%FIT_TONE Least-squares phasor fit with offset and linear drift removal.

time_s = double(time_s(:));
values = double(values(:));
valid = isfinite(time_s) & isfinite(values);
time_s = time_s(valid);
values = values(valid);
if numel(values) < 8
    error('dpll:InsufficientToneSamples', ...
        'At least eight finite samples are required for a tone fit.');
end

t0 = mean(time_s);
centered_time = time_s - t0;
omega_time = 2 * pi * frequency_hz * time_s;
design = [ones(size(time_s)), centered_time, ...
    cos(omega_time), sin(omega_time)];
coeff = design \ values;
fitted = design * coeff;
residual = values - fitted;
total = values - mean(values);

fit.frequency_hz = double(frequency_hz);
fit.reference_time_s = t0;
fit.offset = coeff(1);
fit.slope_per_s = coeff(2);
fit.cosine_coefficient = coeff(3);
fit.sine_coefficient = coeff(4);
fit.phasor = complex(coeff(3), -coeff(4));
fit.amplitude = abs(fit.phasor);
fit.phase_rad = angle(fit.phasor);
fit.rms_residual = sqrt(mean(residual.^2));
denominator = sum(total.^2);
if denominator == 0
    fit.r_squared = NaN;
else
    fit.r_squared = 1 - sum(residual.^2) / denominator;
end
fit.sample_count = numel(values);
end
