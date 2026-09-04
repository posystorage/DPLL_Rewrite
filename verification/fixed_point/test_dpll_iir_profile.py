import cmath
import math
import unittest


Q30 = float(1 << 30)
POST_IIR_SAMPLE_RATE_HZ = 3_125_000.0 / 16.0

ACQUIRE_22K = (
    0x003E186B,
    0x007C30D5,
    0x003E186B,
    0x8B9E5F9E,
    0x355A020C,
)

TRACK_22K = (
    0x00E4A5DB,
    0x01C94BB6,
    0x00E4A5DB,
    0x97189691,
    0x2C7A00DC,
)


def signed_q30(word):
    if word & 0x80000000:
        word -= 1 << 32
    return word / Q30


def cascade_gain_db(coefficients, frequency_hz):
    b0, b1, b2, a1, a2 = map(signed_q30, coefficients)
    z1 = cmath.exp(-2j * math.pi * frequency_hz / POST_IIR_SAMPLE_RATE_HZ)
    section = (b0 + b1 * z1 + b2 * z1 * z1) / (
        1.0 + a1 * z1 + a2 * z1 * z1
    )
    dc_section = (b0 + b1 + b2) / (1.0 + a1 + a2)
    return 20.0 * math.log10(abs((section / dc_section) ** 2))


class DpllIirProfileTests(unittest.TestCase):
    def test_22k_profile_suppresses_double_frequency_image(self):
        # The TB input is 21.5 kHz around a 22 kHz center, so the mixer image
        # is 43.5 kHz. Both FPGA-selected banks must exceed the 25 dB target.
        self.assertLessEqual(cascade_gain_db(ACQUIRE_22K, 43_500.0), -25.0)
        self.assertLessEqual(cascade_gain_db(TRACK_22K, 43_500.0), -25.0)

    def test_22k_acquire_bank_keeps_capture_error_band(self):
        self.assertGreater(cascade_gain_db(ACQUIRE_22K, 500.0), -0.1)
        self.assertGreater(cascade_gain_db(ACQUIRE_22K, 2_000.0), -1.0)

    def test_22k_track_bank_uses_8khz_cutoff(self):
        self.assertGreater(cascade_gain_db(TRACK_22K, 500.0), -0.2)
        self.assertAlmostEqual(cascade_gain_db(TRACK_22K, 8_000.0), -6.02,
                               delta=0.15)


if __name__ == "__main__":
    unittest.main()
