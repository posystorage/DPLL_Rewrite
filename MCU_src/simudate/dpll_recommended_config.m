function cfg = dpll_recommended_config(center_frequency_hz)
%DPLL_RECOMMENDED_CONFIG Reference-only selected P-shift-8 candidate.
%
% Hardware requirements:
%   P_PRODUCT_SHIFT = 8
%   post-IQ CIC output shift = 9
%   Kp_blend = 375000
% ARM register update:
%   TRACK IIR cutoff = 8 kHz (two existing cascaded sections)

if nargin < 1, center_frequency_hz = 20000; end
cfg = dpll_current_config(center_frequency_hz);
cfg.model_name = 'DPLL reference-only P-shift-8 candidate';
cfg.cic.output_shift = 9;
cfg.shifts.p_product = 8;
cfg.gains.kp_track = int64(6000000);
cfg.gains.ki_track = int64(2500000);
cfg.gains.kp_blend = int64(375000);
cfg.iir.track_cutoff_hz = 8000;
post_cic_rate_hz = cfg.input_sample_rate_hz / cfg.cic.rate;
cfg.iir.track = dpll.design_biquad_q30( ...
    cfg.iir.track_cutoff_hz, post_cic_rate_hz);
end
