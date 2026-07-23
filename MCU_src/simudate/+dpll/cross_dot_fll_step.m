function [state, freq_valid, block_valid, freq_error, ambiguous] = cross_dot_fll_step(state, i_in, q_in, cfg)
%CROSS_DOT_FLL_STEP Cross/dot FLL with 16-sample blocks and replay.

if isempty(state)
    state.i_delay = zeros(1, cfg.delay_samples, 'int64');
    state.q_delay = zeros(1, cfg.delay_samples, 'int64');
    state.history_count = 0;
    state.block_count = 0;
    state.dot_acc = int64(0);
    state.cross_acc = int64(0);
    state.replay_count = 0;
    state.replay_error = int64(0);
    state.replay_ambiguous = false;
end

freq_valid = state.replay_count > 0;
block_valid = state.replay_count == cfg.block_samples;
freq_error = state.replay_error;
ambiguous = state.replay_ambiguous;
if freq_valid
    state.replay_count = state.replay_count - 1;
end

i_in = int64(i_in);
q_in = int64(q_in);
delayed_i = state.i_delay(end);
delayed_q = state.q_delay(end);
history_ready = state.history_count >= cfg.delay_samples;
state.i_delay = [i_in, state.i_delay(1:end-1)];
state.q_delay = [q_in, state.q_delay(1:end-1)];
state.history_count = min(state.history_count + 1, 15);
if ~history_ready
    return;
end

dot_value = i_in * delayed_i + q_in * delayed_q;
cross_value = q_in * delayed_i - i_in * delayed_q;
state.dot_acc = state.dot_acc + dot_value;
state.cross_acc = state.cross_acc + cross_value;
state.block_count = state.block_count + 1;
if state.block_count < cfg.block_samples
    return;
end

normalization = int64(cfg.rate * cfg.delay_samples);
if state.dot_acc <= 0 || normalization == 0
    next_error = int64(0);
    next_ambiguous = true;
else
    % The RTL numerator is 71 bits. MATLAB int64 cannot hold that product,
    % so evaluate the same positive integer ratio in double before flooring.
    % The operands themselves remain exact integers and the final result is
    % only 22 bits; RTL co-simulation is the authority for boundary-LSB ties.
    denominator = state.dot_acc * normalization;
    quotient = int64(floor(double(abs(state.cross_acc)) * ...
        double(cfg.angle_freq_scale) / double(denominator)));
    if state.cross_acc < 0
        quotient = -quotient;
    end
    [next_error, ~, ~] = dpll.fixed_saturate(quotient, 22);
    next_ambiguous = false;
end
state.dot_acc = int64(0);
state.cross_acc = int64(0);
state.block_count = 0;
state.replay_error = next_error;
state.replay_ambiguous = next_ambiguous;
state.replay_count = cfg.block_samples;
end
