function result = test_replay_smoke()
cfg = dpll_current_config(20000);
input_data = generate_synthetic_input(0.08, 20000, 6000);
result = simulate_dpll(input_data, cfg);
assert(~isempty(result.phase_error));
assert(any(result.loop_state == 6), 'Synthetic replay did not reach TRACK.');
assert(all(result.tracking_word > 0));
assert(~isempty(result.events.predicted_interval_error), ...
    'Synthetic replay did not produce pulse intervals.');
assert(max(abs(result.events.identity_error_samples)) < 1e-6, ...
    'The two pulse interval prediction formulas disagree.');
assert(~result.metadata.posterior_interval_data_used);

anchor_index = result.trace.input_index(find(result.trace.loop_state == 6, 1, 'first')) + 1000;
cfg.pulse.first_pulse_sample_index = anchor_index;
anchored = dpll.predict_pulse_events(result.trace, cfg);
assert(anchored.anchor_used);
assert(abs(anchored.event_input_index(1) - anchor_index) < 1e-6, ...
    'First-pulse anchor was not preserved by event interpolation.');
end
