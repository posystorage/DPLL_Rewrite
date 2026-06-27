# Review P0 Datapath Fix - 2026-06-28

## Scope

This pass addresses the highest-priority datapath defects from `docs/review.md`.
It does not claim full DPLL signoff. The system bus `adc_clk -> pll_adc_clk`
timing issue remains intentionally out of scope per user instruction.

## Fixed In This Pass

- Front-end `/40` decimation now uses the existing Xilinx `cic_compiler_0` IP.
  The active DPLL core consumes `pre_cic_sample` and `pre_cic_valid`; the old
  counter-generated sample pulse is no longer the active data-valid source.
- Tracking NCO phase accumulator in `dpll_single_clock_core_stage_a` now runs
  continuously at `clk_125m`; CIC valid only latches ADC/DDC samples.
- IQ LO now uses the existing Xilinx DDS Compiler IP `LO_DDS_H` for real
  sin/cos generation instead of the old four-phase `{+1,0,-1,0}` logic.
- IQ multiplication now uses the existing Xilinx `input_multiplier` IP.
- Post-CIC phase now uses the existing Xilinx `angle_CORDIC` IP; `phase_error`
  is no longer wired directly from Q amplitude.
- A valid-gated DC blocker was added before IQ mixing.
- FLL phase difference now uses an 8-deep delay line for true M=1/2/4/8 and
  18-bit wrapped subtraction.
- `post_iq_cic_stage_a` no longer flushes state on illegal APPLY; illegal
  configs flag an error while preserving the active configuration.

## Evidence

- `fll_phase_difference_stage_a_tb`: PASS in
  `reports/xsim/detector_fll_stage_a_cli_20260628_p0`.
- `post_iq_cic_stage_a_tb`: PASS in
  `reports/xsim/iq_cic_stage_a_cli_20260628_p0`.
- `dpll_single_clock_core_stage_a_tb` with DDS/multiplier/CORDIC IP models:
  PASS in `reports/xsim/single_clock_core_stage_a_cli_20260628_p0`.
- Vivado project synthesis reached `synth_design Complete!` with 0 errors and
  0 critical warnings, recorded in
  `reports/vivado_single_clock_core_stage_a_project_synth/manifest.txt`.

## Known Remaining Items

- Full FLL/PLL state manager, dwell, holdover, reacquire, and loss reason are
  not implemented yet.
- ARM command/API refactor beyond existing register aliases is not complete.
- DACout1 debug formatter timing cleanup remains incomplete.
- Dynamic VCO MUL/DIV timing/resource cleanup remains incomplete.
- Full frequency sweep, noise, reacquire, and board-level validation are not
  complete.
- Timing closure remains not clean and is not claimed.

## Notes

- The active LO uses `LO_DDS_H` because the old `LO_DDS.xcix` container is
  present but its expanded `LO_DDS/LO_DDS.xci` directory is not present in this
  working tree. `LO_DDS_H` is an existing Xilinx DDS Compiler IP with 48-bit
  phase input and 16-bit sin/cos output.
- Some scripted XSIM reruns can fail at `xelab` cleanup on Windows with an
  access-denied `xsim.dir/.../obj` message when another Vivado process holds
  file handles. Manual isolated run directories were used for the PASS evidence
  listed above.
