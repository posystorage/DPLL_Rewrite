function result = simulate_dpll(input_data, cfg)
%SIMULATE_DPLL Replay 3.125 MSPS FPGA-equivalent data through the DPLL.
%
% Datapath updates are event-driven, while every event carries an exact
% 125 MHz fabric tick. The downstream MUL/DIV and final DDS remain outside
% the agreed model boundary.

if nargin < 2
    cfg = dpll_current_config(20000);
end
validate_input(input_data, cfg);
codes = input_data.pll_input_codes(:);
sample_count = numel(codes);
max_trace = ceil(sample_count / cfg.cic.rate) + 8;
trace = allocate_trace(max_trace);
phase_observation_mode = lower(string( ...
    cfg.architecture.phase_observation_mode));
oracle_enabled = phase_observation_mode ~= "rtl";
if oracle_enabled
    validate_oracle_input(input_data, sample_count, cfg);
    nco_phase_at_input = zeros(sample_count, 1);
else
    nco_phase_at_input = zeros(0, 1);
end

[startup, manager_state, active_track] = initialize_startup(codes, input_data, cfg);
commanded_word = startup.tracking_word;
active_nco_word = startup.tracking_word;
freq_state = startup.freq_state;
freq_correction = startup.freq_state;
phase_acc = startup.phase_accumulator;
phase_unwrapped = startup.phase_rad;

base_tick = int64(round((input_data.input_start_index - 1) * ...
    cfg.fabric_clocks_per_input));
phase_tick = base_tick;
pending_nco_tick = int64(-1);
pending_nco_word = active_nco_word;

history_capacity = max_trace + 2;
command_tick = zeros(history_capacity, 1, 'int64');
command_word = zeros(history_capacity, 1, 'uint64');
command_count = 1;
command_tick(1) = base_tick;
command_word(1) = commanded_word;
nco_tick = zeros(history_capacity, 1, 'int64');
nco_word = zeros(history_capacity, 1, 'uint64');
nco_count = 1;
nco_tick(1) = base_tick;
nco_word(1) = active_nco_word;

cic_state = [];
iir_state = [];
fll_state = [];
loop_filter_state.freq_state = freq_state;
phase_error_hold = int64(0);
freq_error = int64(0);
freq_error_available = false;
signal_present = false;
active_bypass = cfg.iir.mode == 0;
trace_count = 0;
status = initialize_status();
fll_cfg = cfg.fll;
fll_cfg.rate = cfg.cic.rate;
analysis_start_input_index = input_data.input_start_index + ...
    round(cfg.startup.preroll_duration_s * cfg.input_sample_rate_hz);
if strcmpi(cfg.startup.mode, 'cold')
    analysis_start_input_index = input_data.input_start_index;
end

for local_n = 1:sample_count
    global_n = input_data.input_start_index + local_n - 1;
    sample_tick = base_tick + int64((local_n - 1) * cfg.fabric_clocks_per_input);
    [phase_acc, phase_unwrapped, phase_tick, active_nco_word, ...
        pending_nco_tick, nco_tick, nco_word, nco_count] = ...
        advance_nco(phase_acc, phase_unwrapped, phase_tick, sample_tick, ...
        active_nco_word, pending_nco_tick, pending_nco_word, ...
        nco_tick, nco_word, nco_count, cfg);

    nco_phase = double(phase_acc) / 2^cfg.word_width * (2 * pi);
    if oracle_enabled
        nco_phase_at_input(local_n) = phase_unwrapped;
    end
    lo_cos = int64(round_away(32767 * cos(nco_phase)));
    lo_sin = int64(round_away(-32767 * sin(nco_phase)));
    i_mixer = mixer_truncate(int64(codes(local_n)) * lo_cos);
    q_mixer = mixer_truncate(int64(codes(local_n)) * lo_sin);

    [cic_state, cic_valid, i_cic, q_cic, cic_sat] = ...
        dpll.post_cic_step(cic_state, i_mixer, q_mixer, cfg.cic);
    status.cic_saturation_count = status.cic_saturation_count + double(cic_sat);
    if ~cic_valid
        continue;
    end

    requested_track = cfg.iir.mode == 2 || ...
        (cfg.iir.mode == 3 && (manager_state.track_iir_preheat || ...
        manager_state.loop_state == 5 || manager_state.loop_state == 6));
    requested_bypass = cfg.iir.mode == 0;
    if requested_track ~= active_track || requested_bypass ~= active_bypass
        active_track = requested_track;
        active_bypass = requested_bypass;
        iir_state = [];
        fll_state = [];
        status.iir_selection_reset_count = status.iir_selection_reset_count + 1;
        continue; % selection_changed clears this detector transaction.
    end

    if active_bypass
        i_baseband = i_cic;
        q_baseband = q_cic;
        iir_sat = false;
    else
        if active_track, coeff = cfg.iir.track; else, coeff = cfg.iir.acquire; end
        [iir_state, i_baseband, q_baseband, iir_sat] = ...
            dpll.post_iir_step(iir_state, i_cic, q_cic, coeff, cfg.iir);
    end
    status.iir_saturation_count = status.iir_saturation_count + double(iir_sat);

    cic_tick = sample_tick + int64(cfg.latency.mixer_to_post_cic_input_ticks + ...
        cfg.latency.post_cic_ticks);
    iq_tick = cic_tick + int64(cfg.latency.post_iir_ticks);
    cordic_tick = iq_tick + int64(cfg.latency.cordic_ticks);

    [phase_word, magnitude, cordic_out_of_range] = ...
        dpll.cordic_quantize(i_baseband, q_baseband, cfg);
    rtl_phase_error = dpll.fixed_wrap( ...
        phase_word - cfg.phase_setpoint, cfg.phase_width);
    new_phase_error = select_phase_observation(rtl_phase_error, ...
        input_data, nco_phase_at_input, local_n, cfg);
    status.cordic_out_of_range_count = status.cordic_out_of_range_count + ...
        double(cordic_out_of_range);
    if signal_present
        if cfg.magnitude_exit ~= 0 && magnitude < cfg.magnitude_exit
            signal_present = false;
        end
    elseif cfg.magnitude_enter == 0 || magnitude >= cfg.magnitude_enter
        signal_present = true;
    end

    % FLL and CORDIC run in parallel. The controller therefore consumes the
    % most recently completed CORDIC phase, not this IQ sample's phase.
    raw_control_phase_error = phase_error_hold;
    [fll_state, freq_valid, block_valid, fll_value, ambiguous] = ...
        dpll.cross_dot_fll_step(fll_state, i_baseband, q_baseband, fll_cfg);
    if freq_valid && ~ambiguous
        freq_error = fll_value;
        freq_error_available = true;
    end
    control_phase_error = dpll.phase_lead_predict( ...
        raw_control_phase_error, freq_error, cfg);
    status.fll_ambiguous_count = status.fll_ambiguous_count + double(ambiguous);

    controller_output = empty_controller_output(freq_state, freq_correction, commanded_word);
    tracking_apply_tick = int64(-1);
    [controller_update, control] = controller_schedule(manager_state, cfg, ...
        freq_valid, block_valid, ambiguous, freq_error_available);
    if controller_update
        [loop_filter_state, controller_output] = dpll.hybrid_loop_step( ...
            loop_filter_state, control_phase_error, freq_error, control, cfg);
        freq_state = controller_output.freq_state;
        freq_correction = controller_output.freq_correction;
        commanded_word = controller_output.tracking_word;
        tracking_apply_tick = iq_tick + int64(cfg.latency.fll_to_tracking_word_ticks);
        command_count = command_count + 1;
        command_tick(command_count) = tracking_apply_tick;
        command_word(command_count) = commanded_word;
        pending_nco_tick = tracking_apply_tick + int64(cfg.latency.tracking_dds_ticks);
        pending_nco_word = commanded_word;
        status.controller_saturation_high_count = ...
            status.controller_saturation_high_count + double(controller_output.saturated_high);
        status.controller_saturation_low_count = ...
            status.controller_saturation_low_count + double(controller_output.saturated_low);
        status.controller_update_count = status.controller_update_count + 1;
        status.fll_integral_update_count = status.fll_integral_update_count + ...
            double(control.enable_fll);
        status.fll_feedforward_update_count = status.fll_feedforward_update_count + ...
            double(control.enable_fll_feedforward);
        status.phase_2p2z_update_count = status.phase_2p2z_update_count + ...
            double(control.enable_phase_2p2z);
        status.phase_2p2z_saturation_high_count = ...
            status.phase_2p2z_saturation_high_count + ...
            double(controller_output.phase_2p2z_saturated_high);
        status.phase_2p2z_saturation_low_count = ...
            status.phase_2p2z_saturation_low_count + ...
            double(controller_output.phase_2p2z_saturated_low);
    end

    if block_valid && ~ambiguous
        measurement.phase_error = raw_control_phase_error;
        measurement.freq_error = freq_error;
        measurement.saturated_high = controller_output.saturated_high;
        measurement.saturated_low = controller_output.saturated_low;
        [manager_state, ~] = dpll.state_manager_step(manager_state, measurement, cfg);
    end
    phase_error_hold = new_phase_error;

    trace_count = trace_count + 1;
    trace.input_index(trace_count) = global_n;
    trace.fabric_tick(trace_count) = cordic_tick;
    trace.time_s(trace_count) = double(cordic_tick) / cfg.fabric_clock_hz;
    trace.i_baseband(trace_count) = i_baseband;
    trace.q_baseband(trace_count) = q_baseband;
    trace.phase_error(trace_count) = new_phase_error;
    trace.rtl_phase_error(trace_count) = rtl_phase_error;
    trace.control_phase_error(trace_count) = control_phase_error;
    trace.raw_control_phase_error(trace_count) = raw_control_phase_error;
    trace.freq_error(trace_count) = freq_error;
    trace.freq_error_valid(trace_count) = freq_valid && ~ambiguous;
    trace.freq_error_block_valid(trace_count) = block_valid && ~ambiguous;
    trace.fll_ambiguous(trace_count) = ambiguous;
    trace.cordic_out_of_range(trace_count) = cordic_out_of_range;
    trace.freq_state(trace_count) = freq_state;
    trace.freq_correction(trace_count) = freq_correction;
    trace.tracking_word(trace_count) = commanded_word;
    trace.active_nco_word(trace_count) = active_nco_word;
    trace.tracking_word_apply_tick(trace_count) = tracking_apply_tick;
    trace.tracking_frequency_hz(trace_count) = ...
        double(commanded_word) * cfg.fabric_clock_hz / 2^cfg.word_width;
    trace.tracking_phase_rad(trace_count) = phase_unwrapped;
    trace.loop_state(trace_count) = manager_state.loop_state;
    trace.loss_reason(trace_count) = manager_state.loss_reason;
    trace.magnitude(trace_count) = magnitude;
    trace.signal_present(trace_count) = signal_present;
    trace.analysis_valid(trace_count) = global_n >= analysis_start_input_index && ...
        manager_state.loop_state == 6;
    trace.cic_saturated(trace_count) = cic_sat;
    trace.iir_saturated(trace_count) = iir_sat;
    trace.controller_saturated_high(trace_count) = controller_output.saturated_high;
    trace.controller_saturated_low(trace_count) = controller_output.saturated_low;
    trace.fll_term(trace_count) = controller_output.fll_term;
    trace.i_term(trace_count) = controller_output.i_term;
    trace.p_term(trace_count) = controller_output.p_term;
    trace.ff_term(trace_count) = controller_output.ff_term;
    trace.phase_2p2z_term(trace_count) = controller_output.phase_2p2z_term;
    trace.phase_2p2z_accumulator(trace_count) = ...
        controller_output.phase_2p2z_accumulator;
    trace.phase_2p2z_saturated_high(trace_count) = ...
        controller_output.phase_2p2z_saturated_high;
    trace.phase_2p2z_saturated_low(trace_count) = ...
        controller_output.phase_2p2z_saturated_low;
    trace.controller_updated(trace_count) = controller_update;
    trace.fll_integral_applied(trace_count) = controller_update && control.enable_fll;
    trace.fll_feedforward_applied(trace_count) = ...
        controller_update && control.enable_fll_feedforward;
end

trace = trim_trace(trace, trace_count);
first_analysis = find(trace.analysis_valid, 1, 'first');
if isempty(first_analysis)
    effective_analysis_start_input_index = input_data.input_end_index + 1;
else
    effective_analysis_start_input_index = trace.input_index(first_analysis);
end
result.metadata.model_name = cfg.model_name;
result.metadata.source_file = get_source_file(input_data);
result.metadata.input_format = input_data.format;
result.metadata.input_sample_count = sample_count;
result.metadata.input_sample_rate_hz = input_data.sample_rate_hz;
result.metadata.input_start_index = input_data.input_start_index;
result.metadata.source_raw_sample_rate_hz = input_data.source_raw_sample_rate_hz;
result.metadata.source_samples_per_input = input_data.source_samples_per_input;
result.metadata.source_raw_start_index = input_data.source_raw_start_index;
result.metadata.source_raw_last_mapped_index = input_data.source_raw_start_index + ...
    (sample_count - 1) * input_data.source_samples_per_input;
result.metadata.startup_mode = lower(cfg.startup.mode);
result.metadata.initial_frequency_hz = startup.frequency_hz;
result.metadata.initial_tracking_word = startup.tracking_word;
result.metadata.initial_phase_rad = startup.phase_rad;
result.metadata.preroll_duration_s = cfg.startup.preroll_duration_s;
result.metadata.analysis_start_input_index = effective_analysis_start_input_index;
result.metadata.analysis_start_raw_index = input_data.source_raw_start_index + ...
    (effective_analysis_start_input_index - input_data.input_start_index) * ...
    input_data.source_samples_per_input;
result.metadata.fixed_pipeline_latency_abstracted = false;
result.metadata.posterior_interval_data_used = false;
result.metadata.phase_observation_mode = char(phase_observation_mode);
result.metadata.oracle_phase_delay_s = ...
    double(cfg.architecture.oracle_phase_delay_s);
result.config = cfg;
result.trace = trace;
result.status = status;
result.word_history.fabric_tick = command_tick(1:command_count);
result.word_history.tracking_word = command_word(1:command_count);
result.nco_word_history.fabric_tick = nco_tick(1:nco_count);
result.nco_word_history.tracking_word = nco_word(1:nco_count);

result.phase_error = trace.phase_error;
result.freq_error = trace.freq_error;
result.freq_state = trace.freq_state;
result.freq_correction = trace.freq_correction;
result.tracking_word = trace.tracking_word;
result.loop_state = trace.loop_state;
end

function [startup, manager, active_track] = initialize_startup(codes, input_data, cfg)
if strcmpi(cfg.startup.mode, 'prelocked')
    startup = dpll.estimate_prelock(codes, input_data.sample_rate_hz, cfg);
    manager = initialize_manager(uint8(6));
    active_track = true;
elseif strcmpi(cfg.startup.mode, 'cold')
    startup.frequency_hz = cfg.center_frequency_hz;
    startup.phase_rad = 0;
    startup.phase_accumulator = uint64(0);
    startup.tracking_word = cfg.center_word;
    startup.freq_state = int64(0);
    startup.estimation_sample_count = 0;
    startup.zero_crossing_count = 0;
    manager = initialize_manager(uint8(3));
    active_track = false;
else
    error('dpll:InvalidStartupMode', 'startup.mode must be prelocked or cold.');
end
end

function manager = initialize_manager(loop_state)
manager.loop_state = loop_state;
manager.loss_reason = uint8(0);
manager.good_count = 0;
manager.bad_count = 0;
manager.warmup_count = 0;
manager.track_iir_preheat = false;
end

function trace = allocate_trace(count)
trace.input_index = zeros(count, 1);
trace.fabric_tick = zeros(count, 1, 'int64');
trace.time_s = zeros(count, 1);
trace.i_baseband = zeros(count, 1, 'int64');
trace.q_baseband = zeros(count, 1, 'int64');
trace.phase_error = zeros(count, 1, 'int64');
trace.rtl_phase_error = zeros(count, 1, 'int64');
trace.control_phase_error = zeros(count, 1, 'int64');
trace.raw_control_phase_error = zeros(count, 1, 'int64');
trace.freq_error = zeros(count, 1, 'int64');
trace.freq_error_valid = false(count, 1);
trace.freq_error_block_valid = false(count, 1);
trace.fll_ambiguous = false(count, 1);
trace.cordic_out_of_range = false(count, 1);
trace.freq_state = zeros(count, 1, 'int64');
trace.freq_correction = zeros(count, 1, 'int64');
trace.tracking_word = zeros(count, 1, 'uint64');
trace.active_nco_word = zeros(count, 1, 'uint64');
trace.tracking_word_apply_tick = -ones(count, 1, 'int64');
trace.tracking_frequency_hz = zeros(count, 1);
trace.tracking_phase_rad = zeros(count, 1);
trace.loop_state = zeros(count, 1, 'uint8');
trace.loss_reason = zeros(count, 1, 'uint8');
trace.magnitude = zeros(count, 1, 'int64');
trace.signal_present = false(count, 1);
trace.analysis_valid = false(count, 1);
trace.cic_saturated = false(count, 1);
trace.iir_saturated = false(count, 1);
trace.controller_saturated_high = false(count, 1);
trace.controller_saturated_low = false(count, 1);
trace.fll_term = zeros(count, 1, 'int64');
trace.i_term = zeros(count, 1, 'int64');
trace.p_term = zeros(count, 1, 'int64');
trace.ff_term = zeros(count, 1, 'int64');
trace.phase_2p2z_term = zeros(count, 1, 'int64');
trace.phase_2p2z_accumulator = zeros(count, 1, 'int64');
trace.phase_2p2z_saturated_high = false(count, 1);
trace.phase_2p2z_saturated_low = false(count, 1);
trace.controller_updated = false(count, 1);
trace.fll_integral_applied = false(count, 1);
trace.fll_feedforward_applied = false(count, 1);
end

function status = initialize_status()
status.cic_saturation_count = 0;
status.iir_saturation_count = 0;
status.cordic_out_of_range_count = 0;
status.controller_saturation_high_count = 0;
status.controller_saturation_low_count = 0;
status.iir_selection_reset_count = 0;
status.fll_ambiguous_count = 0;
status.controller_update_count = 0;
status.fll_integral_update_count = 0;
status.fll_feedforward_update_count = 0;
status.phase_2p2z_update_count = 0;
status.phase_2p2z_saturation_high_count = 0;
status.phase_2p2z_saturation_low_count = 0;
end

function [phase_acc, phase_unwrapped, phase_tick, active_word, pending_tick, ...
    history_tick, history_word, history_count] = advance_nco( ...
    phase_acc, phase_unwrapped, phase_tick, target_tick, active_word, ...
    pending_tick, pending_word, history_tick, history_word, history_count, cfg)
if pending_tick >= 0 && pending_tick <= target_tick
    [phase_acc, phase_unwrapped] = advance_segment(phase_acc, phase_unwrapped, ...
        pending_tick - phase_tick, active_word, cfg);
    phase_tick = pending_tick;
    active_word = pending_word;
    history_count = history_count + 1;
    history_tick(history_count) = pending_tick;
    history_word(history_count) = pending_word;
    pending_tick = int64(-1);
end
[phase_acc, phase_unwrapped] = advance_segment(phase_acc, phase_unwrapped, ...
    target_tick - phase_tick, active_word, cfg);
phase_tick = target_tick;
end

function [phase_acc, phase_unwrapped] = advance_segment( ...
    phase_acc, phase_unwrapped, delta_ticks, word, cfg)
if delta_ticks <= 0, return; end
increment = word * uint64(delta_ticks);
phase_acc = mod(phase_acc + increment, uint64(2^cfg.word_width));
phase_unwrapped = phase_unwrapped + double(word) * double(delta_ticks) / ...
    2^cfg.word_width * (2 * pi);
end

function validate_input(input_data, cfg)
required = {'pll_input_codes', 'sample_rate_hz', 'input_start_index', ...
    'source_raw_sample_rate_hz', 'source_samples_per_input', ...
    'source_raw_start_index', 'format'};
if ~isstruct(input_data) || ~all(isfield(input_data, required))
    error('dpll:InvalidInputStruct', 'input_data is missing timing or code fields.');
end
if ~isa(input_data.pll_input_codes, 'int16') || ~isvector(input_data.pll_input_codes)
    error('dpll:InvalidCodes', 'pll_input_codes must be an int16 vector.');
end
if double(input_data.sample_rate_hz) ~= cfg.input_sample_rate_hz
    error('dpll:InvalidSampleRate', 'Input sample rate must be 3125000 Hz.');
end
end

function y = round_away(x)
y = sign(x) .* floor(abs(x) + 0.5);
end

function y = mixer_truncate(product)
shifted = dpll.arshift(product, 13);
if shifted == 131072, y = int64(131071); ...
else, y = dpll.fixed_wrap(shifted, 18); end
end

function output = empty_controller_output(freq_state, freq_correction, tracking_word)
output.freq_state = freq_state;
output.freq_correction = freq_correction;
output.tracking_word = tracking_word;
output.fll_term = int64(0);
output.i_term = int64(0);
output.p_term = int64(0);
output.ff_term = int64(0);
output.phase_2p2z_term = int64(0);
output.phase_2p2z_accumulator = int64(0);
output.phase_2p2z_saturated_high = false;
output.phase_2p2z_saturated_low = false;
output.saturated_high = false;
output.saturated_low = false;
end

function [update, control] = controller_schedule(manager_state, cfg, ...
    freq_valid, block_valid, ambiguous, freq_error_available)
control = dpll.control_for_state(manager_state, cfg);
switch lower(cfg.architecture.controller_update_mode)
    case 'fll_replay'
        update = freq_valid && ~ambiguous;
        control.enable_fll_feedforward = ...
            control.enable_fll_feedforward && update;
    case 'phase_each_fll_block_once'
        update = true;
        control.enable_fll = control.enable_fll && block_valid && ~ambiguous;
        control.enable_fll_feedforward = control.enable_fll_feedforward && ...
            freq_error_available && ~ambiguous;
    otherwise
        error('dpll:InvalidControllerUpdateMode', ...
            'Unsupported controller_update_mode: %s', ...
            cfg.architecture.controller_update_mode);
end
end

function trace = trim_trace(trace, count)
names = fieldnames(trace);
for k = 1:numel(names), trace.(names{k}) = trace.(names{k})(1:count, :); end
end

function source_file = get_source_file(input_data)
if isfield(input_data, 'source_file'), source_file = input_data.source_file; ...
else, source_file = '<in-memory>'; end
end

function validate_oracle_input(input_data, sample_count, cfg)
valid_modes = ["oracle", "oracle_delayed"];
mode = lower(string(cfg.architecture.phase_observation_mode));
if ~any(mode == valid_modes)
    error('dpll:InvalidPhaseObservationMode', ...
        'phase_observation_mode must be rtl, oracle, or oracle_delayed.');
end
if ~isfield(input_data, 'oracle_reference_phase_rad') || ...
        ~isvector(input_data.oracle_reference_phase_rad) || ...
        numel(input_data.oracle_reference_phase_rad) ~= sample_count
    error('dpll:MissingOraclePhase', ...
        'Oracle observation requires one reference phase per input sample.');
end
if any(~isfinite(double(input_data.oracle_reference_phase_rad(:))))
    error('dpll:InvalidOraclePhase', ...
        'Oracle reference phase must be finite.');
end
validateattributes(cfg.architecture.oracle_phase_delay_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
end

function phase_error = select_phase_observation(rtl_phase_error, ...
    input_data, nco_phase_at_input, local_n, cfg)
mode = lower(string(cfg.architecture.phase_observation_mode));
if mode == "rtl"
    phase_error = rtl_phase_error;
    return;
end
delay_samples = double(cfg.architecture.oracle_phase_delay_s) * ...
    cfg.input_sample_rate_hz;
if mode == "oracle"
    delay_samples = 0;
end
query_index = local_n - delay_samples;
if query_index < 1
    phase_error = rtl_phase_error;
    return;
end
lower_index = floor(query_index);
upper_index = min(lower_index + 1, local_n);
fraction = query_index - lower_index;
reference_phase = interpolate_phase( ...
    double(input_data.oracle_reference_phase_rad(:)), ...
    lower_index, upper_index, fraction);
nco_phase = interpolate_phase(nco_phase_at_input, ...
    lower_index, upper_index, fraction);
delta = mod(reference_phase - nco_phase + pi, 2 * pi) - pi;
phase_error = dpll.fixed_wrap(int64(round_away( ...
    delta / pi * 2^(cfg.phase_width - 1))), cfg.phase_width);
end

function value = interpolate_phase(values, lower_index, upper_index, fraction)
value = values(lower_index) + fraction * ...
    (values(upper_index) - values(lower_index));
end
