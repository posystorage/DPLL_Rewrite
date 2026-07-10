# DPLL Fixed-Point v1 Freeze

Date: 2026-06-27

Status: frozen draft v1 for modeling and RTL ownership. Values marked "model-confirm" are initial constraints, not final tuned coefficients.

## Frequency Word

Frequency words use a 48-bit unit referenced to 125 MHz:

```text
word = round(f_hz / 125000000 * 2^48)
```

All of these use the same unit:

- center frequency word.
- tracking correction word.
- tracking word.
- final DDS input before output MUL/DIV.

Do not truncate the tracking correction before output MUL/DIV.

## Phase

```text
PHASE_W = 18
one turn = 2^PHASE_W
signed range = [-0.5 turn, +0.5 turn)
```

Phase wrap is pure two's-complement modular arithmetic.

## Initial Width Table

| Signal | v1 width | Signed | Notes |
|---|---:|---|---|
| ADC decimated sample | 16 | yes | existing effective width |
| sin/cos | 16 | yes | DDS/wrapper output |
| mixer product retained to CIC | 18 | yes | rounded from full product |
| post-IQ CIC internal | 44 | yes | `18 + ceil(3*log2(312)) + 1` |
| post-IQ CIC output | 20 | yes | after shift/round/saturate |
| post-IQ IIR coefficients | 32 | yes | Q2.30 biquad coefficients |
| magnitude | 20 | no | raw `dpll_angle_CORDIC` Translate magnitude, no scale compensation |
| phase | 18 | yes | one turn is `2^18` |
| FLL error | 22 | yes | phase difference plus margin, model-confirm |
| coefficients | 24 | yes | Kf/Kp/Ki, model-confirm Q format |
| product | 46 | yes | phase/error times coefficient, model-confirm |
| freq_state internal | 56 | yes | saturates to configured limits |
| correction output | 56 | yes | converted to 48-bit word only at final tracking add |
| tracking word | 48 | no | center plus correction, saturated |
| output MUL/DIV input | 48 | no | full tracking word |
| output word | 48 | no | after MUL/DIV, rounded and saturated |
| debug DAC sample | 16 | yes | formatted view only |

## CIC v1

```text
N = 3
M = 1
R legal range = 8..312
input valid rate = 3.125 MSPS
output rate = 3.125 MSPS / R
```

Legacy nominal R values (not used by the adaptive DPLL profile):

| Center frequency | R | Output valid rate |
|---:|---:|---:|
| 5 kHz | 312 | 10.0 kSPS |
| 10 kHz | 156 | 20.0 kSPS |
| 20 kHz | 78 | 40.1 kSPS |
| 50 kHz | 31 | 100.8 kSPS |
| 100 kHz | 16 | 195.3 kSPS |
| 200 kHz | 8 | 390.6 kSPS |

Internal arithmetic:

- integrators and combs use two's-complement natural wrap.
- no per-stage saturation.
- output applies configured right shift, symmetric rounding, and saturation.
- `overflow_seen` records output saturation or illegal config, not natural internal wrap.

Shift contract:

- The review4-fixed APPLY validator accepts a bounded shift range for each R bucket: `recommended_shift - 1` through `recommended_shift + 3`.
- The recommended table is audited in `reports/cic_shift_model_20260630.md` by `scripts/audit_cic_shift_model.py`.
- The table intentionally keeps 5 to 6 bits of CIC gain relative to full `ceil(log2(R^3))` compensation, rather than fully normalizing the CIC output.
- This closes the hard-coded-table contradiction for the v1 configuration contract; it does not prove arbitrary full-scale ADC input cannot saturate.
- Saturation remains a runtime status condition through `overflow_seen` and `DPLL_CORE_FLAGS[0]`.

## CORDIC Magnitude

The active DPLL CORDIC wrapper, `dpll_angle_CORDIC`, is configured as Translate, Word Serial, SignedFraction, 20-bit input/output, Scaled_Radians phase, coarse rotation enabled, and `No_Scale_Compensation`. The legacy `angle_CORDIC` name remains reserved for the frequency meter's validated 16-bit parallel CORDIC path.

Magnitude contract:

- CORDIC X/Y inputs are the post-IQ CIC 20-bit I/Q samples, packed into 24-bit AXI lanes.
- `magnitude`, `MAG_ENTER_THRESHOLD`, `MAG_EXIT_THRESHOLD`, register `0x0101 MAGNITUDE`, and debug DAC source 8 all use the raw 20-bit CORDIC magnitude output.
- No RTL or ARM-side gain compensation is applied to magnitude in v1.
- Threshold tuning must account for the CORDIC no-scale-compensation gain and the post-IQ CIC output scale.

The initial ARM defaults `MAG_ENTER_THRESHOLD=1024` and `MAG_EXIT_THRESHOLD=512` are bring-up defaults in this raw CORDIC output scale, not calibrated physical amplitude limits.

## Post-IQ IIR Stage

Stage-1 post filtering inserts `post_iir_stage_a` after `post_iq_cic_stage_a`
and before the CORDIC/FLL phase path. The module uses two identical biquad
sections in cascade for I and Q. Coefficients are signed Q2.30 and implement:

```text
y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
```

ARM computes one complete profile when the user writes a 5--200 kHz center
frequency. The profile contains CIC R/shift, FLL delay, and both IIR coefficient
banks. It is written before one atomic APPLY; FPGA state transitions do not need
further ARM writes. R is selected from 16, 15, 12, 10, and 8 so that the aliased
double-frequency image is at least 2.2 times the ACQUIRE cutoff and the IIR input
rate is at least 8 times that cutoff. The two identical Butterworth sections then
provide more than 25 dB image attenuation.

After selecting R, ARM chooses the largest FLL delay L in 8, 4, 2, or 1 for
which `fs_iir >= 4*L*acquire_cutoff`. This keeps the cross/dot discriminator's
dot product positive throughout the capture band; higher-frequency profiles
therefore shorten L automatically instead of relying on an ARM write during a
state transition.

For the 22 kHz center used by `dpll_integrated_flow_tb`, ARM selects R=16,
nominal shift=7 plus one explicit CORDIC headroom bit (programmed shift=8),
and FLL delay select=3. The coefficient banks are:

| Mode | Per-section fc | b0 | b1 | b2 | a1 | a2 |
|---|---:|---:|---:|---:|---:|---:|
| ACQUIRE | 4 kHz | 4069483 | 8138965 | 4069483 | -1952555106 | 895091212 |
| FINE/TRACK | 2 kHz | 1062529 | 2125058 | 1062529 | -2049846615 | 980354906 |

The cutoff column is the -3 dB point of each biquad. Because two identical
sections are cascaded, the complete IIR is approximately -6 dB at that frequency.
At the TB's 43.5 kHz mixer image, the quantized ACQUIRE and FINE/TRACK banks give
approximately 89 dB and 113 dB attenuation respectively. The wider 2 kHz second
bank intentionally serves both blend/fine and track, avoiding the previous
ultra-narrow tracking response.

`POST_IIR_CONFIG=3` selects ACQUIRE coefficients outside blend/track states and
TRACK coefficients during `FLL_PLL_BLEND` and `PLL_TRACK`. `POST_IIR_CONFIG=0`
bypasses the stage for regression comparison.

## DC Blocker

The active DC blocker is a valid-gated first-order high-pass stage. With `LEAK_SHIFT=10`, `ACC_WIDTH=48`, and `DATA_WIDTH=16`, define:

```text
INPUT_SHIFT  = ACC_WIDTH - DATA_WIDTH - LEAK_SHIFT - 2
OUTPUT_SHIFT = ACC_WIDTH - DATA_WIDTH - 1
acc[k+1]     = acc[k] - (acc[k] >>> LEAK_SHIFT) + (x[k] <<< INPUT_SHIFT)
hp[k]        = (x[k] <<< (OUTPUT_SHIFT - 1)) - acc[k] + (1 <<< (OUTPUT_SHIFT - 2))
y[k]         = sat16(hp[k] >>> OUTPUT_SHIFT)
```

The `sample_out` and `out_valid` registers update in the same `clk_125m` cycle when `in_valid=1`. When `in_valid=0`, filter state does not advance and `out_valid=0`.

The resulting high-pass path is intentionally attenuating: for frequencies well above the very low cutoff, `y` is approximately `x/2` before saturation. The larger leak shift lowers the pole relative to the earlier bring-up value, reducing interaction with the 5 kHz band edge while preserving the documented output scale. This is covered by `verification/fixed_point/check_dc_blocker_trace.py`.

## Loop Equation

```text
freq_state[k+1] = sat(freq_state[k] + Kf*ef + Ki*ephi)
freq_correction = sat(freq_state[k+1] + Kp*ephi)
tracking_word   = center_word + freq_correction
```

The products do not share one implicit scale: the FLL term uses an arithmetic
right shift of 16, the phase integrator uses 18, and the instantaneous phase P
term uses 12. Cross/dot frequency error has only about 21.4748 LSB/Hz; the
separate FLL shift lets the signed 24-bit Kf range provide adequate capture
bandwidth. BLEND/TRACK Kf values are reduced by four relative to the earlier
shift-18 settings when the same effective gain is desired. The stronger P scale
also makes the 24-bit Kp range capable of damping the phase integrator; with the
22 kHz profile, Kp=6,000,000 and Ki=117,200 give an estimated blend damping
ratio near 0.85.

Mode enables:

| State | Kf | Ki | Kp |
|---|---|---|---|
| FLL_ACQUIRE | enabled | disabled | disabled |
| FLL_PLL_BLEND | enabled | enabled | enabled |
| PLL_TRACK | disabled or small | enabled | enabled |
| HOLDOVER | disabled | disabled | disabled |

Anti-windup:

- Freeze an integrating term only when it pushes further into saturation.
- Allow update when the error moves the state away from saturation.
- P term may still contribute but final correction must saturate.

## Model-Confirm Items

The model/verification owner must confirm before final RTL tuning:

- coefficient Q format and product shifts.
- Kf/Kp/Ki per frequency mode.
- default debug DAC `FREQ_CORRECTION` bit window.
- final tuned magnitude thresholds in raw no-scale-compensation CORDIC output units.
- phase and frequency lock thresholds.
- warmup and dwell valid-sample counts.
- output MUL/DIV overflow behavior for project combinations.

Until confirmed, implementation owners may build parameterized modules but must not hard-code tuned magic constants.
