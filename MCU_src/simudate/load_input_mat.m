function input_data = load_input_mat(mat_path)
%LOAD_INPUT_MAT Load the strict 3.125 MSPS FPGA-equivalent input contract.

arguments
    mat_path (1,1) string
end

if ~isfile(mat_path)
    error('dpll:InputNotFound', 'Input MAT file does not exist: %s', mat_path);
end
raw = load(mat_path, 'pll_input_codes', 'sample_rate_hz');
if ~isfield(raw, 'pll_input_codes') || ~isfield(raw, 'sample_rate_hz')
    error('dpll:MissingInputField', ...
        'MAT file must contain pll_input_codes and sample_rate_hz.');
end
if ~isa(raw.pll_input_codes, 'int16') || ~isvector(raw.pll_input_codes) || ...
        ~isreal(raw.pll_input_codes)
    error('dpll:InvalidCodes', ...
        'pll_input_codes must be a real int16 vector of FPGA-equivalent codes.');
end
if ~isnumeric(raw.sample_rate_hz) || ~isscalar(raw.sample_rate_hz) || ...
        ~isfinite(raw.sample_rate_hz) || abs(double(raw.sample_rate_hz) - 3125000) > 1e-6
    error('dpll:InvalidSampleRate', 'sample_rate_hz must be exactly 3125000.');
end

input_data.pll_input_codes = raw.pll_input_codes(:);
input_data.sample_rate_hz = double(raw.sample_rate_hz);
input_data.source_file = char(mat_path);
end
