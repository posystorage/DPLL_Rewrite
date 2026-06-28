#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


def s16(value: str) -> int:
    raw = int(value) & 0xFFFF
    return raw - 0x10000 if raw & 0x8000 else raw


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    with args.trace.open(newline="") as f:
        rows = list(csv.DictReader(f))

    inputs = []
    outputs = []
    for row in rows:
        if int(row["in_valid"]):
            inputs.append((s16(row["i_in"]), s16(row["q_in"])))
        if int(row["out_valid"]):
            outputs.append({
                "cycle": int(row["cycle"]),
                "phase": s16(row["phase"]),
                "magnitude": int(row["magnitude"]) & 0xFFFF,
            })

    expected_inputs = [
        (16384, 0),
        (0, 16384),
        (-16384, 0),
        (0, -16384),
        (11585, 11585),
        (11585, -11585),
    ]
    if inputs[:len(expected_inputs)] != expected_inputs:
        print(f"FAIL: unexpected CORDIC input sequence {inputs[:len(expected_inputs)]}")
        return 1
    if len(outputs) < len(expected_inputs):
        print(f"FAIL: only {len(outputs)} CORDIC outputs for {len(expected_inputs)} inputs")
        return 1

    got = outputs[:len(expected_inputs)]
    phase = [row["phase"] for row in got]
    mag = [row["magnitude"] for row in got]

    if abs(phase[0]) > 128:
        print(f"FAIL: +I phase should be near zero, got {phase[0]}")
        return 1
    if not (3900 <= phase[1] <= 4300):
        print(f"FAIL: +Q phase should be near +pi/2 scaled radians, got {phase[1]}")
        return 1
    if not (phase[2] >= 7900 or phase[2] <= -7900):
        print(f"FAIL: -I phase should be near +/-pi scaled boundary, got {phase[2]}")
        return 1
    if not (-4300 <= phase[3] <= -3900):
        print(f"FAIL: -Q phase should be near -pi/2 scaled radians, got {phase[3]}")
        return 1
    if not (1900 <= phase[4] <= 2200):
        print(f"FAIL: +45 degree phase should be near +pi/4 scaled radians, got {phase[4]}")
        return 1
    if not (-2200 <= phase[5] <= -1900):
        print(f"FAIL: -45 degree phase should be near -pi/4 scaled radians, got {phase[5]}")
        return 1

    axis_mags = mag[:4]
    diag_mags = mag[4:6]
    if min(axis_mags) < 18000 or max(axis_mags) > 20000:
        print(f"FAIL: axis magnitudes should reflect raw no-scale-compensation gain, got {axis_mags}")
        return 1
    if min(diag_mags) < 18000 or max(diag_mags) > 20000:
        print(f"FAIL: diagonal magnitudes should match axis magnitude scale, got {diag_mags}")
        return 1
    if max(axis_mags + diag_mags) - min(axis_mags + diag_mags) > 1024:
        print(f"FAIL: equal-amplitude vectors produced inconsistent magnitudes {mag}")
        return 1

    print(f"PASS: angle CORDIC IP trace checked={len(expected_inputs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
