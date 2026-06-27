import math
import unittest

from dpll_fixed import (
    ADC_CLOCK_HZ,
    FREQ_WORD_W,
    PHASE_W,
    cic_internal_width,
    freq_hz_from_word,
    freq_word_from_hz,
    mask,
    output_mul_div,
    signed,
    tracking_word,
    unsigned,
    wrap_phase_delta,
)


class FixedPointModelTests(unittest.TestCase):
    def test_signed_and_unsigned_wrap(self):
        self.assertEqual(unsigned(-1, 8), 0xFF)
        self.assertEqual(signed(0x7F, 8), 127)
        self.assertEqual(signed(0x80, 8), -128)
        self.assertEqual(signed(0xFF, 8), -1)

    def test_frequency_word_round_trip(self):
        word = freq_word_from_hz(125_000.0)
        hz = freq_hz_from_word(word)
        lsb_hz = ADC_CLOCK_HZ / float(1 << FREQ_WORD_W)
        self.assertLessEqual(abs(hz - 125_000.0), lsb_hz / 2.0)

    def test_frequency_word_saturates_unsigned(self):
        self.assertEqual(freq_word_from_hz(-1.0), 0)
        self.assertEqual(freq_word_from_hz(ADC_CLOCK_HZ * 2.0), mask(FREQ_WORD_W))

    def test_phase_delta_wraps_to_signed_half_turn(self):
        quarter = 1 << (PHASE_W - 2)
        near_top = (1 << PHASE_W) - 2
        self.assertEqual(wrap_phase_delta(2, near_top), 4)
        self.assertEqual(wrap_phase_delta(near_top, 2), -4)
        self.assertEqual(wrap_phase_delta(quarter, 0), quarter)

    def test_tracking_correction_is_full_width_until_mul_div(self):
        center = freq_word_from_hz(100_000.0)
        correction = freq_word_from_hz(25_000.0)
        tracked = tracking_word(center, correction)
        out = output_mul_div(tracked, 3, 2)
        expected = (tracked * 3 + 1) // 2
        self.assertEqual(out, expected)

    def test_output_mul_div_rounding_and_saturation(self):
        self.assertEqual(output_mul_div(10, 1, 3), 3)
        self.assertEqual(output_mul_div(11, 1, 3), 4)
        self.assertEqual(output_mul_div(mask(FREQ_WORD_W), 2, 1), mask(FREQ_WORD_W))
        with self.assertRaises(ValueError):
            output_mul_div(1, 1, 0)

    def test_cic_width_matches_v1_bound(self):
        self.assertGreaterEqual(cic_internal_width(18, 312), 44)
        self.assertEqual(cic_internal_width(18, 8), 29)
        with self.assertRaises(ValueError):
            cic_internal_width(18, 7)


if __name__ == "__main__":
    unittest.main()
