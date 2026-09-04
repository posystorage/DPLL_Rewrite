function extraction = extract_pci_reference_frontend( ...
    pci_path, output_mat, options)
%EXTRACT_PCI_REFERENCE_FRONTEND Parameterized FPGA-equivalent CH2 extraction.
%
% The implementation follows PCI_CH2_CIC_DCBlock_Emulation.m but refuses to
% overwrite existing outputs and records full provenance in the MAT metadata.

arguments
    pci_path (1,1) string
    output_mat (1,1) string
    options.dataset_id (1,1) string = ""
    options.output_bin (1,1) string = ""
    options.frontend_mex_dir (1,1) string
    options.channel_count (1,1) double = 2
    options.channel_index (1,1) double = 2
    options.header_bytes (1,1) double = 1024
    options.source_sample_rate_hz (1,1) double = 62.5e6
    options.emulated_sample_rate_hz (1,1) double = 125e6
    options.cic_rate (1,1) double = 40
    options.source_chunk_length (1,1) double = 5e6
    options.maximum_source_samples (1,1) double = inf
    options.source_sha256 (1,1) string = ""
    options.compute_source_sha256 (1,1) logical = true
end

if ~isfile(pci_path)
    error('reference_analysis:PciNotFound', ...
        'PCI source does not exist: %s', pci_path);
end
if isfile(output_mat)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite reference frontend MAT: %s', output_mat);
end
if strlength(options.output_bin) > 0 && isfile(options.output_bin)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite reference frontend BIN: %s', ...
        options.output_bin);
end
if ~isfolder(options.frontend_mex_dir)
    error('reference_analysis:MexDirectoryNotFound', ...
        'Frontend MEX directory does not exist: %s', ...
        options.frontend_mex_dir);
end
mex_name = 'fpga_frontend_process_mex';
mex_path = fullfile(options.frontend_mex_dir, ...
    [mex_name '.' mexext]);
if ~isfile(mex_path)
    error('reference_analysis:MexNotFound', ...
        'Compiled frontend MEX does not exist: %s', mex_path);
end
validateattributes(options.channel_index, {'numeric'}, ...
    {'integer', '>=', 1, '<=', options.channel_count});
validateattributes(options.source_chunk_length, {'numeric'}, ...
    {'integer', 'positive', '<=', 5e6});

emulated_per_source = options.emulated_sample_rate_hz / ...
    options.source_sample_rate_hz;
source_per_output = options.cic_rate / emulated_per_source;
if source_per_output ~= round(source_per_output)
    error('reference_analysis:NonintegerFrontendRatio', ...
        'Frontend rates do not produce an integer source/output ratio.');
end
source_per_output = round(source_per_output);
if mod(options.source_chunk_length, source_per_output) ~= 0
    error('reference_analysis:InvalidFrontendChunk', ...
        'source_chunk_length must be divisible by %d.', source_per_output);
end

file_info = dir(pci_path);
data_bytes = double(file_info.bytes) - options.header_bytes;
bytes_per_time_sample = 2 * options.channel_count;
if data_bytes <= 0 || mod(data_bytes, bytes_per_time_sample) ~= 0
    error('reference_analysis:InvalidPciLength', ...
        'PCI data length does not match interleaved uint16 channels.');
end
file_source_count = data_bytes / bytes_per_time_sample;
source_count = min(file_source_count, floor(options.maximum_source_samples));
expected_output_count = ceil(source_count / source_per_output);
frontendOutput = zeros(expected_output_count, 1, 'int16');

fp = fopen(pci_path, 'r', 'l');
if fp < 0
    error('reference_analysis:PciOpenFailed', ...
        'Cannot open PCI source: %s', pci_path);
end
cleanup_input = onCleanup(@() fclose(fp));
if fseek(fp, options.header_bytes, 'bof') ~= 0
    error('reference_analysis:PciSeekFailed', ...
        'Cannot seek past the PCI header.');
end

old_path = path;
path_cleanup = onCleanup(@() path(old_path));
addpath(options.frontend_mex_dir);
if exist(mex_name, 'file') ~= 3
    error('reference_analysis:MexLoadFailed', ...
        'MATLAB cannot load %s.', mex_path);
end

% [0:3] integrators, [4:11] four comb histories, [12] DC accumulator,
% [13] CIC phase. This state definition is frozen by the existing MEX API.
frontend_state = zeros(14, 1, 'int64');
processed_count = 0;
output_count = 0;
raw_minimum = Inf;
raw_maximum = -Inf;
dc_saturation_count = 0;
next_progress = 0;

fprintf('\n参考前端提取：%s\n', options.dataset_id);
fprintf('  源文件：%s\n', pci_path);
fprintf('  每通道源点数：%d；预计输出：%d。\n', ...
    source_count, expected_output_count);
while processed_count < source_count
    current_count = min(options.source_chunk_length, ...
        source_count - processed_count);
    raw_block = fread(fp, [options.channel_count current_count], ...
        'uint16=>uint16');
    actual_count = floor(numel(raw_block) / options.channel_count);
    if actual_count == 0, break; end
    raw_channel = raw_block(options.channel_index, 1:actual_count).';
    clear raw_block

    if processed_count == 0 && raw_channel(1) >= 32768
        raw_channel(1) = raw_channel(1) - 32768;
    end
    invalid = raw_channel > 16383;
    if any(invalid)
        first_invalid = find(invalid, 1, 'first');
        error('reference_analysis:InvalidAdcCode', ...
            'Source sample %d has code %d outside 14-bit range.', ...
            processed_count + first_invalid, raw_channel(first_invalid));
    end
    raw_minimum = min(raw_minimum, double(min(raw_channel)));
    raw_maximum = max(raw_maximum, double(max(raw_channel)));

    adc14_bits = bitxor(raw_channel, uint16(8191));
    adc14_signed = int64(adc14_bits);
    negative = adc14_bits >= 8192;
    adc14_signed(negative) = adc14_signed(negative) - 16384;
    adc16_signed = int16(adc14_signed * 4);
    [dc_output, frontend_state, saturation_count] = ...
        feval(mex_name, adc16_signed, frontend_state); %#ok<FVAL>
    dc_saturation_count = dc_saturation_count + saturation_count;

    write_start = output_count + 1;
    write_end = output_count + numel(dc_output);
    frontendOutput(write_start:write_end) = dc_output;
    output_count = write_end;
    processed_count = processed_count + actual_count;

    progress = floor(100 * processed_count / source_count);
    if progress >= next_progress
        fprintf('  进度 %3d%%，输出 %d 点。\n', progress, output_count);
        next_progress = 10 * (floor(progress / 10) + 1);
    end
    if actual_count < current_count, break; end
end
clear cleanup_input path_cleanup

if processed_count ~= source_count || output_count ~= expected_output_count
    error('reference_analysis:IncompleteFrontendExtraction', ...
        'Processed/output counts are %d/%d and %d/%d.', ...
        processed_count, source_count, output_count, expected_output_count);
end

metadata.schemaVersion = 2;
metadata.createdAt = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
metadata.datasetId = char(options.dataset_id);
metadata.sourceFile = char(pci_path);
metadata.sourceFileBytes = file_info.bytes;
metadata.sourceChannel = options.channel_index;
metadata.sourceFileTotalSampleCount = file_source_count;
metadata.sourceSampleCount = source_count;
metadata.sourceSampleRate = options.source_sample_rate_hz;
metadata.sourceCodeFormat = '14-bit offset-binary, 0..16383';
metadata.pitayaMapping = ...
    'adc14Signed = bitxor(rawCode,8191) signed; adc16 = adc14Signed << 2';
metadata.emulatedSampleRate = options.emulated_sample_rate_hz;
metadata.outputSampleRate = options.emulated_sample_rate_hz / options.cic_rate;
metadata.sourceSamplesPerOutput = source_per_output;
metadata.outputDataType = 'int16';
metadata.outputSampleCount = output_count;
metadata.cicRate = options.cic_rate;
metadata.cicStages = 4;
metadata.cicDifferentialDelay = 2;
metadata.cicIntegratorWidths = [40 34 28 23];
metadata.cicCombWidths = [21 20 19 19];
metadata.dcDataWidth = 16;
metadata.dcAccumulatorWidth = 48;
metadata.dcLeakShift = 10;
metadata.rawMinimum = raw_minimum;
metadata.rawMaximum = raw_maximum;
metadata.dcSaturationCount = dc_saturation_count;
metadata.frontendMexPath = char(mex_path);
metadata.frontendMexSha256 = char(dpll.file_sha256(mex_path));
metadata.sourceScriptReference = ...
    'PCI_CH2_CIC_DCBlock_Emulation.m behavior, parameterized copy';
metadata.absoluteGroupDelayCalibrated = false;
if strlength(options.source_sha256) > 0
    validate_sha256(options.source_sha256);
    metadata.sourceSha256 = char(upper(options.source_sha256));
elseif options.compute_source_sha256
    metadata.sourceSha256 = char(dpll.file_sha256(pci_path));
else
    metadata.sourceSha256 = '';
end

metadata.outputBinFile = '';
metadata.outputBinBytes = 0;
metadata.outputBinSha256 = '';
if strlength(options.output_bin) > 0
    [bin_dir, ~, ~] = fileparts(options.output_bin);
    if ~isempty(bin_dir) && ~isfolder(bin_dir), mkdir(bin_dir); end
    bin_id = fopen(options.output_bin, 'w', 'l');
    if bin_id < 0
        error('reference_analysis:BinCreateFailed', ...
            'Cannot create frontend BIN: %s', options.output_bin);
    end
    bin_cleanup = onCleanup(@() fclose(bin_id));
    written_count = fwrite(bin_id, frontendOutput, 'int16');
    if written_count ~= numel(frontendOutput)
        error('reference_analysis:IncompleteBinWrite', ...
            'Wrote %d/%d frontend samples to BIN.', ...
            written_count, numel(frontendOutput));
    end
    clear bin_cleanup
    bin_info = dir(options.output_bin);
    metadata.outputBinFile = char(options.output_bin);
    metadata.outputBinBytes = bin_info.bytes;
    metadata.outputBinSha256 = char(dpll.file_sha256(options.output_bin));
end

[output_dir, ~, ~] = fileparts(output_mat);
if ~isempty(output_dir) && ~isfolder(output_dir), mkdir(output_dir); end
save(output_mat, 'frontendOutput', 'metadata', '-v7.3');

extraction.schema_version = 1;
extraction.dataset_id = char(options.dataset_id);
extraction.output_mat = char(output_mat);
extraction.output_bin = metadata.outputBinFile;
extraction.output_bin_bytes = metadata.outputBinBytes;
extraction.output_bin_sha256 = metadata.outputBinSha256;
extraction.source_sample_count = source_count;
extraction.output_sample_count = output_count;
extraction.raw_minimum = raw_minimum;
extraction.raw_maximum = raw_maximum;
extraction.dc_saturation_count = dc_saturation_count;
extraction.source_sha256 = metadata.sourceSha256;
extraction.frontend_mex_sha256 = metadata.frontendMexSha256;
fprintf('  完成：%s\n', output_mat);
end

function validate_sha256(value)
if strlength(value) ~= 64 || isempty(regexp(char(value), ...
        '^[0-9A-Fa-f]{64}$', 'once'))
    error('reference_analysis:InvalidSha256', ...
        'source_sha256 must contain exactly 64 hexadecimal characters.');
end
end
