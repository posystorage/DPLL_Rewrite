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
cfg.cic.output_shift = 9;
cfg.cic.stages = 3;
cfg.cic.acc_width = 44;
cfg.cic.output_width = 20;
cfg.cic.warmup_outputs = 3;

cfg.iir.mode = 3; % AUTO: acquire coefficients, then track coefficients.
cfg.iir.coeff_frac = 30;
cfg.iir.data_width = 20;
cfg.iir.sections = 2;
post_cic_rate_hz = cfg.input_sample_rate_hz / cfg.cic.rate;
cfg.iir.acquire_cutoff_hz = 4000;
cfg.iir.track_cutoff_hz = 8000;
cfg.iir.acquire = dpll.design_biquad_q30( ...
    cfg.iir.acquire_cutoff_hz, post_cic_rate_hz);
cfg.iir.track = dpll.design_biquad_q30( ...
    cfg.iir.track_cutoff_hz, post_cic_rate_hz);

cfg.fll.delay_sel = 3;
cfg.fll.delay_samples = 8;
cfg.fll.block_samples = 16;
cfg.fll.angle_freq_scale = int64(10680836);

cfg.gains.kp_track = int64(6000000);
cfg.gains.ki_track = int64(180000);
cfg.gains.kf_acquire = int64(8000000);
cfg.gains.kf_blend = int64(1500000);
cfg.gains.kf_track = int64(250000);
cfg.gains.kp_blend = int64(375000);
cfg.gains.ki_blend = int64(468800);
% Ideal frequency-word conversion for direct FLL feedforward is
% freq_error * 6710886 >> 6 for the current 3.125/125 MHz clock ratio.
cfg.gains.kff_track = int64(6710886);
cfg.shifts.p_product = 8;
cfg.shifts.i_product = 18;
cfg.shifts.fll_product = 16;
cfg.shifts.ff_product = 6;

% Optional FPGA-realizable controller structures. The defaults reproduce the
% audited RTL path exactly; experiments must opt in explicitly.
cfg.architecture.controller_update_mode = 'fll_replay';
cfg.architecture.phase_lead_samples = 0;
cfg.architecture.fll_feedforward_enable = false;
cfg.architecture.phase_2p2z_enable = false;
cfg.architecture.phase_observation_mode = 'rtl';
cfg.architecture.oracle_phase_delay_s = 0;

% Optional parallel phase compensator. Coefficients are intentionally zero
% in the default configuration; candidate builders must opt in and freeze a
% complete quantized coefficient set before reading the real reference.
cfg.phase_2p2z.enabled = false;
cfg.phase_2p2z.topology = 'parallel_constant_peak_bandpass';
cfg.phase_2p2z.sample_rate_hz = post_cic_rate_hz;
cfg.phase_2p2z.center_frequency_hz = 0;
cfg.phase_2p2z.quality_factor = 0;
cfg.phase_2p2z.requested_peak_gain_word_per_phase_code = 0;
cfg.phase_2p2z.quantized_peak_gain_word_per_phase_code = 0;
cfg.phase_2p2z.quantized_peak_phase_deg = 0;
cfg.phase_2p2z.maximum_pole_radius = 0;
cfg.phase_2p2z.coefficient_frac = 22;
cfg.phase_2p2z.coefficient_width = 2;
cfg.phase_2p2z.input_width = cfg.phase_width;
cfg.phase_2p2z.output_width = 36;
cfg.phase_2p2z.accumulator_width = 62;
cfg.phase_2p2z.b0 = int64(0);
cfg.phase_2p2z.b1 = int64(0);
cfg.phase_2p2z.b2 = int64(0);
cfg.phase_2p2z.a1 = int64(0);
cfg.phase_2p2z.a2 = int64(0);
cfg.phase_2p2z.reset_when_disabled = true;
cfg.phase_2p2z.update_scope = 'track_controller_event';

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

cfg.startup.mode = 'prelocked';
cfg.startup.frequency_estimation_duration_s = 0.020;
cfg.startup.preroll_duration_s = 0.050;

% 125 MHz event latencies audited from the stage-A RTL and configured IP.
cfg.latency.mixer_to_post_cic_input_ticks = 5;
cfg.latency.post_cic_ticks = 12;
cfg.latency.post_iir_ticks = 21;
cfg.latency.cordic_ticks = 26;
cfg.latency.fll_to_tracking_word_ticks = 11;
cfg.latency.tracking_dds_ticks = 9;

root_dir = fileparts(mfilename('fullpath'));
cfg.files.pll_input_mat = fullfile(root_dir, 'data', ...
    'dat5_cc62M5_ch2_CIC_DCBlock_3M125.mat');
cfg.files.peak_mat = fullfile(root_dir, 'data', ...
    'dat5_cc62M5采样峰距离.mat');
cfg.files.replay_output_mat = fullfile(root_dir, 'data', ...
    'dat5_dpll_replay_result.mat');
cfg.files.validation_output_mat = fullfile(root_dir, 'data', ...
    'dat5_dpll_peak_validation.mat');

cfg.io.input_sample_range = [1 Inf];
cfg.io.source_raw_sample_rate_hz = 62500000;
cfg.io.source_samples_per_input = 20;
cfg.validation.slow_window_pulses = 21;

cfg.options.loop_enable = true;
cfg.options.store_iq = true;
cfg.options.abstract_fixed_pipeline_latency = false;
cfg.options.warn_on_saturation = true;
end
