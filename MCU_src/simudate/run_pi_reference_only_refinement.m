function refinement = run_pi_reference_only_refinement(base_cfg, output_dir)
%RUN_PI_REFERENCE_ONLY_REFINEMENT Test FPGA-realizable final loop variants.

raw_dir = fullfile(output_dir, 'raw');
figure_dir = fullfile(output_dir, 'figures');
response_dir = fullfile(output_dir, 'fm80_response');
if ~isfolder(raw_dir), mkdir(raw_dir); end
if ~isfolder(figure_dir), mkdir(figure_dir); end
if ~isfolder(response_dir), mkdir(response_dir); end

candidates = build_candidates(base_cfg);
input_data = load_input_mat(string(base_cfg.files.pll_input_mat), ...
    base_cfg.io.input_sample_range);
rows = repmat(struct(), numel(candidates), 1);
validations = cell(numel(candidates), 1);
replay_files = strings(numel(candidates), 1);

for k = 1:numel(candidates)
    replay_file = fullfile(raw_dir, candidates(k).id + "_replay.mat");
    replay_files(k) = string(replay_file);
    if isfile(replay_file)
        frozen = load(replay_file, 'result', 'summary', 'exact_validation');
        result = frozen.result;
        summary = frozen.summary;
        exact_validation = frozen.exact_validation;
    else
        fprintf('PI refinement %d/%d: %s\n', ...
            k, numel(candidates), candidates(k).id);
        result = simulate_dpll(input_data, candidates(k).cfg);
        summary = analyze_dpll_result(result, false);
        exact_validation = validate_exact_reference_cycle_events(result);
        save(replay_file, 'result', 'summary', 'exact_validation', '-v7.3');
    end
    validations{k} = exact_validation;
    rows(k).candidate = candidates(k).id;
    rows(k).p_product_shift = result.config.shifts.p_product;
    rows(k).kp_track = double(result.config.gains.kp_track);
    rows(k).ki_track = double(result.config.gains.ki_track);
    rows(k).phase_lead_samples = ...
        result.config.architecture.phase_lead_samples;
    rows(k).phase_rms_rad = summary.phase_rms_rad;
    rows(k).exact113_rms_cycles = ...
        exact_validation.summary.pll_rms_cycles;
    rows(k).exact113_fast_std_cycles = ...
        exact_validation.summary.pll_fast_std_cycles;
    rows(k).exact113_peak_to_peak_cycles = ...
        exact_validation.summary.pll_peak_to_peak_cycles;
    rows(k).controller_saturation_count = ...
        summary.controller_saturation_count;
    rows(k).track_fraction = summary.track_fraction;
    rows(k).posterior_data_used = ...
        result.metadata.posterior_interval_data_used;
end
metrics = struct2table(rows);
if any(metrics.posterior_data_used)
    error('dpll:PosteriorContamination', ...
        'PI refinement used posterior peak data.');
end

fm_options.phase_modulation_rad = 0.03;
fm_options.amplitude_codes = 6000;
fm_options.carrier_lead_s = 0.10;
fm_options.settle_cycles = 1;
fm_options.measurement_cycles = 2;
fm_options.minimum_measurement_s = 0.25;
fm_options.save_full_raw = false;
fm_rows = repmat(struct(), numel(candidates), 1);
for k = 1:numel(candidates)
    candidate_response_dir = fullfile(response_dir, candidates(k).id);
    experiment_file = fullfile(candidate_response_dir, ...
        'fm_frequency_response_experiment.mat');
    if isfile(experiment_file)
        frozen_experiment = load(experiment_file, 'experiment');
        experiment = frozen_experiment.experiment;
    else
        experiment = run_fm_frequency_response_experiment(candidates(k).cfg, ...
            80, string(candidate_response_dir), fm_options);
    end
    row = experiment.response(1, :);
    fm_rows(k).candidate = candidates(k).id;
    fm_rows(k).closed_loop_gain_db = row.closed_loop_gain_db;
    fm_rows(k).closed_loop_phase_deg = row.closed_loop_phase_deg;
    fm_rows(k).frequency_residual_gain_db = ...
        row.frequency_residual_gain_db;
    fm_rows(k).phase_error_rms_rad = row.phase_error_rms_rad;
    fm_rows(k).controller_saturation_rate = ...
        row.controller_saturation_rate;
end
fm_response = struct2table(fm_rows);
metrics = outerjoin(metrics, fm_response, 'Keys', 'candidate', ...
    'MergeKeys', true, 'Type', 'left');
instability_boundary = run_instability_boundary(base_cfg, output_dir, ...
    fm_options);

[~, selected_row] = min(metrics.exact113_rms_cycles);
selected_id = metrics.candidate(selected_row);
selected_index = find(string({candidates.id}) == selected_id, 1, 'first');
selected = candidates(selected_index);
cold = run_cold_start_candidate_regression(candidates(1).cfg, ...
    selected.cfg, string(fullfile(output_dir, 'cold_start')));

refinement.schema_version = 1;
refinement.posterior_peak_data_loaded = false;
refinement.candidates = candidates;
refinement.metrics = metrics;
refinement.validations = validations;
refinement.replay_files = replay_files;
refinement.selected_candidate = selected;
refinement.selection_rule = ...
    'Minimum reference-only exact-113 interval RMS; no peak posterior.';
refinement.cold_start = cold;
refinement.instability_boundary = instability_boundary;
writetable(metrics, fullfile(output_dir, 'pi_refinement_metrics.csv'));
writetable(instability_boundary, fullfile(output_dir, ...
    'p_shift_instability_boundary.csv'));
save(fullfile(output_dir, 'pi_reference_only_refinement.mat'), ...
    'refinement', '-v7.3');
refinement.figure_files = make_figure(refinement, figure_dir);
save(fullfile(output_dir, 'pi_reference_only_refinement.mat'), ...
    'refinement', '-v7.3');
write_report(refinement, output_dir);
end

function metrics = run_instability_boundary(base_cfg, output_dir, fm_options)
shifts = [7 6 5];
rows = repmat(struct(), numel(shifts), 1);
root = fullfile(output_dir, 'extended_p_sweep');
for k = 1:numel(shifts)
    shift = shifts(k);
    candidate_dir = fullfile(root, sprintf('p_shift_%d', shift));
    experiment_file = fullfile(candidate_dir, ...
        'fm_frequency_response_experiment.mat');
    if isfile(experiment_file)
        frozen = load(experiment_file, 'experiment');
        experiment = frozen.experiment;
    else
        cfg = base_cfg;
        cfg.shifts.p_product = shift;
        cfg.gains.kp_blend = int64(round(750000 / 2^(9 - shift)));
        experiment = run_fm_frequency_response_experiment(cfg, 80, ...
            string(candidate_dir), fm_options);
    end
    response = experiment.response(1, :);
    rows(k).p_product_shift = shift;
    rows(k).closed_loop_gain_db = response.closed_loop_gain_db;
    rows(k).closed_loop_phase_deg = response.closed_loop_phase_deg;
    rows(k).frequency_residual_gain_db = ...
        response.frequency_residual_gain_db;
    rows(k).phase_error_rms_rad = response.phase_error_rms_rad;
    rows(k).controller_saturation_rate = ...
        response.controller_saturation_rate;
end
metrics = struct2table(rows);
end

function candidates = build_candidates(base_cfg)
ids = ["p9_lead0"; "p8_lead0"; "p7_lead0"; ...
    "p9_lead47"; "p8_lead47"];
candidates = repmat(struct('id', "", 'cfg', struct()), numel(ids), 1);
for k = 1:numel(ids)
    candidates(k).id = ids(k);
    candidates(k).cfg = base_cfg;
end
candidates(2).cfg.shifts.p_product = 8;
candidates(2).cfg.gains.kp_blend = int64(375000);
candidates(3).cfg.shifts.p_product = 7;
candidates(3).cfg.gains.kp_blend = int64(187500);
candidates(4).cfg.architecture.phase_lead_samples = 47;
candidates(5).cfg.shifts.p_product = 8;
candidates(5).cfg.gains.kp_blend = int64(375000);
candidates(5).cfg.architecture.phase_lead_samples = 47;
end

function files = make_figure(refinement, figure_dir)
metrics = refinement.metrics;
labels = strrep(metrics.candidate, '_', ' ');
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Name', 'Reference-only PI refinement');
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, 'FPGA-realizable PI and phase-lead refinement without peaks');
nexttile;
bar(1:height(metrics), [metrics.exact113_rms_cycles, ...
    metrics.exact113_fast_std_cycles], 'grouped');
xticks(1:height(metrics)); xticklabels(labels);
ylabel('Exact-113 error (cycles)'); grid on;
legend('RMS', 'Fast std', 'Location', 'best');
nexttile;
bar(1:height(metrics), [metrics.closed_loop_gain_db, ...
    metrics.frequency_residual_gain_db], 'grouped');
xticks(1:height(metrics)); xticklabels(labels);
ylabel('80 Hz response (dB)'); grid on;
legend('Tracking gain', 'Residual gain', 'Location', 'best');
nexttile; hold on;
colors = lines(height(metrics));
for k = 1:height(metrics)
    value = refinement.validations{k};
    plot(value.event_time_s(2:end), value.pll_residual_error, ...
        'Color', colors(k, :), 'DisplayName', labels(k));
end
xlabel('Time (s)'); ylabel('Exact-113 residual (cycles)');
grid on; legend('Location', 'best');
files = dpll.export_paper_figure(fig, ...
    fullfile(figure_dir, 'pi_reference_only_refinement'), [7.2 7.2]);
close(fig);
end

function write_report(refinement, output_dir)
path = fullfile(output_dir, 'pi_reference_only_refinement_report.md');
file_id = fopen(path, 'w');
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>
fprintf(file_id, '# Reference-only PI refinement\n\n');
fprintf(file_id, ['No posterior peak data was loaded. Candidate selection ' ...
    'uses exact-113 events generated from the real reference phase.\n\n']);
fprintf(file_id, ['| Candidate | Exact RMS | Fast std | 80 Hz gain | ' ...
    '80 Hz residual | Phase RMS |\n']);
fprintf(file_id, '|---|---:|---:|---:|---:|---:|\n');
for k = 1:height(refinement.metrics)
    r = refinement.metrics(k, :);
    fprintf(file_id, '| %s | %.6f | %.6f | %.6f | %.6f | %.6f |\n', ...
        r.candidate, r.exact113_rms_cycles, ...
        r.exact113_fast_std_cycles, r.closed_loop_gain_db, ...
        r.frequency_residual_gain_db, r.phase_rms_rad);
end
fprintf(file_id, '\nSelected: **%s**.\n', ...
    refinement.selected_candidate.id);
fprintf(file_id, '\n## Instability boundary at 80 Hz\n\n');
fprintf(file_id, ['| P shift | Gain (dB) | Residual (dB) | Phase RMS ' ...
    '| Saturation rate |\n']);
fprintf(file_id, '|---:|---:|---:|---:|---:|\n');
for k = 1:height(refinement.instability_boundary)
    r = refinement.instability_boundary(k, :);
    fprintf(file_id, '| %d | %.6f | %.6f | %.6f | %.6f |\n', ...
        r.p_product_shift, r.closed_loop_gain_db, ...
        r.frequency_residual_gain_db, r.phase_error_rms_rad, ...
        r.controller_saturation_rate);
end
end
