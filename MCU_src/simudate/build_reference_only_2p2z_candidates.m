function candidates = build_reference_only_2p2z_candidates()
%BUILD_REFERENCE_ONLY_2P2Z_CANDIDATES Freeze the minimal causal test set.
%
% Candidate coefficients are derived analytically from the controller update
% rate. No captured reference or posterior peak data is read here.

base_cfg = dpll_recommended_config(20000);
% Match the audited 20260731 matrix capture window exactly. Leaving the
% default [1 Inf] here would silently run a longer waveform than the frozen
% P8/8 kHz baseline and invalidate the comparison.
base_cfg.io.input_sample_range = [1 4000000];
base_cfg.files.peak_mat = '';
base_cfg.files.validation_output_mat = '';
base_cfg.files.replay_output_mat = '';
update_rate_hz = base_cfg.input_sample_rate_hz / base_cfg.cic.rate;
baseline_p_gain = double(base_cfg.gains.kp_track) / ...
    2^base_cfg.shifts.p_product;

definitions = {
    'p8_iir8k_baseline', 'P8/8 kHz 基线', 0.00;
    'p8_iir8k_2p2z_wide', 'P8/8 kHz + 宽带 2P2Z', 0.75;
    'p8_iir8k_2p2z_safe', 'P8/8 kHz + 低增益 2P2Z', 0.40};
candidates = repmat(struct('id', '', 'label_cn', '', 'cfg', base_cfg, ...
    'design', struct()), size(definitions, 1), 1);

for k = 1:size(definitions, 1)
    cfg = base_cfg;
    fraction = definitions{k, 3};
    cfg.model_name = ['DPLL reference-only 2P2Z candidate ' definitions{k, 1}];
    if fraction > 0
        cfg.phase_2p2z = dpll.design_phase_2p2z_q( ...
            update_rate_hz, 75, 0.90, fraction * baseline_p_gain, ...
            22, cfg.phase_width);
        cfg.architecture.phase_2p2z_enable = true;
    end
    design.peak_gain_fraction_of_p8 = fraction;
    design.baseline_p_gain_word_per_phase_code = baseline_p_gain;
    design.center_frequency_hz = 75;
    design.quality_factor = 0.90;
    design.nominal_band_hz = [40 120];
    design.selection_inputs = ...
        'synthetic phase tones and reference-only exact-113 metrics';
    design.posterior_peak_data_allowed = false;
    candidates(k).id = definitions{k, 1};
    candidates(k).label_cn = definitions{k, 2};
    candidates(k).cfg = cfg;
    candidates(k).design = design;
end
end
