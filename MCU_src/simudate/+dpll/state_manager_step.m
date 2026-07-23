function [state, control] = state_manager_step(state, measurement, cfg)
%STATE_MANAGER_STEP Measurement-event form of loop_state_manager_stage_a.

if isempty(state)
    state.loop_state = uint8(3); % RESET/CONFIGURE elapse before first block.
    state.loss_reason = uint8(0);
    state.good_count = 0;
    state.bad_count = 0;
    state.warmup_count = 0;
    state.track_iir_preheat = false;
end

phase_ok = abs(int64(measurement.phase_error)) <= cfg.phase_threshold;
freq_ok = abs(int64(measurement.freq_error)) <= cfg.freq_threshold;
saturated = measurement.saturated_high || measurement.saturated_low;

switch double(state.loop_state)
    case 3 % WARMUP
        if state.warmup_count >= cfg.warmup_samples - 1
            state.loop_state = uint8(4);
            state.warmup_count = 0;
        else
            state.warmup_count = state.warmup_count + 1;
        end

    case {4, 8} % FLL_ACQUIRE / REACQUIRE
        if freq_ok && ~saturated
            state.bad_count = 0;
            state.loss_reason = uint8(0);
            if state.track_iir_preheat
                if state.good_count >= cfg.preheat_blocks - 1
                    state.loop_state = uint8(5);
                    state.track_iir_preheat = false;
                    state.good_count = 0;
                else
                    state.good_count = state.good_count + 1;
                end
            elseif state.good_count >= cfg.acquire_dwell - 1
                state.track_iir_preheat = true;
                state.good_count = 0;
            else
                state.good_count = state.good_count + 1;
            end
        else
            state.good_count = 0;
            state.bad_count = state.bad_count + 1;
            state.loss_reason = uint8(3 + 2 * saturated);
        end

    case 5 % FLL_PLL_BLEND
        state.track_iir_preheat = false;
        if freq_ok && ~saturated
            state.bad_count = 0;
            state.loss_reason = uint8(0);
            if phase_ok
                if state.good_count >= cfg.blend_dwell - 1
                    state.loop_state = uint8(6);
                    state.good_count = 0;
                else
                    state.good_count = state.good_count + 1;
                end
            else
                state.good_count = 0;
            end
        else
            state.good_count = 0;
            if state.bad_count >= cfg.loss_dwell - 1
                state.loop_state = uint8(8);
                state.loss_reason = uint8(3 + 2 * saturated);
                state.bad_count = 0;
            else
                state.bad_count = state.bad_count + 1;
            end
        end

    case 6 % PLL_TRACK
        if ~phase_ok || ~freq_ok || saturated
            if state.bad_count >= cfg.loss_dwell - 1
                state.loop_state = uint8(8);
                if saturated
                    state.loss_reason = uint8(5);
                elseif ~freq_ok
                    state.loss_reason = uint8(3);
                else
                    state.loss_reason = uint8(2);
                end
                state.bad_count = 0;
            else
                state.bad_count = state.bad_count + 1;
            end
        else
            state.bad_count = 0;
            state.loss_reason = uint8(0);
        end

    otherwise
        state.loop_state = uint8(8);
        state.loss_reason = uint8(6);
end
control = dpll.control_for_state(state, cfg);
end
