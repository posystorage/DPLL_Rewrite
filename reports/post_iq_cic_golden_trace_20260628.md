# post-IQ CIC Golden Trace

Source trace: `E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\reports\xsim\iq_cic_stage_a_cli_20260720_210616_057\post_iq_cic_trace.csv`

The checker models the current RTL non-blocking assignment timing, including:

- 3-stage integrator and 3-stage comb data path.
- Decimation using the pre-update integrator sample, matching the RTL register timing.
- Unconditional configuration APPLY, explicit flush, and warmup suppression.
- Sign-symmetric rounding, output saturation, and I/Q shared valid alignment.

Rows checked: 10

PASS: post-IQ CIC golden trace matches RTL.
