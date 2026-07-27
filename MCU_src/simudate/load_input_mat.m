function input_data = load_input_mat(mat_path, sample_range)
%LOAD_INPUT_MAT Load either supported 3.125 MSPS FPGA-equivalent format.

arguments
    mat_path (1,1) string
    sample_range (1,2) double = [1 Inf]
end

if ~isfile(mat_path)
    error('dpll:InputNotFound', 'Input MAT file does not exist: %s', mat_path);
end
validateattributes(sample_range(1), {'numeric'}, {'integer', 'positive'});
if ~(isinf(sample_range(2)) || ...
        (sample_range(2) >= sample_range(1) && sample_range(2) == floor(sample_range(2))))
    error('dpll:InvalidSampleRange', 'sample_range must be [positiveStart endOrInf].');
end

variables = whos('-file', mat_path);
names = string({variables.name});
if all(ismember(["frontendOutput", "metadata"], names))
    meta_raw = load(mat_path, 'metadata');
    metadata = meta_raw.metadata;
    required = {'outputSampleRate', 'sourceSampleRate', 'sourceSampleCount'};
    if ~all(isfield(metadata, required))
        error('dpll:InvalidFrontendMetadata', ...
            'frontendOutput metadata is missing required timing fields.');
    end
    info = variables(names == "frontendOutput");
    if ~strcmp(info.class, 'int16') || numel(info.size) ~= 2 || info.size(2) ~= 1
        error('dpll:InvalidCodes', 'frontendOutput must be an N-by-1 int16 vector.');
    end
    first_index = sample_range(1);
    last_index = min(sample_range(2), info.size(1));
    if first_index > info.size(1)
        error('dpll:InvalidSampleRange', 'sample_range starts after frontendOutput ends.');
    end
    mapped = matfile(mat_path);
    codes = mapped.frontendOutput(first_index:last_index, 1);
    sample_rate_hz = double(metadata.outputSampleRate);
    source_raw_rate_hz = double(metadata.sourceSampleRate);
    ratio = source_raw_rate_hz / sample_rate_hz;
    if ratio ~= round(ratio)
        error('dpll:NonIntegerTimeMapping', ...
            'sourceSampleRate/outputSampleRate must be an integer.');
    end
    input_data.format = 'frontendOutput';
    input_data.frontend_metadata = metadata;
    input_data.source_raw_sample_rate_hz = source_raw_rate_hz;
    input_data.source_samples_per_input = round(ratio);
    input_data.source_raw_start_index = 1 + (first_index - 1) * round(ratio);
    input_data.source_raw_total_count = double(metadata.sourceSampleCount);
else
    raw = load(mat_path, 'pll_input_codes', 'sample_rate_hz');
    if ~isfield(raw, 'pll_input_codes') || ~isfield(raw, 'sample_rate_hz')
        error('dpll:MissingInputField', ...
            ['MAT file must contain either frontendOutput+metadata or ' ...
             'pll_input_codes+sample_rate_hz.']);
    end
    if ~isa(raw.pll_input_codes, 'int16') || ~isvector(raw.pll_input_codes) || ...
            ~isreal(raw.pll_input_codes)
        error('dpll:InvalidCodes', 'pll_input_codes must be a real int16 vector.');
    end
    first_index = sample_range(1);
    last_index = min(sample_range(2), numel(raw.pll_input_codes));
    codes = raw.pll_input_codes(first_index:last_index);
    sample_rate_hz = double(raw.sample_rate_hz);
    input_data.format = 'legacy';
    input_data.source_raw_sample_rate_hz = sample_rate_hz;
    input_data.source_samples_per_input = 1;
    input_data.source_raw_start_index = first_index;
    input_data.source_raw_total_count = numel(raw.pll_input_codes);
end
if abs(sample_rate_hz - 3125000) > 1e-6
    error('dpll:InvalidSampleRate', 'Input sample rate must be exactly 3125000.');
end

input_data.pll_input_codes = codes(:);
input_data.sample_rate_hz = sample_rate_hz;
input_data.source_file = char(mat_path);
input_data.input_start_index = first_index;
input_data.input_end_index = last_index;
end
