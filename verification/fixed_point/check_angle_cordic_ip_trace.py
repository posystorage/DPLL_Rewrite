#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


def signed(value: str, width: int) -> int:
    raw = int(value) & ((1 << width) - 1)
    sign = 1 << (width - 1)
    return raw - (1 << width) if raw & sign else raw


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    with args.trace.open(newline="") as f:
        rows = list(csv.DictReader(f))

    inputs = []
    outputs = []
    for row in rows:
        if int(row["in_valid"]) and int(row["in_ready"]):
            inputs.append((signed(row["i_in"], 20), signed(row["q_in"], 20)))
        if int(row["out_valid"]):
            outputs.append({
                "cycle": int(row["cycle"]),
                "phase": signed(row["phase"], 18),
                "magnitude": int(row["magnitude"]) & 0xFFFFF,
            })

    expected_inputs = [
        (131072, 0),
        (0, 131072),
        (-131072, 0),
        (0, -131072),
        (92782, 92782),
        (92782, -92782),
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

    if abs(phase[0]) > 2048:
        print(f"FAIL: +I phase should be near zero, got {phase[0]}")
        return 1
    if not (62400 <= phase[1] <= 68800):
        print(f"FAIL: +Q phase should be near +pi/2 scaled radians, got {phase[1]}")
        return 1
    if not (phase[2] >= 126000 or phase[2] <= -126000):
        print(f"FAIL: -I phase should be near +/-pi scaled boundary, got {phase[2]}")
        return 1
    if not (-68800 <= phase[3] <= -62400):
        print(f"FAIL: -Q phase should be near -pi/2 scaled radians, got {phase[3]}")
        return 1
    if not (30400 <= phase[4] <= 35200):
        print(f"FAIL: +45 degree phase should be near +pi/4 scaled radians, got {phase[4]}")
        return 1
    if not (-35200 <= phase[5] <= -30400):
        print(f"FAIL: -45 degree phase should be near -pi/4 scaled radians, got {phase[5]}")
        return 1

    axis_mags = mag[:4]
    diag_mags = mag[4:6]
    if min(axis_mags) < 144000 or max(axis_mags) > 160000:
        print(f"FAIL: axis magnitudes should reflect raw no-scale-compensation gain, got {axis_mags}")
        return 1
    if min(diag_mags) < 144000 or max(diag_mags) > 160000:
        print(f"FAIL: diagonal magnitudes should match axis magnitude scale, got {diag_mags}")
        return 1
    if max(axis_mags + diag_mags) - min(axis_mags + diag_mags) > 8192:
        print(f"FAIL: equal-amplitude vectors produced inconsistent magnitudes {mag}")
        return 1

    print(f"PASS: angle CORDIC IP trace checked={len(expected_inputs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
