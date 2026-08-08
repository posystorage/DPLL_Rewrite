function extraction = refine_fixed_clock_peaks_subsample( ...
    pci_path, seed_peak_mat, output_mat, options)
%REFINE_FIXED_CLOCK_PEAKS_SUBSAMPLE Refine integer peak seeds without overwrite.
%
% This function reads only short CH1 windows around frozen seed locations.
% The first frozen, integer-xcorr-aligned event is retained as the template so
% this is a fractional refinement of the existing extraction convention, not
% a silent redefinition of peak identity. Every candidate lag is scored using
% an equal-length normalized correlation and the maximum is refined with a
% three-point parabola. Returned locations remain double precision in the
% original 62.5 MHz, one-based PCI coordinate.

arguments
    pci_path (1,1) string
    seed_peak_mat (1,1) string
    output_mat (1,1) string
    options.dataset_id (1,1) string = ""
    options.channel_index (1,1) double = 1
    options.channel_count (1,1) double = 2
    options.header_bytes (1,1) double = 1024
    options.sample_rate_hz (1,1) double = 62.5e6
    options.template_half_width (1,1) double = 200
    options.integer_search_half_width (1,1) double = 1
    options.template_iterations (1,1) double = 1
    options.minimum_correlation (1,1) double = 0.80
    options.compute_source_sha256 (1,1) logical = true
end

require_file(pci_path, "PCI");
require_file(seed_peak_mat, "Seed peak");
if isfile(output_mat)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite subsample peak result: %s', output_mat);
end
validateattributes(options.channel_index, {'numeric'}, ...
    {'integer', '>=', 1, '<=', options.channel_count});
validateattributes(options.channel_count, {'numeric'}, ...
    {'integer', '>=', 1});
validateattributes(options.header_bytes, {'numeric'}, ...
    {'integer', 'nonnegative'});
validateattributes(options.template_half_width, {'numeric'}, ...
    {'integer', '>=', 8});
validateattributes(options.integer_search_half_width, {'numeric'}, ...
    {'integer', '>=', 1});
validateattributes(options.template_iterations, {'numeric'}, ...
    {'integer', '>=', 1});

seed = load(seed_peak_mat, 'samplingPeakDistance', ...
    'samplingPeakFirstLocation', 'channel1SampleRate');
required = {'samplingPeakDistance', 'samplingPeakFirstLocation', ...
    'channel1SampleRate'};
if ~all(isfield(seed, required))
    error('reference_analysis:InvalidSeedPeakMat', ...
        'Seed MAT is missing one or more required peak variables.');
end
if abs(double(seed.channel1SampleRate) - options.sample_rate_hz) > 1e-6
    error('reference_analysis:PeakSampleRateMismatch', ...
        'Seed peak sample rate does not match the requested raw rate.');
end

seed_distance = double(seed.samplingPeakDistance(:));
seed_location = double(seed.samplingPeakFirstLocation) + ...
    [0; cumsum(seed_distance)];
if numel(seed_location) < 3 || any(~isfinite(seed_location)) || ...
        any(diff(seed_location) <= 0)
    error('reference_analysis:InvalidSeedLocations', ...
        'Seed peak locations must contain at least three increasing values.');
end

file_info = dir(pci_path);
bytes_per_time_sample = 2 * options.channel_count;
data_bytes = double(file_info.bytes) - options.header_bytes;
if data_bytes <= 0 || mod(data_bytes, bytes_per_time_sample) ~= 0
    error('reference_analysis:InvalidPciLength', ...
        'PCI length is incompatible with the configured interleaved format.');
end
source_sample_count = data_bytes / bytes_per_time_sample;

template_half = options.template_half_width;
search_half = options.integer_search_half_width;
if search_half ~= 1
    error('reference_analysis:InvalidFractionalSearch', ...
        ['Fractional refinement must preserve the frozen integer seed; ' ...
         'integer_search_half_width must therefore equal 1.']);
end
guard = 2;
extended_half = template_half + search_half + guard;
if any(round(seed_location) <= extended_half) || ...
        any(round(seed_location) > source_sample_count - extended_half)
    error('reference_analysis:SeedNearBoundary', ...
        'At least one seed cannot provide a complete refinement window.');
end

windows = read_interleaved_windows(pci_path, round(seed_location), ...
    extended_half, options.channel_index, options.channel_count, ...
    options.header_bytes);
relative_extended = (-extended_half:extended_half).';
relative_template = (-template_half:template_half).';
zero_columns = relative_extended >= -template_half & ...
    relative_extended <= template_half;
initial_stack = windows(zero_columns, :);
initial_stack = remove_column_baseline(initial_stack);
template = normalize_waveform(initial_stack(:, 1));

count = numel(seed_location);
integer_lag = zeros(count, 1);
fractional_lag = zeros(count, 1);
peak_correlation = nan(count, 1);
correlation_curvature = nan(count, 1);
correlation_grid = nan(2 * search_half + 1, count);
lag_grid = (-search_half:search_half).';
integer_seed_consistent = false(count, 1);
center_index = find(lag_grid == 0, 1);
for k = 1:count
    segment = initial_stack(:, k);
    segment = normalize_waveform(segment);
    score = original_overlap_correlation(segment, template, lag_grid);
    correlation_grid(:, k) = score;
    [~, maximum_index] = max(score);
    integer_seed_consistent(k) = maximum_index == center_index;
    peak_correlation(k) = score(center_index);
    fractional_lag(k) = parabolic_peak_offset(score, center_index);
    integer_lag(k) = 0;
    correlation_curvature(k) = score(center_index - 1) - ...
        2 * score(center_index) + score(center_index + 1);
end

refined_location = seed_location + fractional_lag;
refined_distance = diff(refined_location);
accepted = isfinite(peak_correlation) & ...
    peak_correlation >= options.minimum_correlation & ...
    integer_seed_consistent & abs(fractional_lag) <= 0.5;
if nnz(accepted) < count - 1
    error('reference_analysis:LowPeakCorrelation', ...
        ['Only %d/%d seed peaks pass the correlation threshold %.3f. ' ...
         'No peak file was saved.'], nnz(accepted), count, ...
        options.minimum_correlation);
end

samplingPeakFirstLocation = refined_location(1);
samplingPeakDistance = refined_distance;
samplingPeakMeanDistance = mean(refined_distance);
channel1SampleRate = options.sample_rate_hz;

extraction.schema_version = 1;
extraction.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
extraction.dataset_id = char(options.dataset_id);
extraction.method = ['frozen first-event template, equal-overlap normalized ' ...
    'correlation, three-point parabolic sub-sample interpolation'];
extraction.coordinate = ...
    'one-based original fixed-clock PCI sample coordinate, double precision';
extraction.pci_path = char(pci_path);
extraction.seed_peak_mat = char(seed_peak_mat);
extraction.output_mat = char(output_mat);
extraction.pci_bytes = file_info.bytes;
extraction.pci_sample_count_per_channel = source_sample_count;
extraction.sample_rate_hz = options.sample_rate_hz;
extraction.channel_index = options.channel_index;
extraction.channel_count = options.channel_count;
extraction.header_bytes = options.header_bytes;
extraction.seed_location_raw = seed_location;
extraction.refined_location_raw = refined_location;
extraction.seed_distance_raw = seed_distance;
extraction.refined_distance_raw = refined_distance;
extraction.integer_lag = integer_lag;
extraction.fractional_lag = fractional_lag;
extraction.peak_correlation = peak_correlation;
extraction.correlation_curvature = correlation_curvature;
extraction.integer_seed_consistent = integer_seed_consistent;
extraction.accepted = accepted;
extraction.template_relative_sample = relative_template;
extraction.template_waveform = template;
extraction.correlation_lag_grid = lag_grid;
extraction.correlation_grid = correlation_grid;
extraction.options = options;
extraction.seed_sha256 = char(dpll.file_sha256(seed_peak_mat));
if options.compute_source_sha256
    extraction.pci_sha256 = char(dpll.file_sha256(pci_path));
else
    extraction.pci_sha256 = '';
end
extraction.summary.peak_count = count;
extraction.summary.interval_count = numel(refined_distance);
extraction.summary.minimum_correlation = min(peak_correlation);
extraction.summary.median_correlation = median(peak_correlation);
extraction.summary.fractional_lag_rms_samples = ...
    sqrt(mean(fractional_lag.^2));
extraction.summary.fractional_lag_min_samples = min(fractional_lag);
extraction.summary.fractional_lag_max_samples = max(fractional_lag);
extraction.summary.refined_distance_mean_samples = mean(refined_distance);
extraction.summary.refined_distance_std_samples = std(refined_distance);

[output_dir, ~, ~] = fileparts(output_mat);
if ~isempty(output_dir) && ~isfolder(output_dir), mkdir(output_dir); end
save(output_mat, 'extraction', 'samplingPeakFirstLocation', ...
    'samplingPeakDistance', 'samplingPeakMeanDistance', ...
    'channel1SampleRate', '-v7.3');
end

function windows = read_interleaved_windows(path, centers, half_width, ...
    channel_index, channel_count, header_bytes)
fp = fopen(path, 'r', 'l');
if fp < 0
    error('reference_analysis:PciOpenFailed', ...
        'Cannot open PCI file: %s', path);
end
cleanup = onCleanup(@() fclose(fp));
window_length = 2 * half_width + 1;
windows = zeros(window_length, numel(centers));
for k = 1:numel(centers)
    first_sample = centers(k) - half_width;
    byte_offset = header_bytes + ...
        2 * (first_sample - 1) * channel_count;
    if fseek(fp, byte_offset, 'bof') ~= 0
        error('reference_analysis:PciSeekFailed', ...
            'Cannot seek to peak window %d.', k);
    end
    raw = fread(fp, [channel_count window_length], 'uint16=>double');
    if size(raw, 2) ~= window_length
        error('reference_analysis:ShortPciRead', ...
            'Peak window %d is incomplete.', k);
    end
    windows(:, k) = raw(channel_index, :).';
end
end

function centered = remove_column_baseline(values)
centered = values - median(values, 1, 'omitnan');
end

function normalized = normalize_waveform(values)
values = double(values(:));
values = values - mean(values, 'omitnan');
scale = sqrt(sum(values.^2, 'omitnan'));
if ~isfinite(scale) || scale <= 0
    error('reference_analysis:DegenerateTemplate', ...
        'The peak template has zero or invalid energy.');
end
normalized = values / scale;
end

function score = original_overlap_correlation(segment, template, lag_grid)
% Match MATLAB xcorr(segment, template, ..., 'coeff') around zero lag.
score = nan(numel(lag_grid), 1);
normalization = sqrt(sum(segment.^2) * sum(template.^2));
for k = 1:numel(lag_grid)
    lag = lag_grid(k);
    if lag >= 0
        x = segment(1 + lag:end);
        y = template(1:end - lag);
    else
        x = segment(1:end + lag);
        y = template(1 - lag:end);
    end
    score(k) = sum(x .* y) / normalization;
end
end

function offset = parabolic_peak_offset(values, maximum_index)
if maximum_index <= 1 || maximum_index >= numel(values)
    offset = 0;
    return;
end
left = values(maximum_index - 1);
center = values(maximum_index);
right = values(maximum_index + 1);
denominator = left - 2 * center + right;
if ~isfinite(denominator) || abs(denominator) < 10 * eps(max(1, abs(center)))
    offset = 0;
else
    offset = 0.5 * (left - right) / denominator;
    offset = max(-1, min(1, offset));
end
end

function require_file(path, role)
if ~isfile(path)
    error('reference_analysis:InputNotFound', ...
        '%s file not found: %s', role, path);
end
end
