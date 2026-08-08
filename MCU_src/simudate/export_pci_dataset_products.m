function product = export_pci_dataset_products(dataset_id, options)
%EXPORT_PCI_DATASET_PRODUCTS Export fractional peaks and CIC MAT/BIN.

arguments
    dataset_id (1,1) string
    options.external_data_dir (1,1) string = ...
        "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260723"
    options.audit_root (1,1) string = ""
    options.analysis_sample_count (1,1) double = 80e6
    options.export_peaks (1,1) logical = true
    options.export_frontend (1,1) logical = true
    options.reuse_existing_frontend (1,1) logical = true
end

if ~ismember(dataset_id, ["dat5", "dat6", "dat8"])
    error('reference_analysis:UnknownDataset', ...
        'dataset_id must be dat5, dat6, or dat8.');
end
sim_dir = string(fileparts(mfilename('fullpath')));
if strlength(options.audit_root) == 0
    tag = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    audit_root = fullfile(sim_dir, 'results', 'pci_dataset_export', ...
        tag, dataset_id);
else
    audit_root = options.audit_root;
end
if isfolder(audit_root)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite dataset audit root: %s', audit_root);
end
raw_path = fullfile(options.external_data_dir, ...
    dataset_id + "_cc62M5.pci");
if ~isfile(raw_path)
    error('reference_analysis:PciNotFound', ...
        'PCI source does not exist: %s', raw_path);
end
mkdir(audit_root);

base_name = dataset_id + "_cc62M5";
frontend_mat = fullfile(options.external_data_dir, ...
    base_name + "_ch2_CIC_DCBlock_3M125.mat");
frontend_bin = fullfile(options.external_data_dir, ...
    base_name + "_ch2_CIC_DCBlock_3M125.bin");
if dataset_id == "dat8"
    peak_outputs = [ ...
        fullfile(options.external_data_dir, ...
        base_name + "采样峰距离_亚采样_候选A_族02.mat"); ...
        fullfile(options.external_data_dir, ...
        base_name + "采样峰距离_亚采样_候选B_族04.mat")];
    peak_manifest = fullfile(options.external_data_dir, ...
        base_name + "采样峰族_亚采样.mat");
else
    peak_outputs = fullfile(options.external_data_dir, ...
        base_name + "采样峰距离_亚采样.mat");
    peak_manifest = "";
end
if options.export_peaks
    all_peak_outputs = peak_outputs;
    if strlength(peak_manifest) > 0
        all_peak_outputs(end + 1, 1) = peak_manifest;
    end
    existing = arrayfun(@isfile, all_peak_outputs);
    if any(existing)
        error('reference_analysis:OutputExists', ...
            'Refusing to overwrite peak output: %s', ...
            all_peak_outputs(find(existing, 1)));
    end
end

fprintf('\n%s：计算原始PCI SHA-256...\n', dataset_id);
source_sha256 = string(dpll.file_sha256(raw_path));
product.schema_version = 1;
product.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
product.dataset_id = char(dataset_id);
product.raw_path = char(raw_path);
product.raw_sha256 = char(source_sha256);
product.audit_root = char(audit_root);
product.peak_products = struct([]);
product.peak_manifest = '';

if options.export_peaks
    extraction_mat = fullfile(audit_root, ...
        base_name + "_peak_families_xcorr.mat");
    if dataset_id == "dat8"
        extraction = extract_fixed_clock_peak_families(raw_path, ...
            extraction_mat, dataset_id=dataset_id, ...
            analysis_sample_count=options.analysis_sample_count, ...
            nominal_macro_period_samples=326618, ...
            source_sha256=source_sha256, compute_source_sha256=false);
    else
        extraction = extract_fixed_clock_peak_families(raw_path, ...
            extraction_mat, dataset_id=dataset_id, ...
            analysis_sample_count=options.analysis_sample_count, ...
            source_sha256=source_sha256, compute_source_sha256=false);
    end
    export_fixed_clock_peak_family_tables(extraction_mat, ...
        fullfile(audit_root, 'extraction_tables'));
    candidate_ids = extraction.sampling_candidate_family_ids(:);
    if dataset_id == "dat8"
        if ~isequal(candidate_ids, [2; 4])
            error('reference_analysis:UnexpectedDat8SamplingFamilies', ...
                'dat8 must retain negative candidate families 02 and 04.');
        end
        labels = ["candidate_A_family02"; "candidate_B_family04"];
        products = cell(2, 1);
        for k = 1:2
            products{k} = write_subsample_peak_distance_mat( ...
                extraction_mat, candidate_ids(k), peak_outputs(k), ...
                candidate_label=labels(k), ...
                physical_identity_confirmed=false);
        end
        peakFamilyManifest.schemaVersion = 1;
        peakFamilyManifest.createdAt = product.created_at;
        peakFamilyManifest.datasetId = char(dataset_id);
        peakFamilyManifest.sourcePci = char(raw_path);
        peakFamilyManifest.sourcePciSha256 = char(source_sha256);
        peakFamilyManifest.sourceExtractionMat = char(extraction_mat);
        peakFamilyManifest.candidateFamilyIds = candidate_ids;
        peakFamilyManifest.candidateLabels = labels;
        peakFamilyManifest.candidateFiles = peak_outputs;
        peakFamilyManifest.physicalSelectionMade = false;
        peakFamilyManifest.selectionNote = [ ...
            'Two stable negative candidates are retained. ' ...
            'No physical sampling family was selected.'];
        save(peak_manifest, 'peakFamilyManifest', '-v7.3');
        product.peak_products = vertcat(products{:});
        product.peak_manifest = char(peak_manifest);
    else
        if numel(candidate_ids) ~= 1
            error('reference_analysis:AmbiguousSamplingFamily', ...
                '%s must contain exactly one negative sampling family.', ...
                dataset_id);
        end
        product.peak_products = write_subsample_peak_distance_mat( ...
            extraction_mat, candidate_ids, peak_outputs, ...
            candidate_label="sampling", physical_identity_confirmed=true);
    end
    product.peak_extraction_mat = char(extraction_mat);
end

product.frontend_reused = false;
product.frontend_validation = struct();
if options.export_frontend
    mat_exists = isfile(frontend_mat);
    bin_exists = isfile(frontend_bin);
    if xor(mat_exists, bin_exists)
        error('reference_analysis:IncompleteFrontendPair', ...
            'Only one frontend output exists for %s; refusing to continue.', ...
            dataset_id);
    elseif mat_exists && bin_exists
        if ~options.reuse_existing_frontend
            error('reference_analysis:OutputExists', ...
                'Frontend MAT/BIN already exist for %s.', dataset_id);
        end
        validation = validate_pci_frontend_pair(frontend_mat, frontend_bin);
        product.frontend_reused = true;
    else
        extract_pci_reference_frontend(raw_path, frontend_mat, ...
            dataset_id=dataset_id, output_bin=frontend_bin, ...
            frontend_mex_dir=options.external_data_dir, ...
            source_sha256=source_sha256, compute_source_sha256=false);
        validation = validate_pci_frontend_pair(frontend_mat, frontend_bin);
    end
    product.frontend_validation = validation;
end

save(fullfile(audit_root, dataset_id + "_product_manifest.mat"), ...
    'product', '-v7.3');
summary_table = table(string(product.dataset_id), string(product.raw_path), ...
    string(product.raw_sha256), options.export_peaks, ...
    options.export_frontend, product.frontend_reused, ...
    'VariableNames', {'dataset', 'raw_pci', 'raw_sha256', ...
    'peaks_exported', 'frontend_exported', 'frontend_reused'});
writetable(summary_table, fullfile(audit_root, ...
    dataset_id + "_product_summary.csv"));
end
