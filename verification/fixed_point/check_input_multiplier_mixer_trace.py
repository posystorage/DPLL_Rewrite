#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


def to_signed(value: int, width: int) -> int:
    mask = (1 << width) - 1
    value &= mask
    sign = 1 << (width - 1)
    return value - (1 << width) if value & sign else value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    with args.trace.open(newline="") as f:
        raw_rows = list(csv.DictReader(f))

    if len(raw_rows) % 2 != 0:
        print("FAIL: trace should contain input/product row pairs")
        return 1

    inputs = []
    products = []
    for idx in range(0, len(raw_rows), 2):
        in_row = raw_rows[idx]
        prod_row = raw_rows[idx + 1]
        if in_row["cycle"] != prod_row["cycle"]:
            print(f"FAIL: row pair cycle mismatch at rows {idx}/{idx + 1}")
            return 1
        inputs.append({
            "cycle": int(in_row["cycle"]),
            "valid": int(in_row["valid_or_product_valid"]),
            "sample": int(in_row["a"]),
            "i": int(in_row["b"]),
            "q": int(in_row["c"]),
        })
        products.append({
            "cycle": int(prod_row["cycle"]),
            "product_valid": int(prod_row["valid_or_product_valid"]),
            "i": int(prod_row["a"]),
            "q": int(prod_row["b"]),
        })

    valid_inputs = [row for row in inputs if row["valid"]]
    checked = 0
    for idx in range(1, len(inputs)):
        prev = inputs[idx - 1]
        got = products[idx]
        if got["product_valid"] != prev["valid"]:
            print(
                f"FAIL: cycle {got['cycle']} product_valid={got['product_valid']} "
                f"expected previous input valid {prev['valid']}"
            )
            return 1
        if not prev["valid"]:
            continue
        exp_i = to_signed(prev["sample"], 16) * to_signed(prev["i"], 16)
        exp_q = to_signed(prev["sample"], 16) * to_signed(prev["q"], 16)
        if got["i"] != exp_i or got["q"] != exp_q:
            print(
                f"FAIL: cycle {got['cycle']} product mismatch got ({got['i']},{got['q']}) "
                f"expected ({exp_i},{exp_q}) from previous sample cycle {prev['cycle']}"
            )
            return 1
        checked += 1

    if checked != len(valid_inputs):
        print(f"FAIL: checked {checked} products for {len(valid_inputs)} valid inputs")
        return 1

    print(f"PASS: input multiplier mixer trace checked={checked}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
