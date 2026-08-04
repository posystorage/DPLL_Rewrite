function predicted = phase_lead_predict(phase_error, freq_error, cfg)
%PHASE_LEAD_PREDICT Fixed-point phase prediction from the held FLL estimate.
%
% freq_error converts to phase-word change per post-CIC sample by 1/16 for
% the current rate/word definitions. Integer lead samples therefore require
% only a multiply followed by four arithmetic right shifts in RTL.

lead_samples = int64(cfg.architecture.phase_lead_samples);
if lead_samples == 0
    predicted = int64(phase_error);
    return;
end
lead_term = dpll.arshift(int64(freq_error) * lead_samples, 4);
predicted = dpll.fixed_wrap(int64(phase_error) + lead_term, cfg.phase_width);
end
