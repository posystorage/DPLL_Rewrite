#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


PHASE_MASK = (1 << 48) - 1
PINC_WORD = 0x4000_0000_0000


def s16(text: str) -> int:
    value = int(text) & 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    with args.trace.open(newline="") as f:
        rows = list(csv.DictReader(f))

    outputs = []
    for row in rows:
        if int(row["data_valid"]) != int(row["phase_valid"]):
            print(f"FAIL: cycle {row['cycle']} data_valid and phase_valid differ")
            return 1
        if int(row["data_valid"]):
            outputs.append({
                "cycle": int(row["cycle"]),
                "phase": int(row["phase"], 16),
                "cos": s16(row["cos"]),
                "sin": s16(row["sin"]),
            })

    if len(outputs) < 12:
        print(f"FAIL: only {len(outputs)} valid DDS outputs")
        return 1

    checked_delta = 0
    for prev, got in zip(outputs, outputs[1:]):
        delta = (got["phase"] - prev["phase"]) & PHASE_MASK
        if delta != PINC_WORD:
            print(
                f"FAIL: phase delta at cycle {got['cycle']} is 0x{delta:012x}, "
                f"expected streaming PINC 0x{PINC_WORD:012x}"
            )
            return 1
        checked_delta += 1

    saw_positive_cos = any(row["cos"] > 12000 for row in outputs)
    saw_negative_cos = any(row["cos"] < -12000 for row in outputs)
    saw_positive_sin = any(row["sin"] > 12000 for row in outputs)
    saw_negative_sin = any(row["sin"] < -12000 for row in outputs)
    if not (saw_positive_cos and saw_negative_cos and saw_positive_sin and saw_negative_sin):
        print("FAIL: DDS sin/cos outputs did not span all expected quadrants")
        return 1

    print(f"PASS: LO_DDS_H streaming PINC trace outputs={len(outputs)} deltas={checked_delta}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
