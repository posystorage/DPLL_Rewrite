function reference = estimate_independent_peak_reference(result, peak_raw_index, options)
%ESTIMATE_INDEPENDENT_PEAK_REFERENCE Reference phase at posterior event times.
%
% The reference phase comes only from the captured 3.125 MHz waveform. Peak
% positions select query times but do not fit phase gain, delay, or PLL gains.

arguments
    result (1,1) struct
    peak_raw_index (:,1) double
    options.half_bandwidth_hz (1,1) double = 500
end

% Load the complete captured reference so zero-phase FFT filtering has guard
% samples beyond the frozen replay interval. The PLL result remains frozen to
% its configured input range.
input_data = load_input_mat(string(result.metadata.source_file), [1 Inf]);
query_index = 1 + (double(peak_raw_index(:)) - ...
    double(input_data.source_raw_start_index)) / ...
    double(input_data.source_samples_per_input);
if any(query_index < 1 | query_index > numel(input_data.pll_input_codes))
    error('dpll:ReferencePhaseCoverage', ...
        'Independent reference waveform does not cover all peak events.');
end

zero = dpll.estimate_zero_crossing_phase(input_data.pll_input_codes, ...
    query_index, input_data.sample_rate_hz);
analytic = dpll.estimate_fft_analytic_phase(input_data.pll_input_codes, ...
    query_index, input_data.sample_rate_hz, zero.carrier_frequency_hz, ...
    options.half_bandwidth_hz);
if any(~analytic.coverage) || any(~zero.coverage)
    error('dpll:ReferencePhaseCoverage', ...
        'An independent phase estimator did not cover every peak event.');
end

reference.schema_version = 1;
reference.selected_method = 'fft_analytic';
reference.peak_raw_index = double(peak_raw_index(:));
reference.query_input_index = query_index;
reference.phase_cycles = analytic.phase_cycles;
reference.zero_crossing_phase_cycles = zero.phase_cycles;
reference.amplitude_codes = analytic.amplitude_codes;
reference.carrier_frequency_hz = analytic.carrier_frequency_hz;
reference.zero_crossing_frequency_hz = zero.carrier_frequency_hz;
reference.half_bandwidth_hz = options.half_bandwidth_hz;
reference.source_file = result.metadata.source_file;
reference.loaded_reference_input_range = [input_data.input_start_index, ...
    input_data.input_end_index];
reference.posterior_peak_data_loaded = true;
reference.phase_gain_fitted_from_peaks = false;
reference.time_delay_fitted_from_peaks = false;
end
