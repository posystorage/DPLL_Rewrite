function cases = build_dpll_investigation_cases(base_cfg, layer_name)
%BUILD_DPLL_INVESTIGATION_CASES Define reproducible diagnostic case matrices.

switch lower(layer_name)
    case 'layer1'
        cases = build_layer1(base_cfg);
    case 'layer2'
        cases = build_layer2(base_cfg);
    case 'layer3p'
        cases = build_layer3p(base_cfg);
    case 'layer3i'
        cases = build_layer3i(base_cfg);
    case 'layer3s'
        cases = build_layer3s(base_cfg);
    case 'layer3n'
        cases = build_layer3n(base_cfg);
    otherwise
        error('dpll:UnknownInvestigationLayer', ...
            'Unknown investigation layer: %s', layer_name);
end
cases = cases(:);
end

function cases = build_layer3n(base_cfg)
cases = repmat(empty_case(), 0, 1);
coefficients = int64([-838861 -1677722 -3355443]);
config_ids = {'ffm0p125', 'ffm0p25', 'ffm0p5'};
for config_index = 1:numel(coefficients)
    run_cfg = base_cfg;
    run_cfg.gains.kf_track = int64(0);
    run_cfg.architecture.fll_feedforward_enable = true;
    run_cfg.gains.kff_track = coefficients(config_index);
    for fm = [40 60 80]
        settle_s = 1 / fm;
        measurement_s = 0.25;
        duration_s = 0.08 + settle_s + measurement_s;
        spec = make_spec(base_cfg, fm, 0.03, duration_s);
        case_id = sprintf('l3n_%s_fm%03d', config_ids{config_index}, fm);
        cases(end + 1) = make_case(case_id, 'layer3n', ...
            config_ids{config_index}, run_cfg, spec, ...
            0.08 + settle_s, duration_s); %#ok<AGROW>
    end
end
end

function cases = build_layer3s(base_cfg)
cases = repmat(empty_case(), 0, 1);
configs = repmat(struct('id', '', 'cfg', base_cfg), 8, 1);
configs(1).id = 'baseline';
configs(1).cfg = base_cfg;
configs(2).id = 'multirate_kf250k';
configs(2).cfg = base_cfg;
configs(2).cfg.architecture.controller_update_mode = ...
    'phase_each_fll_block_once';
configs(3).id = 'multirate_kf4m';
configs(3).cfg = configs(2).cfg;
configs(3).cfg.gains.kf_track = int64(4000000);
configs(4).id = 'phase_lead8';
configs(4).cfg = base_cfg;
configs(4).cfg.architecture.phase_lead_samples = 8;
configs(5).id = 'phase_lead16';
configs(5).cfg = base_cfg;
configs(5).cfg.architecture.phase_lead_samples = 16;
configs(6).id = 'ff0p25';
configs(6).cfg = base_cfg;
configs(6).cfg.gains.kf_track = int64(0);
configs(6).cfg.architecture.fll_feedforward_enable = true;
configs(6).cfg.gains.kff_track = int64(1677722);
configs(7).id = 'ff0p5';
configs(7).cfg = configs(6).cfg;
configs(7).cfg.gains.kff_track = int64(3355443);
configs(8).id = 'ff1p0';
configs(8).cfg = configs(6).cfg;
configs(8).cfg.gains.kff_track = int64(6710886);

for config_index = 1:numel(configs)
    for fm = [40 60 80]
        settle_s = 1 / fm;
        measurement_s = 0.25;
        duration_s = 0.08 + settle_s + measurement_s;
        spec = make_spec(base_cfg, fm, 0.03, duration_s);
        case_id = sprintf('l3s_%s_fm%03d', configs(config_index).id, fm);
        cases(end + 1) = make_case(case_id, 'layer3s', ...
            configs(config_index).id, configs(config_index).cfg, spec, ...
            0.08 + settle_s, duration_s); %#ok<AGROW>
    end
end
end

function cases = build_layer3i(base_cfg)
cases = repmat(empty_case(), 0, 1);
ki_values = [0 625000 1250000 2500000 5000000];
config_ids = {'ki0', 'ki0p625m', 'ki1p25m', 'ki2p5m', 'ki5m'};
for config_index = 1:numel(ki_values)
    run_cfg = base_cfg;
    run_cfg.shifts.p_product = 9;
    run_cfg.gains.ki_track = int64(ki_values(config_index));
    for fm = [10 20 40 60 80]
        settle_s = 1 / fm;
        measurement_s = 0.25;
        duration_s = 0.08 + settle_s + measurement_s;
        spec = make_spec(base_cfg, fm, 0.03, duration_s);
        case_id = sprintf('l3i_%s_fm%03d', config_ids{config_index}, fm);
        cases(end + 1) = make_case(case_id, 'layer3i', ...
            config_ids{config_index}, run_cfg, spec, ...
            0.08 + settle_s, duration_s); %#ok<AGROW>
    end
end
end

function cases = build_layer3p(base_cfg)
cases = repmat(empty_case(), 0, 1);
configs = repmat(struct('id', '', 'cfg', base_cfg), 5, 1);
configs(1).id = 'p1_baseline';
configs(1).cfg = base_cfg;
configs(2).id = 'p1p398_kpmax';
configs(2).cfg = base_cfg;
configs(2).cfg.gains.kp_track = int64(8388607);
configs(3).id = 'p2_shift11';
configs(3).cfg = base_cfg;
configs(3).cfg.shifts.p_product = 11;
configs(4).id = 'p4_shift10';
configs(4).cfg = base_cfg;
configs(4).cfg.shifts.p_product = 10;
configs(5).id = 'p8_shift9';
configs(5).cfg = base_cfg;
configs(5).cfg.shifts.p_product = 9;

for config_index = 1:numel(configs)
    for fm = [20 40 60 80]
        settle_s = 1 / fm;
        measurement_s = 0.25;
        duration_s = 0.08 + settle_s + measurement_s;
        spec = make_spec(base_cfg, fm, 0.03, duration_s);
        case_id = sprintf('l3p_%s_fm%03d', configs(config_index).id, fm);
        cases(end + 1) = make_case(case_id, 'layer3p', ...
            configs(config_index).id, configs(config_index).cfg, spec, ...
            0.08 + settle_s, duration_s); %#ok<AGROW>
    end
end
end

function cases = build_layer1(base_cfg)
cases = repmat(empty_case(), 0, 1);
pure_spec = make_spec(base_cfg, 80, 0, 0.60);
cases(end + 1) = make_case('l1_autonomous', 'layer1', ...
    'baseline', base_cfg, pure_spec, 0.12, pure_spec.duration_s); %#ok<AGROW>

frequencies_hz = [40 60 80];
phase_amplitudes_rad = [0.03 0.075 0.15];
for beta = phase_amplitudes_rad
    for fm = frequencies_hz
        settle_s = 1 / fm;
        measurement_s = 0.25;
        duration_s = 0.08 + settle_s + measurement_s;
        spec = make_spec(base_cfg, fm, beta, duration_s);
        case_id = sprintf('l1_fm%03d_b%s', fm, number_token(beta));
        cases(end + 1) = make_case(case_id, 'layer1', 'baseline', ...
            base_cfg, spec, 0.08 + settle_s, duration_s); %#ok<AGROW>
    end
end
end

function cases = build_layer2(base_cfg)
cases = repmat(empty_case(), 0, 1);
configs = repmat(struct('id', '', 'cfg', base_cfg), 5, 1);
configs(1).id = 'full_loop';
configs(1).cfg = base_cfg;
configs(2).id = 'pi_only';
configs(2).cfg = base_cfg;
configs(2).cfg.gains.kf_track = int64(0);
configs(3).id = 'fll_62k5';
configs(3).cfg = base_cfg;
configs(3).cfg.gains.kf_track = int64(62500);
configs(4).id = 'fll_125k';
configs(4).cfg = base_cfg;
configs(4).cfg.gains.kf_track = int64(125000);
configs(5).id = 'fll_only';
configs(5).cfg = base_cfg;
configs(5).cfg.gains.kp_track = int64(0);
configs(5).cfg.gains.ki_track = int64(0);

for config_index = 1:numel(configs)
    for fm = [40 60 80]
        settle_s = 1 / fm;
        measurement_s = 0.25;
        duration_s = 0.08 + settle_s + measurement_s;
        spec = make_spec(base_cfg, fm, 0.05, duration_s);
        case_id = sprintf('l2_%s_fm%03d', configs(config_index).id, fm);
        cases(end + 1) = make_case(case_id, 'layer2', ...
            configs(config_index).id, configs(config_index).cfg, spec, ...
            0.08 + settle_s, duration_s); %#ok<AGROW>
    end
end
end

function spec = make_spec(cfg, fm, beta, duration_s)
spec.sample_rate_hz = cfg.input_sample_rate_hz;
spec.carrier_frequency_hz = cfg.center_frequency_hz;
spec.modulation_frequency_hz = fm;
spec.phase_modulation_rad = beta;
spec.carrier_lead_s = 0.08;
spec.duration_s = duration_s;
spec.amplitude_codes = 6000;
end

function item = make_case(case_id, layer, config_id, cfg, spec, start_s, end_s)
item = empty_case();
item.case_id = string(case_id);
item.layer = string(layer);
item.config_id = string(config_id);
item.measurement_start_s = start_s;
item.measurement_end_s = end_s;
item.spec = spec;
item.cfg = cfg;
end

function item = empty_case()
item.case_id = "";
item.layer = "";
item.config_id = "";
item.measurement_start_s = NaN;
item.measurement_end_s = NaN;
item.spec = struct();
item.cfg = struct();
end

function token = number_token(value)
token = strrep(sprintf('%.3f', value), '.', 'p');
end
