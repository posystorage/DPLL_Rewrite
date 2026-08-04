function cfg = dpll_optimized_config(center_frequency_hz)
%DPLL_OPTIMIZED_CONFIG Frozen high-frequency-tracking candidate.
%
% Hardware requirements:
%   dpll_single_clock_core_stage_a.v: P_PRODUCT_SHIFT 12 -> 9
%   ARM registers: post-IQ CIC shift 9 and Kp_blend 750000.

if nargin < 1, center_frequency_hz = 20000; end
cfg = dpll_current_config(center_frequency_hz);
cfg.model_name = 'DPLL optimized high-frequency tracking preset';
cfg.cic.output_shift = 9;
cfg.shifts.p_product = 9;
cfg.gains.kp_track = int64(6000000);
cfg.gains.ki_track = int64(2500000);
cfg.gains.kp_blend = int64(750000);
end
