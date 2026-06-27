"""Fixed-point helpers for the DPLL refactor v1 model.

The functions here intentionally mirror docs/dpll_fixed_point_v1.md.  They are
small enough to audit and strict enough to catch common RTL integration mistakes
before Vivado is involved.
"""

from __future__ import annotations

ADC_CLOCK_HZ = 125_000_000
FREQ_WORD_W = 48
PHASE_W = 18
CIC_N = 3
CIC_M = 1
CIC_R_MIN = 8
CIC_R_MAX = 312


def mask(width: int) -> int:
    if width <= 0:
        raise ValueError("width must be positive")
    return (1 << width) - 1


def unsigned(value: int, width: int) -> int:
    return value & mask(width)


def signed(value: int, width: int) -> int:
    value &= mask(width)
    sign = 1 << (width - 1)
    return value - (1 << width) if value & sign else value


def saturate_signed(value: int, width: int) -> int:
    lo = -(1 << (width - 1))
    hi = (1 << (width - 1)) - 1
    return min(max(value, lo), hi)


def saturate_unsigned(value: int, width: int) -> int:
    return min(max(value, 0), mask(width))


def freq_word_from_hz(freq_hz: float, sample_hz: int = ADC_CLOCK_HZ) -> int:
    word = round(freq_hz / sample_hz * (1 << FREQ_WORD_W))
    return saturate_unsigned(word, FREQ_WORD_W)


def freq_hz_from_word(word: int, sample_hz: int = ADC_CLOCK_HZ) -> float:
    return unsigned(word, FREQ_WORD_W) * sample_hz / float(1 << FREQ_WORD_W)


def wrap_phase_delta(new_phase: int, old_phase: int, width: int = PHASE_W) -> int:
    return signed(new_phase - old_phase, width)


def tracking_word(center_word: int, correction: int) -> int:
    return saturate_unsigned(unsigned(center_word, FREQ_WORD_W) + correction, FREQ_WORD_W)


def output_mul_div(word: int, mul: int, div: int) -> int:
    if div <= 0:
        raise ValueError("div must be positive")
    if mul < 0:
        raise ValueError("mul must be non-negative")
    full = unsigned(word, FREQ_WORD_W) * mul
    rounded = (full + div // 2) // div
    return saturate_unsigned(rounded, FREQ_WORD_W)


def cic_internal_width(input_width: int, r_value: int, n_stages: int = CIC_N) -> int:
    if not CIC_R_MIN <= r_value <= CIC_R_MAX:
        raise ValueError("R outside legal v1 range")
    growth = (r_value * CIC_M) ** n_stages
    return input_width + growth.bit_length() + 1
