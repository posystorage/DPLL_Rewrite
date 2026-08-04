function manifest = write_dpll_artifact_manifest(output_root)
%WRITE_DPLL_ARTIFACT_MANIFEST Hash every retained validation artifact.

arguments
    output_root (1,1) string
end
if ~isfolder(output_root)
    error('dpll:OutputNotFound', 'Output directory not found: %s', output_root);
end
files = dir(fullfile(output_root, '**', '*'));
files = files(~[files.isdir]);
exclude = ["artifact_manifest.csv", "artifact_inventory.md"];
keep = ~ismember(string({files.name}), exclude);
files = files(keep);

count = numel(files);
relative_path = strings(count, 1);
extension = strings(count, 1);
category = strings(count, 1);
size_bytes = zeros(count, 1);
sha256 = strings(count, 1);
modified = NaT(count, 1);
root_prefix = char(output_root + filesep);
for k = 1:count
    path = fullfile(files(k).folder, files(k).name);
    relative_path(k) = string(strrep(path, root_prefix, ''));
    [~, ~, ext] = fileparts(path);
    extension(k) = lower(string(ext));
    category(k) = categorize(relative_path(k), extension(k));
    size_bytes(k) = files(k).bytes;
    sha256(k) = dpll.file_sha256(path);
    modified(k) = datetime(files(k).datenum, 'ConvertFrom', 'datenum');
end
manifest = table(relative_path, category, extension, size_bytes, ...
    modified, sha256);
manifest = sortrows(manifest, 'relative_path');
writetable(manifest, fullfile(output_root, 'artifact_manifest.csv'));
write_inventory(fullfile(output_root, 'artifact_inventory.md'), manifest);
end

function value = categorize(path, extension)
if contains(path, filesep + "raw" + filesep)
    value = "raw_data";
elseif contains(path, filesep + "tables" + filesep) || extension == ".csv"
    value = "table";
elseif any(extension == [".png", ".pdf", ".svg", ".fig"])
    value = "figure";
elseif extension == ".md"
    value = "report";
elseif extension == ".mat"
    value = "derived_data";
else
    value = "other";
end
end

function write_inventory(path, manifest)
file_id = fopen(path, 'w');
if file_id < 0
    error('dpll:ManifestOpenFailed', 'Cannot write inventory: %s', path);
end
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>
fprintf(file_id, '# DPLL validation artifact inventory\n\n');
fprintf(file_id, 'Files: **%d**  \n', height(manifest));
fprintf(file_id, 'Total size: **%.3f MiB**  \n', ...
    sum(manifest.size_bytes) / 2^20);
fprintf(file_id, 'Zero-length files: **%d**\n\n', ...
    nnz(manifest.size_bytes == 0));
categories = unique(manifest.category, 'stable');
fprintf(file_id, '| Category | Files | Size (MiB) |\n');
fprintf(file_id, '|---|---:|---:|\n');
for k = 1:numel(categories)
    use = manifest.category == categories(k);
    fprintf(file_id, '| %s | %d | %.3f |\n', categories(k), ...
        nnz(use), sum(manifest.size_bytes(use)) / 2^20);
end
fprintf(file_id, ['\nSHA-256, byte size, modification time, and relative ' ...
    'path for every file are stored in `artifact_manifest.csv`.\n']);
end
