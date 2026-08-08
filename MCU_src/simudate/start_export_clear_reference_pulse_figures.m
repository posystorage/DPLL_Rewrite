function outputs = start_export_clear_reference_pulse_figures(options)
%START_EXPORT_CLEAR_REFERENCE_PULSE_FIGURES Direct dat5/dat6 figures.

arguments
    options.analysis_root (1,1) string = fullfile( ...
        fileparts(mfilename('fullpath')), 'results', ...
        'reference_pulse_relation', '20260806_040804_multidataset', ...
        'analysis')
    options.output_root (1,1) string = ""
    options.show_figures (1,1) logical = false
end
sim_dir = string(fileparts(mfilename('fullpath')));
if strlength(options.output_root) == 0
    tag = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    output_root = fullfile(sim_dir, 'results', ...
        'reference_pulse_relation', tag + "_clear_per_dataset");
else
    output_root = options.output_root;
end
if isfolder(output_root)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite clear figure root: %s', output_root);
end
study_ids = ["dat5_sampling"; "dat6_sampling"];
labels = ["dat5 采样峰"; "dat6 采样峰"];
relative_outputs = ["dat5"; "dat6"];
outputs = cell(numel(study_ids), 1);
for k = 1:numel(study_ids)
    study_path = fullfile(options.analysis_root, study_ids(k), ...
        'reference_pulse_relation_study.mat');
    outputs{k} = export_direct_reference_pulse_figure(study_path, ...
        fullfile(output_root, relative_outputs(k)), ...
        dataset_label=labels(k), show_figure=options.show_figures, ...
        export_data=true);
end
save(fullfile(output_root, 'clear_per_dataset_figure_manifest.mat'), ...
    'outputs', 'study_ids', 'labels', '-v7.3');
fprintf('\ndat5/dat6独立直观图已导出：%s\n', output_root);
fprintf('dat8已经人工校验排除，本入口仅导出dat5/dat6。\n');
end
