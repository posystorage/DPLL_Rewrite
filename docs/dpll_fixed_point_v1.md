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
| magnitude | 16 | no | raw `angle_CORDIC` Translate magnitude, no scale compensation |
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

Suggested R:

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

## CORDIC Magnitude

The active `angle_CORDIC` IP is configured as Translate, SignedFraction, 16-bit input/output, Scaled_Radians phase, coarse rotation enabled, and `No_Scale_Compensation`.

Magnitude contract:

- CORDIC X/Y inputs are rounded and saturated from post-IQ CIC 20-bit I/Q into 16-bit SignedFraction samples by the DPLL core.
- `magnitude`, `MAG_ENTER_THRESHOLD`, `MAG_EXIT_THRESHOLD`, register `0x0101 MAGNITUDE`, and debug DAC source 8 all use the raw 16-bit CORDIC magnitude output.
- No RTL or ARM-side gain compensation is applied to magnitude in v1.
- Threshold tuning must account for the CORDIC no-scale-compensation gain and the 20-bit to 16-bit input rounding step.

The initial ARM defaults `MAG_ENTER_THRESHOLD=1024` and `MAG_EXIT_THRESHOLD=512` are bring-up defaults in this raw CORDIC output scale, not calibrated physical amplitude limits.

## Loop Equation

```text
freq_state[k+1] = sat(freq_state[k] + Kf*ef + Ki*ephi)
freq_correction = sat(freq_state[k+1] + Kp*ephi)
tracking_word   = center_word + freq_correction
```

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
- CIC output shift per R.
- default debug DAC `FREQ_CORRECTION` bit window.
- final tuned magnitude thresholds in raw no-scale-compensation CORDIC output units.
- phase and frequency lock thresholds.
- warmup and dwell valid-sample counts.
- output MUL/DIV overflow behavior for project combinations.

Until confirmed, implementation owners may build parameterized modules but must not hard-code tuned magic constants.
