#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


WORD_MASK = (1 << 48) - 1


def parse_int(text: str) -> int:
    return int(text, 0)


def sat_word(value: int) -> int:
    if value < 0:
        return 0
    if value > WORD_MASK:
        return WORD_MASK
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    with args.trace.open(newline="") as f:
        rows = list(csv.DictReader(f))

    if len(rows) < 8:
        print(f"FAIL: only {len(rows)} nonzero-gain tracking rows")
        return 1

    nonzero = 0
    track_states = 0
    locked_rows = 0
    corrections = set()
    pending_expected = None
    for expected_index, row in enumerate(rows):
        index = parse_int(row["index"])
        center = parse_int(row["center_word"])
        tracking = parse_int(row["tracking_word"])
        correction = parse_int(row["freq_correction"])
        loop_state = parse_int(row["loop_state"])
        locked = parse_int(row["locked"])
        magnitude = parse_int(row["magnitude"])

        if index != expected_index:
            print(f"FAIL: row index {index} != expected {expected_index}")
            return 1
        if pending_expected is not None and tracking != pending_expected:
            print(
                f"FAIL: row {index} tracking 0x{tracking:012x} != previous "
                f"sat(center+correction) 0x{pending_expected:012x}"
            )
            return 1
        pending_expected = sat_word(center + correction)
        if correction != 0 and tracking != center:
            nonzero += 1
            corrections.add(correction)
        if loop_state == 6:
            track_states += 1
        if locked:
            locked_rows += 1
        if magnitude <= 0:
            print(f"FAIL: row {index} magnitude is not positive")
            return 1

    if nonzero < 4:
        print(f"FAIL: only {nonzero} rows have nonzero correction")
        return 1
    if len(corrections) < 3:
        print(f"FAIL: only {len(corrections)} distinct nonzero corrections")
        return 1
    if track_states < 4:
        print(f"FAIL: only {track_states} rows reached TRACK state")
        return 1
    if locked_rows < 4:
        print(f"FAIL: only {locked_rows} rows asserted locked")
        return 1

    print(
        f"PASS: DPLL core nonzero tracking trace rows={len(rows)} "
        f"nonzero={nonzero} distinct_corrections={len(corrections)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
