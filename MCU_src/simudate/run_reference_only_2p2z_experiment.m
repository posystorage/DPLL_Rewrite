function experiment = run_reference_only_2p2z_experiment( ...
    candidates, output_dir, options)
%RUN_REFERENCE_ONLY_2P2Z_EXPERIMENT Causal 2P2Z discrimination experiment.
%
% This entry point deliberately has no peak-file argument. Candidate
% coefficients are frozen before the captured reference waveform is loaded,
% and selection uses only synthetic tones plus exact-reference-cycle events.

arguments
    candidates (:,1) struct
    output_dir (1,1) string
    options (1,1) struct = struct()
end
options = apply_defaults(options);
guard_new_output_directory(output_dir);
paths = create_output_tree(output_dir);

freeze.created_at = timestamp_now();
freeze.candidates = candidates;
freeze.selection_policy = ...
    'synthetic stability gate, then minimum reference-only exact-113 RMS';
freeze.posterior_peak_data_loaded = false;
freeze.posterior_peak_data_allowed_for_selection = false;
save(fullfile(output_dir, 'candidate_freeze.mat'), ...
    'freeze', 'candidates', '-v7.3');
coefficient_table = build_coefficient_table(candidates);
writetable(coefficient_table, fullfile(paths.tables, ...
    'controller_coefficients.csv'));

fprintf('\n[1/3] 运行无后验多音相位调制判别...\n');
[synthetic_response, synthetic_summary, synthetic_files, synthetic_spec] = ...
    run_synthetic_gate(candidates, paths, options);
writetable(synthetic_response, fullfile(paths.tables, ...
    'synthetic_frequency_response.csv'));
writetable(synthetic_summary, fullfile(paths.tables, ...
    'synthetic_candidate_summary.csv'));

fprintf('\n[2/3] 运行冻结真实参考 replay（基线复用，不重跑旧矩阵）...\n');
[real_metrics, segment_metrics, interval_series, real_files, ...
    real_results, exact_validations, provenance] = run_real_reference_stage( ...
    candidates, synthetic_summary, paths, options, freeze);
writetable(real_metrics, fullfile(paths.tables, 'combined_metrics.csv'));
writetable(segment_metrics, fullfile(paths.tables, 'segment_metrics.csv'));
writetable(interval_series, fullfile(paths.tables, 'interval_series.csv'));
writetable(struct2table(provenance), fullfile(paths.tables, 'provenance.csv'));

[selected_index, selection] = select_candidate(real_metrics);
selected_result = real_results{selected_index};
selected_exact = exact_validations{selected_index};
selected_series = build_controller_series(selected_result, ...
    candidates(selected_index).id, options.maximum_plot_points);
writetable(selected_series, fullfile(paths.tables, ...
    'selected_controller_time_series.csv'));

fprintf('\n[3/3] 生成中文图、报告和冻结 MAT...\n');
figure_files = make_chinese_figures(real_metrics, synthetic_response, ...
    candidates, selected_index, selected_result, selected_exact, paths.figures);
report_path = write_chinese_report(output_dir, real_metrics, ...
    synthetic_summary, coefficient_table, selection, provenance);

experiment.schema_version = 1;
experiment.created_at = timestamp_now();
experiment.output_directory = char(output_dir);
experiment.candidate_freeze = freeze;
experiment.candidates = candidates;
experiment.coefficient_table = coefficient_table;
experiment.synthetic_spec = synthetic_spec;
experiment.synthetic_response = synthetic_response;
experiment.synthetic_summary = synthetic_summary;
experiment.real_metrics = real_metrics;
experiment.segment_metrics = segment_metrics;
experiment.interval_series = interval_series;
experiment.synthetic_raw_files = synthetic_files;
experiment.real_raw_files = real_files;
experiment.selected_candidate_id = selection.selected_candidate_id;
experiment.selection = selection;
experiment.provenance = provenance;
experiment.figure_files = figure_files;
experiment.report_path = report_path;
experiment.posterior_peak_data_loaded = false;
experiment.posterior_peak_data_used_for_selection = false;
save(fullfile(output_dir, 'reference_only_2p2z_experiment.mat'), ...
    'experiment', '-v7.3');
fprintf('实验完成，reference-only 选择结果：%s\n', ...
    selection.selected_candidate_id);
end

function [response_table, summary_table, raw_files, spec] = ...
    run_synthetic_gate(candidates, paths, options)
base_cfg = candidates(1).cfg;
resume_input = fullfile(options.resume_source_dir, 'raw', ...
    'synthetic_multitone_input.mat');
if strlength(string(options.resume_source_dir)) > 0 && isfile(resume_input)
    frozen_input = load(resume_input, 'input_data', 'truth', 'spec');
    input_data = frozen_input.input_data;
    truth = frozen_input.truth;
    spec = frozen_input.spec;
    copyfile(resume_input, fullfile(paths.raw, 'synthetic_multitone_input.mat'));
else
    spec.sample_rate_hz = base_cfg.input_sample_rate_hz;
    spec.carrier_frequency_hz = base_cfg.center_frequency_hz;
    spec.duration_s = options.synthetic_duration_s;
    spec.amplitude_codes = 6000;
    spec.phase_tone_hz = options.synthetic_tones_hz;
    spec.phase_tone_rad = options.synthetic_phase_tone_rad * ...
        ones(size(options.synthetic_tones_hz));
    spec.am_tone_hz = [];
    spec.am_depth = [];
    spec.second_harmonic_ratio = 0;
    spec.third_harmonic_ratio = 0;
    spec.noise_rms_codes = 0;
    spec.random_seed = 1;
    [input_data, truth] = generate_multitone_reference_input(spec);
    save(fullfile(paths.raw, 'synthetic_multitone_input.mat'), ...
        'input_data', 'truth', 'spec', '-v7.3');
end

response_rows = repmat(struct(), 0, 1);
summary_rows = repmat(struct(), 0, 1);
raw_files = strings(numel(candidates), 1);
for k = 1:numel(candidates)
    fprintf('  合成判别 %d/%d: %s\n', k, numel(candidates), candidates(k).id);
    resume_file = fullfile(options.resume_source_dir, 'raw', sprintf( ...
        '%s_synthetic.mat', candidates(k).id));
    if strlength(string(options.resume_source_dir)) > 0 && isfile(resume_file)
        frozen = load(resume_file, 'result', 'rows', 'summary');
        result = frozen.result;
        rows = frozen.rows;
        summary = frozen.summary;
    else
        cfg = candidates(k).cfg;
        cfg.options.warn_on_saturation = false;
        result = simulate_dpll(input_data, cfg);
        assert_reference_only_result(result);
        [rows, summary] = analyze_multitone_result( ...
            candidates(k), result, truth, options);
    end
    response_rows = append_rows(response_rows, rows);
    summary_rows = append_rows(summary_rows, summary);
    raw_file = fullfile(paths.raw, sprintf('%s_synthetic.mat', ...
        candidates(k).id));
    raw_files(k) = string(raw_file);
    if strlength(string(options.resume_source_dir)) > 0 && isfile(resume_file)
        copyfile(resume_file, raw_file);
    else
        save(raw_file, 'result', 'truth', 'spec', 'rows', 'summary', '-v7.3');
    end
end
response_table = struct2table(response_rows);
summary_table = struct2table(summary_rows);
end

function [rows, summary] = analyze_multitone_result(candidate, result, ...
    truth, options)
valid = result.trace.analysis_valid & ...
    result.trace.time_s >= options.synthetic_analysis_start_s;
time_s = result.trace.time_s(valid);
phase_scale = pi / 2^(result.config.phase_width - 1);
phase_error_rad = double(result.trace.phase_error(valid)) * phase_scale;
output_frequency_hz = result.trace.tracking_frequency_hz(valid);
rows = repmat(struct(), 0, 1);
phase_error_amplitudes = zeros(numel(truth.phase_tone_hz), 1);
for tone_index = 1:numel(truth.phase_tone_hz)
    frequency_hz = truth.phase_tone_hz(tone_index);
    phase_amplitude = truth.spec.phase_tone_rad(tone_index);
    input_phase = phase_amplitude * sin(2 * pi * frequency_hz * time_s);
    input_frequency = result.config.center_frequency_hz + ...
        phase_amplitude * frequency_hz * cos(2 * pi * frequency_hz * time_s);
    input_phase_fit = dpll.fit_tone(time_s, input_phase, frequency_hz);
    phase_error_fit = dpll.fit_tone(time_s, phase_error_rad, frequency_hz);
    input_frequency_fit = dpll.fit_tone(time_s, input_frequency, frequency_hz);
    output_frequency_fit = dpll.fit_tone( ...
        time_s, output_frequency_hz, frequency_hz);
    phase_residual = phase_error_fit.phasor / input_phase_fit.phasor;
    closed_loop = output_frequency_fit.phasor / input_frequency_fit.phasor;
    row.candidate_id = string(candidate.id);
    row.candidate_label_cn = string(candidate.label_cn);
    row.modulation_frequency_hz = frequency_hz;
    row.input_phase_amplitude_rad = phase_amplitude;
    row.phase_error_amplitude_rad = phase_error_fit.amplitude;
    row.phase_residual_gain = abs(phase_residual);
    row.phase_residual_gain_db = ratio_db(abs(phase_residual));
    row.phase_residual_phase_deg = rad2deg(angle(phase_residual));
    row.closed_loop_gain = abs(closed_loop);
    row.closed_loop_gain_db = ratio_db(abs(closed_loop));
    row.closed_loop_phase_deg = rad2deg(angle(closed_loop));
    row.output_fit_r_squared = output_frequency_fit.r_squared;
    row.phase_fit_r_squared = phase_error_fit.r_squared;
    rows = append_rows(rows, row);
    phase_error_amplitudes(tone_index) = phase_error_fit.amplitude;
end
band = truth.phase_tone_hz >= 40 & truth.phase_tone_hz <= 120;
phase_rms = rms_plain(phase_error_rad);
controller_saturation_count = result.status.controller_saturation_high_count + ...
    result.status.controller_saturation_low_count;
two_p_two_z_saturation_count = result.status.phase_2p2z_saturation_high_count + ...
    result.status.phase_2p2z_saturation_low_count;
summary.candidate_id = string(candidate.id);
summary.candidate_label_cn = string(candidate.label_cn);
summary.band_40_120_combined_residual_gain = sqrt(sum( ...
    phase_error_amplitudes(band).^2) / sum(truth.spec.phase_tone_rad(band).^2));
summary.band_40_120_combined_residual_gain_db = ...
    ratio_db(summary.band_40_120_combined_residual_gain);
summary.band_40_120_worst_residual_gain_db = max( ...
    [rows(band).phase_residual_gain_db]);
summary.phase_rms_rad = phase_rms;
summary.track_fraction = mean(result.trace.loop_state(valid) == 6);
summary.controller_saturation_count = controller_saturation_count;
summary.phase_2p2z_saturation_count = two_p_two_z_saturation_count;
summary.cordic_out_of_range_count = nnz(result.trace.cordic_out_of_range(valid));
summary.stability_gate_passed = summary.track_fraction > 0.99 && ...
    controller_saturation_count == 0 && two_p_two_z_saturation_count == 0 && ...
    summary.cordic_out_of_range_count == 0 && phase_rms < 0.1;
summary.posterior_data_used = false;
end

function [metrics, segments, intervals, raw_files, results, exacts, ...
    provenance] = run_real_reference_stage(candidates, synthetic_summary, ...
    paths, options, freeze)
baseline_path = string(options.frozen_baseline_file);
if ~isfile(baseline_path)
    error('dpll:FrozenBaselineMissing', ...
        'Frozen P8/8 kHz baseline not found: %s', baseline_path);
end
source_path = string(candidates(1).cfg.files.pll_input_mat);
source_hash = dpll.file_sha256(source_path);
input_data = load_input_mat(source_path, candidates(1).cfg.io.input_sample_range);

metric_rows = repmat(struct(), 0, 1);
segment_rows = repmat(struct(), 0, 1);
interval_rows = repmat(struct(), 0, 1);
raw_files = strings(numel(candidates), 1);
results = cell(numel(candidates), 1);
exacts = cell(numel(candidates), 1);
for k = 1:numel(candidates)
    fprintf('  真实参考 %d/%d: %s\n', k, numel(candidates), candidates(k).id);
    resume_file = fullfile(options.resume_source_dir, 'raw', sprintf( ...
        '%s_real_reference.mat', candidates(k).id));
    resume_available = strlength(string(options.resume_source_dir)) > 0 && ...
        isfile(resume_file);
    resumed = false;
    baseline_reused = k == 1 && options.reuse_frozen_baseline;
    if resume_available
        resume_probe = load(resume_file, 'result', 'summary', ...
            'baseline_reused');
        resumed = real_replay_is_compatible(resume_probe.result, ...
            candidates(k).cfg);
        if resumed
            result = resume_probe.result;
            summary = resume_probe.summary;
            if isfield(resume_probe, 'baseline_reused')
                baseline_reused = resume_probe.baseline_reused;
            end
        else
            fprintf('    跳过不兼容的续跑文件（配置或样本范围不一致）\n');
            clear resume_probe;
        end
    end
    if ~resumed && baseline_reused
        frozen = load(baseline_path, 'result', 'summary');
        result = frozen.result;
        summary = frozen.summary;
        verify_frozen_baseline(result, candidates(k).cfg, source_hash);
    elseif ~resumed
        run_cfg = candidates(k).cfg;
        run_cfg.options.warn_on_saturation = false;
        result = simulate_dpll(input_data, run_cfg);
        summary = analyze_dpll_result(result, false);
    end
    assert_reference_only_result(result);
    exact = validate_exact_reference_cycle_events(result, ...
        options.exact_event_margin_s);
    raw_file = fullfile(paths.raw, sprintf('%s_real_reference.mat', ...
        candidates(k).id));
    raw_files(k) = string(raw_file);
    candidate_freeze_time = freeze.created_at; %#ok<NASGU>
    save(raw_file, 'result', 'summary', 'exact', 'source_hash', ...
        'baseline_reused', 'candidate_freeze_time', '-v7.3');
    results{k} = result;
    exacts{k} = exact;
    synthetic = synthetic_summary(k, :);
    metric_rows = append_rows(metric_rows, build_real_metric_row( ...
        candidates(k), result, summary, exact, synthetic, baseline_reused));
    segment_rows = append_rows(segment_rows, attach_candidate_to_segments( ...
        candidates(k), exact.segment_metrics));
    interval_rows = append_rows(interval_rows, build_interval_rows( ...
        candidates(k), exact));
end
metrics = struct2table(metric_rows);
segments = struct2table(segment_rows);
intervals = struct2table(interval_rows);
source_info = dir(source_path);
baseline_info = dir(baseline_path);
provenance.created_at = string(timestamp_now());
provenance.reference_source_file = source_path;
provenance.reference_source_sha256 = string(source_hash);
provenance.reference_source_bytes = source_info.bytes;
provenance.input_sample_range = string(mat2str( ...
    candidates(1).cfg.io.input_sample_range));
provenance.frozen_baseline_file = baseline_path;
provenance.frozen_baseline_sha256 = string(dpll.file_sha256(baseline_path));
provenance.frozen_baseline_bytes = baseline_info.bytes;
provenance.candidate_freeze_time = string(freeze.created_at);
provenance.matlab_version = string(version);
provenance.posterior_peak_file_loaded = false;
provenance.posterior_peak_data_used_for_selection = false;
provenance.resume_source_directory = string(options.resume_source_dir);
end

function row = build_real_metric_row(candidate, result, summary, exact, ...
    synthetic, baseline_reused)
valid = result.trace.analysis_valid;
word_to_hz = result.config.fabric_clock_hz / 2^result.config.word_width;
two_p_two_z = trace_field_or_zero(result.trace, 'phase_2p2z_term');
two_p_two_z = double(two_p_two_z(valid));
row.candidate_id = string(candidate.id);
row.candidate_label_cn = string(candidate.label_cn);
row.baseline_reused = baseline_reused;
row.input_sample_count = result.metadata.input_sample_count;
row.analysis_duration_s = result.trace.time_s(find(valid, 1, 'last')) - ...
    result.trace.time_s(find(valid, 1, 'first'));
row.phase_2p2z_enabled = candidate.cfg.architecture.phase_2p2z_enable;
row.phase_2p2z_center_hz = candidate.cfg.phase_2p2z.center_frequency_hz;
row.phase_2p2z_quality_factor = candidate.cfg.phase_2p2z.quality_factor;
row.phase_2p2z_peak_gain_fraction_of_p8 = ...
    candidate.design.peak_gain_fraction_of_p8;
row.internal_phase_rms_mrad = 1e3 * summary.phase_rms_rad;
row.exact113_rms_cycles = exact.summary.pll_rms_cycles;
row.exact113_fast_rms_cycles = exact.summary.fast_rms_cycles;
row.exact113_slow_rms_cycles = exact.summary.slow_rms_cycles;
row.exact113_peak_to_peak_cycles = exact.summary.pll_peak_to_peak_cycles;
row.endpoint_delta_phase_rms_mrad = exact.summary.delta_phase_113_rms_mrad;
row.endpoint_delta_phase_peak_abs_mrad = ...
    exact.summary.delta_phase_113_peak_abs_mrad;
row.endpoint_delta_phase_p95_abs_mrad = ...
    exact.summary.delta_phase_113_p95_abs_mrad;
row.endpoint_delta_phase_over_3mrad_fraction = ...
    exact.summary.delta_phase_over_3mrad_fraction;
row.endpoint_equivalent_rms_cycles = ...
    exact.summary.equivalent_interval_rms_cycles;
row.endpoint_equivalent_peak_abs_cycles = ...
    exact.summary.equivalent_interval_peak_abs_cycles;
row.endpoint_equivalent_over_1cycle_fraction = ...
    exact.summary.equivalent_interval_over_1cycle_fraction;
row.endpoint_identity_rms_cycles = exact.summary.endpoint_identity_rms_cycles;
row.endpoint_prediction_correlation = ...
    exact.summary.endpoint_prediction_correlation;
row.dominant_event_frequency_hz = exact.summary.dominant_event_frequency_hz;
row.synthetic_band_40_120_residual_gain_db = ...
    synthetic.band_40_120_combined_residual_gain_db;
row.synthetic_worst_40_120_residual_gain_db = ...
    synthetic.band_40_120_worst_residual_gain_db;
row.synthetic_stability_gate_passed = synthetic.stability_gate_passed;
row.phase_2p2z_term_rms_hz = rms_plain(two_p_two_z) * word_to_hz;
row.phase_2p2z_term_peak_hz = max_abs(two_p_two_z) * word_to_hz;
row.controller_saturation_count = summary.controller_saturation_count;
row.phase_2p2z_saturation_count = status_field_or_zero( ...
    result.status, 'phase_2p2z_saturation_high_count') + ...
    status_field_or_zero(result.status, 'phase_2p2z_saturation_low_count');
row.track_fraction = summary.track_fraction;
row.posterior_data_used = false;
end

function rows = attach_candidate_to_segments(candidate, segment_table)
rows = repmat(struct(), 0, 1);
for k = 1:height(segment_table)
    source = table2struct(segment_table(k, :));
    source.candidate_id = string(candidate.id);
    source.candidate_label_cn = string(candidate.label_cn);
    ordered = orderfields(source, ...
        [{'candidate_id', 'candidate_label_cn'}, ...
        setdiff(fieldnames(source).', {'candidate_id', 'candidate_label_cn'}, ...
        'stable')]);
    rows = append_rows(rows, ordered);
end
end

function rows = build_interval_rows(candidate, exact)
count = numel(exact.pll_residual_error);
rows = repmat(struct(), 0, 1);
for k = 1:count
    row.candidate_id = string(candidate.id);
    row.candidate_label_cn = string(candidate.label_cn);
    row.interval_index = k;
    row.interval_end_time_s = exact.event_time_s(k + 1);
    row.pll_interval_error_cycles = exact.pll_residual_error(k);
    row.delta_phase_113_mrad = 1e3 * exact.delta_phase_113_rad(k);
    row.endpoint_equivalent_error_cycles = ...
        exact.equivalent_interval_error_cycles(k);
    row.slow_error_cycles = exact.slow_error(k);
    row.fast_error_cycles = exact.fast_error(k);
    rows = append_rows(rows, row);
end
end

function [selected_index, selection] = select_candidate(metrics)
eligible = metrics.synthetic_stability_gate_passed & ...
    metrics.controller_saturation_count == 0 & ...
    metrics.phase_2p2z_saturation_count == 0 & metrics.track_fraction > 0.99;
if ~any(eligible)
    error('dpll:NoStable2P2ZCandidate', ...
        'No candidate passed the causal synthetic/reference-only safety gate.');
end
score = metrics.exact113_rms_cycles;
score(~eligible) = Inf;
[~, selected_index] = min(score);
baseline_index = find(metrics.candidate_id == "p8_iir8k_baseline", 1);
selection.selected_candidate_id = metrics.candidate_id(selected_index);
selection.selection_metric = ...
    'minimum exact113_rms_cycles after synthetic stability gate';
selection.selected_exact113_rms_cycles = metrics.exact113_rms_cycles(selected_index);
selection.baseline_exact113_rms_cycles = metrics.exact113_rms_cycles(baseline_index);
selection.exact113_reduction_percent = 100 * ...
    (selection.baseline_exact113_rms_cycles - ...
    selection.selected_exact113_rms_cycles) / ...
    selection.baseline_exact113_rms_cycles;
selection.selected_endpoint_delta_phase_rms_mrad = ...
    metrics.endpoint_delta_phase_rms_mrad(selected_index);
selection.selected_endpoint_delta_phase_peak_abs_mrad = ...
    metrics.endpoint_delta_phase_peak_abs_mrad(selected_index);
selection.selected_endpoint_delta_phase_over_3mrad_fraction = ...
    metrics.endpoint_delta_phase_over_3mrad_fraction(selected_index);
selection.synthetic_stability_gate_passed = eligible(selected_index);
selection.posterior_peak_data_used = false;
end

function files = make_chinese_figures(metrics, response, candidates, ...
    selected_index, selected_result, selected_exact, figure_dir)
labels = metrics.candidate_label_cn;
x = 1:height(metrics);
fig = figure('Visible', 'off', 'Color', 'w', 'Name', '候选总体对比');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '参考输入独立的 DPLL 与宽带 2P2Z 对比');
nexttile; bar(x, metrics.exact113_rms_cycles);
ylabel('exact-113 均方根误差（周期）'); grid on;
set_candidate_ticks(x, labels);
nexttile; bar(x, metrics.endpoint_delta_phase_rms_mrad);
yline(3, '--r', '3 mrad 目标', 'LabelHorizontalAlignment', 'left');
ylabel('113 周期端点相位差 RMS（mrad）'); grid on;
set_candidate_ticks(x, labels);
nexttile; bar(x, metrics.internal_phase_rms_mrad);
ylabel('内部相位残差 RMS（mrad）'); grid on;
set_candidate_ticks(x, labels);
nexttile; bar(x, metrics.synthetic_band_40_120_residual_gain_db);
ylabel('40–120 Hz 合成相位残差增益（dB）'); grid on;
set_candidate_ticks(x, labels);
files.summary = export_chinese(fig, fullfile(figure_dir, ...
    '候选总体对比'), [9.0 7.0]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w', 'Name', '合成频率响应');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '无峰值后验的多音相位调制响应');
colors = lines(numel(candidates));
nexttile; hold on;
for k = 1:numel(candidates)
    rows = response(response.candidate_id == string(candidates(k).id), :);
    plot(rows.modulation_frequency_hz, rows.phase_residual_gain_db, ...
        'o-', 'Color', colors(k, :), 'LineWidth', 1.1, ...
        'DisplayName', candidates(k).label_cn);
end
xline(40, ':k', 'HandleVisibility', 'off');
xline(120, ':k', 'HandleVisibility', 'off');
ylabel('相位残差增益（dB）'); grid on; legend('Location', 'best');
nexttile; hold on;
for k = 1:numel(candidates)
    rows = response(response.candidate_id == string(candidates(k).id), :);
    plot(rows.modulation_frequency_hz, rows.closed_loop_gain_db, ...
        's-', 'Color', colors(k, :), 'LineWidth', 1.1, ...
        'DisplayName', candidates(k).label_cn);
end
xline(40, ':k', 'HandleVisibility', 'off');
xline(120, ':k', 'HandleVisibility', 'off');
yline(0, '--k', 'HandleVisibility', 'off');
xlabel('调制频率（Hz）'); ylabel('闭环频率增益（dB）'); grid on;
files.synthetic_response = export_chinese(fig, fullfile(figure_dir, ...
    '合成多音频率响应'), [8.6 6.8]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w', 'Name', '端点误差');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('选中配置：%s（严格参考输入独立）', ...
    candidates(selected_index).label_cn));
interval_time = selected_exact.event_time_s(2:end);
nexttile;
plot(interval_time, selected_exact.pll_residual_error, '-', ...
    'LineWidth', 1.0, 'DisplayName', '重建输出间距误差'); hold on;
plot(interval_time, selected_exact.equivalent_interval_error_cycles, '--', ...
    'LineWidth', 1.0, 'DisplayName', '端点相位差等效值');
yline(0, ':k', 'HandleVisibility', 'off');
ylabel('误差（输出周期）'); grid on; legend('Location', 'best');
nexttile;
plot(interval_time, 1e3 * selected_exact.delta_phase_113_rad, ...
    'LineWidth', 1.0);
yline(3, '--r', '+3 mrad'); yline(-3, '--r', '-3 mrad');
yline(0, ':k', 'HandleVisibility', 'off');
xlabel('时间（s）'); ylabel('端点相位差（mrad）'); grid on;
title(sprintf('|端点相位差| > 3 mrad：%.1f%%', 100 * mean( ...
    abs(selected_exact.delta_phase_113_rad) > 3e-3)));
files.endpoint = export_chinese(fig, fullfile(figure_dir, ...
    'exact113端点相位与间距误差'), [9.0 6.6]);
close(fig);

fig = plot_controller_variables(selected_result, ...
    candidates(selected_index).label_cn);
files.controller = export_chinese(fig, fullfile(figure_dir, ...
    '控制器重要变量'), [9.2 8.0]);
close(fig);
end

function fig = plot_controller_variables(result, label)
valid_indices = find(result.trace.analysis_valid);
stride = max(1, ceil(numel(valid_indices) / 5000));
indices = valid_indices(1:stride:end);
time_s = result.trace.time_s(indices);
phase_scale_mrad = 1e3 * pi / 2^(result.config.phase_width - 1);
word_to_hz = result.config.fabric_clock_hz / 2^result.config.word_width;
two_p_two_z = trace_field_or_zero(result.trace, 'phase_2p2z_term');
raw_control = trace_field_or_zero(result.trace, 'raw_control_phase_error');
fig = figure('Visible', 'off', 'Color', 'w', 'Name', '控制器重要变量');
layout = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('%s：TRACK 区间内部变量', label));
nexttile;
plot(time_s, double(result.trace.phase_error(indices)) * phase_scale_mrad);
ylabel('相位残差（mrad）'); grid on;
nexttile;
frequency = result.trace.tracking_frequency_hz(indices);
plot(time_s, frequency - median(frequency));
ylabel('跟踪频率偏差（Hz）'); grid on;
nexttile; hold on;
plot(time_s, double(result.trace.p_term(indices)) * word_to_hz, ...
    'DisplayName', 'P 项');
plot(time_s, double(result.trace.i_term(indices)) * word_to_hz, ...
    'DisplayName', 'I 项');
plot(time_s, double(result.trace.fll_term(indices)) * word_to_hz, ...
    'DisplayName', 'FLL 项');
plot(time_s, double(two_p_two_z(indices)) * word_to_hz, ...
    'DisplayName', '2P2Z 项');
ylabel('控制增量（Hz）'); grid on; legend('Location', 'best');
nexttile; hold on;
plot(time_s, double(raw_control(indices)) * phase_scale_mrad, ...
    'DisplayName', '控制器输入');
plot(time_s, double(result.trace.phase_error(indices)) * phase_scale_mrad, ...
    'DisplayName', '当前检测相位');
xlabel('时间（s）'); ylabel('相位观测（mrad）');
grid on; legend('Location', 'best');
end

function series = build_controller_series(result, candidate_id, maximum_points)
valid_indices = find(result.trace.analysis_valid);
stride = max(1, ceil(numel(valid_indices) / maximum_points));
indices = valid_indices(1:stride:end);
word_to_hz = result.config.fabric_clock_hz / 2^result.config.word_width;
phase_scale_mrad = 1e3 * pi / 2^(result.config.phase_width - 1);
two_p_two_z = trace_field_or_zero(result.trace, 'phase_2p2z_term');
series = table(repmat(string(candidate_id), numel(indices), 1), ...
    result.trace.time_s(indices), ...
    double(result.trace.phase_error(indices)) * phase_scale_mrad, ...
    result.trace.tracking_frequency_hz(indices), ...
    double(result.trace.p_term(indices)) * word_to_hz, ...
    double(result.trace.i_term(indices)) * word_to_hz, ...
    double(result.trace.fll_term(indices)) * word_to_hz, ...
    double(two_p_two_z(indices)) * word_to_hz, ...
    'VariableNames', {'candidate_id', 'time_s', 'phase_error_mrad', ...
    'tracking_frequency_hz', 'p_term_hz', 'i_term_hz', 'fll_term_hz', ...
    'phase_2p2z_term_hz'});
end

function table_value = build_coefficient_table(candidates)
rows = repmat(struct(), 0, 1);
for k = 1:numel(candidates)
    cfg = candidates(k).cfg.phase_2p2z;
    row.candidate_id = string(candidates(k).id);
    row.candidate_label_cn = string(candidates(k).label_cn);
    row.enabled = candidates(k).cfg.architecture.phase_2p2z_enable;
    row.topology = string(cfg.topology);
    row.update_rate_hz = cfg.sample_rate_hz;
    row.center_frequency_hz = cfg.center_frequency_hz;
    row.quality_factor = cfg.quality_factor;
    row.peak_gain_fraction_of_p8 = ...
        candidates(k).design.peak_gain_fraction_of_p8;
    row.coefficient_frac = cfg.coefficient_frac;
    row.coefficient_width = cfg.coefficient_width;
    row.input_width = cfg.input_width;
    row.output_width = cfg.output_width;
    row.accumulator_width = cfg.accumulator_width;
    row.b0 = cfg.b0; row.b1 = cfg.b1; row.b2 = cfg.b2;
    row.a1 = cfg.a1; row.a2 = cfg.a2;
    row.maximum_pole_radius = cfg.maximum_pole_radius;
    row.quantized_peak_gain_word_per_phase_code = ...
        cfg.quantized_peak_gain_word_per_phase_code;
    rows = append_rows(rows, row);
end
table_value = struct2table(rows);
end

function path = write_chinese_report(output_dir, metrics, synthetic, ...
    coefficients, selection, provenance)
path = fullfile(output_dir, 'reference_only_2p2z_report_cn.md');
file_id = fopen(path, 'w', 'n', 'UTF-8');
if file_id < 0
    error('dpll:ReportOpenFailed', '无法创建报告：%s', path);
end
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>
fprintf(file_id, '# DPLL 参考输入独立 2P2Z 最小判别实验\n\n');
fprintf(file_id, '生成时间：%s\n\n', timestamp_now());
fprintf(file_id, ['本实验没有加载采样峰位置或峰间距。候选系数先冻结，' ...
    '再运行合成多音和真实参考 replay；选择仅使用合成稳定性门控与 ' ...
    'exact-113 参考事件指标。\n\n']);
fprintf(file_id, '## 验收逻辑\n\n');
fprintf(file_id, ['- 第一层：PLL 内部相位残差、40–120 Hz 合成响应、' ...
    '控制器/2P2Z 饱和。\n']);
fprintf(file_id, ['- 第二层：每 113 个参考周期的端点相位差，以及按 ' ...
    '`-2000/(2*pi)*delta_phase` 换算的 226000 输出周期间距误差。\n']);
fprintf(file_id, ['- 这里的 exact-113 事件由参考相位自身定义，不是真实采样峰，' ...
    '因此不构成峰值后验闭环。\n\n']);
fprintf(file_id, ['| 候选 | exact-113 RMS（周期） | 端点 RMS（mrad） | ' ...
    '端点峰值（mrad） | 超过 3 mrad | 内部相位 RMS（mrad） | ' ...
    '40–120 Hz 残差（dB） | 饱和次数 |\n']);
fprintf(file_id, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(metrics)
    fprintf(file_id, '| %s | %.6f | %.6f | %.6f | %.2f%% | %.6f | %.3f | %d |\n', ...
        metrics.candidate_label_cn(k), metrics.exact113_rms_cycles(k), ...
        metrics.endpoint_delta_phase_rms_mrad(k), ...
        metrics.endpoint_delta_phase_peak_abs_mrad(k), ...
        100 * metrics.endpoint_delta_phase_over_3mrad_fraction(k), ...
        metrics.internal_phase_rms_mrad(k), ...
        metrics.synthetic_band_40_120_residual_gain_db(k), ...
        metrics.controller_saturation_count(k) + ...
        metrics.phase_2p2z_saturation_count(k));
end
fprintf(file_id, '\n## 冻结的 2P2Z 系数\n\n');
fprintf(file_id, '| 候选 | Q 格式 | b0 | b1 | b2 | a1 | a2 | 极点最大半径 |\n');
fprintf(file_id, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(coefficients)
    fprintf(file_id, '| %s | Q%d | %d | %d | %d | %d | %d | %.9f |\n', ...
        coefficients.candidate_label_cn(k), coefficients.coefficient_frac(k), ...
        coefficients.b0(k), coefficients.b1(k), coefficients.b2(k), ...
        coefficients.a1(k), coefficients.a2(k), ...
        coefficients.maximum_pole_radius(k));
end
fprintf(file_id, '\n## 判定\n\n');
fprintf(file_id, '选中配置：**%s**。\n\n', selection.selected_candidate_id);
fprintf(file_id, ['相对 P8/8 kHz 基线，exact-113 RMS 变化为 **%.3f%%**，' ...
    '选中配置端点相位差 RMS 为 **%.6f mrad**。\n\n'], ...
    selection.exact113_reduction_percent, ...
    selection.selected_endpoint_delta_phase_rms_mrad);
if selection.selected_endpoint_delta_phase_rms_mrad <= 3
    fprintf(file_id, ['选中配置的端点相位差 **RMS** 低于 3 mrad；' ...
        '但峰值绝对值仍为 **%.6f mrad**，且 **%.2f%%** 的事件超过 ' ...
        '3 mrad。因此这里只能判定 RMS 达标，不能判定逐事件间距已消除。\n\n'], ...
        selection.selected_endpoint_delta_phase_peak_abs_mrad, ...
        100 * selection.selected_endpoint_delta_phase_over_3mrad_fraction);
else
    fprintf(file_id, ['选中配置尚未满足 3 mrad 端点相位差目标，' ...
        '因此不能据此进入 HDL 修改。\n\n']);
end
fprintf(file_id, ['本阶段仍是 MATLAB 参考输入独立验证，不构成 HDL 修改放行；' ...
    '还需要在更长参考段和实际自适应采样链路上复核。\n\n']);
fprintf(file_id, '## 数据隔离与复现\n\n');
fprintf(file_id, '- 真实参考 SHA-256：`%s`\n', ...
    provenance.reference_source_sha256);
fprintf(file_id, '- 冻结基线 SHA-256：`%s`\n', ...
    provenance.frozen_baseline_sha256);
fprintf(file_id, '- 峰值后验加载：`false`\n');
fprintf(file_id, '- 峰值后验用于选择：`false`\n');
fprintf(file_id, '- MATLAB：`%s`\n\n', provenance.matlab_version);
fprintf(file_id, ['分段指标、逐事件序列、合成频响和控制器变量分别位于 ' ...
    '`tables/segment_metrics.csv`、`tables/interval_series.csv`、' ...
    '`tables/synthetic_frequency_response.csv` 和 ' ...
    '`tables/selected_controller_time_series.csv`。\n']);
end

function verify_frozen_baseline(result, cfg, source_hash)
if result.config.shifts.p_product ~= 8 || ...
        abs(result.config.iir.track_cutoff_hz - 8000) > eps
    error('dpll:FrozenBaselineMismatch', ...
        'Frozen baseline is not the audited P8/8 kHz replay.');
end

if result.config.gains.kp_track ~= cfg.gains.kp_track || ...
        result.config.gains.ki_track ~= cfg.gains.ki_track
    error('dpll:FrozenBaselineMismatch', ...
        'Frozen baseline PI gains do not match the candidate freeze.');
end
if isfield(result.metadata, 'source_file') && isfile(result.metadata.source_file)
    frozen_hash = dpll.file_sha256(result.metadata.source_file);
    if ~strcmpi(frozen_hash, source_hash)
        error('dpll:FrozenBaselineSourceMismatch', ...
            'Frozen baseline source hash differs from the current reference.');
    end
end
end

function compatible = real_replay_is_compatible(result, cfg)
compatible = isfield(result, 'metadata') && isfield(result, 'config') && ...
    result.config.shifts.p_product == cfg.shifts.p_product && ...
    result.config.gains.kp_track == cfg.gains.kp_track && ...
    result.config.gains.ki_track == cfg.gains.ki_track && ...
    abs(result.config.iir.track_cutoff_hz - cfg.iir.track_cutoff_hz) < eps;
range = double(cfg.io.input_sample_range);
if compatible && numel(range) == 2 && isfinite(range(2))
    compatible = result.metadata.input_sample_count == range(2) - range(1) + 1;
end
expected_2p2z = cfg.architecture.phase_2p2z_enable;
actual_2p2z = isfield(result.config, 'architecture') && ...
    isfield(result.config.architecture, 'phase_2p2z_enable') && ...
    result.config.architecture.phase_2p2z_enable;
if compatible && expected_2p2z ~= actual_2p2z
    compatible = false;
end
if compatible && expected_2p2z
    fields = {'b0', 'b1', 'b2', 'a1', 'a2', 'coefficient_frac'};
    compatible = isfield(result.config, 'phase_2p2z');
    for k = 1:numel(fields)
        compatible = compatible && ...
            result.config.phase_2p2z.(fields{k}) == cfg.phase_2p2z.(fields{k});
    end
end
end

function assert_reference_only_result(result)
if ~isfield(result, 'metadata') || ...
        ~isfield(result.metadata, 'posterior_interval_data_used') || ...
        result.metadata.posterior_interval_data_used
    error('dpll:PosteriorContamination', ...
        'Reference-only experiment encountered posterior interval data.');
end
end

function files = export_chinese(fig, base_path, size_inches)
files = dpll.export_paper_figure(fig, base_path, size_inches, ...
    'Microsoft YaHei');
end

function set_candidate_ticks(x, labels)
xticks(x); xticklabels(labels); xtickangle(16);
end

function value = trace_field_or_zero(trace, name)
if isfield(trace, name)
    value = trace.(name);
else
    value = zeros(size(trace.phase_error), 'int64');
end
end

function value = status_field_or_zero(status, name)
if isfield(status, name), value = status.(name); else, value = 0; end
end

function value = max_abs(values)
if isempty(values), value = NaN; else, value = max(abs(double(values))); end
end

function value = rms_plain(values)
values = double(values(:));
if isempty(values), value = NaN; else, value = sqrt(mean(values.^2)); end
end

function value = ratio_db(value)
value = 20 * log10(max(double(value), realmin));
end

function rows = append_rows(rows, additions)
if isempty(rows), rows = additions(:); else, rows = [rows; additions(:)]; end %#ok<AGROW>
end

function paths = create_output_tree(output_dir)
mkdir(output_dir);
paths.raw = fullfile(output_dir, 'raw');
paths.tables = fullfile(output_dir, 'tables');
paths.figures = fullfile(output_dir, 'figures');
mkdir(paths.raw); mkdir(paths.tables); mkdir(paths.figures);
end

function guard_new_output_directory(output_dir)
if ~isfolder(output_dir), return; end
entries = dir(output_dir);
entries = entries(~ismember({entries.name}, {'.', '..'}));
if ~isempty(entries)
    error('dpll:OutputDirectoryNotEmpty', ...
        'Refusing to overwrite existing results: %s', output_dir);
end
end

function options = apply_defaults(options)
root_dir = fileparts(mfilename('fullpath'));
defaults.frozen_baseline_file = fullfile(root_dir, 'results', ...
    'p_shift_iir_matrix', '20260731_full', 'reference_only', 'raw', ...
    'p8_iir8k_replay.mat');
defaults.reuse_frozen_baseline = true;
defaults.synthetic_duration_s = 0.60;
defaults.synthetic_analysis_start_s = 0.10;
defaults.synthetic_tones_hz = [20 40 60 80 100 120 160];
defaults.synthetic_phase_tone_rad = 0.004;
defaults.exact_event_margin_s = 0.005;
defaults.maximum_plot_points = 10000;
defaults.resume_source_dir = "";
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options, names{k}), options.(names{k}) = defaults.(names{k}); end
end
end

function value = timestamp_now()
value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
end
