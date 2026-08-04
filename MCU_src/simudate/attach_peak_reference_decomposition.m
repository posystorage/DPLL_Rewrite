function validation = attach_peak_reference_decomposition( ...
    validation, reference)
%ATTACH_PEAK_REFERENCE_DECOMPOSITION Split total and loop-only peak errors.

if ~isequal(double(validation.peak_raw_index(:)), ...
        double(reference.peak_raw_index(:)))
    error('dpll:PeakReferenceMismatch', ...
        'Independent reference events do not match validation peak events.');
end

multiplier = validation.metadata.output_multiplier;
ideal = validation.metadata.ideal_output_interval;
event_error = diff(double(reference.phase_cycles(:))) * multiplier - ideal;
zero_error = diff(double(reference.zero_crossing_phase_cycles(:))) * ...
    multiplier - ideal;
total_error = validation.recovered_interval_error(:);
loop_only_error = total_error - event_error;

validation.independent_reference = reference;
validation.reference_event_error = event_error;
validation.zero_crossing_reference_event_error = zero_error;
validation.loop_only_error = loop_only_error;
validation.summary.reference_event_rms_error = rms_plain(event_error);
validation.summary.zero_crossing_event_rms_error = rms_plain(zero_error);
validation.summary.loop_only_rms_error = rms_plain(loop_only_error);
validation.summary.total_vs_reference_event_correlation = ...
    corr(total_error, event_error);
validation.summary.reference_estimator_delta_rms_error = ...
    rms_plain(event_error - zero_error);
validation.summary.reference_event_lag1_correlation = ...
    lag1_correlation(event_error);
end

function value = rms_plain(x)
value = sqrt(mean(double(x).^2));
end

function value = lag1_correlation(x)
if numel(x) < 3
    value = NaN;
else
    value = corr(x(1:end-1), x(2:end));
end
end
