function peaks = load_peak_events(mat_path)
%LOAD_PEAK_EVENTS Load fixed-clock pulse events without rounding positions.

arguments
    mat_path (1,1) string
end

if ~isfile(mat_path)
    error('reference_analysis:PeakFileNotFound', ...
        'Peak-event MAT file does not exist: %s', mat_path);
end

variables = whos('-file', mat_path);
names = string({variables.name});
required = ["channel1SampleRate", "samplingPeakFirstLocation", ...
    "samplingPeakDistance"];
if ~all(ismember(required, names))
    error('reference_analysis:IncompletePeakFile', ...
        'Peak-event MAT file is missing one or more required variables.');
end

raw = load(mat_path, 'channel1SampleRate', ...
    'samplingPeakFirstLocation', 'samplingPeakDistance', ...
    'samplingPeakMeanDistance');
sample_rate_hz = double(raw.channel1SampleRate);
first_raw_index = double(raw.samplingPeakFirstLocation);
distance = double(raw.samplingPeakDistance(:));

validateattributes(sample_rate_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(first_raw_index, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
if isempty(distance) || ~isreal(distance) || ...
        any(~isfinite(distance) | distance <= 0)
    error('reference_analysis:InvalidPeakDistance', ...
        'samplingPeakDistance must be a nonempty positive finite vector.');
end

raw_index = first_raw_index + [0; cumsum(distance)];
if any(diff(raw_index) <= 0)
    error('reference_analysis:NonmonotonicPeakEvents', ...
        'Loaded peak positions are not strictly increasing.');
end

saved_mean = NaN;
if isfield(raw, 'samplingPeakMeanDistance')
    saved_mean = double(raw.samplingPeakMeanDistance);
end
fractional_tolerance = 1e-9;

peaks.schema_version = 1;
peaks.source_file = char(mat_path);
peaks.raw_sample_rate_hz = sample_rate_hz;
peaks.first_raw_index = first_raw_index;
peaks.raw_index = raw_index;
peaks.time_s = (raw_index - 1) / sample_rate_hz;
peaks.interval_raw_samples = distance;
peaks.interval_s = distance / sample_rate_hz;
peaks.saved_mean_interval_raw_samples = saved_mean;
peaks.event_count = numel(raw_index);
peaks.interval_count = numel(distance);
peaks.fractional_first_location = ...
    abs(first_raw_index - round(first_raw_index)) > fractional_tolerance;
peaks.fractional_distance_count = nnz( ...
    abs(distance - round(distance)) > fractional_tolerance);
peaks.positions_were_rounded_by_loader = false;
end
