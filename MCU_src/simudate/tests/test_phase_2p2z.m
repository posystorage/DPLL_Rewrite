function test_phase_2p2z()
%TEST_PHASE_2P2Z Fixed-point recurrence, saturation, and legacy isolation.

designed = dpll.design_phase_2p2z_q(195312.5, 75, 0.9, 12000, 22, 18);
assert(designed.b2 == -designed.b0 && designed.b1 == 0);
assert(designed.maximum_pole_radius < 1);
assert(abs(designed.quantized_peak_gain_word_per_phase_code - 12000) < 5);

candidates = build_reference_only_2p2z_candidates();
for candidate_index = 1:numel(candidates)
    assert(strlength(string(candidates(candidate_index).cfg.files.peak_mat)) == 0);
end
experiment_source = fileread(fullfile(fileparts(fileparts( ...
    mfilename('fullpath'))), 'run_reference_only_2p2z_experiment.m'));
assert(~contains(experiment_source, 'load_peak_prior'));
assert(~contains(experiment_source, 'samplingPeakDistance'));
launcher_source = fileread(fullfile(fileparts(fileparts( ...
    mfilename('fullpath'))), 'start_dpll_simulation.m'));
assert(contains(launcher_source, ...
    'comparisonCandidateIds = ["p8_iir8k_baseline"'));
assert(contains(launcher_source, '"p8_iir8k_2p2z_wide"]'));
assert(contains(launcher_source, 'validate_exact_reference_cycle_events'));
assert(contains(launcher_source, 'run_peak_validation'));
assert(contains(launcher_source, ...
    "'manual_simulation_comparison', resultTag"));
assert(contains(launcher_source, ...
    'plot_virtual_stretch_comparison_cn'));
assert(contains(launcher_source, 'plot_final_comparison_cn'));
assert(~contains(launcher_source, 'bar('));
assert(contains(launcher_source, 'plot_acceptance_text_table'));
assert(contains(launcher_source, ...
    '113周期端点相位差（mrad）'));
assert(contains(launcher_source, ...
    'comparisonRun.posterior_peak_data_used_for_control = false'));
assert(contains(launcher_source, ...
    'comparisonRun.posterior_peak_data_used_for_selection = false'));

cfg = designed;
cfg.coefficient_frac = 2;
cfg.input_width = 8;
cfg.output_width = 12;
cfg.accumulator_width = 32;
cfg.b0 = int64(4);
cfg.b1 = int64(2);
cfg.b2 = int64(0);
cfg.a1 = int64(-2);
cfg.a2 = int64(1);
state = [];
[state, first] = dpll.fixed_2p2z_step(state, int64(4), cfg);
[state, second] = dpll.fixed_2p2z_step(state, int64(0), cfg);
[~, third] = dpll.fixed_2p2z_step(state, int64(0), cfg);
assert(first.value == 4 && second.value == 4 && third.value == 1);

fast_state = [];
reference_state = [];
sequence = int64([127 -128 64 -17 0 91 -3 126 -127 11]);
for k = 1:40
    input_value = sequence(mod(k - 1, numel(sequence)) + 1);
    [fast_state, fast_output] = dpll.fixed_2p2z_step( ...
        fast_state, input_value, cfg);
    [reference_state, reference_output] = slow_reference_2p2z( ...
        reference_state, input_value, cfg);
    assert(fast_output.value == reference_output.value);
    assert(fast_output.accumulator == reference_output.accumulator);
    assert(fast_output.saturated_high == reference_output.saturated_high);
    assert(fast_output.saturated_low == reference_output.saturated_low);
end

cfg.b0 = int64(400);
cfg.b1 = int64(0);
cfg.a1 = int64(0);
cfg.a2 = int64(0);
cfg.output_width = 8;
[saturated_state, saturated] = dpll.fixed_2p2z_step([], int64(200), cfg); %#ok<ASGLU>
assert(saturated.input_saturated_high);
assert(saturated.output_saturated_high && saturated.value == 127);

legacy_cfg = dpll_current_config(20000);
manager.loop_state = uint8(6);
control = dpll.control_for_state(manager, legacy_cfg);
assert(~control.enable_phase_2p2z);
new_state = [];
legacy_state = [];
phase_values = int64([-911 0 127 504 -333 88 -1 700]);
freq_values = int64([15 -12 8 0 21 -7 3 11]);
for k = 1:numel(phase_values)
    [new_state, new_output] = dpll.hybrid_loop_step(new_state, ...
        phase_values(k), freq_values(k), control, legacy_cfg);
    [legacy_state, legacy_output] = legacy_reference_step(legacy_state, ...
        phase_values(k), freq_values(k), control, legacy_cfg);
    assert(new_state.freq_state == legacy_state.freq_state);
    assert(new_output.freq_correction == legacy_output.freq_correction);
    assert(new_output.tracking_word == legacy_output.tracking_word);
    assert(new_output.phase_2p2z_term == 0);
end

enabled_cfg = legacy_cfg;
enabled_cfg.architecture.phase_2p2z_enable = true;
enabled_cfg.phase_2p2z = designed;
track_control = dpll.control_for_state(manager, enabled_cfg);
assert(track_control.enable_phase_2p2z);
[active_state, active_output] = dpll.hybrid_loop_step([], int64(1000), ...
    int64(0), track_control, enabled_cfg);
assert(~isempty(active_state.phase_2p2z));
assert(active_output.phase_2p2z_term ~= 0);
manager.loop_state = uint8(5);
blend_control = dpll.control_for_state(manager, enabled_cfg);
assert(~blend_control.enable_phase_2p2z);
[reset_state, reset_output] = dpll.hybrid_loop_step(active_state, ...
    int64(1000), int64(0), blend_control, enabled_cfg);
assert(isempty(reset_state.phase_2p2z));
assert(reset_output.phase_2p2z_term == 0);
end

function [state, output] = slow_reference_2p2z(state, input_value, cfg)
if isempty(state)
    state.x1 = int64(0); state.x2 = int64(0);
    state.y1 = int64(0); state.y2 = int64(0);
end
[x, input_high, input_low] = dpll.fixed_saturate(input_value, cfg.input_width);
raw = int64(cfg.b0) * x + int64(cfg.b1) * state.x1 + ...
    int64(cfg.b2) * state.x2 - int64(cfg.a1) * state.y1 - ...
    int64(cfg.a2) * state.y2;
[accumulator, accumulator_high, accumulator_low] = ...
    dpll.fixed_saturate(raw, cfg.accumulator_width);
scaled = dpll.arshift(accumulator, cfg.coefficient_frac);
[y, output_high, output_low] = dpll.fixed_saturate(scaled, cfg.output_width);
state.x2 = state.x1; state.x1 = x;
state.y2 = state.y1; state.y1 = y;
output.value = y;
output.accumulator = accumulator;
output.saturated_high = input_high || accumulator_high || output_high;
output.saturated_low = input_low || accumulator_low || output_low;
end

function [state, output] = legacy_reference_step(state, phase_error, ...
    freq_error, control, cfg)
if isempty(state), state.freq_state = int64(0); end
fll_term = int64(0);
i_term = int64(0);
p_term = int64(0);
ff_term = int64(0);
if control.enable_fll
    fll_term = dpll.arshift(int64(freq_error) * control.kf, ...
        cfg.shifts.fll_product);
end
if control.enable_pll_i
    i_term = dpll.arshift(int64(phase_error) * control.ki, ...
        cfg.shifts.i_product);
end
if control.enable_pll_p
    p_term = dpll.arshift(int64(phase_error) * control.kp, ...
        cfg.shifts.p_product);
end
if control.enable_fll_feedforward
    ff_term = dpll.arshift(int64(freq_error) * control.kff, ...
        cfg.shifts.ff_product);
end
state_sum = state.freq_state + fll_term + i_term;
new_state = min(max(state_sum, cfg.negative_limit), cfg.positive_limit);
push_high = state.freq_state >= cfg.positive_limit && ...
    (fll_term + i_term) > 0;
push_low = state.freq_state <= cfg.negative_limit && ...
    (fll_term + i_term) < 0;
if ~(push_high || push_low), state.freq_state = new_state; end
correction_sum = state.freq_state + p_term + ff_term;
output.freq_correction = min(max(correction_sum, ...
    cfg.negative_limit), cfg.positive_limit);
tracking_signed = int64(cfg.center_word) + output.freq_correction;
tracking_signed = min(max(tracking_signed, int64(0)), int64(2^48 - 1));
output.tracking_word = uint64(tracking_signed);
end
