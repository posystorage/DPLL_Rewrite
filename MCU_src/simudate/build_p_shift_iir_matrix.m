function candidates = build_p_shift_iir_matrix(base_cfg)
%BUILD_P_SHIFT_IIR_MATRIX Build the controlled P-shift/IIR 2-by-2 matrix.

ids = {'p9_iir2k', 'p9_iir8k', 'p8_iir2k', 'p8_iir8k'};
labels = {'P9 / 2 kHz', 'P9 / 8 kHz', ...
    'P8 / 2 kHz', 'P8 / 8 kHz'};
p_shift = [9 9 8 8];
cutoff_hz = [2000 8000 2000 8000];
candidates = repmat(struct('id', '', 'label', '', 'cfg', base_cfg), ...
    numel(ids), 1);
post_cic_rate_hz = base_cfg.input_sample_rate_hz / base_cfg.cic.rate;

for k = 1:numel(ids)
    cfg = base_cfg;
    cfg.shifts.p_product = p_shift(k);
    cfg.gains.kp_blend = int64(round(6000000 / 2^(12 - p_shift(k))));
    cfg.iir.track_cutoff_hz = cutoff_hz(k);
    cfg.iir.track = dpll.design_biquad_q30( ...
        cutoff_hz(k), post_cic_rate_hz);
    cfg.model_name = ['DPLL matrix candidate ' labels{k}];
    candidates(k).id = ids{k};
    candidates(k).label = labels{k};
    candidates(k).cfg = cfg;
end
end
