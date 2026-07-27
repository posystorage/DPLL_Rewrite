function test_peak_validation_boundary(result)
%TEST_PEAK_VALIDATION_BOUNDARY Exercise the separate posterior entry point.

fs = result.metadata.source_raw_sample_rate_hz;
first = ceil(result.metadata.analysis_start_raw_index) + 1000;
mean_distance = fs * 113 / 20000;
samplingPeakDistance = repmat(mean_distance, 6, 1);
samplingPeakFirstLocation = int64(first);
samplingPeakMeanDistance = int64(round(mean_distance));
channel1SampleRate = fs;
peak_file = string(fullfile(tempdir, 'dpll_synthetic_peak_validation.mat'));
save(peak_file, 'samplingPeakDistance', 'samplingPeakFirstLocation', ...
    'samplingPeakMeanDistance', 'channel1SampleRate');
cleanup = onCleanup(@() delete_if_present(peak_file));

validation = validate_peak_alignment(result, peak_file, false);
assert(validation.metadata.posterior_data_used);
assert(validation.summary.peak_count >= 3);
assert(all(isfinite(validation.recovered_interval_output_cycles)));
assert(~result.metadata.posterior_interval_data_used);
end

function delete_if_present(path)
if isfile(path), delete(path); end
end
