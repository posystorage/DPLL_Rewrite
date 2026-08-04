function audit = run_detector_counterfactual_audit(base_cfg, output_dir, options)
%RUN_DETECTOR_COUNTERFACTUAL_AUDIT Isolate detector delay and structure.

arguments
    base_cfg (1,1) struct
    output_dir (1,1) string
    options.frequencies_hz (:,1) double = [10 20 40 60 80 120 200].'
    options.phase_tone_rad (1,1) double = 0.004
    options.duration_s (1,1) double = 0.60
    options.measurement_start_s (1,1) double = 0.08
    options.measurement_end_s (1,1) double = 0.58
    options.oracle_delay_s (1,1) double = 238.35e-6
    options.amplitude_codes (1,1) double = 6000
    options.save_full_result (1,1) logical = true
    options.resume (1,1) logical = true
end

if ~isfolder(output_dir), mkdir(output_dir); end
raw_dir = fullfile(output_dir, 'raw');
table_dir = fullfile(output_dir, 'tables');
figure_dir = fullfile(output_dir, 'figures');
make_dirs(raw_dir, table_dir, figure_dir);

spec.sample_rate_hz = base_cfg.input_sample_rate_hz;
spec.carrier_frequency_hz = base_cfg.center_frequency_hz;
spec.duration_s = options.duration_s;
spec.amplitude_codes = options.amplitude_codes;
spec.phase_tone_hz = options.frequencies_hz;
spec.phase_tone_rad = repmat(options.phase_tone_rad, ...
    numel(options.frequencies_hz), 1);
spec.am_tone_hz = [];
spec.am_depth = [];
spec.second_harmonic_ratio = 0;
spec.third_harmonic_ratio = 0;
spec.noise_rms_codes = 0;
spec.random_seed = 1;
[input_data, truth] = generate_multitone_reference_input(spec);
input_data.oracle_reference_phase_rad = truth.total_phase_rad;
save(fullfile(raw_dir, 'counterfactual_input.mat'), ...
    'input_data', 'truth', 'spec', '-v7.3');

variants = build_variants(base_cfg, options.oracle_delay_s);
response_rows = repmat(empty_response_row(), 0, 1);
summary_rows = repmat(empty_summary_row(), numel(variants), 1);
case_files = strings(numel(variants), 1);
cases = cell(numel(variants), 1);

for k = 1:numel(variants)
    case_files(k) = fullfile(raw_dir, variants(k).id + ".mat");
    if options.resume && isfile(case_files(k))
        loaded = load(case_files(k), 'case_data');
        if isfield(loaded, 'case_data') && ...
                loaded.case_data.variant.id == variants(k).id
            fprintf('Counterfactual %d/%d: %s (resume)\n', ...
                k, numel(variants), variants(k).id);
            rows = table2struct(loaded.case_data.response);
            response_rows = [response_rows; rows]; %#ok<AGROW>
            summary_rows(k) = normalize_summary(loaded.case_data.summary);
            cases{k} = struct('measurement', loaded.case_data.measurement);
            continue;
        end
    end
    fprintf('Counterfactual %d/%d: %s\n', k, numel(variants), variants(k).id);
    result = simulate_dpll(input_data, variants(k).cfg);
    try
        exact = validate_truth_reference_cycle_events(result, ...
            truth.total_phase_rad, spec.sample_rate_hz, 0.01);
    catch exception
        exact = failed_exact_validation(exception);
    end
    [rows, measurement] = analyze_response(result, spec, ...
        options, variants(k));
    response_rows = [response_rows; rows]; %#ok<AGROW>
    summary_rows(k) = summarize_case(result, exact, measurement, variants(k));

    case_data.schema_version = 1;
    case_data.variant = variants(k);
    case_data.spec = spec;
    case_data.response = struct2table(rows);
    case_data.summary = summary_rows(k);
    case_data.exact_reference_events = exact;
    case_data.measurement = measurement;
    case_data.posterior_peak_data_loaded = false;
    if options.save_full_result
        case_data.result = result;
    else
        case_data.metadata = result.metadata;
        case_data.status = result.status;
        case_data.word_history = result.word_history;
    end
    save(case_files(k), 'case_data', '-v7.3');
    cases{k} = struct('measurement', measurement);
    clear case_data result exact measurement rows
end

response_table = struct2table(response_rows);
summary_table = struct2table(summary_rows);
writetable(response_table, fullfile(table_dir, ...
    'detector_counterfactual_frequency_response.csv'));
writetable(summary_table, fullfile(table_dir, ...
    'detector_counterfactual_summary.csv'));
figure_files = make_figures(response_table, summary_table, cases, figure_dir);

audit.schema_version = 1;
audit.created_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
audit.posterior_peak_data_loaded = false;
audit.options = options;
audit.base_config = base_cfg;
audit.spec = spec;
audit.variants = variants;
audit.response = response_table;
audit.summary = summary_table;
audit.case_files = case_files;
audit.figure_files = figure_files;
audit.report_path = fullfile(output_dir, ...
    'detector_counterfactual_report.md');
write_report(audit.report_path, audit);
save(fullfile(output_dir, 'detector_counterfactual_audit.mat'), ...
    'audit', '-v7.3');
end

function variants = build_variants(base_cfg, oracle_delay_s)
variants = repmat(struct('id', "", 'label', "", 'cfg', base_cfg), 9, 1);

variants(1) = make_variant('rtl_two_2k', 'RTL: 2 sections, 2 kHz', ...
    configure_iir(base_cfg, 2, 2000, 2));

cfg = variants(1).cfg;
cfg.architecture.phase_observation_mode = 'oracle_delayed';
cfg.architecture.oracle_phase_delay_s = oracle_delay_s;
variants(2) = make_variant('oracle_delay', ...
    sprintf('Ideal phase + %.2f us delay', 1e6 * oracle_delay_s), cfg);

cfg = variants(1).cfg;
cfg.architecture.phase_observation_mode = 'oracle';
cfg.architecture.oracle_phase_delay_s = 0;
variants(3) = make_variant('oracle_zero', 'Ideal phase: zero filter delay', cfg);

variants(4) = make_variant('rtl_two_4k', 'RTL: 2 sections, 4 kHz', ...
    configure_iir(base_cfg, 2, 4000, 2));
variants(5) = make_variant('rtl_two_8k', 'RTL: 2 sections, 8 kHz', ...
    configure_iir(base_cfg, 2, 8000, 2));
variants(6) = make_variant('rtl_one_2k', 'Candidate: 1 section, 2 kHz', ...
    configure_iir(base_cfg, 1, 2000, 2));

cfg = base_cfg;
cfg.iir.mode = 0;
variants(7) = make_variant('rtl_bypass', 'Diagnostic: IIR bypass', cfg);

cfg = variants(1).cfg;
cfg.architecture.controller_update_mode = 'phase_each_fll_block_once';
cfg.gains.kf_track = int64(16) * cfg.gains.kf_track;
variants(8) = make_variant('rtl_decoupled', ...
    'Candidate: phase-rate PI, block-rate FLL', cfg);

cfg = configure_iir(dpll_current_config(base_cfg.center_frequency_hz), ...
    2, 2000, 2);
cfg.cic.output_shift = base_cfg.cic.output_shift;
variants(9) = make_variant('hardware_p12', ...
    'Current HDL scaling: P shift 12', cfg);
end

function cfg = configure_iir(cfg, sections, cutoff_hz, mode)
cfg.iir.sections = sections;
cfg.iir.mode = mode;
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

function [rows, measurement] = analyze_response(result, spec, options, variant)
word_time = double(result.word_history.fabric_tick(:)) / ...
    result.config.fabric_clock_hz;
word_frequency = double(result.word_history.tracking_word(:)) * ...
    result.config.fabric_clock_hz / 2^result.config.word_width;
word_keep = word_time >= options.measurement_start_s & ...
    word_time <= options.measurement_end_s;
word_time = word_time(word_keep);
word_frequency = word_frequency(word_keep);
input_frequency = spec.carrier_frequency_hz * ones(size(word_time));
for k = 1:numel(spec.phase_tone_hz)
    input_frequency = input_frequency + ...
        spec.phase_tone_rad(k) * spec.phase_tone_hz(k) * ...
        cos(2 * pi * spec.phase_tone_hz(k) * word_time);
end

trace_keep = result.trace.time_s >= options.measurement_start_s & ...
    result.trace.time_s <= options.measurement_end_s;
trace_time = result.trace.time_s(trace_keep);
phase_scale = pi / 2^(result.config.phase_width - 1);
phase_error = double(result.trace.phase_error(trace_keep)) * phase_scale;
rtl_phase_error = double(result.trace.rtl_phase_error(trace_keep)) * phase_scale;

rows = repmat(empty_response_row(), numel(spec.phase_tone_hz), 1);
for k = 1:numel(spec.phase_tone_hz)
    frequency = spec.phase_tone_hz(k);
    input_fit = dpll.fit_tone(word_time, input_frequency, frequency);
    output_fit = dpll.fit_tone(word_time, word_frequency, frequency);
    residual_fit = dpll.fit_tone(word_time, ...
        input_frequency - word_frequency, frequency);
    phase_fit = dpll.fit_tone(trace_time, phase_error, frequency);
    input_phase_fit = dpll.fit_tone(trace_time, ...
        spec.phase_tone_rad(k) * sin(2 * pi * frequency * trace_time), ...
        frequency);
    closed = output_fit.phasor / input_fit.phasor;
    residual = residual_fit.phasor / input_fit.phasor;
    phase_residual = phase_fit.phasor / input_phase_fit.phasor;
    rows(k).variant_id = variant.id;
    rows(k).variant_label = variant.label;
    rows(k).frequency_hz = frequency;
    rows(k).closed_loop_gain_db = ratio_db(abs(closed));
    rows(k).closed_loop_phase_deg = rad2deg(angle(closed));
    rows(k).frequency_residual_gain_db = ratio_db(abs(residual));
    rows(k).phase_residual_gain_db = ratio_db(abs(phase_residual));
    rows(k).output_fit_r_squared = output_fit.r_squared;
    rows(k).phase_fit_r_squared = phase_fit.r_squared;
end

measurement.word_time_s = word_time;
measurement.input_frequency_hz = input_frequency;
measurement.output_frequency_hz = word_frequency;
measurement.frequency_error_hz = input_frequency - word_frequency;
measurement.trace_time_s = trace_time;
measurement.phase_error_rad = phase_error;
measurement.rtl_phase_error_rad = rtl_phase_error;
end

function row = summarize_case(result, exact, measurement, variant)
analysis = result.trace.analysis_valid;
controller_sat = result.trace.controller_saturated_high(analysis) | ...
    result.trace.controller_saturated_low(analysis);
row = empty_summary_row();
row.variant_id = variant.id;
row.variant_label = variant.label;
row.phase_observation_mode = string(result.metadata.phase_observation_mode);
row.iir_mode = result.config.iir.mode;
row.iir_sections = result.config.iir.sections;
row.iir_cutoff_hz = result.config.iir.track_cutoff_hz;
row.controller_update_mode = string( ...
    result.config.architecture.controller_update_mode);
row.p_product_shift = result.config.shifts.p_product;
row.exact113_rms_cycles = exact.summary.rms_cycles;
row.exact113_std_cycles = exact.summary.std_cycles;
row.phase_error_rms_rad = rms_plain(measurement.phase_error_rad);
row.frequency_error_rms_hz = rms_plain(measurement.frequency_error_hz);
row.cic_saturation_rate = mean(result.trace.cic_saturated(analysis));
row.iir_saturation_rate = mean(result.trace.iir_saturated(analysis));
row.cordic_out_of_range_rate = mean( ...
    result.trace.cordic_out_of_range(analysis));
row.controller_saturation_rate = mean(controller_sat);
row.controller_update_fraction = mean( ...
    result.trace.controller_updated(analysis));
row.track_fraction = mean(result.trace.loop_state == 6);
row.posterior_peak_data_loaded = false;
end

function row = empty_response_row()
row.variant_id = "";
row.variant_label = "";
row.frequency_hz = NaN;
row.closed_loop_gain_db = NaN;
row.closed_loop_phase_deg = NaN;
row.frequency_residual_gain_db = NaN;
row.phase_residual_gain_db = NaN;
row.output_fit_r_squared = NaN;
row.phase_fit_r_squared = NaN;
end

function row = empty_summary_row()
row.variant_id = "";
row.variant_label = "";
row.phase_observation_mode = "";
row.iir_mode = NaN;
row.iir_sections = NaN;
row.iir_cutoff_hz = NaN;
row.controller_update_mode = "";
row.p_product_shift = NaN;
row.exact113_rms_cycles = NaN;
row.exact113_std_cycles = NaN;
row.phase_error_rms_rad = NaN;
row.frequency_error_rms_hz = NaN;
row.cic_saturation_rate = NaN;
row.iir_saturation_rate = NaN;
row.cordic_out_of_range_rate = NaN;
row.controller_saturation_rate = NaN;
row.controller_update_fraction = NaN;
row.track_fraction = NaN;
row.posterior_peak_data_loaded = false;
end

function row = normalize_summary(value)
row = empty_summary_row();
names = intersect(fieldnames(row), fieldnames(value));
for k = 1:numel(names)
    row.(names{k}) = value.(names{k});
end
end

function exact = failed_exact_validation(exception)
exact.schema_version = 1;
exact.posterior_peak_data_loaded = false;
exact.valid = false;
exact.failure_identifier = string(exception.identifier);
exact.failure_message = string(exception.message);
exact.pll_residual_error = zeros(0, 1);
exact.summary.event_count = 0;
exact.summary.interval_count = 0;
exact.summary.rms_cycles = NaN;
exact.summary.std_cycles = NaN;
exact.summary.peak_to_peak_cycles = NaN;
exact.summary.mean_cycles = NaN;
end

function files = make_figures(response, summary, cases, figure_dir)
files = struct();
selected = ["rtl_two_2k", "oracle_delay", "oracle_zero", ...
    "rtl_two_4k", "rtl_two_8k", "rtl_one_2k"];
fig = figure('Visible', 'off', 'Color', 'w');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(layout);
hold on;
for k = 1:numel(selected)
    use = response.variant_id == selected(k);
    semilogx(response.frequency_hz(use), ...
        response.frequency_residual_gain_db(use), '.-', ...
        'LineWidth', 1.0, 'MarkerSize', 10, ...
        'DisplayName', char(response.variant_label(find(use, 1))));
end
yline(0, '--k', 'HandleVisibility', 'off');
xlabel('Modulation frequency (Hz)');
ylabel('|1 - H| (dB)');
grid on;
legend('Location', 'eastoutside');
nexttile(layout);
hold on;
for k = 1:numel(selected)
    use = response.variant_id == selected(k);
    semilogx(response.frequency_hz(use), ...
        response.closed_loop_phase_deg(use), '.-', ...
        'LineWidth', 1.0, 'MarkerSize', 10, ...
        'DisplayName', char(response.variant_label(find(use, 1))));
end
xlabel('Modulation frequency (Hz)');
ylabel('Closed-loop phase (deg)');
grid on;
title(layout, 'Detector counterfactual closed-loop response');
files.response = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'detector_counterfactual_response'), [8.6 6.4]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w');
values = summary.exact113_rms_cycles;
bar(categorical(summary.variant_label, summary.variant_label), values);
ylabel('Exact-113 residual RMS (output cycles)');
grid on;
xtickangle(28);
title('Reference-truth event validation');
files.exact = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'detector_counterfactual_exact113'), [9.0 4.8]);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ids = ["rtl_two_2k", "oracle_delay", "oracle_zero"];
nexttile(layout); hold on;
for k = 1:numel(ids)
    index = find(summary.variant_id == ids(k), 1);
    value = cases{index}.measurement;
    use = value.word_time_s >= 0.30 & value.word_time_s <= 0.36;
    plot(value.word_time_s(use), value.frequency_error_hz(use), ...
        'DisplayName', char(summary.variant_label(index)));
end
ylabel('Frequency residual (Hz)'); grid on; legend('Location', 'best');
nexttile(layout); hold on;
for k = 1:numel(ids)
    index = find(summary.variant_id == ids(k), 1);
    value = cases{index}.measurement;
    use = value.trace_time_s >= 0.30 & value.trace_time_s <= 0.36;
    plot(value.trace_time_s(use), value.phase_error_rad(use), ...
        'DisplayName', char(summary.variant_label(index)));
end
xlabel('Time (s)'); ylabel('Phase error (rad)'); grid on;
title(layout, 'Current, delayed-ideal, and zero-delay-ideal phase observation');
files.time = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'detector_counterfactual_time_trace'), [8.0 6.0]);
close(fig);
end

function write_report(path, audit)
file_id = fopen(path, 'w');
if file_id < 0, error('dpll:ReportOpenFailed', 'Cannot write %s.', path); end
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>
fprintf(file_id, '# Detector counterfactual audit\n\n');
fprintf(file_id, 'Posterior peak data loaded: **false**.\n\n');
fprintf(file_id, ['The ideal-phase cases replace only the phase observation. ' ...
    'FLL, PI, NCO, fixed-point controller, and event timing remain active.\n\n']);
fprintf(file_id, '| Variant | Exact-113 RMS | Phase RMS | Saturation |\n');
fprintf(file_id, '|---|---:|---:|---:|\n');
for k = 1:height(audit.summary)
    row = audit.summary(k, :);
    fprintf(file_id, '| %s | %.6f | %.6g | %.6g |\n', ...
        row.variant_label, row.exact113_rms_cycles, ...
        row.phase_error_rms_rad, row.controller_saturation_rate);
end
fprintf(file_id, '\n## Frequency response\n\n');
fprintf(file_id, '| Variant | Frequency (Hz) | Residual (dB) | Phase (deg) |\n');
fprintf(file_id, '|---|---:|---:|---:|\n');
for k = 1:height(audit.response)
    row = audit.response(k, :);
    fprintf(file_id, '| %s | %.0f | %.3f | %.3f |\n', ...
        row.variant_label, row.frequency_hz, ...
        row.frequency_residual_gain_db, row.closed_loop_phase_deg);
end
end

function make_dirs(varargin)
for k = 1:nargin
    if ~isfolder(varargin{k}), mkdir(varargin{k}); end
end
end

function value = ratio_db(ratio)
value = 20 * log10(max(double(ratio), realmin));
end

function value = rms_plain(values)
values = double(values(:));
value = sqrt(mean(values.^2));
end
