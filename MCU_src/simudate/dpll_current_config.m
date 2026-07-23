function cfg = dpll_current_config(center_frequency_hz)
%DPLL_CURRENT_CONFIG Current hardware test preset (Kp=6M, Ki=2.5M).

if nargin < 1
    center_frequency_hz = 20000;
end
cfg = dpll_default_config(center_frequency_hz);
cfg.model_name = 'DPLL current hardware preset replay';
cfg.gains.kp_track = int64(6000000);
cfg.gains.ki_track = int64(2500000);
end
