function result = simulate_dpll(input_data, cfg)
%SIMULATE_DPLL Replay FPGA-equivalent 3.125 MSPS data through the DPLL.
%
% This is an event-driven fixed-point model. Data-dependent CIC/IIR/FLL
% behavior is modeled; constant 125 MHz pipeline latency is abstracted.

if nargin < 2
    cfg = dpll_current_config();
end
validate_input(input_data, cfg);
codes = input_data.pll_input_codes(:);
sample_count = numel(codes);
max_trace = ceil(sample_count / cfg.cic.rate) + 8;

trace.input_index = zeros(max_trace, 1);
trace.time_s = zeros(max_trace, 1);
trace.i_baseband = zeros(max_trace, 1, 'int64');
trace.q_baseband = zeros(max_trace, 1, 'int64');
trace.phase_error = zeros(max_trace, 1, 'int64');
trace.freq_error = zeros(max_trace, 1, 'int64');
trace.freq_error_valid = false(max_trace, 1);
trace.freq_error_block_valid = false(max_trace, 1);
trace.fll_ambiguous = false(max_trace, 1);
trace.freq_state = zeros(max_trace, 1, 'int64');
trace.freq_correction = zeros(max_trace, 1, 'int64');
trace.tracking_word = zeros(max_trace, 1, 'uint64');
trace.tracking_frequency_hz = zeros(max_trace, 1);
trace.tracking_phase_rad = zeros(max_trace, 1);
trace.loop_state = zeros(max_trace, 1, 'uint8');
trace.loss_reason = zeros(max_trace, 1, 'uint8');
trace.magnitude = zeros(max_trace, 1, 'int64');
trace.signal_present = false(max_trace, 1);
trace.cic_saturated = false(max_trace, 1);
trace.iir_saturated = false(max_trace, 1);
trace.controller_saturated_high = false(max_trace, 1);
trace.controller_saturated_low = false(max_trace, 1);
trace.fll_term = zeros(max_trace, 1, 'int64');
trace.i_term = zeros(max_trace, 1, 'int64');
trace.p_term = zeros(max_trace, 1, 'int64');

cic_state = [];
iir_state = [];
fll_state = [];
loop_filter_state = [];
manager_state = initialize_manager();

tracking_word = cfg.center_word;
freq_state = int64(0);
freq_correction = int64(0);
phase_acc = uint64(0);
phase_modulus = uint64(2^48);
tracking_phase_unwrapped = 0;
freq_error = int64(0);
signal_present = false;
active_track = false;
active_bypass = cfg.iir.mode == 0;
trace_count = 0;

status.cic_saturation_count = 0;
status.iir_saturation_count = 0;
status.cordic_out_of_range_count = 0;
status.controller_saturation_high_count = 0;
status.controller_saturation_low_count = 0;
status.iir_selection_reset_count = 0;
status.fll_ambiguous_count = 0;

fll_cfg = cfg.fll;
fll_cfg.rate = cfg.cic.rate;
for n = 1:sample_count
    nco_phase = double(phase_acc) / 2^48 * (2 * pi);
    lo_cos = int64(round_away(32767 * cos(nco_phase)));
    lo_sin = int64(round_away(-32767 * sin(nco_phase)));
    i_mixer = mixer_truncate(int64(codes(n)) * lo_cos);
    q_mixer = mixer_truncate(int64(codes(n)) * lo_sin);

    [cic_state, cic_valid, i_cic, q_cic, cic_sat] = ...
        dpll.post_cic_step(cic_state, i_mixer, q_mixer, cfg.cic);
    if cic_sat
        status.cic_saturation_count = status.cic_saturation_count + 1;
    end

    if cic_valid
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
            cic_valid = false; % selection_changed clears this detector event.
        end
    end

    if cic_valid
        if active_bypass
            i_baseband = i_cic;
            q_baseband = q_cic;
            iir_sat = false;
        else
            if active_track
                coeff = cfg.iir.track;
            else
                coeff = cfg.iir.acquire;
            end
            [iir_state, i_baseband, q_baseband, iir_sat] = ...
                dpll.post_iir_step(iir_state, i_cic, q_cic, coeff, cfg.iir);
        end
        if iir_sat
            status.iir_saturation_count = status.iir_saturation_count + 1;
        end

        [phase_word, magnitude, cordic_out_of_range] = ...
            dpll.cordic_quantize(i_baseband, q_baseband, cfg);
        if cordic_out_of_range
            status.cordic_out_of_range_count = status.cordic_out_of_range_count + 1;
        end
        phase_error = dpll.fixed_wrap(phase_word - cfg.phase_setpoint, cfg.phase_width);
        if signal_present
            if cfg.magnitude_exit ~= 0 && magnitude < cfg.magnitude_exit
                signal_present = false;
            end
        elseif cfg.magnitude_enter == 0 || magnitude >= cfg.magnitude_enter
            signal_present = true;
        end

        [fll_state, freq_valid, block_valid, fll_value, ambiguous] = ...
            dpll.cross_dot_fll_step(fll_state, i_baseband, q_baseband, fll_cfg);
        if freq_valid
            freq_error = fll_value;
        end
        if ambiguous
            status.fll_ambiguous_count = status.fll_ambiguous_count + 1;
        end

        controller_output = empty_controller_output(freq_state, freq_correction, tracking_word);
        if freq_valid && ~ambiguous
            control = dpll.control_for_state(manager_state, cfg);
            if isempty(loop_filter_state)
                loop_filter_state.freq_state = freq_state;
            end
            [loop_filter_state, controller_output] = dpll.hybrid_loop_step( ...
                loop_filter_state, phase_error, freq_error, control, cfg);
            freq_state = controller_output.freq_state;
            freq_correction = controller_output.freq_correction;
            tracking_word = controller_output.tracking_word;
            if controller_output.saturated_high
                status.controller_saturation_high_count = ...
                    status.controller_saturation_high_count + 1;
            end
            if controller_output.saturated_low
                status.controller_saturation_low_count = ...
                    status.controller_saturation_low_count + 1;
            end
        end

        if block_valid && ~ambiguous
            measurement.phase_error = phase_error;
            measurement.freq_error = freq_error;
            measurement.saturated_high = controller_output.saturated_high;
            measurement.saturated_low = controller_output.saturated_low;
            [manager_state, ~] = dpll.state_manager_step(manager_state, measurement, cfg);
        end

        trace_count = trace_count + 1;
        trace.input_index(trace_count) = n;
        trace.time_s(trace_count) = (n - 1) / cfg.input_sample_rate_hz;
        trace.i_baseband(trace_count) = i_baseband;
        trace.q_baseband(trace_count) = q_baseband;
        trace.phase_error(trace_count) = phase_error;
        trace.freq_error(trace_count) = freq_error;
        trace.freq_error_valid(trace_count) = freq_valid && ~ambiguous;
        trace.freq_error_block_valid(trace_count) = block_valid && ~ambiguous;
        trace.fll_ambiguous(trace_count) = ambiguous;
        trace.freq_state(trace_count) = freq_state;
        trace.freq_correction(trace_count) = freq_correction;
        trace.tracking_word(trace_count) = tracking_word;
        trace.tracking_frequency_hz(trace_count) = ...
            double(tracking_word) * cfg.fabric_clock_hz / 2^48;
        trace.tracking_phase_rad(trace_count) = tracking_phase_unwrapped;
        trace.loop_state(trace_count) = manager_state.loop_state;
        trace.loss_reason(trace_count) = manager_state.loss_reason;
        trace.magnitude(trace_count) = magnitude;
        trace.signal_present(trace_count) = signal_present;
        trace.cic_saturated(trace_count) = cic_sat;
        trace.iir_saturated(trace_count) = iir_sat;
        trace.controller_saturated_high(trace_count) = controller_output.saturated_high;
        trace.controller_saturated_low(trace_count) = controller_output.saturated_low;
        trace.fll_term(trace_count) = controller_output.fll_term;
        trace.i_term(trace_count) = controller_output.i_term;
        trace.p_term(trace_count) = controller_output.p_term;
    end

    phase_increment = tracking_word * uint64(cfg.fabric_clocks_per_input);
    phase_acc = mod(phase_acc + phase_increment, phase_modulus);
    tracking_phase_unwrapped = tracking_phase_unwrapped + ...
        double(tracking_word) * cfg.fabric_clocks_per_input / 2^48 * (2 * pi);
end

trace = trim_trace(trace, trace_count);
events = dpll.predict_pulse_events(trace, cfg);
result.metadata.model_name = cfg.model_name;
result.metadata.source_file = get_source_file(input_data);
result.metadata.input_sample_count = sample_count;
result.metadata.input_sample_rate_hz = input_data.sample_rate_hz;
result.metadata.fixed_pipeline_latency_abstracted = ...
    cfg.options.abstract_fixed_pipeline_latency;
result.metadata.posterior_interval_data_used = false;
result.config = cfg;
result.trace = trace;
result.events = events;
result.status = status;

% Approved core outputs are also exposed at top level for convenient sweeps.
result.phase_error = trace.phase_error;
result.freq_error = trace.freq_error;
result.freq_state = trace.freq_state;
result.freq_correction = trace.freq_correction;
result.tracking_word = trace.tracking_word;
result.loop_state = trace.loop_state;
result.reference_phase = events.reference_phase;
result.tracking_phase = events.tracking_phase;
result.event_time_s = events.event_time_s;
result.event_input_index = events.event_input_index;
result.phase_error_at_event = events.phase_error_at_event;
result.tracking_phase_at_event = events.tracking_phase_at_event;
result.predicted_interval_samples = events.predicted_interval_samples;
result.predicted_interval_error = events.predicted_interval_error;
end

function validate_input(input_data, cfg)
if ~isstruct(input_data) || ~isfield(input_data, 'pll_input_codes') || ...
        ~isfield(input_data, 'sample_rate_hz')
    error('dpll:InvalidInputStruct', ...
        'input_data must contain pll_input_codes and sample_rate_hz.');
end
if ~isa(input_data.pll_input_codes, 'int16') || ~isvector(input_data.pll_input_codes)
    error('dpll:InvalidCodes', 'pll_input_codes must be an int16 vector.');
end
if double(input_data.sample_rate_hz) ~= cfg.input_sample_rate_hz
    error('dpll:InvalidSampleRate', 'Input sample rate must be 3125000 Hz.');
end
end

function manager = initialize_manager()
manager.loop_state = uint8(3);
manager.loss_reason = uint8(0);
manager.good_count = 0;
manager.bad_count = 0;
manager.warmup_count = 0;
manager.track_iir_preheat = false;
end

function y = round_away(x)
y = sign(x) .* floor(abs(x) + 0.5);
end

function y = mixer_truncate(product)
shifted = dpll.arshift(product, 13);
if shifted == 131072
    y = int64(131071);
else
    y = dpll.fixed_wrap(shifted, 18);
end
end

function output = empty_controller_output(freq_state, freq_correction, tracking_word)
output.freq_state = freq_state;
output.freq_correction = freq_correction;
output.tracking_word = tracking_word;
output.fll_term = int64(0);
output.i_term = int64(0);
output.p_term = int64(0);
output.saturated_high = false;
output.saturated_low = false;
end

function trace = trim_trace(trace, count)
names = fieldnames(trace);
for k = 1:numel(names)
    trace.(names{k}) = trace.(names{k})(1:count, :);
end
end

function source_file = get_source_file(input_data)
if isfield(input_data, 'source_file')
    source_file = input_data.source_file;
else
    source_file = '<in-memory>';
end
end
