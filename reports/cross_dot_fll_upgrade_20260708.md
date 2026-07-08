# Cross-dot FLL upgrade note - 2026-07-08

## Why HDL was changed

The previous integrated simulations showed a structural limitation in the current
FLL path:

- With post-IIR enabled, the phase-difference FLL saw much weaker effective
  frequency-error pulses and `freq_correction` converged too slowly.
- With post-IIR bypassed, the FLL had enough pull-in strength, but residual
  mirror/phase ripple produced wrong-sign pulses and the final frequency
  convergence was not stable.
- The design document `dpll_iir_cic_notch_crossdot_codex.md` explicitly
  recommends replacing phase-difference / unwrap FLL with cross-dot block
  accumulation for this condition.

This HDL change is therefore limited to the FLL estimator and the FLL connection
point. Post-IIR coefficients and post-IIR enable mode are not changed.

## HDL change record

1. Added `fll_cross_dot_stage_a` in
   `DPLL_Rewrite.srcs/sources_1/DigitalPLL/hybrid_loop/fll_phase_difference_stage_a.v`.
2. Kept the existing `fll_phase_difference_stage_a` module intact for existing
   unit tests and comparison.
3. The new cross-dot FLL:
   - uses filtered I/Q samples after post-IIR,
   - supports the existing `fll_delay_sel` mapping of L = 1/2/4/8 samples,
   - uses block accumulation with `BLOCK_SAMPLES=16`,
   - computes `dot = sum(I[k]*I[k-L] + Q[k]*Q[k-L])`,
   - computes `cross = sum(Q[k]*I[k-L] - I[k]*Q[k-L])`,
   - uses the small-angle `cross/dot` approximation and keeps the previous
     `freq_error` scale of about 21.4748 LSB/Hz,
   - marks samples ambiguous when accumulated dot energy is not positive.
4. Updated
   `DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/dpll_single_clock_core_stage_a.v`
   so the hybrid loop receives `freq_error` from `fll_cross_dot_stage_a` instead
   of the phase-difference FLL.
5. After the first R=31/post-IIR AUTO simulation, added block-result replay in
   `fll_cross_dot_stage_a`: the averaged cross-dot result is replayed for
   `BLOCK_SAMPLES` post-IIR sample periods. This preserves the physical
   `freq_error` scale used by lock thresholds while restoring the update rate
   expected by the existing hybrid loop.

## First simulation evidence

Snapshot `dpll_integrated_flow_tb_behav_crossdot_r31` compiled and ran to the
testbench finish with post-IIR still in AUTO mode. The first implementation
stayed in `FLL_ACQUIRE` and reached only about `freq_correction=-16.9M` by
12 ms. The observed `freq_error` direction was correct but the loop update was
too weak because one averaged block produced only one hybrid-loop update.

## Boundaries intentionally not changed

- No post-IIR coefficients were modified.
- No post-IIR bypass was enabled.
- No CIC, mixer, CORDIC, register map, wrapper, or non-FLL datapath HDL was
  changed.
- PID/hybrid-loop HDL was not changed in this step.
