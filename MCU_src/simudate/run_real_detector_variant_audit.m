function audit = run_real_detector_variant_audit( ...
    input_mat_path, causal_audit_mat_path, output_dir, options)
%RUN_REAL_DETECTOR_VARIANT_AUDIT Reference-only real-input filter selection.

arguments
    input_mat_path (1,1) string
    causal_audit_mat_path (1,1) string
    output_dir (1,1) string
    options.input_sample_range (1,2) double = [1 4000000]
    options.save_full_result (1,1) logical = true
    options.resume (1,1) logical = true
end

require_file(input_mat_path, 'Reference input');
require_file(causal_audit_mat_path, 'Causal phase audit');
if ~isfolder(output_dir), mkdir(output_dir); end
raw_dir = fullfile(output_dir, 'raw');
table_dir = fullfile(output_dir, 'tables');
figure_dir = fullfile(output_dir, 'figures');
make_dirs(raw_dir, table_dir, figure_dir);

source = load_input_mat(input_mat_path, options.input_sample_range);
truth_file = load(causal_audit_mat_path, 'audit');
truth = truth_file.audit;
if truth.posterior_peak_data_loaded
    error('dpll:PosteriorContamination', ...
        'Real detector selection requires posterior-free phase truth.');
end
variants = build_variants();
rows = repmat(empty_row(), numel(variants), 1);
case_files = strings(numel(variants), 1);

for k = 1:numel(variants)
    case_files(k) = fullfile(raw_dir, variants(k).id + ".mat");
    if options.resume && isfile(case_files(k))
        loaded = load(case_files(k), 'case_data');
        if isfield(loaded, 'case_data') && ...
                loaded.case_data.variant.id == variants(k).id
            fprintf('Real detector %d/%d: %s (resume)\n', ...
                k, numel(variants), variants(k).id);
            rows(k) = loaded.case_data.row;
            continue;
        end
    end
    fprintf('Real detector %d/%d: %s\n', k, numel(variants), variants(k).id);
    result = simulate_dpll(source, variants(k).cfg);
    exact = validate_reference_phase_series_events(result, ...
        truth.time_s, truth.phase_cycles, 0.01);
    row = summarize_result(result, exact, truth, variants(k));
    rows(k) = row;
    case_data.schema_version = 1;
    case_data.variant = variants(k);
    case_data.row = row;
    case_data.exact_reference_events = exact;
    case_data.posterior_peak_data_loaded = false;
    if options.save_full_result
        case_data.result = result;
    else
        case_data.metadata = result.metadata;
        case_data.status = result.status;
        case_data.word_history = result.word_history;
    end
    save(case_files(k), 'case_data', '-v7.3');
    clear case_data result exact
end

metrics = struct2table(rows);
valid = metrics.track_fraction > 0.99 & ...
    metrics.controller_saturation_rate == 0 & ...
    metrics.cordic_out_of_range_rate == 0;
eligible = find(valid);
if isempty(eligible)
    error('dpll:NoEligibleRealCandidate', ...
        'No real-input detector candidate remained locked and unsaturated.');
end
score = metrics.exact113_rms_cycles(eligible) + ...
    metrics.detector_truth_rms_output_cycles(eligible);
[~, local_best] = min(score);
selected_index = eligible(local_best);
selected_id = metrics.variant_id(selected_index);
metrics.selected = false(height(metrics), 1);
metrics.selected(selected_index) = true;
writetable(metrics, fullfile(table_dir, 'real_detector_variant_metrics.csv'));
figure_files = make_figure(metrics, figure_dir);
provenance = table(["reference_input"; "causal_phase_truth"], ...
    [input_mat_path; causal_audit_mat_path], ...
    [dpll.file_sha256(input_mat_path); ...
    dpll.file_sha256(causal_audit_mat_path)], ...
    'VariableNames', {'role', 'path', 'sha256'});
writetable(provenance, fullfile(table_dir, 'source_provenance.csv'));

audit.schema_version = 1;
audit.created_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
audit.posterior_peak_data_loaded = false;
audit.options = options;
audit.variants = variants;
audit.metrics = metrics;
audit.selected_id = selected_id;
audit.case_files = case_files;
audit.provenance = provenance;
audit.figure_files = figure_files;
audit.report_path = fullfile(output_dir, 'real_detector_variant_report.md');
write_report(audit.report_path, audit);
save(fullfile(output_dir, 'real_detector_variant_audit.mat'), ...
    'audit', '-v7.3');
end

function variants = build_variants()
base = dpll_recommended_config(20000);
variants = repmat(struct('id', "", 'label', "", 'cfg', base), 5, 1);
variants(1) = make_variant('two_2k', 'Two sections, 2 kHz', ...
    configure_iir(base, 2, 2000));
variants(2) = make_variant('two_4k', 'Two sections, 4 kHz', ...
    configure_iir(base, 2, 4000));
variants(3) = make_variant('two_8k', 'Two sections, 8 kHz', ...
    configure_iir(base, 2, 8000));
variants(4) = make_variant('one_2k', 'One section, 2 kHz', ...
    configure_iir(base, 1, 2000));
cfg = configure_iir(base, 2, 2000);
cfg.architecture.controller_update_mode = 'phase_each_fll_block_once';
cfg.gains.kf_track = int64(16) * cfg.gains.kf_track;
variants(5) = make_variant('decoupled', 'Phase-rate PI, block-rate FLL', cfg);
end

function cfg = configure_iir(cfg, sections, cutoff_hz)
cfg.iir.sections = sections;
cfg.iir.mode = 2;
cfg.iir.track_cutoff_hz = cutoff_hz;
cfg.iir.acquire_cutoff_hz = cutoff_hz;
sample_rate_hz = cfg.input_sample_rate_hz / cfg.cic.rate;
cfg.iir.track = dpll.design_biquad_q30(cutoff_hz, sample_rate_hz);
cfg.iir.acquire = cfg.iir.track;
end

function value = make_variant(id, label, cfg)
value.id = string(id);
value.label = string(label);
value.cfg = cfg;
value.cfg.model_name = char(label);
end

function row = summarize_result(result, exact, truth, variant)
use = result.trace.analysis_valid & ...
    result.trace.time_s >= truth.time_s(1) & ...
    result.trace.time_s <= truth.time_s(end);
trace_time = result.trace.time_s(use);
phase_scale = pi / 2^(result.config.phase_width - 1);
phase_error = double(result.trace.phase_error(use)) * phase_scale;
detector_phase = unwrap(phase_error + ...
    double(result.config.phase_setpoint) * phase_scale);
reference_phase = (double(result.trace.tracking_phase_rad(use)) + ...
    detector_phase) / (2 * pi);
truth_phase = interp1(truth.time_s, truth.phase_cycles, trace_time, 'linear');
delta = reference_phase - truth_phase;
time_centered = trace_time - mean(trace_time);
delta = delta - [ones(size(time_centered)), time_centered] * ...
    ([ones(size(time_centered)), time_centered] \ delta);
controller_sat = result.trace.controller_saturated_high(use) | ...
    result.trace.controller_saturated_low(use);

row = empty_row();
row.variant_id = variant.id;
row.variant_label = variant.label;
row.iir_sections = result.config.iir.sections;
row.iir_cutoff_hz = result.config.iir.track_cutoff_hz;
row.controller_update_mode = string( ...
    result.config.architecture.controller_update_mode);
row.exact113_rms_cycles = exact.summary.rms_cycles;
row.detector_truth_rms_output_cycles = ...
    result.config.pulse.output_multiplier * sqrt(mean(delta.^2));
row.phase_error_rms_rad = sqrt(mean(phase_error.^2));
row.tracking_frequency_std_hz = std(result.trace.tracking_frequency_hz(use));
row.track_fraction = mean(result.trace.loop_state == 6);
row.cic_saturation_rate = mean(result.trace.cic_saturated(use));
row.iir_saturation_rate = mean(result.trace.iir_saturated(use));
row.cordic_out_of_range_rate = mean(result.trace.cordic_out_of_range(use));
row.controller_saturation_rate = mean(controller_sat);
row.posterior_peak_data_loaded = false;
end

function row = empty_row()
row.variant_id = "";
row.variant_label = "";
row.iir_sections = NaN;
row.iir_cutoff_hz = NaN;
row.controller_update_mode = "";
row.exact113_rms_cycles = NaN;
row.detector_truth_rms_output_cycles = NaN;
row.phase_error_rms_rad = NaN;
row.tracking_frequency_std_hz = NaN;
row.track_fraction = NaN;
row.cic_saturation_rate = NaN;
row.iir_saturation_rate = NaN;
row.cordic_out_of_range_rate = NaN;
row.controller_saturation_rate = NaN;
row.posterior_peak_data_loaded = false;
end

function files = make_figure(metrics, figure_dir)
fig = figure('Visible', 'off', 'Color', 'w');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
labels = categorical(metrics.variant_label, metrics.variant_label);
nexttile(layout); bar(labels, metrics.exact113_rms_cycles);
ylabel('Exact-113 RMS (cycles)'); grid on; xtickangle(20);
nexttile(layout); bar(labels, metrics.detector_truth_rms_output_cycles);
ylabel('Detector vs truth RMS (cycles)'); grid on; xtickangle(20);
title(layout, 'Real-reference detector variants, posterior-free');
files = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'real_detector_variant_comparison'), [8.0 6.0]);
close(fig);
end

function write_report(path, audit)
file_id = fopen(path, 'w');
if file_id < 0, error('dpll:ReportOpenFailed', 'Cannot write %s.', path); end
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>
fprintf(file_id, '# Real-reference detector variant audit\n\n');
fprintf(file_id, 'Posterior peak data loaded: **false**.\n\n');
fprintf(file_id, ['| Variant | Exact-113 RMS | Detector truth RMS | ' ...
    'Tracking std (Hz) | Selected |\n']);
fprintf(file_id, '|---|---:|---:|---:|---:|\n');
for k = 1:height(audit.metrics)
    row = audit.metrics(k, :);
    fprintf(file_id, '| %s | %.6f | %.6f | %.6f | %s |\n', ...
        row.variant_label, row.exact113_rms_cycles, ...
        row.detector_truth_rms_output_cycles, ...
        row.tracking_frequency_std_hz, string(row.selected));
end
fprintf(file_id, '\nSelected without peak data: **%s**.\n', audit.selected_id);
end

function require_file(path, role)
if ~isfile(path), error('dpll:InputNotFound', '%s not found: %s', role, path); end
end

function make_dirs(varargin)
for k = 1:nargin
    if ~isfolder(varargin{k}), mkdir(varargin{k}); end
end
end
