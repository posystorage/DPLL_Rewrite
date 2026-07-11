# RFC: VCO MUL/DIV Configuration Status

## Motivation

`docs/review2.md` points out that the output word scaler silently rewrites VCO
frequency scaling parameters:

- `MUL=0` becomes `1`
- `DIV=0` becomes `1`
- `DIV[15]=1` becomes `0x7fff` because the legacy divider IP treated the
  divisor as signed

That hides host-side configuration errors and can make the DAC output differ from
the requested configuration without a visible fault.

## Proposed v1-Compatible Change

Keep the existing register addresses and add one read-only status bit in the
reserved high region of `DPLL_CORE_FLAGS_Addr` (`0x0108`):

| Bit | Name | Meaning |
|---:|---|---|
| 17 | `vco_mul_div_config_error` | Sticky flag set when a requested VCO MUL/DIV sample has `MUL=0` or `DIV=0`. |

No write address changes are introduced. Existing low status bits keep their
current positions.

## RTL Behavior

- Reject illegal VCO MUL/DIV samples before they enter the multiplier/divider IP.
- Preserve the previous valid output word when an illegal sample is rejected.
- Set `vco_mul_div_config_error` until reset.
- Do not silently clamp or replace illegal factors.
- Keep the existing latest-wins pending behavior for legal samples.
- Replace the legacy signed divider IP with `div_gen_pll_u`, an unsigned
  Vivado 2018.3 divider instance, so the full 16-bit `DIV` range is legal.

## ARM Behavior

- Existing software remains ABI-compatible because no address or low-bit meaning
  changes.
- ARM mock tests should learn bit 17 so host code can detect configuration
  errors from `DPLL_CORE_FLAGS_Addr`.

## IP Sign-Off

The original `div_gen_pll` High Radix instance keeps `operand_sign` disabled as
`Signed` in Vivado 2018.3. The active RTL now instantiates the replacement
`div_gen_pll_u` Radix2 IP with `operand_sign=Unsigned`, `SIGNED_B=0`,
non-blocking flow control, and the same manually managed latency budget.
