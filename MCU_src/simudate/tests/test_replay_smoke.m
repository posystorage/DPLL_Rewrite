function result = test_replay_smoke()
cfg = dpll_current_config(20000);
input_data = generate_synthetic_input(0.08, 20000, 6000);
result = simulate_dpll(input_data, cfg);
assert(~isempty(result.phase_error));
assert(strcmp(result.metadata.startup_mode, 'prelocked'));
assert(any(result.loop_state == 6), 'Synthetic replay did not reach TRACK.');
assert(any(result.trace.analysis_valid), 'Prelocked replay has no analysis-valid samples.');
assert(all(result.tracking_word > 0));
assert(~result.metadata.posterior_interval_data_used);
assert(all(diff(result.word_history.fabric_tick) >= 0));
assert(result.metadata.initial_frequency_hz > 19990 && ...
    result.metadata.initial_frequency_hz < 20010);

cfg.architecture.controller_update_mode = 'phase_each_fll_block_once';
decoupled = simulate_dpll(input_data, cfg);
assert(decoupled.status.controller_update_count > ...
    decoupled.status.fll_integral_update_count * 8, ...
    'Decoupled PI/FLL scheduling did not reduce FLL integral applications.');
assert(any(decoupled.trace.controller_updated));

oracle_input = input_data;
time_s = (0:numel(oracle_input.pll_input_codes)-1).' / ...
    oracle_input.sample_rate_hz;
oracle_input.oracle_reference_phase_rad = 2 * pi * 20000 * time_s;
oracle_cfg = cfg;
oracle_cfg.architecture.phase_observation_mode = 'oracle';
oracle = simulate_dpll(oracle_input, oracle_cfg);
assert(strcmp(oracle.metadata.phase_observation_mode, 'oracle'));
assert(any(oracle.trace.phase_error ~= oracle.trace.rtl_phase_error));
truth_events = validate_truth_reference_cycle_events(oracle, ...
    oracle_input.oracle_reference_phase_rad, oracle_input.sample_rate_hz, 0.005);
assert(~truth_events.posterior_peak_data_loaded);
assert(all(isfinite(truth_events.pll_residual_error)));

delayed_cfg = oracle_cfg;
delayed_cfg.architecture.phase_observation_mode = 'oracle_delayed';
delayed_cfg.architecture.oracle_phase_delay_s = 200e-6;
delayed = simulate_dpll(oracle_input, delayed_cfg);
assert(strcmp(delayed.metadata.phase_observation_mode, 'oracle_delayed'));
assert(delayed.metadata.oracle_phase_delay_s == 200e-6);

cold_cfg = dpll_current_config(20000);
cold_cfg.startup.mode = 'cold';
cold = simulate_dpll(input_data, cold_cfg);
assert(strcmp(cold.metadata.startup_mode, 'cold'));
assert(any(cold.loop_state == 6), 'Cold-start regression did not reach TRACK.');
end
