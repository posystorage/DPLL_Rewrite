function run = start_reference_pulse_multidataset_analysis(options)
%START_REFERENCE_PULSE_MULTIDATASET_ANALYSIS Full dat5/dat6 workflow.
%
% This entry point never loads a DPLL replay or controller configuration.
% Peak events are posterior diagnostics only and are not used by the IQ
% estimator, a controller, or a training path.

arguments
    options.output_root (1,1) string = ""
    options.external_data_dir (1,1) string = ...
        "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260723"
    options.analysis_sample_count (1,1) double = 80e6
    options.show_figures (1,1) logical = false
end

sim_dir = string(fileparts(mfilename('fullpath')));
if strlength(options.output_root) == 0
    tag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    output_root = fullfile(sim_dir, 'results', ...
        'reference_pulse_relation', tag + "_multidataset");
else
    output_root = options.output_root;
end
if isfolder(output_root)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite multidataset run: %s', output_root);
end
validateattributes(options.analysis_sample_count, {'numeric'}, ...
    {'integer', 'positive'});

raw_paths = [ ...
    fullfile(options.external_data_dir, 'dat5_cc62M5.pci'); ...
    fullfile(options.external_data_dir, 'dat6_cc62M5.pci')];
dataset_ids = ["dat5"; "dat6"];
for k = 1:numel(raw_paths)
    require_file(raw_paths(k), dataset_ids(k) + " PCI");
end
dat5_reference = fullfile(sim_dir, 'data', ...
    'dat5_cc62M5_ch2_CIC_DCBlock_3M125.mat');
require_file(dat5_reference, "dat5 reference frontend");

mkdir(output_root);
extraction_dir = fullfile(output_root, 'extraction');
reference_dir = fullfile(output_root, 'reference');
mkdir(extraction_dir);
mkdir(reference_dir);

source_sha256 = strings(2, 1);
peak_extractions = cell(2, 1);
peak_outputs = strings(2, 1);
for k = 1:2
    fprintf('\n计算%s原始PCI哈希...\n', dataset_ids(k));
    source_sha256(k) = string(dpll.file_sha256(raw_paths(k)));
    peak_outputs(k) = fullfile(extraction_dir, ...
        dataset_ids(k) + "_peak_families_xcorr.mat");
    peak_extractions{k} = extract_fixed_clock_peak_families( ...
        raw_paths(k), peak_outputs(k), dataset_id=dataset_ids(k), ...
        analysis_sample_count=options.analysis_sample_count, ...
        source_sha256=source_sha256(k), ...
        compute_source_sha256=false);
    export_fixed_clock_peak_family_tables(peak_outputs(k), ...
        fullfile(output_root, 'extraction_tables', dataset_ids(k)));
end

candidate_ids = cellfun(@(value) ...
    value.sampling_candidate_family_ids(:), peak_extractions, ...
    'UniformOutput', false);
if any(cellfun(@numel, candidate_ids) ~= 1)
    error('reference_analysis:AmbiguousDat5Dat6SamplingFamily', ...
        'dat5 and dat6 must each contain exactly one negative sampling family.');
end

reference_paths = strings(2, 1);
reference_paths(1) = dat5_reference;
for k = 2
    reference_paths(k) = fullfile(reference_dir, ...
        dataset_ids(k) + "_ch2_frontend_3M125.mat");
    extract_pci_reference_frontend(raw_paths(k), reference_paths(k), ...
        dataset_id=dataset_ids(k), ...
        frontend_mex_dir=options.external_data_dir, ...
        source_sha256=source_sha256(k), ...
        compute_source_sha256=false);
end

analysis_ids = ["dat5_sampling"; "dat6_sampling"];
analysis_labels = ["dat5 采样峰"; "dat6 采样峰"];
analysis_reference = reference_paths;
analysis_peak = [ ...
    peak_extractions{1}.family_files(candidate_ids{1}); ...
    peak_extractions{2}.family_files(candidate_ids{2})];
analysis_dirs = strings(2, 1);
studies = cell(2, 1);
for k = 1:2
    analysis_dirs(k) = fullfile(output_root, 'analysis', analysis_ids(k));
    studies{k} = run_reference_pulse_relation_analysis( ...
        analysis_reference(k), analysis_peak(k), analysis_dirs(k), ...
        dataset_id=analysis_ids(k), ...
        show_figures=options.show_figures, export_figures=true);
end

aggregate = build_reference_pulse_multidataset_summary(analysis_dirs, ...
    fullfile(output_root, 'summary'), labels=analysis_labels, ...
    show_figures=options.show_figures);

legacy_peak_paths = [ ...
    fullfile(sim_dir, 'data', 'dat5_cc62M5采样峰距离.mat'); ...
    fullfile(options.external_data_dir, 'dat6_cc62M5采样峰距离.mat')];
for k = 1:2
    require_file(legacy_peak_paths(k), dataset_ids(k) + " legacy peak");
end
baseline_dirs = strings(2, 1);
for k = 1:2
    baseline_dirs(k) = fullfile(output_root, 'analysis_baselines', ...
        dataset_ids(k) + "_integer_legacy");
    run_reference_pulse_relation_analysis(reference_paths(k), ...
        legacy_peak_paths(k), baseline_dirs(k), ...
        dataset_id=dataset_ids(k) + "_integer_legacy", ...
        show_figures=options.show_figures, export_figures=true);
end
baseline_comparison = build_peak_localization_baseline_comparison( ...
    baseline_dirs, analysis_dirs(1:2), ...
    fullfile(output_root, 'baseline_comparison'), ...
    labels=["dat5 采样峰"; "dat6 采样峰"], ...
    show_figures=options.show_figures);

run.schema_version = 1;
run.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
run.output_root = char(output_root);
run.raw_paths = raw_paths;
run.source_sha256 = source_sha256;
run.peak_outputs = peak_outputs;
run.reference_paths = reference_paths;
run.analysis_ids = analysis_ids;
run.analysis_labels = analysis_labels;
run.analysis_peak_paths = analysis_peak;
run.analysis_dirs = analysis_dirs;
study_summary_cells = cellfun(@(value) value.summary, studies, ...
    'UniformOutput', false);
run.study_summaries = vertcat(study_summary_cells{:});
run.aggregate_summary = aggregate.summary_metrics;
run.baseline_dirs = baseline_dirs;
run.baseline_comparison = baseline_comparison.metrics;
run.simulated_loop_data_loaded = false;
run.controller_configuration_used = false;
run.posterior_peak_data_used_for_controller = false;
run.posterior_peak_data_used_for_training = false;
save(fullfile(output_root, 'multidataset_run_manifest.mat'), ...
    'run', '-v7.3');
fprintf('\n完整独立参考-脉冲分析完成：%s\n', output_root);
fprintf('dat8已经人工校验排除，本次仅分析dat5/dat6。\n');
end

function require_file(path, role)
if ~isfile(path)
    error('reference_analysis:InputNotFound', ...
        '%s file not found: %s', role, path);
end
end
