#!/usr/bin/env python3
from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path

from dpll_fixed import freq_word_from_hz, mask, unsigned


ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports" / "dpll_core_sine_sweep_trace_20260629.md"
STABLE_TRACE = ROOT / "reports" / "dpll_core_sine_sweep_trace_20260629.csv"
EXPECTED_CENTERS = [5_000.0, 10_000.0, 20_000.0, 50_000.0, 100_000.0, 150_000.0, 200_000.0]
WORD_WIDTH = 48
STATE_WIDTH = 56
MODEL_COLUMNS = [
    "freq_state",
    "hybrid_state_before",
    "hybrid_center_word",
    "hybrid_positive_limit",
    "hybrid_negative_limit",
    "hybrid_fll_term",
    "hybrid_i_term",
    "hybrid_p_term",
]


def parse_int(value: str) -> int:
    return int(value, 0)


def parse_float(value: str) -> float:
    return float(value)


def sat_state(value: int, positive_limit: int, negative_limit: int) -> int:
    return min(max(value, negative_limit), positive_limit)


def sat_word(value: int) -> int:
    return min(max(value, 0), mask(WORD_WIDTH))


def latest_trace() -> Path:
    traces = sorted(
        ROOT.glob("reports/xsim/dpll_core_sine_sweep_*/dpll_core_sine_sweep_trace.csv"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if not traces:
        raise FileNotFoundError("no dpll_core_sine_sweep_trace.csv found under reports/xsim")
    return traces[0]


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_stable_trace(rows: list[dict[str, str]]) -> None:
    if not rows:
        STABLE_TRACE.write_text("", encoding="utf-8")
        return
    with STABLE_TRACE.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def check_case(case_index: int, rows: list[dict[str, str]]) -> tuple[list[str], str]:
    failures: list[str] = []
    center_hz = parse_float(rows[0]["center_hz"])
    input_hz = parse_float(rows[0]["input_hz"])
    center_word = parse_int(rows[0]["center_word"])
    expected_center = freq_word_from_hz(center_hz)
    expected_input = freq_word_from_hz(input_hz)
    expected_delta = unsigned(expected_input - expected_center, 48)
    if center_word != expected_center:
        failures.append(f"center word 0x{center_word:012x} != golden 0x{expected_center:012x}")
    if input_hz <= center_hz:
        failures.append(f"input_hz {input_hz} must be above center_hz {center_hz}")

    sample_counts: list[int] = []
    fll_valid_counts: list[int] = []
    magnitudes: list[int] = []
    distinct_tracking: set[int] = set()
    nonzero = 0
    positive = 0
    tail_positive = 0
    track = 0
    locked = 0
    signal = 0
    control_model_matches = 0
    tracking_latency_matches = 0
    float_model_matches = 0
    state = 0
    pending_tracking: int | None = None
    tail_start = len(rows) // 2
    for index, row in enumerate(rows):
        row_index = parse_int(row["index"])
        if row_index != index:
            failures.append(f"row index {row_index} != {index}")
        sample_counts.append(parse_int(row["sample_count"]))
        fll_valid_counts.append(parse_int(row["fll_valid_count"]))
        tracking_word = parse_int(row["tracking_word"])
        correction = parse_int(row["freq_correction"])
        distinct_tracking.add(tracking_word)
        if correction != 0:
            nonzero += 1
        if tracking_word > center_word:
            positive += 1
            if index >= tail_start:
                tail_positive += 1
        if parse_int(row["loop_state"]) == 6:
            track += 1
        if parse_int(row["locked"]):
            locked += 1
        if parse_int(row["signal_present"]):
            signal += 1
        magnitudes.append(parse_int(row["magnitude"]))

        state_before = parse_int(row["hybrid_state_before"])
        hybrid_center = parse_int(row["hybrid_center_word"])
        positive_limit = parse_int(row["hybrid_positive_limit"])
        negative_limit = parse_int(row["hybrid_negative_limit"])
        fll_term = parse_int(row["hybrid_fll_term"])
        i_term = parse_int(row["hybrid_i_term"])
        p_term = parse_int(row["hybrid_p_term"])
        state_delta = fll_term + i_term
        push_high = state_before >= positive_limit and state_delta > 0
        push_low = state_before <= negative_limit and state_delta < 0
        expected_state = state_before if (push_high or push_low) else sat_state(
            state_before + state_delta, positive_limit, negative_limit
        )
        expected_correction = sat_state(expected_state + p_term, positive_limit, negative_limit)
        expected_tracking = sat_word(hybrid_center + expected_correction)
        float_state = state_before if (push_high or push_low) else sat_state(
            int(float(state_before) + float(state_delta)), positive_limit, negative_limit
        )
        float_correction = sat_state(
            int(float(float_state) + float(p_term)), positive_limit, negative_limit
        )
        float_tracking = sat_word(int(float(hybrid_center) + float(float_correction)))
        if state_before != state:
            failures.append(f"row {index}: replay state {state} != captured state_before {state_before}")
        if hybrid_center != center_word:
            failures.append(f"row {index}: hybrid center 0x{hybrid_center:012x} != row center 0x{center_word:012x}")
        if parse_int(row["freq_state"]) != expected_state:
            failures.append(f"row {index}: fixed model state {expected_state} != RTL {parse_int(row['freq_state'])}")
        if correction != expected_correction:
            failures.append(f"row {index}: fixed model correction {expected_correction} != RTL {correction}")
        if pending_tracking is not None and tracking_word != pending_tracking:
            failures.append(
                f"row {index}: RTL tracking 0x{tracking_word:012x} != previous fixed model tracking 0x{pending_tracking:012x}"
            )
        elif pending_tracking is not None:
            tracking_latency_matches += 1
        if float_state != expected_state or float_correction != expected_correction or float_tracking != expected_tracking:
            failures.append(f"row {index}: float replay diverged from fixed model")
        else:
            float_model_matches += 1
        if parse_int(row["freq_state"]) == expected_state and correction == expected_correction:
            control_model_matches += 1
        state = expected_state
        pending_tracking = expected_tracking

    if len(rows) < 16:
        failures.append(f"tracking rows {len(rows)} < 16")
    if nonzero < 8:
        failures.append(f"nonzero corrections {nonzero} < 8")
    if positive < 4:
        failures.append(f"positive tracking rows {positive} < 4")
    if tail_positive < max(4, len(rows) - tail_start - 1):
        failures.append(f"tail positive tracking rows {tail_positive} too low for {len(rows) - tail_start} tail rows")
    if len(distinct_tracking) < 8:
        failures.append(f"distinct tracking words {len(distinct_tracking)} < 8")
    if track < 8:
        failures.append(f"TRACK rows {track} < 8")
    if locked < 8:
        failures.append(f"locked rows {locked} < 8")
    if signal < 8:
        failures.append(f"signal-present rows {signal} < 8")
    if fll_valid_counts[-1] < 16:
        failures.append(f"FLL-valid count {fll_valid_counts[-1]} < 16")
    if max(magnitudes) <= 0:
        failures.append("magnitude never became positive")
    if control_model_matches != len(rows):
        failures.append(f"control model matched {control_model_matches}/{len(rows)} rows")
    if tracking_latency_matches != max(0, len(rows) - 1):
        failures.append(f"tracking latency matched {tracking_latency_matches}/{max(0, len(rows) - 1)} rows")
    if float_model_matches != len(rows):
        failures.append(f"float replay matched {float_model_matches}/{len(rows)} rows")
    if any(b <= a for a, b in zip(sample_counts, sample_counts[1:])):
        failures.append("sample_count is not strictly increasing")
    if any(b < a for a, b in zip(fll_valid_counts, fll_valid_counts[1:])):
        failures.append("fll_valid_count decreased")

    result = "PASS" if not failures else "; ".join(failures)
    line = (
        f"| {case_index} | {center_hz:.0f} | {input_hz:.0f} | "
        f"`0x{center_word:012x}` | `0x{expected_input:012x}` | "
        f"`0x{expected_delta:012x}` | {len(rows)} | {nonzero} | {positive} | "
        f"{tail_positive}/{len(rows) - tail_start} | {control_model_matches}/{len(rows)} | "
        f"{tracking_latency_matches}/{max(0, len(rows) - 1)} | {float_model_matches}/{len(rows)} | "
        f"{track} | {locked} | {fll_valid_counts[-1]} | {max(magnitudes)} | {result} |"
    )
    return [f"case {case_index}: {failure}" for failure in failures], line


def check_rows(rows: list[dict[str, str]]) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    grouped: dict[int, list[dict[str, str]]] = defaultdict(list)
    missing_columns = [column for column in MODEL_COLUMNS if rows and column not in rows[0]]
    if missing_columns:
        return [f"trace is missing model replay columns: {', '.join(missing_columns)}"], [
            "# DPLL Core Sine Sweep RTL Trace",
            "",
            "FAIL: trace is missing the fixed/float model replay columns generated by the current RTL testbench.",
        ]
    for row in rows:
        grouped[parse_int(row["case_index"])].append(row)

    lines = [
        "# DPLL Core Sine Sweep RTL Trace",
        "",
        "Generated by `python verification\\fixed_point\\check_dpll_core_sine_sweep_trace.py`.",
        "",
        "| Case | Center Hz | Input Hz | Center Word | Input Word | High-Side Delta | Rows | Nonzero | Positive | Tail Positive | Control Model | Tracking Delay | Float Replay | TRACK | Locked | FLL Valid | Max Mag | Result |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]

    if sorted(grouped) != list(range(len(EXPECTED_CENTERS))):
        failures.append(f"expected case indexes 0..{len(EXPECTED_CENTERS)-1}, got {sorted(grouped)}")

    for case_index, expected_center in enumerate(EXPECTED_CENTERS):
        case_rows = grouped.get(case_index, [])
        if not case_rows:
            continue
        center_hz = parse_float(case_rows[0]["center_hz"])
        if abs(center_hz - expected_center) > 0.001:
            failures.append(f"case {case_index}: center {center_hz} != expected {expected_center}")
        case_failures, line = check_case(case_index, case_rows)
        failures.extend(case_failures)
        lines.append(line)

    lines.extend([
        "",
        "Scope:",
        "- This is a sine-input RTL/IP sweep over the review2 5, 10, 20, 50, 100, 150, and 200 kHz centers.",
        "- The checker requires positive high-side tracking response in the final half of each case, not only during early transients.",
        "- The RTL testbench exports the hybrid-loop state and term operands used for each tracking update; this checker replays the frozen fixed-point control law and a float reference against every emitted RTL row.",
        "- `freq_state` and `freq_correction` are checked in the same row; external `tracking_word` is checked against the previous row's fixed-point `center+correction`, matching the core's registered NCO hold update.",
        "- This validates the closed-loop control-law outputs for the exercised sine traces; it is still not a full coefficient-tuning or noise-margin characterization.",
    ])
    return failures, lines


def main() -> int:
    trace = (ROOT / sys.argv[1]).resolve() if len(sys.argv) > 1 else latest_trace()
    rows = load_rows(trace)
    write_stable_trace(rows)
    failures, lines = check_rows(rows)
    lines.insert(4, f"Stable trace: `{STABLE_TRACE.relative_to(ROOT)}`")
    lines.insert(5, f"Source run trace: `{trace.relative_to(ROOT)}`")
    lines.insert(6, "")
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"trace={trace}")
    print(f"report={REPORT}")
    if failures:
        print("FAIL:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("PASS: DPLL core sine sweep trace")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
