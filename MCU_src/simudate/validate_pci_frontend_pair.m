function validation = validate_pci_frontend_pair(mat_path, bin_path)
%VALIDATE_PCI_FRONTEND_PAIR Validate MAT/BIN size and bit-exact contents.

arguments
    mat_path (1,1) string
    bin_path (1,1) string
end
if ~isfile(mat_path) || ~isfile(bin_path)
    error('reference_analysis:FrontendPairMissing', ...
        'Both frontend MAT and BIN must exist.');
end
variables = whos('-file', mat_path);
names = string({variables.name});
if ~all(ismember(["frontendOutput", "metadata"], names))
    error('reference_analysis:InvalidFrontendMat', ...
        'Frontend MAT must contain frontendOutput and metadata.');
end
info = variables(names == "frontendOutput");
if ~strcmp(info.class, 'int16') || info.size(2) ~= 1
    error('reference_analysis:InvalidFrontendMat', ...
        'frontendOutput must be an N-by-1 int16 vector.');
end
output_count = info.size(1);
bin_info = dir(bin_path);
if bin_info.bytes ~= 2 * output_count
    error('reference_analysis:FrontendBinSizeMismatch', ...
        'BIN bytes %d do not equal 2*%d.', bin_info.bytes, output_count);
end

mapped = matfile(mat_path);
bin_id = fopen(bin_path, 'r', 'l');
if bin_id < 0
    error('reference_analysis:BinOpenFailed', ...
        'Cannot open frontend BIN: %s', bin_path);
end
cleanup = onCleanup(@() fclose(bin_id));
chunk = 5e6;
first = 1;
while first <= output_count
    last = min(output_count, first + chunk - 1);
    from_mat = mapped.frontendOutput(first:last, 1);
    from_bin = fread(bin_id, [last - first + 1 1], 'int16=>int16');
    if ~isequal(from_mat, from_bin)
        error('reference_analysis:FrontendPairDataMismatch', ...
            'MAT/BIN differ in output range %d:%d.', first, last);
    end
    first = last + 1;
end
if ~isempty(fread(bin_id, [1 1], 'uint8=>uint8'))
    error('reference_analysis:FrontendBinTrailingData', ...
        'BIN contains trailing bytes.');
end
metadata_raw = load(mat_path, 'metadata');
metadata = metadata_raw.metadata;
if isfield(metadata, 'outputSampleCount') && ...
        double(metadata.outputSampleCount) ~= output_count
    error('reference_analysis:FrontendMetadataCountMismatch', ...
        'metadata.outputSampleCount does not match frontendOutput.');
end

validation.mat_path = char(mat_path);
validation.bin_path = char(bin_path);
validation.output_sample_count = output_count;
validation.bin_bytes = bin_info.bytes;
validation.bit_exact = true;
validation.mat_sha256 = char(dpll.file_sha256(mat_path));
validation.bin_sha256 = char(dpll.file_sha256(bin_path));
validation.metadata = metadata;
end
