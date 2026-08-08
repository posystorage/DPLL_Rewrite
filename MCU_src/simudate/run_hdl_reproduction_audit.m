function audit = run_hdl_reproduction_audit( ...
    pll_input_mat, peak_mat, output_root, options)
%RUN_HDL_REPRODUCTION_AUDIT Fresh negative-control replay for HDL settings.
%
% All cases use the same captured reference and the same simulation path.
% Candidate configurations, source hashes, and hypotheses are frozen before
% any peak timestamp is loaded. Posterior peak data is optional and is only
% accessed after every reference-only replay has completed.

arguments
    pll_input_mat (1,1) string
    peak_mat (1,1) string
    output_root (1,1) string
    options.input_sample_range (1,2) double = [1 4000000]
    options.center_frequency_hz (1,1) double = 20000
    options.startup_mode (1,1) string = "prelocked"
    options.prelock_duration_s (1,1) double = 0.020
    options.preroll_duration_s (1,1) double = 0.050
    options.exact_margin_s (1,1) double = 0.005
    options.one_point_threshold_cycles (1,1) double = 1
    options.run_posterior (1,1) logical = true
    options.show_plots (1,1) logical = true
    options.export_figures (1,1) logical = true
end

if isfolder(output_root)
    error('dpll:HdlAuditOutputExists', ...
        'Refusing to overwrite HDL audit output: %s', output_root);
end
mkdir(output_root);
raw_dir = fullfile(output_root, 'raw');
table_dir = fullfile(output_root, 'tables');
figure_dir = fullfile(output_root, 'figures');
mkdir(raw_dir); mkdir(table_dir); mkdir(figure_dir);

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
source = verify_parameter_sources(project_root);
input_hash = string(dpll.file_sha256(pll_input_mat));

candidates = build_hdl_reproduction_candidates( ...
    options.center_frequency_hz);
candidate_count = numel(candidates);
paths = repmat(struct('raw_dir', '', 'replay', '', 'exact', '', ...
    'posterior', ''), candidate_count, 1);

for k = 1:candidate_count
    paths(k).raw_dir = fullfile(raw_dir, candidates(k).id);
    mkdir(paths(k).raw_dir);
    paths(k).replay = fullfile(paths(k).raw_dir, 'dpll_replay.mat');
    paths(k).exact = fullfile(paths(k).raw_dir, ...
        'exact113_reference_validation.mat');
    paths(k).posterior = fullfile(paths(k).raw_dir, ...
        'posterior_peak_validation.mat');

    cfg = candidates(k).cfg;
    cfg.files.pll_input_mat = char(pll_input_mat);
    cfg.files.peak_mat = '';
    cfg.files.replay_output_mat = paths(k).replay;
    cfg.files.validation_output_mat = paths(k).posterior;
    cfg.io.input_sample_range = options.input_sample_range;
    cfg.startup.mode = char(options.startup_mode);
    cfg.startup.frequency_estimation_duration_s = ...
        options.prelock_duration_s;
    cfg.startup.preroll_duration_s = options.preroll_duration_s;
    candidates(k).cfg = cfg;
end

config_manifest = build_config_manifest(candidates);
source_manifest = build_source_manifest(source);
writetable(config_manifest, fullfile(table_dir, ...
    'candidate_config_manifest.csv'));
writetable(source_manifest, fullfile(table_dir, ...
    'source_provenance_manifest.csv'));

freeze.schema_version = 1;
freeze.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
freeze.experiment = 'HDL negative-control reproduction audit';
freeze.candidates = candidates;
freeze.paths = paths;
freeze.options = options;
freeze.input_file = char(pll_input_mat);
freeze.input_sha256 = char(input_hash);
freeze.peak_file_path_only = char(peak_mat);
freeze.peak_sha256 = '';
freeze.posterior_peak_distance_loaded = false;
freeze.posterior_peak_data_used_for_control = false;
freeze.posterior_peak_data_used_for_selection = false;
freeze.preregistered_hypotheses = {
    'register_optimized_p12 exact113 RMS > 1 cycle';
    'optimized_p8_no_2p2z exact113 RMS <= 1 cycle';
    'P8 exact113 RMS is lower than matched P12';
    'matched register_optimized_p12 and P8 cases remain unsaturated';
    'all cases use the same input hash and reference event grid'};
save(fullfile(output_root, 'hdl_audit_freeze.mat'), ...
    'freeze', 'candidates', 'paths', 'config_manifest', ...
    'source_manifest', '-v7.3');

fprintf('\n============================================================\n');
fprintf('HDL 参数负对照复现实验（全新运行，不复用旧结果）\n');
fprintf('  输入 SHA-256 : %s\n', input_hash);
fprintf('  输入范围     : [%g, %g] @ 3.125 MHz\n', ...
    options.input_sample_range(1), options.input_sample_range(2));
fprintf('  输出目录     : %s\n', output_root);
for k = 1:candidate_count
    cfg = candidates(k).cfg;
    fprintf(['  [%d] %s: R%d/shift%d, IIR %.0f Hz, P%d, ' ...
        'Kp/Ki=%d/%d, 2P2Z=%d\n'], k, candidates(k).label_cn, ...
        cfg.cic.rate, cfg.cic.output_shift, cfg.iir.track_cutoff_hz, ...
        cfg.shifts.p_product, cfg.gains.kp_track, cfg.gains.ki_track, ...
        cfg.architecture.phase_2p2z_enable);
end
fprintf('============================================================\n');

% Load the reference input exactly once and reuse the same immutable array.
% No peak MAT file is opened in this stage.
input_data = load_input_mat(pll_input_mat, options.input_sample_range);
empty_run = struct('candidate', struct(), 'cfg', struct(), ...
    'paths', struct(), 'result', struct(), 'summary', struct(), ...
    'exact', struct(), 'validation', [], 'acceptance', struct());
runs = repmat(empty_run, candidate_count, 1);

for k = 1:candidate_count
    fprintf('\n--- reference-only %d/%d: %s ---\n', ...
        k, candidate_count, candidates(k).label_cn);
    cfg = candidates(k).cfg;
    result = simulate_dpll(input_data, cfg);
    summary = analyze_dpll_result(result, false);
    if result.metadata.posterior_interval_data_used || ...
            summary.posterior_interval_data_used
        error('dpll:PosteriorContamination', ...
            'Reference-only HDL audit was posterior-contaminated.');
    end
    save(paths(k).replay, 'result', 'summary', '-v7.3');

    exact = validate_exact_reference_cycle_events( ...
        result, options.exact_margin_s);
    if exact.posterior_peak_data_loaded
        error('dpll:PosteriorContamination', ...
            'Exact-113 HDL audit loaded peak data.');
    end
    save(paths(k).exact, 'exact', '-v7.3');

    runs(k).candidate = candidates(k);
    runs(k).cfg = cfg;
    runs(k).paths = paths(k);
    runs(k).result = result;
    runs(k).summary = summary;
    runs(k).exact = exact;
end
clear input_data result summary exact

event_alignment = build_event_alignment(runs, candidate_count);
writetable(event_alignment, fullfile(table_dir, ...
    'reference_event_grid_alignment.csv'));

peak_hash = "";
if options.run_posterior
    % The peak file is first opened only here, after all configurations and
    % all reference-only results are frozen on disk.
    peak_hash = string(dpll.file_sha256(peak_mat));
    for k = 1:candidate_count
        fprintf('\n--- posterior %d/%d: %s ---\n', ...
            k, candidate_count, candidates(k).label_cn);
        runs(k).validation = run_peak_validation( ...
            string(paths(k).replay), peak_mat, ...
            string(paths(k).posterior), false);
    end
end

for k = 1:candidate_count
    runs(k).acceptance = build_acceptance(runs(k), ...
        options.one_point_threshold_cycles);
end

metrics = build_metrics(runs, input_hash);
hypotheses = evaluate_hypotheses(runs, event_alignment, ...
    options.one_point_threshold_cycles);
writetable(metrics, fullfile(table_dir, 'hdl_reproduction_metrics.csv'));
writetable(hypotheses, fullfile(table_dir, ...
    'preregistered_hypothesis_results.csv'));
writetable(build_exact_interval_table(runs), fullfile(table_dir, ...
    'exact113_interval_series.csv'));
writetable(build_exact_segment_table(runs), fullfile(table_dir, ...
    'exact113_segment_metrics.csv'));
if options.run_posterior
    writetable(build_posterior_interval_table(runs), fullfile(table_dir, ...
        'posterior_interval_series.csv'));
end

figure_files = struct();
if options.export_figures
    fig1 = plot_exact_negative_controls(runs, ...
        options.one_point_threshold_cycles, options.show_plots);
    figure_files.figure1 = dpll.export_paper_figure(fig1, ...
        fullfile(figure_dir, 'figure1_exact113_negative_controls_cn'), ...
        [10.0 7.8], 'Microsoft YaHei');

    fig2 = plot_internal_phase_controls(runs, options.show_plots);
    figure_files.figure2 = dpll.export_paper_figure(fig2, ...
        fullfile(figure_dir, 'figure2_internal_phase_negative_controls_cn'), ...
        [10.0 7.8], 'Microsoft YaHei');

    fig3 = plot_exact_distribution_and_table(runs, hypotheses, ...
        options.one_point_threshold_cycles, options.show_plots);
    figure_files.figure3 = dpll.export_paper_figure(fig3, ...
        fullfile(figure_dir, 'figure3_exact113_distribution_audit_cn'), ...
        [10.0 6.2], 'Microsoft YaHei');

    fig4 = plot_posterior_audit(runs, ...
        options.one_point_threshold_cycles, options.show_plots);
    figure_files.figure4 = dpll.export_paper_figure(fig4, ...
        fullfile(figure_dir, 'figure4_posterior_isolation_audit_cn'), ...
        [10.0 7.0], 'Microsoft YaHei');

    if ~options.show_plots
        close(fig1); close(fig2); close(fig3); close(fig4);
    end
end

report_path = fullfile(output_root, 'hdl_reproduction_audit_report_cn.md');
write_report(report_path, metrics, hypotheses, source_manifest, ...
    event_alignment, input_hash, peak_hash, options);

records = repmat(struct('candidate_id', '', 'label_cn', '', ...
    'paths', struct(), 'summary', struct(), 'acceptance', struct()), ...
    candidate_count, 1);
for k = 1:candidate_count
    records(k).candidate_id = runs(k).candidate.id;
    records(k).label_cn = runs(k).candidate.label_cn;
    records(k).paths = runs(k).paths;
    records(k).summary = runs(k).summary;
    records(k).acceptance = runs(k).acceptance;
end

audit.schema_version = 1;
audit.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
audit.output_root = char(output_root);
audit.input_file = char(pll_input_mat);
audit.input_sha256 = char(input_hash);
audit.peak_file = char(peak_mat);
audit.peak_sha256 = char(peak_hash);
audit.records = records;
audit.metrics = metrics;
audit.hypotheses = hypotheses;
audit.event_alignment = event_alignment;
audit.source_manifest = source_manifest;
audit.figure_files = figure_files;
audit.report_path = report_path;
audit.posterior_peak_data_used_for_control = false;
audit.posterior_peak_data_used_for_selection = false;
audit.all_preregistered_hypotheses_passed = all(hypotheses.passed);
save(fullfile(output_root, 'hdl_reproduction_audit.mat'), ...
    'audit', 'metrics', 'hypotheses', 'event_alignment', ...
    'source_manifest', 'config_manifest', '-v7.3');

fprintf('\n============================================================\n');
fprintf('HDL 参数负对照复现实验完成\n');
for k = 1:candidate_count
    fprintf('  %s: exact RMS %.6f, max %.6f', ...
        runs(k).candidate.label_cn, ...
        runs(k).acceptance.reference_only.rms_cycles, ...
        runs(k).acceptance.reference_only.max_abs_cycles);
    if ~isempty(runs(k).validation)
        fprintf(', posterior total %.6f, loop-only %.6f', ...
            runs(k).acceptance.posterior.rms_cycles, ...
            runs(k).acceptance.posterior.loop_only_rms_cycles);
    end
    fprintf('\n');
end
fprintf('  预注册判定全部通过: %d\n', ...
    audit.all_preregistered_hypotheses_passed);
fprintf('  报告: %s\n', report_path);
fprintf('  结果: %s\n', output_root);
fprintf('============================================================\n');
end

function source = verify_parameter_sources(project_root)
source.core = fullfile(project_root, 'DPLL_Rewrite.srcs', 'sources_1', ...
    'DigitalPLL', 'DDC', 'dpll_single_clock_core_stage_a.v');
source.wrapper = fullfile(project_root, 'DPLL_Rewrite.srcs', 'sources_1', ...
    'DigitalPLL', 'dpll_wrapper.v');
source.arm = fullfile(project_root, 'DPLL_Rewrite.sdk', 'DPLL_2COM', ...
    'src', 'dpll_profile.c');
core_text = fileread(source.core);
wrapper_text = fileread(source.wrapper);
arm_text = fileread(source.arm);
assert(contains(core_text, '.P_PRODUCT_SHIFT(12)'));
assert(contains(wrapper_text, '.REGISTER_DEFAULT_VALUE(31), .ADDRESS(16''h0060)'));
assert(contains(wrapper_text, '.REGISTER_DEFAULT_VALUE(10), .ADDRESS(16''h0061)'));
assert(contains(wrapper_text, 'DEFAULT_POST_IIR_TRACK_B0 = 32''sd48851600'));
assert(contains(arm_text, 'profile->kp_track = 6000000'));
assert(contains(arm_text, 'profile->ki_track = 180000'));
assert(contains(arm_text, 'static const uint16_t dpll_cic_candidates[] = { 16U'));
source.core_hash = dpll.file_sha256(source.core);
source.wrapper_hash = dpll.file_sha256(source.wrapper);
source.arm_hash = dpll.file_sha256(source.arm);
end

function table_value = build_source_manifest(source)
table_value = table( ...
    ["fixed_p_shift"; "wrapper_reset_detector"; "arm_operating_profile"], ...
    string({source.core; source.wrapper; source.arm}), ...
    string({source.core_hash; source.wrapper_hash; source.arm_hash}), ...
    ["P_PRODUCT_SHIFT=12"; ...
     "CIC R=31, shift=10, TRACK IIR=8 kHz"; ...
     "20 kHz band selects R16/shift8/TRACK2k/Kp6M/Ki180k"], ...
    'VariableNames', {'source_role', 'source_file', 'sha256', 'evidence'});
end

function table_value = build_config_manifest(candidates)
rows = repmat(struct(), numel(candidates), 1);
for k = 1:numel(candidates)
    cfg = candidates(k).cfg;
    rows(k).candidate_id = string(candidates(k).id);
    rows(k).candidate_label_cn = string(candidates(k).label_cn);
    rows(k).role_cn = string(candidates(k).role_cn);
    rows(k).cic_rate = cfg.cic.rate;
    rows(k).cic_output_shift = cfg.cic.output_shift;
    rows(k).iir_acquire_cutoff_hz = cfg.iir.acquire_cutoff_hz;
    rows(k).iir_track_cutoff_hz = cfg.iir.track_cutoff_hz;
    rows(k).p_product_shift = cfg.shifts.p_product;
    rows(k).i_product_shift = cfg.shifts.i_product;
    rows(k).kp_track = cfg.gains.kp_track;
    rows(k).ki_track = cfg.gains.ki_track;
    rows(k).kp_blend = cfg.gains.kp_blend;
    rows(k).phase_2p2z_enabled = cfg.architecture.phase_2p2z_enable;
    rows(k).parameter_source_cn = ...
        string(candidates(k).parameter_source_cn);
end
table_value = struct2table(rows);
end

function acceptance = build_acceptance(run, threshold)
reference_error = double(run.exact.pll_residual_error(:));
reference_abs = abs(reference_error);
acceptance.internal.phase_rms_mrad = 1e3 * run.summary.phase_rms_rad;
acceptance.internal.phase_peak_abs_mrad = 1e3 * run.summary.phase_peak_rad;
acceptance.internal.track_fraction = run.summary.track_fraction;
acceptance.internal.controller_saturation_count = ...
    run.summary.controller_saturation_count;
acceptance.reference_only.rms_cycles = rms_plain(reference_error);
acceptance.reference_only.max_abs_cycles = max(reference_abs);
acceptance.reference_only.over_one_fraction = ...
    mean(reference_abs > threshold);
acceptance.reference_only.rms_pass = ...
    acceptance.reference_only.rms_cycles <= threshold;
acceptance.reference_only.all_intervals_pass = ...
    acceptance.reference_only.max_abs_cycles <= threshold;
acceptance.reference_only.endpoint_phase_rms_mrad = ...
    run.exact.summary.delta_phase_113_rms_mrad;
acceptance.reference_only.endpoint_phase_peak_abs_mrad = ...
    run.exact.summary.delta_phase_113_peak_abs_mrad;
acceptance.reference_only.posterior_data_used = false;

if isempty(run.validation)
    acceptance.posterior = [];
else
    total_error = double(run.validation.recovered_interval_error(:));
    acceptance.posterior.rms_cycles = rms_plain(total_error);
    acceptance.posterior.max_abs_cycles = max(abs(total_error));
    acceptance.posterior.over_one_fraction = mean(abs(total_error) > threshold);
    acceptance.posterior.reference_event_rms_cycles = ...
        run.validation.summary.reference_event_rms_error;
    acceptance.posterior.loop_only_rms_cycles = ...
        run.validation.summary.loop_only_rms_error;
    acceptance.posterior.correlation = ...
        run.validation.summary.total_vs_reference_event_correlation;
    acceptance.posterior.posterior_data_used = true;
end
end

function metrics = build_metrics(runs, input_hash)
rows = repmat(struct(), numel(runs), 1);
for k = 1:numel(runs)
    cfg = runs(k).cfg;
    value = runs(k).acceptance;
    rows(k).candidate_id = string(runs(k).candidate.id);
    rows(k).candidate_label_cn = string(runs(k).candidate.label_cn);
    rows(k).role_cn = string(runs(k).candidate.role_cn);
    rows(k).input_sha256 = input_hash;
    rows(k).cic_rate = cfg.cic.rate;
    rows(k).cic_output_shift = cfg.cic.output_shift;
    rows(k).track_iir_cutoff_hz = cfg.iir.track_cutoff_hz;
    rows(k).p_product_shift = cfg.shifts.p_product;
    rows(k).kp_track = cfg.gains.kp_track;
    rows(k).ki_track = cfg.gains.ki_track;
    rows(k).kp_blend = cfg.gains.kp_blend;
    rows(k).phase_2p2z_enabled = cfg.architecture.phase_2p2z_enable;
    rows(k).internal_phase_rms_mrad = value.internal.phase_rms_mrad;
    rows(k).internal_phase_peak_abs_mrad = value.internal.phase_peak_abs_mrad;
    rows(k).track_fraction = value.internal.track_fraction;
    rows(k).controller_saturation_count = ...
        value.internal.controller_saturation_count;
    rows(k).detector_saturation_count = ...
        runs(k).result.status.cic_saturation_count + ...
        runs(k).result.status.iir_saturation_count;
    rows(k).exact113_rms_cycles = value.reference_only.rms_cycles;
    rows(k).exact113_max_abs_cycles = value.reference_only.max_abs_cycles;
    rows(k).exact113_over_one_fraction = ...
        value.reference_only.over_one_fraction;
    rows(k).exact113_rms_pass = value.reference_only.rms_pass;
    rows(k).exact113_all_intervals_pass = ...
        value.reference_only.all_intervals_pass;
    rows(k).endpoint_phase_rms_mrad = ...
        value.reference_only.endpoint_phase_rms_mrad;
    rows(k).endpoint_phase_peak_abs_mrad = ...
        value.reference_only.endpoint_phase_peak_abs_mrad;
    if isempty(value.posterior)
        rows(k).posterior_total_rms_cycles = NaN;
        rows(k).posterior_reference_event_rms_cycles = NaN;
        rows(k).posterior_loop_only_rms_cycles = NaN;
        rows(k).posterior_total_event_correlation = NaN;
    else
        rows(k).posterior_total_rms_cycles = value.posterior.rms_cycles;
        rows(k).posterior_reference_event_rms_cycles = ...
            value.posterior.reference_event_rms_cycles;
        rows(k).posterior_loop_only_rms_cycles = ...
            value.posterior.loop_only_rms_cycles;
        rows(k).posterior_total_event_correlation = ...
            value.posterior.correlation;
    end
    rows(k).posterior_peak_data_used_for_control = false;
    rows(k).posterior_peak_data_used_for_selection = false;
end
metrics = struct2table(rows);
end

function hypotheses = evaluate_hypotheses(runs, alignment, threshold)
p12 = runs(3).acceptance.reference_only.rms_cycles;
p8 = runs(4).acceptance.reference_only.rms_cycles;
improvement = 100 * (p12 - p8) / p12;
matched_unsaturated = all(arrayfun(@(r) ...
    r.acceptance.internal.controller_saturation_count == 0 && ...
    r.result.status.cic_saturation_count == 0 && ...
    r.result.status.iir_saturation_count == 0, runs(3:4)));
all_track = all(arrayfun(@(r) ...
    r.acceptance.internal.track_fraction > 0.99, runs));
grid_delta = max(alignment.max_abs_event_time_delta_us);

id = ["p12_negative_control_bad"; "p8_positive_control_pass"; ...
    "p8_improves_matched_p12"; "matched_pair_unsaturated"; ...
    "all_cases_track"; "common_reference_event_grid"];
value = [p12; p8; improvement; double(matched_unsaturated); ...
    double(all_track); grid_delta];
unit = ["cycles RMS"; "cycles RMS"; "%"; "boolean"; ...
    "boolean"; "us"];
criterion = ["> 1"; "<= 1"; "> 0"; "true"; "true"; "<= 0.32 us"];
passed = [p12 > threshold; p8 <= threshold; improvement > 0; ...
    matched_unsaturated; all_track; grid_delta <= 0.32];
hypotheses = table(id, value, unit, criterion, passed);
end

function alignment = build_event_alignment(runs, reference_index)
reference = runs(reference_index).exact;
rows = repmat(struct(), numel(runs), 1);
for k = 1:numel(runs)
    [common, index_a, index_b] = intersect( ...
        double(runs(k).exact.target_reference_cycles(:)), ...
        double(reference.target_reference_cycles(:)), 'stable');
    if isempty(common)
        max_delta_us = Inf;
    else
        delta = runs(k).exact.event_time_s(index_a) - ...
            reference.event_time_s(index_b);
        max_delta_us = 1e6 * max(abs(delta));
    end
    rows(k).candidate_id = string(runs(k).candidate.id);
    rows(k).candidate_event_count = ...
        numel(runs(k).exact.target_reference_cycles);
    rows(k).common_event_count = numel(common);
    rows(k).target_cycle_grid_match = ...
        numel(common) == numel(reference.target_reference_cycles) && ...
        numel(common) == numel(runs(k).exact.target_reference_cycles);
    rows(k).max_abs_event_time_delta_us = max_delta_us;
end
alignment = struct2table(rows);
end

function table_value = build_exact_interval_table(runs)
table_value = table();
for k = 1:numel(runs)
    exact = runs(k).exact;
    count = numel(exact.pll_residual_error);
    current = table(repmat(string(runs(k).candidate.id), count, 1), ...
        (1:count).', exact.event_time_s(2:end), ...
        double(exact.pll_residual_error(:)), ...
        1e3 * double(exact.delta_phase_113_rad(:)), ...
        'VariableNames', {'candidate_id', 'interval_index', ...
        'interval_end_time_s', 'exact113_error_cycles', ...
        'endpoint_phase_delta_mrad'});
    table_value = append_table(table_value, current);
end
end

function table_value = build_exact_segment_table(runs)
table_value = table();
for k = 1:numel(runs)
    current = runs(k).exact.segment_metrics;
    current = addvars(current, ...
        repmat(string(runs(k).candidate.id), height(current), 1), ...
        'Before', 1, 'NewVariableNames', 'candidate_id');
    table_value = append_table(table_value, current);
end
end

function table_value = build_posterior_interval_table(runs)
table_value = table();
for k = 1:numel(runs)
    if isempty(runs(k).validation), continue; end
    validation = runs(k).validation;
    count = numel(validation.recovered_interval_error);
    current = table(repmat(string(runs(k).candidate.id), count, 1), ...
        (1:count).', validation.peak_time_s(2:end), ...
        double(validation.recovered_interval_error(:)), ...
        double(validation.reference_event_error(:)), ...
        double(validation.loop_only_error(:)), ...
        'VariableNames', {'candidate_id', 'interval_index', ...
        'interval_end_time_s', 'posterior_total_error_cycles', ...
        'reference_event_error_cycles', 'loop_only_error_cycles'});
    table_value = append_table(table_value, current);
end
end

function fig = plot_exact_negative_controls(runs, threshold, show_plots)
fig = prepare_figure(1, 'HDL负对照 exact-113', show_plots);
layout = tiledlayout(fig, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '图1：同一真实参考输入下的HDL负对照（2P2Z全部关闭）');
limit = 1.2;
for k = 1:numel(runs)
    limit = max(limit, max(abs(double(runs(k).exact.pll_residual_error))));
end
limit = 1.05 * limit;
colors = lines(numel(runs));
for k = 1:numel(runs)
    nexttile;
    plot(runs(k).exact.event_time_s(2:end), ...
        runs(k).exact.pll_residual_error, 'Color', colors(k, :), ...
        'LineWidth', 0.9); hold on;
    yline(threshold, '--r'); yline(-threshold, '--r'); yline(0, ':k');
    ylim([-limit limit]); grid on;
    ylabel('间距误差（周期）');
    title(sprintf('%s：RMS %.3f，max %.3f', ...
        runs(k).candidate.label_cn, ...
        runs(k).acceptance.reference_only.rms_cycles, ...
        runs(k).acceptance.reference_only.max_abs_cycles));
end
xlabel(layout, '时间（s）');
end

function fig = plot_internal_phase_controls(runs, show_plots)
fig = prepare_figure(2, 'HDL负对照内部相位', show_plots);
layout = tiledlayout(fig, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '图2：PLL内部瞬时相位残差负对照（未加载真实峰）');
limit = 1;
for k = 1:numel(runs)
    indices = trace_indices(runs(k).result, 8000);
    values = phase_mrad(runs(k).result, indices);
    limit = max(limit, max(abs(values)));
end
limit = 1.05 * limit;
colors = lines(numel(runs));
for k = 1:numel(runs)
    nexttile;
    indices = trace_indices(runs(k).result, 8000);
    plot(runs(k).result.trace.time_s(indices), ...
        phase_mrad(runs(k).result, indices), ...
        'Color', colors(k, :), 'LineWidth', 0.7); hold on;
    yline(0, ':k'); ylim([-limit limit]); grid on;
    ylabel('相位残差（mrad）');
    title(sprintf('%s：RMS %.3f mrad', ...
        runs(k).candidate.label_cn, ...
        runs(k).acceptance.internal.phase_rms_mrad));
end
xlabel(layout, '时间（s）');
end

function fig = plot_exact_distribution_and_table( ...
    runs, hypotheses, threshold, show_plots)
fig = prepare_figure(3, 'HDL负对照分布与判定', show_plots);
layout = tiledlayout(fig, 1, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '图3：exact-113分布和预注册判定');
colors = lines(numel(runs));

nexttile;
for k = 1:numel(runs)
    values = sort(abs(double(runs(k).exact.pll_residual_error(:))));
    percentile = 100 * (1:numel(values)).' / numel(values);
    plot(values, percentile, 'Color', colors(k, :), ...
        'LineWidth', 1.1, 'DisplayName', runs(k).candidate.label_cn); hold on;
end
xline(threshold, '--r', '1点阈值', 'HandleVisibility', 'off');
xlabel('绝对exact-113误差（周期）'); ylabel('累计区间比例（%）');
ylim([0 100]); grid on; legend('Location', 'best');

nexttile;
axis off; xlim([0 1]); ylim([0 1]); hold on;
text(0.02, 0.97, '预注册判定（运行前冻结）', ...
    'FontWeight', 'bold', 'VerticalAlignment', 'top');
for k = 1:height(hypotheses)
    y = 0.84 - (k - 1) * 0.13;
    text(0.03, y, strrep(hypotheses.id(k), '_', ' '), ...
        'Interpreter', 'none');
    color = choose_color(hypotheses.passed(k));
    text(0.96, y, sprintf('%g %s  [%s]', ...
        hypotheses.value(k), hypotheses.unit(k), ...
        pass_text(hypotheses.passed(k))), ...
        'HorizontalAlignment', 'right', 'Color', color, ...
        'FontWeight', 'bold');
    plot([0.02 0.98], [y-0.055 y-0.055], '-', ...
        'Color', [0.88 0.88 0.88]);
end
end

function fig = plot_posterior_audit(runs, threshold, show_plots)
fig = prepare_figure(4, 'HDL负对照posterior隔离', show_plots);
layout = tiledlayout(fig, 2, 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, '图4：冻结后的真实峰posterior，仅用于最终复核');
colors = lines(numel(runs));

if isempty(runs(1).validation)
    nexttile([2 1]); axis off;
    text(0.5, 0.5, 'posterior已关闭', 'HorizontalAlignment', 'center');
    return;
end

nexttile;
for k = 1:numel(runs)
    time = runs(k).validation.peak_time_s(2:end);
    plot(time, runs(k).validation.loop_only_error, ...
        'Color', colors(k, :), 'LineWidth', 0.9, ...
        'DisplayName', runs(k).candidate.label_cn); hold on;
end
yline(threshold, '--r', 'HandleVisibility', 'off');
yline(-threshold, '--r', 'HandleVisibility', 'off');
yline(0, ':k', 'HandleVisibility', 'off');
ylabel('loop-only（周期）'); grid on; legend('Location', 'best');
title('真实峰时刻的环路贡献；不包含reference-event项');

nexttile;
selected = [3 4];
all_values = [];
for n = 1:numel(selected)
    k = selected(n);
    event = double(runs(k).validation.reference_event_error(:));
    total = double(runs(k).validation.recovered_interval_error(:));
    plot(event, total, '.', 'Color', colors(k, :), 'MarkerSize', 10, ...
        'DisplayName', runs(k).candidate.label_cn); hold on;
    all_values = [all_values; event; total]; %#ok<AGROW>
end
limit = 1.05 * max(abs(all_values));
plot([-limit limit], [-limit limit], '--k', ...
    'DisplayName', '总误差=reference-event');
xlim([-limit limit]); ylim([-limit limit]); axis square; grid on;
xlabel('reference-event（周期）'); ylabel('posterior总误差（周期）');
legend('Location', 'best');
title('最强P12负对照与P8正对照：总误差仍由事件项主导');
end

function write_report(path, metrics, hypotheses, source_manifest, ...
    alignment, input_hash, peak_hash, options)
file_id = fopen(path, 'w', 'n', 'UTF-8');
if file_id < 0
    error('dpll:ReportOpenFailed', 'Cannot create report: %s', path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, '# HDL参数负对照复现实验\n\n');
fprintf(file_id, '生成时间：%s\n\n', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf(file_id, '输入SHA-256：`%s`。\n\n', input_hash);
fprintf(file_id, ['候选、源码哈希和假设均在打开峰时间戳前冻结。' ...
    '所有候选关闭2P2Z，不进行参数搜索，也不复用旧replay。\n\n']);

fprintf(file_id, '## 参数口径\n\n');
fprintf(file_id, ['“RTL复位检测链”只表示wrapper的R31/shift10/8k字面值，' ...
    '不冒充ARM加载后的工作profile；“ARM当前工作profile”对应提交代码' ...
    '在20 kHz下生成的R16/shift8/2k/Ki180k配置。\n\n']);
for k = 1:height(source_manifest)
    fprintf(file_id, '- %s：`%s`，SHA-256 `%s`。\n', ...
        source_manifest.source_role(k), source_manifest.source_file(k), ...
        source_manifest.sha256(k));
end

fprintf(file_id, '\n## 结果\n\n');
fprintf(file_id, ['| 配置 | R/shift | IIR | P shift | Ki | 检测饱和 | ' ...
    '内部相位RMS | exact RMS | exact max | >1点 | posterior总RMS | loop-only |\n']);
fprintf(file_id, ['|---|---:|---:|---:|---:|---:|---:|---:|---:|' ...
    '---:|---:|---:|\n']);
for k = 1:height(metrics)
    fprintf(file_id, ['| %s | %d/%d | %.0f Hz | P%d | %d | %d | ' ...
        '%.3f mrad | %.6f | %.6f | %.2f%% | %.6f | %.6f |\n'], ...
        metrics.candidate_label_cn(k), metrics.cic_rate(k), ...
        metrics.cic_output_shift(k), metrics.track_iir_cutoff_hz(k), ...
        metrics.p_product_shift(k), metrics.ki_track(k), ...
        metrics.detector_saturation_count(k), ...
        metrics.internal_phase_rms_mrad(k), ...
        metrics.exact113_rms_cycles(k), ...
        metrics.exact113_max_abs_cycles(k), ...
        100 * metrics.exact113_over_one_fraction(k), ...
        metrics.posterior_total_rms_cycles(k), ...
        metrics.posterior_loop_only_rms_cycles(k));
end

fprintf(file_id, '\n## 预注册假设\n\n');
fprintf(file_id, '| 假设 | 数值 | 判据 | 结果 |\n');
fprintf(file_id, '|---|---:|---|---|\n');
for k = 1:height(hypotheses)
    fprintf(file_id, '| %s | %.6g %s | %s | %s |\n', ...
        hypotheses.id(k), hypotheses.value(k), hypotheses.unit(k), ...
        hypotheses.criterion(k), pass_text(hypotheses.passed(k)));
end

fprintf(file_id, '\n## 数据隔离和事件网格\n\n');
fprintf(file_id, '- 峰文件SHA-256（posterior阶段才计算）：`%s`。\n', peak_hash);
fprintf(file_id, '- 峰位置用于控制：`false`。\n');
fprintf(file_id, '- 峰位置用于选参：`false`。\n');
fprintf(file_id, '- posterior运行：`%d`。\n', options.run_posterior);
fprintf(file_id, '- 各候选相对P8事件网格最大时间差：%.6f us。\n', ...
    max(alignment.max_abs_event_time_delta_us));

if all(hypotheses.passed)
    fprintf(file_id, ['\n## 结论\n\n负对照成功复现差效果，且P8正对照在同一输入、' ...
        '同一代码路径、无2P2Z条件下恢复到一点RMS以内。该结果支持优化有效。\n']);
else
    fprintf(file_id, ['\n## 结论\n\n至少一项预注册判据未通过；本实验不能证明当前优化有效，' ...
        '不得以图形外观替代失败判定。\n']);
end
end

function fig = prepare_figure(number, name, show_plots)
fig = figure(number); clf(fig);
if show_plots, visibility = 'on'; else, visibility = 'off'; end
set(fig, 'Visible', visibility, 'Color', 'w', 'Name', name);
end

function indices = trace_indices(result, maximum_points)
valid = find(result.trace.analysis_valid);
positions = unique(round(linspace(1, numel(valid), ...
    min(maximum_points, numel(valid)))));
indices = valid(positions);
end

function values = phase_mrad(result, indices)
values = double(result.trace.phase_error(indices)) * 1e3 * pi / ...
    2^(double(result.config.phase_width) - 1);
end

function color = choose_color(passed)
if passed, color = [0.10 0.50 0.25]; else, color = [0.75 0.15 0.12]; end
end

function text_value = pass_text(passed)
if passed, text_value = '通过'; else, text_value = '未通过'; end
end

function output = append_table(output, current)
if isempty(output), output = current; else, output = [output; current]; end
end

function value = rms_plain(values)
values = double(values(:));
if isempty(values), value = NaN; else, value = sqrt(mean(values.^2)); end
end
