# post-IQ CIC Golden Trace

Source trace: `E:\FPGA\DPLL_Rewrite\DPLL_Rewrite_THbox_T3\reports\xsim\iq_cic_stage_a_cli_20260628_233322_825\post_iq_cic_trace.csv`

The checker models the current RTL non-blocking assignment timing, including:

- 3-stage integrator and 3-stage comb data path.
- Decimation using the pre-update integrator sample, matching the RTL register timing.
- Legal APPLY flush, illegal APPLY preservation, explicit flush, and warmup suppression.
- Sign-symmetric rounding, output saturation, and I/Q shared valid alignment.

Rows checked: 12

PASS: post-IQ CIC golden trace matches RTL.
