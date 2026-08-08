function test_reference_peak_extractors()
%TEST_REFERENCE_PEAK_EXTRACTORS Multi-family and frontend PCI smoke tests.

rng(7, 'twister');
sample_count = 32000;
period = 1000;
phase = [100 250 500 750];
polarity = [1 -1 1 -1];
cycle_count = 31;
truth = cell(numel(phase), 1);
channel1 = 8192 + 2 * randn(sample_count, 1);
relative = (-15:15).';
for family = 1:numel(phase)
    center = phase(family) + (0:cycle_count - 1).' * period + ...
        0.22 * sin((0:cycle_count - 1).' * 0.71 + family);
    truth{family} = center;
    for k = 1:numel(center)
        integer_center = round(center(k));
        index = integer_center + relative;
        pulse = 420 * exp(-0.5 * ((index - center(k)) / 3.2).^2);
        channel1(index) = channel1(index) + polarity(family) * pulse;
    end
end
channel1 = uint16(max(0, min(16383, round(channel1))));
time = (0:sample_count - 1).';
channel2 = uint16(round(8192 + 1200 * sin(2 * pi * time / 97)));

base = string(tempname);
pci_path = base + ".pci";
peak_path = base + "_peaks.mat";
frontend_path = base + "_frontend.mat";
frontend_bin_path = base + "_frontend.bin";
subsample_path = base + "_subsample.mat";
table_dir = base + "_tables";
family_paths = base + "_peaks_family" + ...
    compose('%02d', (1:numel(phase)).') + ".mat";
cleanup = onCleanup(@() cleanup_artifacts([pci_path; peak_path; ...
    frontend_path; frontend_bin_path; subsample_path; family_paths], ...
    table_dir));
write_pci(pci_path, channel1, channel2);

extraction = extract_fixed_clock_peak_families(pci_path, peak_path, ...
    dataset_id="synthetic_four_family", ...
    sample_rate_hz=100000, analysis_sample_count=sample_count, ...
    nominal_macro_period_samples=period, period_search_fraction=0.10, ...
    period_histogram_bin_samples=1, ...
    phase_cluster_tolerance_fraction=0.03, ...
    envelope_smooth_samples=5, event_merge_gap_samples=20, ...
    threshold_noise_factor=4, detection_chunk_samples=15000, ...
    peak_search_half_width=20, template_half_width=12, ...
    minimum_family_events=10, minimum_template_correlation=0.70, ...
    compute_source_sha256=false);

assert(abs(extraction.macro_period_samples - period) < 0.5);
assert(numel(extraction.families) == 4);
assert(isequal([extraction.families.polarity], polarity));
assert(isequal(extraction.sampling_candidate_family_ids(:), [2; 4]));
assert(extraction.cluster_diagnostics.unassigned_event_count < 8);
bundle = export_fixed_clock_peak_family_tables(peak_path, table_dir);
assert(height(bundle.family_metrics) == 4);
assert(height(bundle.accepted_events) == 4 * cycle_count);
assert(height(bundle.candidate_assignment) == 4 * cycle_count);
assert(all(isfile(fullfile(table_dir, [ ...
    "peak_family_metrics.csv"; ...
    "accepted_fractional_peak_events.csv"; ...
    "coarse_candidate_assignment.csv"; ...
    "source_provenance.csv"]))));
subsample = write_subsample_peak_distance_mat(peak_path, 2, ...
    subsample_path, candidate_label="candidate_A", ...
    physical_identity_confirmed=false);
assert(subsample.event_count == cycle_count);
saved_subsample = load(subsample_path, 'samplingPeakLocation', ...
    'samplingPeakDistance', 'peakExtractionMetadata');
assert(isa(saved_subsample.samplingPeakLocation, 'double'));
assert(any(abs(saved_subsample.samplingPeakDistance - ...
    round(saved_subsample.samplingPeakDistance)) > 1e-6));
assert(saved_subsample.peakExtractionMetadata.familyId == 2);
assert(~saved_subsample.peakExtractionMetadata.physicalIdentityConfirmed);
for family = 1:numel(phase)
    result = extraction.families(family);
    assert(result.stable);
    assert(result.cycle_occupancy == 1);
    assert(numel(result.refined_location_raw) == cycle_count);
    assert(all(result.template_correlation > 0.95));
    assert(max(abs(result.discrete_location_raw - ...
        round(truth{family}))) <= 1);
    location_error = result.refined_location_raw - truth{family};
    location_error = location_error - median(location_error);
    assert(sqrt(mean(location_error.^2)) < 0.16);
    assert(any(abs(result.fractional_offset_samples) > 1e-4));
    assert(isfile(family_paths(family)));
    compatibility = load(family_paths(family), ...
        'samplingPeakFirstLocation', 'samplingPeakDistance');
    assert(isa(compatibility.samplingPeakFirstLocation, 'double'));
    assert(any(abs(compatibility.samplingPeakDistance - ...
        round(compatibility.samplingPeakDistance)) > 1e-6));
end

overwrite_blocked = false;
try
    extract_fixed_clock_peak_families(pci_path, peak_path, ...
        compute_source_sha256=false);
catch exception
    overwrite_blocked = strcmp(exception.identifier, ...
        'reference_analysis:OutputExists');
end
assert(overwrite_blocked);

mex_dir = string(['E:/JiangSiyi/THz器件采样/' ...
    '光源稳定性分析/20260723']);
mex_path = fullfile(mex_dir, "fpga_frontend_process_mex." + mexext);
if isfile(mex_path)
    known_sha = repmat('A', 1, 64);
    frontend = extract_pci_reference_frontend(pci_path, frontend_path, ...
        dataset_id="synthetic_frontend", output_bin=frontend_bin_path, ...
        frontend_mex_dir=mex_dir, ...
        source_chunk_length=10000, source_sha256=known_sha, ...
        compute_source_sha256=false);
    assert(frontend.source_sample_count == sample_count);
    assert(frontend.output_sample_count == ceil(sample_count / 20));
    saved = load(frontend_path, 'frontendOutput', 'metadata');
    assert(isa(saved.frontendOutput, 'int16'));
    assert(numel(saved.frontendOutput) == ceil(sample_count / 20));
    assert(strcmp(saved.metadata.sourceSha256, known_sha));
    assert(~saved.metadata.absoluteGroupDelayCalibrated);
    assert(isfile(frontend_bin_path));
    validation = validate_pci_frontend_pair( ...
        frontend_path, frontend_bin_path);
    assert(validation.bit_exact);
    assert(validation.output_sample_count == ceil(sample_count / 20));
    assert(strcmp(saved.metadata.outputBinFile, frontend_bin_path));
else
    fprintf('SKIP: synthetic frontend MEX smoke (%s not found).\n', mex_path);
end
end

function write_pci(path, channel1, channel2)
file_id = fopen(path, 'w', 'l');
if file_id < 0
    error('test:CannotCreatePci', 'Cannot create synthetic PCI file.');
end
cleanup = onCleanup(@() fclose(file_id));
header_count = fwrite(file_id, zeros(1024, 1, 'uint8'), 'uint8');
assert(header_count == 1024);
interleaved = [channel1(:).'; channel2(:).'];
sample_count = fwrite(file_id, interleaved, 'uint16');
assert(sample_count == 2 * numel(channel1));
end

function cleanup_artifacts(paths, table_dir)
for k = 1:numel(paths)
    if isfile(paths(k)), delete(paths(k)); end
end
if isfolder(table_dir), rmdir(table_dir, 's'); end
end
