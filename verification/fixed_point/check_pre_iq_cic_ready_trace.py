#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    with args.trace.open(newline="") as f:
        rows = list(csv.DictReader(f))

    ready_low = [row for row in rows if row["in_valid"] == "1" and row["in_ready"] != "1"]
    out_valid = [row for row in rows if row["out_valid"] == "1"]

    if ready_low:
        first = ready_low[0]
        print(f"FAIL: pre-IQ CIC input ready deasserted at cycle {first['cycle']}")
        return 1
    if len(out_valid) < 8:
        print(f"FAIL: expected at least 8 decimated output valids, got {len(out_valid)}")
        return 1

    print(f"PASS: pre-IQ CIC ready trace rows={len(rows)} out_valid={len(out_valid)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
