function prior = load_peak_prior(mat_path)
%LOAD_PEAK_PRIOR Read only the explicitly allowed peak prior fields.
%
% samplingPeakDistance is intentionally not requested from the MAT file.

arguments
    mat_path (1,1) string
end
if ~isfile(mat_path)
    error('dpll:PeakFileNotFound', 'Peak MAT file does not exist: %s', mat_path);
end
raw = load(mat_path, 'channel1SampleRate', ...
    'samplingPeakFirstLocation', 'samplingPeakMeanDistance');
required = {'channel1SampleRate', 'samplingPeakFirstLocation', ...
    'samplingPeakMeanDistance'};
if ~all(isfield(raw, required))
    error('dpll:MissingPeakPrior', 'Peak MAT file is missing an allowed prior field.');
end
validateattributes(raw.channel1SampleRate, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(raw.samplingPeakFirstLocation, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(raw.samplingPeakMeanDistance, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});

prior.source_file = char(mat_path);
prior.raw_sample_rate_hz = double(raw.channel1SampleRate);
prior.first_peak_raw_index = double(raw.samplingPeakFirstLocation);
prior.mean_interval_raw_samples = double(raw.samplingPeakMeanDistance);
prior.reference_cycles_per_pulse = 113;
prior.posterior_distance_loaded = false;
end
