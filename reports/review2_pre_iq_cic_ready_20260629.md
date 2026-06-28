# Review2 pre-IQ CIC Ready Closure

Date: 2026-06-29

## Scope

The pre-IQ CIC is the Xilinx CIC Compiler `/40` decimator in the active DPLL path. Its output AXI stream is configured without `TREADY`, but its input data interface exposes `s_axis_data_tready`.

## Contract

The ADC source is not back-pressure aware. The active DPLL wrapper therefore drives `s_axis_data_tvalid` continuously while not reset and treats any deassertion of `s_axis_data_tready` during valid input as a design failure.

## Evidence

- `pre_iq_cic_40_125m_v1.xci` has `PARAM_VALUE.HAS_DOUT_TREADY=false` and `BUSIFPARAM_VALUE.S_AXIS_DATA.HAS_TREADY=1`.
- `dpll_wrapper.v` connects `s_axis_data_tready` to `pre_cic_ready`.
- `verification/rtl/pre_iq_cic_ready_tb.v` runs the real Vivado 2018.3 CIC VHDL model for 512 continuous input cycles and fails if input ready deasserts.
- `verification/fixed_point/check_pre_iq_cic_ready_trace.py` checks the generated CSV for zero ready-low cycles and confirms decimated output valid activity.
