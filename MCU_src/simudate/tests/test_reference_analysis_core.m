function test_reference_analysis_core()
%TEST_REFERENCE_ANALYSIS_CORE Synthetic checks for the loop-free analysis.

sample_rate_hz = 200000;
duration_s = 0.18;
time_s = (0:round(duration_s * sample_rate_hz) - 1).' / sample_rate_hz;
carrier_frequency_hz = 20000;
modulation_frequency_hz = 30;
phase_modulation_cycles = 0.025;
truth_phase_cycles = carrier_frequency_hz * time_s + ...
    phase_modulation_cycles * sin(2 * pi * modulation_frequency_hz * time_s);
codes = int16(round(6000 * sin(2 * pi * truth_phase_cycles)));

dense = reference_analysis.estimate_iq_phase(codes, sample_rate_hz, ...
    observation_rate_hz=4000, iq_window_s=0.001, ...
    frequency_aperture_s=0.001);
assert(dense.reference_only);
assert(~dense.posterior_peak_data_loaded);
assert(abs(dense.carrier_frequency_hz - carrier_frequency_hz) < 0.2);

truth_at_dense = interp1(time_s, truth_phase_cycles, dense.time_s, 'pchip');
phase_delta = dense.phase_cycles - truth_at_dense;
phase_delta = phase_delta - mean(phase_delta);
assert(sqrt(mean(phase_delta.^2)) < 2e-4);

% Generate events that are exactly 113 truth-reference cycles apart. Their
% raw positions are intentionally fractional and must remain fractional.
first_target = ceil(interp1(time_s, truth_phase_cycles, 0.025));
last_target = floor(interp1(time_s, truth_phase_cycles, 0.155));
targets = (first_target:113:last_target).';
event_time_s = interp1(truth_phase_cycles, time_s, targets, 'pchip');
raw_index = 1 + event_time_s * sample_rate_hz;
samplingPeakFirstLocation = raw_index(1);
samplingPeakDistance = diff(raw_index);
samplingPeakMeanDistance = mean(samplingPeakDistance);
channel1SampleRate = sample_rate_hz;
peak_file = string(fullfile(tempdir, ...
    'reference_analysis_fractional_peak_test.mat'));
save(peak_file, 'samplingPeakFirstLocation', 'samplingPeakDistance', ...
    'samplingPeakMeanDistance', 'channel1SampleRate');
cleanup = onCleanup(@() delete_if_present(peak_file));

peaks = reference_analysis.load_peak_events(peak_file);
assert(~peaks.positions_were_rounded_by_loader);
assert(peaks.fractional_first_location || peaks.fractional_distance_count > 0);
assert(max(abs(peaks.raw_index - raw_index)) < 1e-10);

relation = reference_analysis.build_interval_relation(dense, peaks);
valid = relation.interval.valid;
assert(any(valid));
assert(relation.summary.minimum_observations_per_valid_interval >= 16);
assert(relation.summary.minimum_observations_per_valid_interval >= 5);
assert(relation.summary.identity_passed);
assert(relation.summary.identity_max_abs_output_cycles < 1e-9);
assert(relation.summary.reference_event_rms_output_cycles < 0.15);
assert(~relation.posterior_peak_data_used_for_controller);
assert(~relation.posterior_peak_data_used_for_training);
assert(~relation.simulated_loop_data_loaded);
assert(~relation.controller_configuration_used);

% The core must remain independent of all loop replay paths.
root_dir = fileparts(fileparts(mfilename('fullpath')));
source_files = [ ...
    string(fullfile(root_dir, '+reference_analysis', 'load_peak_events.m')); ...
    string(fullfile(root_dir, '+reference_analysis', 'estimate_iq_phase.m')); ...
    string(fullfile(root_dir, '+reference_analysis', 'build_interval_relation.m'))];
for k = 1:numel(source_files)
    source = lower(fileread(source_files(k)));
    assert(~contains(source, 'simulate_dpll'));
    assert(~contains(source, 'replay_mat'));
    assert(~contains(source, 'dpll_default_config'));
end

% Headless exports must keep the live figure hidden but persist a FIG that
% opens visibly with MATLAB's default openfig behavior.
base_path = string(tempname);
export_cleanup = onCleanup(@() delete_export_set(base_path));
fig = figure('Visible', 'off');
figure_cleanup = onCleanup(@() close_if_valid(fig));
ax = axes(fig);
plot(ax, 1:3, [1 4 2]);
dpll.export_paper_figure(fig, base_path, [3.2 2.4], 'Arial', ...
    ["png", "fig"]);
assert(strcmp(fig.Visible, 'off'));
assert(~isfile(base_path + ".pdf"));
assert(~isfile(base_path + ".svg"));
opened = openfig(base_path + ".fig");
opened_cleanup = onCleanup(@() close_if_valid(opened));
assert(strcmp(opened.Visible, 'on'));
clear opened_cleanup figure_cleanup export_cleanup
end

function delete_if_present(path)
if isfile(path)
    delete(path);
end
end

function delete_export_set(base_path)
for extension = [".png", ".pdf", ".svg", ".fig"]
    delete_if_present(base_path + extension);
end
end

function close_if_valid(fig)
if isgraphics(fig)
    close(fig);
end
end
