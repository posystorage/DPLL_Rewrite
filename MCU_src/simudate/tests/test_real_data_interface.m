function test_real_data_interface()
cfg = dpll_current_config(20000);
cfg.io.input_sample_range = [1 10000];
input_data = load_input_mat(string(cfg.files.pll_input_mat), ...
    cfg.io.input_sample_range);
prior = load_peak_prior(string(cfg.files.peak_mat));
assert(strcmp(input_data.format, 'frontendOutput'));
assert(isa(input_data.pll_input_codes, 'int16'));
assert(numel(input_data.pll_input_codes) == 10000);
assert(input_data.sample_rate_hz == 3125000);
assert(input_data.source_raw_sample_rate_hz == 62500000);
assert(input_data.source_samples_per_input == 20);
assert(prior.first_peak_raw_index == 262206);
assert(prior.mean_interval_raw_samples == 340237);
assert(~prior.posterior_distance_loaded);
assert(~isfield(prior, 'samplingPeakDistance'));
end
