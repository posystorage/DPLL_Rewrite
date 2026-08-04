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
expected_scale = validation.metadata.ideal_output_interval / ...
    double(samplingPeakMeanDistance);
assert(abs(validation.fixed_to_output_scale - expected_scale) < 1e-12);
assert(strcmp(validation.metadata.fixed_clock_scale_source, ...
    'supplied samplingPeakMeanDistance prior'));

reference.peak_raw_index = validation.peak_raw_index;
reference.phase_cycles = (0:validation.summary.peak_count - 1).' * 113;
reference.zero_crossing_phase_cycles = reference.phase_cycles;
validation = attach_peak_reference_decomposition(validation, reference);
assert(validation.summary.reference_event_rms_error < 1e-12);
assert(abs(validation.summary.loop_only_rms_error - ...
    validation.summary.recovered_interval_rms_error) < 1e-9);
assert(~result.metadata.posterior_interval_data_used);
end

function delete_if_present(path)
if isfile(path), delete(path); end
end
