function candidates = build_hdl_reproduction_candidates(center_frequency_hz)
%BUILD_HDL_REPRODUCTION_CANDIDATES Preregister HDL negative controls.
%
% No captured input or peak data is read here. The four cases distinguish
% literal wrapper-reset detector settings, the committed ARM operating
% profile, register-only improvements under the fixed P12 RTL, and the P8
% optimized configuration. All cases explicitly disable 2P2Z.

if nargin < 1, center_frequency_hz = 20000; end

template = struct('id', '', 'label_cn', '', 'role_cn', '', ...
    'cfg', dpll_default_config(center_frequency_hz), ...
    'parameter_source_cn', '');
candidates = repmat(template, 4, 1);

% Case 1: literal wrapper detector reset values with the historical P12
% shift, combined with the current test Kp/Ki instead of power-on 4/2.
cfg = dpll_current_config(center_frequency_hz);
cfg.model_name = 'HDL wrapper reset detector with current test gains';
cfg.cic.rate = 31;
cfg.cic.output_shift = 10;
cfg.measurement_timeout_ticks = 2400 * cfg.cic.rate + 512;
cfg.iir.mode = 3;
cfg.iir.sections = 2;
cfg.iir.acquire_cutoff_hz = 15000;
cfg.iir.track_cutoff_hz = 8000;
cfg.iir.acquire = literal_coefficients( ...
    138975519, 277951039, 138975519, -812870960, 295031213);
cfg.iir.track = literal_coefficients( ...
    48851600, 97703199, 48851600, -1409400772, 531065347);
cfg.shifts.p_product = 12;
cfg.gains.kp_blend = int64(6000000);
cfg = disable_2p2z(cfg);
candidates(1) = make_candidate('rtl_reset_detector_p12', ...
    'RTL复位检测链 + P12', ...
    '源码字面负对照，不冒充ARM运行profile', cfg, ...
    ['dpll_wrapper.v: R31/shift10/15k+8k; historical P12; ' ...
    'Kp/Ki采用当前测试6M/2.5M']);

% Case 2: pre-update ARM 20 kHz profile retained as a historical negative
% control after the P8 hardware update.
cfg = dpll_default_config(center_frequency_hz);
cfg.model_name = 'Pre-update ARM operating profile with fixed P12 RTL';
cfg.cic.output_shift = 8;
cfg.iir.track_cutoff_hz = 2000;
post_cic_rate_hz = cfg.input_sample_rate_hz / cfg.cic.rate;
cfg.iir.track = dpll.design_biquad_q30( ...
    cfg.iir.track_cutoff_hz, post_cic_rate_hz);
cfg.shifts.p_product = 12;
cfg.gains.kp_blend = int64(6000000);
cfg = disable_2p2z(cfg);
candidates(2) = make_candidate('arm_operating_profile_p12', ...
    '更新前ARM工作profile + P12', ...
    '更新前实机软件工作配置', cfg, ...
    ['dpll_profile.c: R16/shift8/acquire4k/track2k, ' ...
    'Kp=6M, Ki=180k; historical fixed RTL P12']);

% Case 3: every register-controlled improvement is enabled, while the RTL
% P shift remains 12. This is the strongest negative control for whether a
% P8 RTL change is genuinely required.
cfg = dpll_recommended_config(center_frequency_hz);
cfg.model_name = 'Register optimized but constrained to fixed P12 RTL';
cfg.shifts.p_product = 12;
cfg.gains.kp_blend = int64(6000000);
cfg = disable_2p2z(cfg);
candidates(3) = make_candidate('register_optimized_p12', ...
    '寄存器优化但仍为P12', ...
    '与最终配置同寄存器，仅保留旧RTL P12', cfg, ...
    'R16/shift9/track8k/Kp6M/Ki2.5M; fixed RTL P12');

% Case 4: current selected FPGA-realizable baseline, without 2P2Z.
cfg = dpll_recommended_config(center_frequency_hz);
cfg.model_name = 'Optimized P8 baseline without 2P2Z';
cfg = disable_2p2z(cfg);
candidates(4) = make_candidate('optimized_p8_no_2p2z', ...
    '最终P8优化（无2P2Z）', ...
    '待验证的优化正对照', cfg, ...
    'R16/shift9/track8k/Kp6M/Ki2.5M/Kp_blend375k; P8');

for k = 1:numel(candidates)
    if candidates(k).cfg.architecture.phase_2p2z_enable
        error('dpll:HdlAudit2p2zEnabled', ...
            'HDL reproduction case unexpectedly enables 2P2Z.');
    end
end
end

function candidate = make_candidate(id, label, role, cfg, source)
candidate.id = id;
candidate.label_cn = label;
candidate.role_cn = role;
candidate.cfg = cfg;
candidate.parameter_source_cn = source;
end

function cfg = disable_2p2z(cfg)
cfg.architecture.phase_2p2z_enable = false;
cfg.phase_2p2z.enabled = false;
cfg.phase_2p2z.b0 = int64(0);
cfg.phase_2p2z.b1 = int64(0);
cfg.phase_2p2z.b2 = int64(0);
cfg.phase_2p2z.a1 = int64(0);
cfg.phase_2p2z.a2 = int64(0);
end

function coeff = literal_coefficients(b0, b1, b2, a1, a2)
coeff.b0 = int64(b0);
coeff.b1 = int64(b1);
coeff.b2 = int64(b2);
coeff.a1 = int64(a1);
coeff.a2 = int64(a2);
end
