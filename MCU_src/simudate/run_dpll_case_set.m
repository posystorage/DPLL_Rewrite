function case_set = run_dpll_case_set(cases, output_dir, options)
%RUN_DPLL_CASE_SET Run a resumable matrix of frozen DPLL investigation cases.

arguments
    cases (:,1) struct
    output_dir (1,1) string
    options.resume (1,1) logical = true
    options.save_full_result_ids (:,1) string = strings(0,1)
end

raw_dir = fullfile(output_dir, 'raw');
stimulus_dir = fullfile(output_dir, 'stimuli');
if ~isfolder(raw_dir), mkdir(raw_dir); end
if ~isfolder(stimulus_dir), mkdir(stimulus_dir); end
rows = repmat(struct(), 0, 1);
raw_files = strings(numel(cases), 1);
stimulus_files = strings(numel(cases), 1);

for k = 1:numel(cases)
    item = cases(k);
    raw_file = fullfile(raw_dir, sprintf('%s.mat', char(item.case_id)));
    raw_files(k) = string(raw_file);
    if options.resume && isfile(raw_file)
        frozen = load(raw_file, 'record');
        record = frozen.record;
        fprintf('Case %d/%d resumed: %s\n', k, numel(cases), item.case_id);
    else
        stimulus_file = fullfile(stimulus_dir, ...
            sprintf('%s.mat', stimulus_token(item.spec)));
        stimulus_files(k) = string(stimulus_file);
        if isfile(stimulus_file)
            stimulus = load(stimulus_file, 'input_data', 'truth', 'spec');
            input_data = stimulus.input_data;
            truth = stimulus.truth;
        else
            spec = item.spec;
            [input_data, truth] = generate_sinusoidal_fm_input(spec);
            save(stimulus_file, 'input_data', 'truth', 'spec', '-v7.3');
        end
        save_full = any(options.save_full_result_ids == string(item.case_id));
        fprintf(['Case %d/%d: %s, config=%s, fm=%.6g Hz, ' ...
            'beta=%.6g rad\n'], k, numel(cases), item.case_id, ...
            item.config_id, item.spec.modulation_frequency_hz, ...
            item.spec.phase_modulation_rad);
        record = run_dpll_fm_case(item, item.cfg, input_data, truth, ...
            string(raw_file), save_full);
    end
    if isempty(rows)
        rows = record.row;
    else
        rows(end + 1, 1) = record.row; %#ok<AGROW>
    end
    partial = struct2table(rows);
    writetable(partial, fullfile(output_dir, 'case_metrics.csv'));
    save(fullfile(output_dir, 'case_set_partial.mat'), ...
        'partial', 'raw_files', 'stimulus_files', '-v7.3');
end

metrics = struct2table(rows);
if any(metrics.posterior_data_used)
    error('dpll:PosteriorContamination', ...
        'At least one investigation case used posterior peak data.');
end
case_set.schema_version = 1;
case_set.metrics = metrics;
case_set.raw_files = raw_files;
case_set.stimulus_files = stimulus_files;
case_set.case_count = height(metrics);
case_set.posterior_peak_data_loaded = false;
case_set.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
case_set.output_dir = char(output_dir);
writetable(metrics, fullfile(output_dir, 'case_metrics.csv'));
save(fullfile(output_dir, 'case_set.mat'), 'case_set', '-v7.3');
end

function token = stimulus_token(spec)
token = sprintf('fm_%s_beta_%s_dur_%s', numeric_token( ...
    spec.modulation_frequency_hz), numeric_token(spec.phase_modulation_rad), ...
    numeric_token(spec.duration_s));
end

function token = numeric_token(value)
token = strrep(sprintf('%.9g', value), '.', 'p');
token = strrep(token, '-', 'm');
token = strrep(token, '+', 'p');
end
