function cfg = dpll_default_config(center_frequency_hz)
%DPLL_DEFAULT_CONFIG Build the ARM-default configuration for replay.

if nargin < 1
    center_frequency_hz = 20000;
end
validateattributes(center_frequency_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});

cfg.model_name = 'DPLL stage-A event-driven fixed-point replay';
cfg.input_sample_rate_hz = 3125000;
cfg.fabric_clock_hz = 125000000;
cfg.fabric_clocks_per_input = 40;
cfg.center_frequency_hz = double(center_frequency_hz);
cfg.word_width = 48;
cfg.phase_width = 18;
cfg.ferr_width = 22;
cfg.state_width = 56;
cfg.coeff_width = 24;

word_scale = 2^cfg.word_width;
cfg.center_word = uint64(round(cfg.center_frequency_hz / ...
    cfg.fabric_clock_hz * word_scale));
center_word_hi = uint64(round(cfg.center_frequency_hz / ...
    cfg.fabric_clock_hz * 2^32));
limit_hi = idivide(center_word_hi + uint64(2), uint64(5), 'floor');
cfg.positive_limit = int64(limit_hi * uint64(65536));
cfg.negative_limit = -cfg.positive_limit;

cfg.cic.rate = 16;
cfg.cic.output_shift = 8;
cfg.cic.stages = 3;
cfg.cic.acc_width = 44;
cfg.cic.output_width = 20;
cfg.cic.warmup_outputs = 3;

cfg.iir.mode = 3; % AUTO: acquire coefficients, then track coefficients.
cfg.iir.coeff_frac = 30;
cfg.iir.data_width = 20;
post_cic_rate_hz = cfg.input_sample_rate_hz / cfg.cic.rate;
cfg.iir.acquire_cutoff_hz = 4000;
cfg.iir.track_cutoff_hz = 2000;
cfg.iir.acquire = design_biquad_q30(cfg.iir.acquire_cutoff_hz, post_cic_rate_hz);
cfg.iir.track = design_biquad_q30(cfg.iir.track_cutoff_hz, post_cic_rate_hz);

cfg.fll.delay_sel = 3;
cfg.fll.delay_samples = 8;
cfg.fll.block_samples = 16;
cfg.fll.angle_freq_scale = int64(10680836);

cfg.gains.kp_track = int64(6000000);
cfg.gains.ki_track = int64(180000);
cfg.gains.kf_acquire = int64(8000000);
cfg.gains.kf_blend = int64(1500000);
cfg.gains.kf_track = int64(250000);
cfg.gains.kp_blend = int64(6000000);
cfg.gains.ki_blend = int64(468800);
cfg.shifts.p_product = 12;
cfg.shifts.i_product = 18;
cfg.shifts.fll_product = 16;

cfg.phase_setpoint = int64(-65536);
cfg.phase_threshold = int64(5825);
cfg.freq_threshold = int64(2147);
cfg.magnitude_enter = int64(16384);
cfg.magnitude_exit = int64(8192);
cfg.acquire_dwell = 16;
cfg.blend_dwell = 64;
cfg.loss_dwell = 64;
cfg.warmup_samples = 16;
cfg.preheat_blocks = 4;
cfg.holdover_timeout_ticks = 1250000;
cfg.measurement_timeout_ticks = 2400 * cfg.cic.rate + 512;

cfg.pulse.reference_cycles_per_pulse = 113;
cfg.pulse.output_multiplier = 2000;
cfg.pulse.ideal_interval_samples = 226000;
cfg.pulse.first_pulse_sample_index = [];

cfg.options.loop_enable = true;
cfg.options.store_iq = true;
cfg.options.abstract_fixed_pipeline_latency = true;
cfg.options.warn_on_saturation = true;
end

function coeff = design_biquad_q30(cutoff_hz, sample_rate_hz)
% Match dpll_profile.c, including its finite Taylor tan approximation.
x = pi * cutoff_hz / sample_rate_hz;
x2 = x * x;
k = x + x * x2 / 3 + 2 * x * x2^2 / 15 + ...
    17 * x * x2^3 / 315 + 62 * x * x2^4 / 2835;
k2 = k * k;
norm_value = 1 / (1 + sqrt(2) * k + k2);
values = [k2 * norm_value, 2 * k2 * norm_value, k2 * norm_value, ...
    2 * (k2 - 1) * norm_value, ...
    (1 - sqrt(2) * k + k2) * norm_value];
q30 = round_away(values * 2^30);
coeff.b0 = int64(q30(1));
coeff.b1 = int64(q30(2));
coeff.b2 = int64(q30(3));
coeff.a1 = int64(q30(4));
coeff.a2 = int64(q30(5));
end

function y = round_away(x)
y = sign(x) .* floor(abs(x) + 0.5);
end
