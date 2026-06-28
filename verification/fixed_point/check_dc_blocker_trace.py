#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


DATA_WIDTH = 16
ACC_WIDTH = 48
LEAK_SHIFT = 7
INPUT_SHIFT = ACC_WIDTH - DATA_WIDTH - LEAK_SHIFT - 2
OUTPUT_SHIFT = ACC_WIDTH - DATA_WIDTH - 1


def to_signed(value: int, width: int) -> int:
    mask = (1 << width) - 1
    value &= mask
    sign = 1 << (width - 1)
    return value - (1 << width) if value & sign else value


def wrap(value: int, width: int) -> int:
    return to_signed(value, width)


def arshift(value: int, amount: int, width: int = ACC_WIDTH) -> int:
    return to_signed(value, width) >> amount


def saturate_to_i16(value: int) -> int:
    if value > 32767:
        return 32767
    if value < -32768:
        return -32768
    return value


def model_rows(rows: list[dict[str, str]]) -> list[int | None]:
    dc_acc = 0
    expected: list[int | None] = []
    for row in rows:
        valid = int(row["in_valid"])
        sample = int(row["sample_in"])
        if valid:
            sample_ext = to_signed(sample, DATA_WIDTH)
            next_acc = wrap(dc_acc - arshift(dc_acc, LEAK_SHIFT) + wrap(sample_ext << INPUT_SHIFT, ACC_WIDTH), ACC_WIDTH)
            next_hp = wrap(
                wrap(sample_ext << (OUTPUT_SHIFT - 1), ACC_WIDTH)
                - dc_acc
                + (1 << (OUTPUT_SHIFT - 2)),
                ACC_WIDTH,
            )
            shifted = arshift(next_hp, OUTPUT_SHIFT)
            expected.append(saturate_to_i16(shifted))
            dc_acc = next_acc
        else:
            expected.append(None)
    return expected


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    with args.trace.open(newline="") as f:
        rows = list(csv.DictReader(f))

    expected = model_rows(rows)
    valid_seen = 0
    for row, exp in zip(rows, expected):
        if exp is None:
            continue
        valid_seen += 1
        got = int(row["sample_out"])
        if got != exp:
            print(
                f"FAIL: cycle {row['cycle']} sample_out got {got} expected {exp} "
                f"for input {row['sample_in']}"
            )
            return 1

    if valid_seen < 32:
        print(f"FAIL: expected at least 32 valid samples, saw {valid_seen}")
        return 1

    print(f"PASS: DC blocker golden trace rows={len(rows)} valid={valid_seen}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
