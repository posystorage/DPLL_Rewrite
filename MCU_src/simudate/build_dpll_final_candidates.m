function candidates = build_dpll_final_candidates(base_cfg)
%BUILD_DPLL_FINAL_CANDIDATES Freeze finalists before posterior validation.

ids = {'baseline_p1_ki2p5', 'p4_ki2p5', 'p8_ki0p625', ...
    'p8_ki1p25', 'p8_ki2p5'};
p_shifts = [12 10 9 9 9];
ki_values = [2500000 2500000 625000 1250000 2500000];
candidates = repmat(struct('id', '', 'cfg', base_cfg), numel(ids), 1);
for k = 1:numel(ids)
    candidates(k).id = ids{k};
    candidates(k).cfg = base_cfg;
    candidates(k).cfg.shifts.p_product = p_shifts(k);
    candidates(k).cfg.gains.ki_track = int64(ki_values(k));
    candidates(k).cfg.gains.kp_blend = int64(round(6000000 / ...
        2^(12 - p_shifts(k))));
    candidates(k).cfg.model_name = ['DPLL frozen candidate ' ids{k}];
end
end
