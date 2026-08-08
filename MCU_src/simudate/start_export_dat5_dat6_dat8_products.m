function products = start_export_dat5_dat6_dat8_products(options)
%START_EXPORT_DAT5_DAT6_DAT8_PRODUCTS Generate external peak/CIC products.

arguments
    options.external_data_dir (1,1) string = ...
        "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260723"
    options.analysis_sample_count (1,1) double = 80e6
end
sim_dir = string(fileparts(mfilename('fullpath')));
tag = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
root = fullfile(sim_dir, 'results', 'pci_dataset_export', tag);
dataset_ids = ["dat5"; "dat6"; "dat8"];
products = cell(3, 1);
for k = 1:3
    products{k} = export_pci_dataset_products(dataset_ids(k), ...
        external_data_dir=options.external_data_dir, ...
        audit_root=fullfile(root, dataset_ids(k)), ...
        analysis_sample_count=options.analysis_sample_count, ...
        export_peaks=true, export_frontend=true, ...
        reuse_existing_frontend=true);
end
save(fullfile(root, 'dat5_dat6_dat8_product_manifest.mat'), ...
    'products', '-v7.3');
fprintf('\n三组亚采样峰距和CIC产品导出完成：%s\n', root);
end
