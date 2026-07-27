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

cfg.startup.mode = 'cold';
cold = simulate_dpll(input_data, cfg);
assert(strcmp(cold.metadata.startup_mode, 'cold'));
assert(any(cold.loop_state == 6), 'Cold-start regression did not reach TRACK.');
end
