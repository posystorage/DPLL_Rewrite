function product = write_subsample_peak_distance_mat( ...
    extraction_source, family_id, output_mat, options)
%WRITE_SUBSAMPLE_PEAK_DISTANCE_MAT Save old-compatible fractional peaks.

arguments
    extraction_source
    family_id (1,1) double
    output_mat (1,1) string
    options.candidate_label (1,1) string = "sampling"
    options.physical_identity_confirmed (1,1) logical = false
end

if isfile(output_mat)
    error('reference_analysis:OutputExists', ...
        'Refusing to overwrite subsample peak MAT: %s', output_mat);
end
source_mat = "";
if ischar(extraction_source) || isstring(extraction_source)
    source_mat = string(extraction_source);
    if ~isfile(source_mat)
        error('reference_analysis:ExtractionNotFound', ...
            'Peak extraction MAT does not exist: %s', source_mat);
    end
    loaded = load(source_mat, 'extraction');
    extraction = loaded.extraction;
elseif isstruct(extraction_source)
    extraction = extraction_source;
else
    error('reference_analysis:InvalidExtraction', ...
        'extraction_source must be an extraction struct or MAT path.');
end

match = find([extraction.families.id] == family_id, 1);
if isempty(match)
    error('reference_analysis:FamilyNotFound', ...
        'Family %d is absent from the extraction.', family_id);
end
family = extraction.families(match);
if ~family.stable || ~family.sampling_candidate
    error('reference_analysis:NotSamplingCandidate', ...
        'Family %d is not a stable negative sampling candidate.', family_id);
end

samplingPeakLocation = double(family.refined_location_raw(:));
samplingPeakDiscreteLocation = double(family.discrete_location_raw(:));
samplingPeakFractionalOffset = double(family.fractional_offset_samples(:));
samplingPeakTemplateCorrelation = double(family.template_correlation(:));
samplingPeakFirstLocation = samplingPeakLocation(1);
samplingPeakDistance = diff(samplingPeakLocation);
samplingPeakMeanDistance = mean(samplingPeakDistance);
channel1SampleRate = double(extraction.sample_rate_hz);

peakExtractionMetadata.schemaVersion = 2;
peakExtractionMetadata.createdAt = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
peakExtractionMetadata.datasetId = extraction.dataset_id;
peakExtractionMetadata.familyId = family.id;
peakExtractionMetadata.candidateLabel = char(options.candidate_label);
peakExtractionMetadata.polarity = family.polarity;
peakExtractionMetadata.physicalIdentityConfirmed = ...
    options.physical_identity_confirmed;
peakExtractionMetadata.coordinate = ...
    'one-based 62.5 MHz raw PCI sample coordinate, fractional double';
peakExtractionMetadata.method = [ ...
    'multi-family coarse detection; discrete signed extremum identity; ' ...
    'median-template zero-lag normalized xcorr; three-point parabola'];
peakExtractionMetadata.sourcePci = extraction.pci_path;
peakExtractionMetadata.sourcePciSha256 = extraction.pci_sha256;
peakExtractionMetadata.sourceExtractionMat = char(source_mat);
peakExtractionMetadata.sourceExtractionMethod = extraction.method;
peakExtractionMetadata.analysisSampleCount = ...
    extraction.analysis_sample_count;
peakExtractionMetadata.macroPeriodSamples = ...
    extraction.macro_period_samples;
peakExtractionMetadata.cycleOccupancy = family.cycle_occupancy;
peakExtractionMetadata.segmentCount = family.segment_count;
peakExtractionMetadata.acceptedEventCount = family.accepted_event_count;
peakExtractionMetadata.exportedContiguousEventCount = ...
    numel(samplingPeakLocation);
peakExtractionMetadata.medianTemplateCorrelation = ...
    family.median_template_correlation;
peakExtractionMetadata.minimumTemplateCorrelation = ...
    family.minimum_template_correlation;
peakExtractionMetadata.posteriorPeakDiagnosticOnly = true;
peakExtractionMetadata.usedByController = false;
peakExtractionMetadata.usedFuturePeak = false;

[output_dir, ~, ~] = fileparts(output_mat);
if ~isempty(output_dir) && ~isfolder(output_dir), mkdir(output_dir); end
save(output_mat, 'samplingPeakFirstLocation', 'samplingPeakDistance', ...
    'samplingPeakMeanDistance', 'channel1SampleRate', ...
    'samplingPeakLocation', 'samplingPeakDiscreteLocation', ...
    'samplingPeakFractionalOffset', ...
    'samplingPeakTemplateCorrelation', 'peakExtractionMetadata', '-v7.3');

product.output_mat = char(output_mat);
product.family_id = family.id;
product.candidate_label = char(options.candidate_label);
product.event_count = numel(samplingPeakLocation);
product.interval_count = numel(samplingPeakDistance);
product.mean_distance_samples = samplingPeakMeanDistance;
product.fractional_offset_rms_samples = ...
    sqrt(mean(samplingPeakFractionalOffset.^2));
product.median_template_correlation = ...
    median(samplingPeakTemplateCorrelation);
product.sha256 = char(dpll.file_sha256(output_mat));
end
