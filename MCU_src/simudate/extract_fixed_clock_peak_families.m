function extraction = extract_fixed_clock_peak_families( ...
    pci_path, output_mat, options)
%EXTRACT_FIXED_CLOCK_PEAK_FAMILIES Multi-family fractional CH1 extraction.
%
% Candidate events are detected in bounded-memory chunks. The macro period
% is estimated by pair-difference voting, not by assuming two events per
% cycle. All stable phase families are retained. Each event is localized at
% a signed discrete extremum and refined by a three-point parabola.

arguments
    pci_path (1,1) string
    output_mat (1,1) string
    options.dataset_id (1,1) string = ""
    options.channel_index (1,1) double = 1
    options.channel_count (1,1) double = 2
    options.header_bytes (1,1) double = 1024
    options.sample_rate_hz (1,1) double = 62.5e6
    options.analysis_sample_count (1,1) double = 80e6
    options.nominal_macro_period_samples (1,1) double = 340000
    options.period_search_fraction (1,1) double = 0.30
    options.period_histogram_bin_samples (1,1) double = 100
    options.phase_cluster_tolerance_fraction (1,1) double = 0.02
    options.envelope_smooth_samples (1,1) double = 25
    options.event_merge_gap_samples (1,1) double = 1800
    options.threshold_noise_factor (1,1) double = 4
    options.detection_chunk_samples (1,1) double = 5e6
    options.classification_half_width (1,1) double = 4000
    options.peak_search_half_width (1,1) double = 1200
    options.template_half_width (1,1) double = 200
    options.minimum_family_events (1,1) double = 20
    options.minimum_template_correlation (1,1) double = 0.75
    options.minimum_family_occupancy (1,1) double = 0.80
    options.maximum_interval_residual_fraction (1,1) double = 0.02
    options.source_sha256 (1,1) string = ""
    options.compute_source_sha256 (1,1) logical = true
end

if ~isfile(pci_path)
    error('reference_analysis:PciNotFound', ...
        'PCI source does not exist: %s', pci_path);
end
if isfile(output_mat)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite peak-family result: %s', output_mat);
end
validateattributes(options.channel_index, {'numeric'}, ...
    {'integer', '>=', 1, '<=', options.channel_count});
validateattributes(options.analysis_sample_count, {'numeric'}, ...
    {'integer', 'positive'});
validateattributes(options.minimum_family_events, {'numeric'}, ...
    {'integer', '>=', 3});
validateattributes(options.minimum_family_occupancy, {'numeric'}, ...
    {'>', 0, '<=', 1});
validateattributes(options.maximum_interval_residual_fraction, {'numeric'}, ...
    {'positive', '<', 0.5});

file_info = dir(pci_path);
data_bytes = double(file_info.bytes) - options.header_bytes;
bytes_per_time_sample = 2 * options.channel_count;
if data_bytes <= 0 || mod(data_bytes, bytes_per_time_sample) ~= 0
    error('reference_analysis:InvalidPciLength', ...
        'PCI data length does not match the configured channels.');
end
source_count = data_bytes / bytes_per_time_sample;
analysis_count = min(source_count, options.analysis_sample_count);

[baseline, noise_sigma] = estimate_channel_baseline_noise(pci_path, ...
    options, min(1e6, analysis_count));
[event_location, event_score] = detect_candidate_events( ...
    pci_path, analysis_count, baseline, noise_sigma, options);
edge_margin = max(options.peak_search_half_width + 2, ...
    options.template_half_width);
inside = event_location > edge_margin & ...
    event_location <= analysis_count - edge_margin;
event_location = event_location(inside);
event_score = event_score(inside);
if numel(event_location) < 2 * options.minimum_family_events
    error('reference_analysis:InsufficientCandidateEvents', ...
        'Only %d candidate events were detected.', numel(event_location));
end

[macro_period, period_diagnostics] = estimate_macro_period( ...
    event_location, options);
[family_assignment, family_phase, cluster_diagnostics] = ...
    cluster_event_phases(event_location, macro_period, options);
family_ids = unique(family_assignment(family_assignment > 0));
families = repmat(empty_family(), 0, 1);
for n = 1:numel(family_ids)
    family_id = family_ids(n);
    use = family_assignment == family_id;
    if nnz(use) < options.minimum_family_events, continue; end
    family = refine_family(pci_path, event_location(use), ...
        event_score(use), family_phase(family_id), macro_period, ...
        cluster_diagnostics.origin_raw_sample, baseline, noise_sigma, options);
    if ~family.stable, continue; end
    family.id = numel(families) + 1;
    families(end + 1, 1) = family; %#ok<AGROW>
end
if isempty(families)
    error('reference_analysis:NoStablePeakFamily', ...
        'No phase family contains enough events.');
end

for k = 1:numel(families)
    families(k).sampling_candidate = families(k).stable && ...
        families(k).polarity < 0 && ...
        families(k).median_template_correlation >= ...
        options.minimum_template_correlation;
end

extraction.schema_version = 1;
extraction.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
extraction.dataset_id = char(options.dataset_id);
extraction.method = ['chunked absolute-envelope candidate detection; ' ...
    'pair-difference macro-period vote; circular multi-family clustering; ' ...
    'signed extremum plus quadratic fractional localization'];
extraction.pci_path = char(pci_path);
extraction.output_mat = char(output_mat);
extraction.source_file_bytes = file_info.bytes;
extraction.source_sample_count_per_channel = source_count;
extraction.analysis_sample_count = analysis_count;
extraction.analysis_duration_s = analysis_count / options.sample_rate_hz;
extraction.sample_rate_hz = options.sample_rate_hz;
extraction.baseline_code = baseline;
extraction.noise_sigma_code = noise_sigma;
extraction.event_location_raw = event_location;
extraction.event_score = event_score;
extraction.macro_period_samples = macro_period;
extraction.period_diagnostics = period_diagnostics;
extraction.cluster_diagnostics = cluster_diagnostics;
extraction.family_assignment = family_assignment;
extraction.families = families;
extraction.options = options;
extraction.sampling_candidate_family_ids = ...
    [families([families.sampling_candidate]).id].';
if strlength(options.source_sha256) > 0
    validate_sha256(options.source_sha256);
    extraction.pci_sha256 = char(upper(options.source_sha256));
elseif options.compute_source_sha256
    extraction.pci_sha256 = char(dpll.file_sha256(pci_path));
else
    extraction.pci_sha256 = '';
end

[output_dir, output_name, ~] = fileparts(output_mat);
if ~isempty(output_dir) && ~isfolder(output_dir), mkdir(output_dir); end
family_files = strings(numel(families), 1);
for k = 1:numel(families)
    family_files(k) = string(fullfile(output_dir, sprintf( ...
        '%s_family%02d.mat', output_name, families(k).id)));
    if isfile(family_files(k))
        error('reference_analysis:OutputExists', ...
            'Refusing to overwrite peak-family result: %s', family_files(k));
    end
end
for k = 1:numel(families)
    save_family_compatibility_mat(family_files(k), families(k), ...
        extraction, options.sample_rate_hz);
end
extraction.family_files = family_files;
save(output_mat, 'extraction', '-v7.3');

fprintf('\n固定时钟峰族提取完成：%s\n', options.dataset_id);
fprintf('  候选事件/宏周期/峰族：%d / %.6f / %d\n', ...
    numel(event_location), macro_period, numel(families));
for k = 1:numel(families)
    fprintf(['  family%02d: n=%d, polarity=%+d, phase=%.3f, ' ...
        'distance %.3f +/- %.3f, corr %.4f, occupancy %.3f, ' ...
        'candidate=%d\n'], ...
        families(k).id, numel(families(k).refined_location_raw), ...
        families(k).polarity, families(k).phase_center_samples, ...
        mean(families(k).refined_distance_raw), ...
        std(families(k).refined_distance_raw), ...
        families(k).median_template_correlation, ...
        families(k).cycle_occupancy, ...
        families(k).sampling_candidate);
end
end

function [baseline, noise_sigma] = estimate_channel_baseline_noise( ...
    path, options, count)
raw = read_channel_range(path, 1, count, options);
baseline = median(raw);
noise_sigma = 1.4826 * median(abs(raw - baseline));
if ~isfinite(noise_sigma) || noise_sigma <= 0
    noise_sigma = std(raw);
end
if ~isfinite(noise_sigma) || noise_sigma <= 0, noise_sigma = eps; end
end

function [locations, scores] = detect_candidate_events( ...
    path, total_count, baseline, noise_sigma, options)
chunk = options.detection_chunk_samples;
overlap = max(4 * options.event_merge_gap_samples, 10000);
step = chunk - overlap;
if step <= 0
    error('reference_analysis:InvalidDetectionChunk', ...
        'Detection chunk must exceed overlap.');
end
locations = zeros(0, 1);
scores = zeros(0, 1);
kernel = ones(options.envelope_smooth_samples, 1) / ...
    options.envelope_smooth_samples;
threshold = options.threshold_noise_factor * noise_sigma;
start_sample = 1;
while start_sample <= total_count
    count = min(chunk, total_count - start_sample + 1);
    raw = read_channel_range(path, start_sample, count, options);
    envelope = conv(abs(raw - baseline), kernel, 'same');
    above = find(envelope >= threshold);
    if ~isempty(above)
        breaks = [0; find(diff(above) > options.event_merge_gap_samples); ...
            numel(above)];
        local_location = zeros(numel(breaks) - 1, 1);
        local_score = zeros(size(local_location));
        for k = 1:numel(local_location)
            region = above(breaks(k) + 1:breaks(k + 1));
            [local_score(k), index] = max(envelope(region));
            local_location(k) = region(index);
        end
        global_location = start_sample - 1 + local_location;
        core_end = start_sample + count - 1;
        if core_end < total_count, core_end = core_end - overlap; end
        keep = global_location >= start_sample & global_location <= core_end;
        locations = [locations; global_location(keep)]; %#ok<AGROW>
        scores = [scores; local_score(keep)]; %#ok<AGROW>
    end
    if start_sample + count - 1 >= total_count, break; end
    start_sample = start_sample + step;
end
[locations, order] = sort(locations);
scores = scores(order);
[locations, scores] = merge_nearby_events(locations, scores, ...
    options.event_merge_gap_samples);
end

function [locations, scores] = merge_nearby_events(locations, scores, gap)
if isempty(locations), return; end
out_location = locations(1);
out_score = scores(1);
for k = 2:numel(locations)
    if locations(k) - out_location(end) <= gap
        if scores(k) > out_score(end)
            out_location(end) = locations(k);
            out_score(end) = scores(k);
        end
    else
        out_location(end + 1, 1) = locations(k); %#ok<AGROW>
        out_score(end + 1, 1) = scores(k); %#ok<AGROW>
    end
end
locations = out_location;
scores = out_score;
end

function [period, diagnostics] = estimate_macro_period(locations, options)
nominal = options.nominal_macro_period_samples;
low = nominal * (1 - options.period_search_fraction);
high = nominal * (1 + options.period_search_fraction);
differences = zeros(0, 1);
for k = 1:numel(locations)
    later = locations(k + 1:end) - locations(k);
    later = later(later >= low & later <= high);
    differences = [differences; later]; %#ok<AGROW>
end
if numel(differences) < options.minimum_family_events
    error('reference_analysis:MacroPeriodNotFound', ...
        'Too few pair differences fall in the macro-period search range.');
end
bin = options.period_histogram_bin_samples;
edges = (floor(low / bin) * bin:bin:ceil(high / bin) * bin).';
counts = histcounts(differences, edges);
[~, peak_bin] = max(counts);
center = 0.5 * (edges(peak_bin) + edges(peak_bin + 1));
near = abs(differences - center) <= 3 * bin;
period = median(differences(near));
diagnostics.search_range_samples = [low high];
diagnostics.vote_count = numel(differences);
diagnostics.histogram_edges = edges;
diagnostics.histogram_counts = counts(:);
diagnostics.winning_bin_center_samples = center;
diagnostics.refinement_count = nnz(near);
diagnostics.median_absolute_deviation_samples = ...
    median(abs(differences(near) - period));
end

function [assignment, centers, diagnostics] = cluster_event_phases( ...
    locations, period, options)
origin = locations(1);
phase = mod(locations - origin, period);
tolerance = options.phase_cluster_tolerance_fraction * period;
assignment = zeros(size(locations));
centers = zeros(0, 1);
remaining = true(size(phase));

% A transitive gap cluster can merge two real dat8 families when sparse
% noise events bridge the gap. Greedy circular-density modes require every
% member to lie directly near one center, so bridge events cannot join modes.
while nnz(remaining) >= options.minimum_family_events
    candidates = find(remaining);
    neighbor_count = zeros(numel(candidates), 1);
    for k = 1:numel(candidates)
        distance = circular_distance(phase(candidates), ...
            phase(candidates(k)), period);
        neighbor_count(k) = nnz(abs(distance) <= tolerance);
    end
    [best_count, best_position] = max(neighbor_count);
    if best_count < options.minimum_family_events, break; end
    seed = phase(candidates(best_position));
    distance = circular_distance(phase, seed, period);
    members = remaining & abs(distance) <= tolerance;
    center = mod(seed + median(distance(members)), period);
    distance = circular_distance(phase, center, period);
    members = remaining & abs(distance) <= tolerance;
    if nnz(members) < options.minimum_family_events
        remaining(candidates(best_position)) = false;
        continue;
    end
    centers(end + 1, 1) = center; %#ok<AGROW>
    assignment(members) = numel(centers);
    remaining(members) = false;
end
[centers, center_order] = sort(centers);
renumbered = zeros(size(assignment));
for k = 1:numel(center_order)
    renumbered(assignment == center_order(k)) = k;
end
assignment = renumbered;
diagnostics.origin_raw_sample = origin;
diagnostics.method = ...
    'greedy non-transitive circular-density modes';
diagnostics.phase_tolerance_samples = tolerance;
diagnostics.family_count = numel(centers);
diagnostics.family_centers_samples = centers;
diagnostics.family_event_counts = arrayfun(@(k) nnz(assignment == k), ...
    (1:numel(centers)).');
diagnostics.unassigned_event_count = nnz(assignment == 0);
end

function distance = circular_distance(value, center, period)
distance = mod(value - center + period / 2, period) - period / 2;
end

function validate_sha256(value)
if strlength(value) ~= 64 || isempty(regexp(char(value), ...
        '^[0-9A-Fa-f]{64}$', 'once'))
    error('reference_analysis:InvalidSha256', ...
        'source_sha256 must contain exactly 64 hexadecimal characters.');
end
end

function family = refine_family(path, coarse_location, event_score, ...
    phase_center, period, phase_origin, baseline, noise_sigma, options)
coarse_location = sort(double(coarse_location(:)));
search_half = options.peak_search_half_width;
windows = read_windows(path, round(coarse_location), search_half + 2, options);
pos_amp = nan(numel(coarse_location), 1);
neg_amp = nan(size(pos_amp));
for k = 1:numel(coarse_location)
    wave = windows(:, k) - baseline;
    pos_amp(k) = max(wave);
    neg_amp(k) = abs(min(wave));
end
if median(neg_amp) >= median(pos_amp), polarity = -1; else, polarity = 1; end

discrete_location = nan(size(coarse_location));
waveform_fractional_offset = nan(size(coarse_location));
amplitude = nan(size(coarse_location));
waveform_curvature = nan(size(coarse_location));
for k = 1:numel(coarse_location)
    wave = windows(:, k) - baseline;
    if polarity < 0
        [~, index] = min(wave(3:end - 2));
    else
        [~, index] = max(wave(3:end - 2));
    end
    index = index + 2;
    discrete_location(k) = round(coarse_location(k)) + ...
        index - (search_half + 3);
    triplet = wave(index - 1:index + 1);
    denominator = triplet(1) - 2 * triplet(2) + triplet(3);
    if abs(denominator) > eps(max(1, max(abs(triplet))))
        waveform_fractional_offset(k) = 0.5 * ...
            (triplet(1) - triplet(3)) / denominator;
    else
        waveform_fractional_offset(k) = 0;
    end
    waveform_fractional_offset(k) = max(-0.5, ...
        min(0.5, waveform_fractional_offset(k)));
    amplitude(k) = polarity * triplet(2);
    waveform_curvature(k) = polarity * denominator;
end

template_windows = read_windows(path, round(discrete_location), ...
    options.template_half_width, options);
template_windows = template_windows - median(template_windows, 1);
template = median(template_windows, 2);
template = normalize_columns(template);
correlation = nan(numel(coarse_location), 1);
fractional_offset = nan(numel(coarse_location), 1);
curvature = nan(numel(coarse_location), 1);
integer_seed_consistent = false(numel(coarse_location), 1);
lag_grid = (-1:1).';
for k = 1:numel(coarse_location)
    value = normalize_columns(template_windows(:, k));
    score = original_overlap_correlation(value, template, lag_grid);
    [~, maximum_index] = max(score);
    integer_seed_consistent(k) = maximum_index == 2;
    correlation(k) = score(2);
    fractional_offset(k) = parabolic_peak_offset(score, 2);
    curvature(k) = score(1) - 2 * score(2) + score(3);
end
refined_location = discrete_location + fractional_offset;

cycle_reference = phase_origin + phase_center;
cycle_index = round((refined_location - cycle_reference) / period);
[cycle_index, select_index] = select_best_cycle_candidate( ...
    cycle_index, correlation, amplitude);
refined_location = refined_location(select_index);
discrete_location = discrete_location(select_index);
fractional_offset = fractional_offset(select_index);
amplitude = amplitude(select_index);
curvature = curvature(select_index);
waveform_fractional_offset = waveform_fractional_offset(select_index);
waveform_curvature = waveform_curvature(select_index);
integer_seed_consistent = integer_seed_consistent(select_index);
correlation = correlation(select_index);
event_score = event_score(select_index);
coarse_location = coarse_location(select_index);

quality = correlation >= options.minimum_template_correlation & ...
    isfinite(refined_location) & isfinite(amplitude);
cycle_index = cycle_index(quality);
refined_location = refined_location(quality);
discrete_location = discrete_location(quality);
fractional_offset = fractional_offset(quality);
amplitude = amplitude(quality);
curvature = curvature(quality);
waveform_fractional_offset = waveform_fractional_offset(quality);
waveform_curvature = waveform_curvature(quality);
integer_seed_consistent = integer_seed_consistent(quality);
correlation = correlation(quality);
event_score = event_score(quality);
coarse_location = coarse_location(quality);

if isempty(cycle_index)
    span_count = 0;
    cycle_occupancy = 0;
    interval_residual = NaN;
    interval_residual_rms = Inf;
else
    span_count = cycle_index(end) - cycle_index(1) + 1;
    cycle_occupancy = numel(cycle_index) / span_count;
    interval_residual = diff(refined_location) - diff(cycle_index) * period;
    interval_residual_rms = sqrt(mean(interval_residual.^2));
end
[run_start, run_end, segment_id, segment_count] = ...
    longest_consecutive_run(cycle_index);
keep = run_start:run_end;

family = empty_family();
family.phase_center_samples = phase_center;
family.polarity = polarity;
family.all_coarse_location_raw = coarse_location;
family.all_discrete_location_raw = discrete_location;
family.all_fractional_offset_samples = fractional_offset;
family.all_waveform_fractional_offset_samples = ...
    waveform_fractional_offset;
family.all_refined_location_raw = refined_location;
family.all_macro_cycle_index = cycle_index;
family.all_template_correlation = correlation;
family.all_segment_id = segment_id;
family.coarse_location_raw = coarse_location(keep);
family.discrete_location_raw = discrete_location(keep);
family.fractional_offset_samples = fractional_offset(keep);
family.waveform_fractional_offset_samples = ...
    waveform_fractional_offset(keep);
family.refined_location_raw = refined_location(keep);
family.refined_distance_raw = diff(family.refined_location_raw);
family.macro_cycle_index = cycle_index(keep);
family.event_score = event_score(keep);
family.amplitude_code = amplitude(keep);
family.curvature_code = curvature(keep);
family.waveform_curvature_code = waveform_curvature(keep);
family.integer_seed_consistent = integer_seed_consistent(keep);
family.template_correlation = correlation(keep);
family.template_relative_sample = ...
    (-options.template_half_width:options.template_half_width).';
family.template_waveform = template;
family.median_template_correlation = median(correlation(keep));
family.minimum_template_correlation = min(correlation(keep));
family.median_snr = median(amplitude(keep)) / noise_sigma;
family.dropped_nonconsecutive_events = numel(cycle_index) - numel(keep);
family.accepted_event_count = numel(cycle_index);
family.cycle_span_count = span_count;
family.cycle_occupancy = cycle_occupancy;
family.interval_residual_samples = interval_residual;
family.interval_residual_rms_samples = interval_residual_rms;
family.segment_count = segment_count;
family.longest_segment_count = numel(keep);
family.stable = numel(keep) >= options.minimum_family_events && ...
    cycle_occupancy >= options.minimum_family_occupancy && ...
    interval_residual_rms <= ...
    options.maximum_interval_residual_fraction * period && ...
    family.median_template_correlation >= ...
    options.minimum_template_correlation;
family.sampling_candidate = false;
end

function [cycle_index, selected] = select_best_cycle_candidate( ...
    cycle_index, correlation, amplitude)
[unique_cycle, ~, group] = unique(cycle_index, 'sorted');
selected = zeros(numel(unique_cycle), 1);
for k = 1:numel(unique_cycle)
    candidates = find(group == k);
    score = correlation(candidates);
    score(~isfinite(score)) = -Inf;
    score = score + 1e-12 * amplitude(candidates);
    [~, best] = max(score);
    selected(k) = candidates(best);
end
cycle_index = unique_cycle;
end

function [first, last, segment_id, segment_count] = ...
    longest_consecutive_run(cycle_index)
if isempty(cycle_index)
    first = 1;
    last = 0;
    segment_id = zeros(0, 1);
    segment_count = 0;
    return;
end
breaks = [0; find(diff(cycle_index) ~= 1); numel(cycle_index)];
lengths = diff(breaks);
[~, index] = max(lengths);
first = breaks(index) + 1;
last = breaks(index + 1);
segment_count = numel(lengths);
segment_id = repelem((1:segment_count).', lengths);
end

function normalized = normalize_columns(value)
value = double(value);
value = value - mean(value, 1);
scale = sqrt(sum(value.^2, 1));
scale(scale <= 0 | ~isfinite(scale)) = 1;
normalized = value ./ scale;
end

function score = original_overlap_correlation(segment, template, lag_grid)
segment = double(segment(:));
template = double(template(:));
normalization = sqrt(sum(segment.^2) * sum(template.^2));
if ~isfinite(normalization) || normalization <= 0
    score = nan(numel(lag_grid), 1);
    return;
end
score = nan(numel(lag_grid), 1);
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
left = values(maximum_index - 1);
center = values(maximum_index);
right = values(maximum_index + 1);
denominator = left - 2 * center + right;
if ~isfinite(denominator) || ...
        abs(denominator) < 10 * eps(max(1, abs(center)))
    offset = 0;
else
    offset = 0.5 * (left - right) / denominator;
    offset = max(-0.5, min(0.5, offset));
end
end

function windows = read_windows(path, centers, half_width, options)
window_length = 2 * half_width + 1;
windows = zeros(window_length, numel(centers));
for k = 1:numel(centers)
    windows(:, k) = read_channel_range(path, ...
        centers(k) - half_width, window_length, options);
end
end

function raw = read_channel_range(path, first_sample, count, options)
fp = fopen(path, 'r', 'l');
if fp < 0
    error('reference_analysis:PciOpenFailed', 'Cannot open %s.', path);
end
cleanup = onCleanup(@() fclose(fp));
byte_offset = options.header_bytes + ...
    2 * ((first_sample - 1) * options.channel_count + ...
    (options.channel_index - 1));
if fseek(fp, byte_offset, 'bof') ~= 0
    error('reference_analysis:PciSeekFailed', ...
        'Cannot seek to raw sample %d.', first_sample);
end
raw = fread(fp, [count 1], 'uint16=>double', ...
    2 * (options.channel_count - 1));
if numel(raw) ~= count
    error('reference_analysis:ShortPciRead', ...
        'Read %d/%d samples at source index %d.', ...
        numel(raw), count, first_sample);
end
end

function family = empty_family()
family = struct('id', 0, 'phase_center_samples', NaN, ...
    'polarity', 0, 'coarse_location_raw', [], ...
    'discrete_location_raw', [], 'fractional_offset_samples', [], ...
    'refined_location_raw', [], 'refined_distance_raw', [], ...
    'macro_cycle_index', [], 'event_score', [], 'amplitude_code', [], ...
    'curvature_code', [], 'template_correlation', [], ...
    'waveform_fractional_offset_samples', [], ...
    'waveform_curvature_code', [], 'integer_seed_consistent', [], ...
    'template_relative_sample', [], 'template_waveform', [], ...
    'median_template_correlation', NaN, ...
    'minimum_template_correlation', NaN, 'median_snr', NaN, ...
    'all_coarse_location_raw', [], 'all_discrete_location_raw', [], ...
    'all_fractional_offset_samples', [], ...
    'all_waveform_fractional_offset_samples', [], ...
    'all_refined_location_raw', [], 'all_macro_cycle_index', [], ...
    'all_template_correlation', [], 'all_segment_id', [], ...
    'dropped_nonconsecutive_events', 0, 'accepted_event_count', 0, ...
    'cycle_span_count', 0, 'cycle_occupancy', 0, ...
    'interval_residual_samples', [], ...
    'interval_residual_rms_samples', Inf, 'segment_count', 0, ...
    'longest_segment_count', 0, 'stable', false, ...
    'sampling_candidate', false);
end

function save_family_compatibility_mat(path, family, extraction, sample_rate)
samplingPeakFirstLocation = family.refined_location_raw(1);
samplingPeakDistance = family.refined_distance_raw;
samplingPeakMeanDistance = mean(samplingPeakDistance);
channel1SampleRate = sample_rate;
peakExtractionMetadata.schemaVersion = 1;
peakExtractionMetadata.datasetId = extraction.dataset_id;
peakExtractionMetadata.familyId = family.id;
peakExtractionMetadata.polarity = family.polarity;
peakExtractionMetadata.samplingCandidate = family.sampling_candidate;
peakExtractionMetadata.sourcePci = extraction.pci_path;
peakExtractionMetadata.sourcePciSha256 = extraction.pci_sha256;
peakExtractionMetadata.coordinate = ...
    'one-based 62.5 MHz raw sample coordinate, fractional double';
peakExtractionMetadata.method = extraction.method;
peakExtractionMetadata.absoluteGroupDelayCalibrated = true;
save(path, 'samplingPeakFirstLocation', 'samplingPeakDistance', ...
    'samplingPeakMeanDistance', 'channel1SampleRate', ...
    'peakExtractionMetadata', '-v7.3');
end
