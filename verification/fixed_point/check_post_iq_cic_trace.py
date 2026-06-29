#!/usr/bin/env python3
import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TRACE_GLOB = "reports/xsim/iq_cic_stage_a_cli_*/post_iq_cic_trace.csv"
REPORT = ROOT / "reports" / "post_iq_cic_golden_trace_20260628.md"
STABLE_CSV = ROOT / "reports" / "post_iq_cic_golden_trace_20260628.csv"

INPUT_WIDTH = 18
ACC_WIDTH = 44
OUTPUT_WIDTH = 20
ROUND_WIDTH = ACC_WIDTH + 1
MIN_RATE = 8
MAX_RATE = 312
WARMUP_OUTPUT_COUNT = 3


def signed(value: int, width: int) -> int:
    mask = (1 << width) - 1
    value &= mask
    sign = 1 << (width - 1)
    return value - (1 << width) if value & sign else value


def arshift(value: int, shift: int) -> int:
    return value >> shift


def rounding_bias_for_shift(shift: int) -> int:
    if shift == 0 or shift >= ROUND_WIDTH:
        return 0
    return 1 << (shift - 1)


def saturate_shifted(value: int) -> int:
    max_value = (1 << (OUTPUT_WIDTH - 1)) - 1
    min_value = -(1 << (OUTPUT_WIDTH - 1))
    return max(min(value, max_value), min_value)


def overflow_needed(value: int) -> bool:
    return value != saturate_shifted(value)


class PostIqCicModel:
    def __init__(self) -> None:
        self.active_rate = MIN_RATE
        self.active_shift = 0
        self.active_rounding_bias = 0
        self.illegal_config_seen = False
        self.overflow_seen = False
        self.pending_clear = False
        self.reset_pipelines()

    def reset_pipelines(self) -> None:
        self.i_int0 = self.i_int1 = self.i_int2 = 0
        self.q_int0 = self.q_int1 = self.q_int2 = 0
        self.i_comb_d0 = self.i_comb_d1 = self.i_comb_d2 = 0
        self.q_comb_d0 = self.q_comb_d1 = self.q_comb_d2 = 0
        self.i_decim_sample = self.q_decim_sample = 0
        self.i_comb1 = self.q_comb1 = 0
        self.i_comb2 = self.q_comb2 = 0
        self.i_comb3 = self.q_comb3 = 0
        self.i_shift_stage0 = self.q_shift_stage0 = 0
        self.i_shift_stage1 = self.q_shift_stage1 = 0
        self.i_shift_stage2 = self.q_shift_stage2 = 0
        self.i_shift_stage3 = self.q_shift_stage3 = 0
        self.i_shift_stage4 = self.q_shift_stage4 = 0
        self.i_shift_stage5 = self.q_shift_stage5 = 0
        self.i_shifted = self.q_shifted = 0
        self.i_rounded = self.q_rounded = 0
        self.comb0_valid = False
        self.comb1_valid = False
        self.comb2_valid = False
        self.output_pipe_valid = False
        self.shift_pipe_valid = [False] * 7
        self.rounded_output_valid = False
        self.sample_count = 0
        self.warmup_outputs_remaining = WARMUP_OUTPUT_COUNT

    def apply_config(self, rate: int, shift: int) -> None:
        if MIN_RATE <= rate <= MAX_RATE:
            self.active_rate = rate
            self.active_shift = shift
            self.active_rounding_bias = rounding_bias_for_shift(shift)
            self.illegal_config_seen = False
            self.pending_clear = True
        else:
            self.illegal_config_seen = True

    def flush(self) -> None:
        self.overflow_seen = False
        self.pending_clear = True

    def step(self, i_in: int, q_in: int) -> tuple[bool, int, int, bool]:
        if self.pending_clear:
            self.reset_pipelines()
            self.pending_clear = False
            return False, 0, 0, self.overflow_seen

        old = self.__dict__.copy()
        old_shift_pipe = list(self.shift_pipe_valid)

        out_valid = False
        i_out = 0
        q_out = 0

        next_comb0_valid = False
        next_comb1_valid = old["comb0_valid"]
        next_comb2_valid = old["comb1_valid"]
        next_output_pipe_valid = old["comb2_valid"]
        next_shift_pipe_valid = [old["output_pipe_valid"]] + old_shift_pipe[:6]
        next_rounded_output_valid = False

        if old["sample_count"] == old["active_rate"] - 1:
            next_comb0_valid = True
            next_sample_count = 0
        else:
            next_sample_count = old["sample_count"] + 1

        next_warmup = old["warmup_outputs_remaining"]
        if old_shift_pipe[6]:
            if old["warmup_outputs_remaining"] != 0:
                next_warmup = old["warmup_outputs_remaining"] - 1
            else:
                next_rounded_output_valid = True

        if old["rounded_output_valid"]:
            i_out = saturate_shifted(old["i_rounded"])
            q_out = saturate_shifted(old["q_rounded"])
            self.overflow_seen = (
                old["overflow_seen"]
                or overflow_needed(old["i_rounded"])
                or overflow_needed(old["q_rounded"])
            )
            out_valid = True

        self.comb0_valid = next_comb0_valid
        self.comb1_valid = next_comb1_valid
        self.comb2_valid = next_comb2_valid
        self.output_pipe_valid = next_output_pipe_valid
        self.shift_pipe_valid = next_shift_pipe_valid
        self.rounded_output_valid = next_rounded_output_valid
        self.sample_count = next_sample_count
        self.warmup_outputs_remaining = next_warmup

        self.i_int0 = signed(old["i_int0"] + signed(i_in, INPUT_WIDTH), ACC_WIDTH)
        self.i_int1 = signed(old["i_int1"] + old["i_int0"], ACC_WIDTH)
        self.i_int2 = signed(old["i_int2"] + old["i_int1"], ACC_WIDTH)
        self.q_int0 = signed(old["q_int0"] + signed(q_in, INPUT_WIDTH), ACC_WIDTH)
        self.q_int1 = signed(old["q_int1"] + old["q_int0"], ACC_WIDTH)
        self.q_int2 = signed(old["q_int2"] + old["q_int1"], ACC_WIDTH)

        if old["comb0_valid"]:
            self.i_comb_d0 = old["i_decim_sample"]
            self.q_comb_d0 = old["q_decim_sample"]
        if old["comb1_valid"]:
            self.i_comb_d1 = old["i_comb1"]
            self.q_comb_d1 = old["q_comb1"]
        if old["comb2_valid"]:
            self.i_comb_d2 = old["i_comb2"]
            self.q_comb_d2 = old["q_comb2"]

        self.i_decim_sample = old["i_int2"]
        self.q_decim_sample = old["q_int2"]
        if old["comb0_valid"]:
            self.i_comb1 = signed(old["i_decim_sample"] - old["i_comb_d0"], ACC_WIDTH)
            self.q_comb1 = signed(old["q_decim_sample"] - old["q_comb_d0"], ACC_WIDTH)
        if old["comb1_valid"]:
            self.i_comb2 = signed(old["i_comb1"] - old["i_comb_d1"], ACC_WIDTH)
            self.q_comb2 = signed(old["q_comb1"] - old["q_comb_d1"], ACC_WIDTH)
        if old["comb2_valid"]:
            self.i_comb3 = signed(old["i_comb2"] - old["i_comb_d2"], ACC_WIDTH)
            self.q_comb3 = signed(old["q_comb2"] - old["q_comb_d2"], ACC_WIDTH)

        if old["output_pipe_valid"]:
            i_bias = (old["active_rounding_bias"] - 1) if (old["i_comb3"] < 0 and old["active_rounding_bias"]) else old["active_rounding_bias"]
            q_bias = (old["active_rounding_bias"] - 1) if (old["q_comb3"] < 0 and old["active_rounding_bias"]) else old["active_rounding_bias"]
            self.i_shift_stage0 = signed(old["i_comb3"] + i_bias, ROUND_WIDTH)
            self.q_shift_stage0 = signed(old["q_comb3"] + q_bias, ROUND_WIDTH)
        if old_shift_pipe[0]:
            self.i_shift_stage1 = arshift(old["i_shift_stage0"], 1) if old["active_shift"] & 1 else old["i_shift_stage0"]
            self.q_shift_stage1 = arshift(old["q_shift_stage0"], 1) if old["active_shift"] & 1 else old["q_shift_stage0"]
        if old_shift_pipe[1]:
            self.i_shift_stage2 = arshift(old["i_shift_stage1"], 2) if old["active_shift"] & 2 else old["i_shift_stage1"]
            self.q_shift_stage2 = arshift(old["q_shift_stage1"], 2) if old["active_shift"] & 2 else old["q_shift_stage1"]
        if old_shift_pipe[2]:
            self.i_shift_stage3 = arshift(old["i_shift_stage2"], 4) if old["active_shift"] & 4 else old["i_shift_stage2"]
            self.q_shift_stage3 = arshift(old["q_shift_stage2"], 4) if old["active_shift"] & 4 else old["q_shift_stage2"]
        if old_shift_pipe[3]:
            self.i_shift_stage4 = arshift(old["i_shift_stage3"], 8) if old["active_shift"] & 8 else old["i_shift_stage3"]
            self.q_shift_stage4 = arshift(old["q_shift_stage3"], 8) if old["active_shift"] & 8 else old["q_shift_stage3"]
        if old_shift_pipe[4]:
            self.i_shift_stage5 = arshift(old["i_shift_stage4"], 16) if old["active_shift"] & 16 else old["i_shift_stage4"]
            self.q_shift_stage5 = arshift(old["q_shift_stage4"], 16) if old["active_shift"] & 16 else old["q_shift_stage4"]
        if old_shift_pipe[5]:
            self.i_shifted = arshift(old["i_shift_stage5"], 32) if old["active_shift"] & 32 else old["i_shift_stage5"]
            self.q_shifted = arshift(old["q_shift_stage5"], 32) if old["active_shift"] & 32 else old["q_shift_stage5"]
        if old_shift_pipe[6] and old["warmup_outputs_remaining"] == 0:
            self.i_rounded = old["i_shifted"]
            self.q_rounded = old["q_shifted"]

        return out_valid, i_out, q_out, self.overflow_seen


def drive_model() -> list[dict[str, int]]:
    model = PostIqCicModel()
    rows: list[dict[str, int]] = []
    sample_index = 0
    output_index = 0
    current_i = 0
    current_q = 0

    def push(i_value: int, q_value: int) -> None:
        nonlocal sample_index, output_index, current_i, current_q
        current_i = i_value
        current_q = q_value
        sample_index += 1
        valid, i_out, q_out, overflow = model.step(i_value, q_value)
        if valid:
            output_index += 1
            rows.append({
                "sample_index": sample_index,
                "output_index": output_index,
                "active_rate_r": model.active_rate,
                "active_output_shift": model.active_shift,
                "i_in": i_value,
                "q_in": q_value,
                "i_out": i_out,
                "q_out": q_out,
                "overflow_seen": int(overflow),
            })

    def ignored_config_cycle(rate: int, shift: int) -> None:
        model.step(current_i, current_q)
        model.apply_config(rate, shift)

    def ignored_flush_cycle() -> None:
        model.step(current_i, current_q)
        model.flush()

    model.apply_config(8, 10)
    for _ in range(32):
        push(1, -1)
    for _ in range(32):
        push(1, -1)

    ignored_config_cycle(7, 10)
    for _ in range(16):
        push(1, -1)

    ignored_config_cycle(8, 10)
    for _ in range(24):
        push(0, 0)
    push(2048, -1024)
    for _ in range(48):
        push(0, 0)

    ignored_config_cycle(12, 11)
    for _ in range(96):
        push(3, -2)

    ignored_flush_cycle()
    for _ in range(48):
        push(-5, 7)

    return rows


def latest_trace() -> Path:
    traces = sorted(ROOT.glob(TRACE_GLOB), key=lambda path: path.stat().st_mtime)
    if not traces:
        raise SystemExit(f"missing xsim trace matching {TRACE_GLOB}")
    return traces[-1]


def load_trace(path: Path) -> list[dict[str, int]]:
    with path.open(newline="", encoding="utf-8") as fh:
        return [{key: int(value, 0) for key, value in row.items()} for row in csv.DictReader(fh)]


def main() -> int:
    trace_path = latest_trace()
    rtl_rows = load_trace(trace_path)
    model_rows = drive_model()

    failures: list[str] = []
    if len(rtl_rows) != len(model_rows):
        failures.append(f"row count rtl={len(rtl_rows)} model={len(model_rows)}")

    for index, (rtl, model) in enumerate(zip(rtl_rows, model_rows)):
        for key in model:
            if rtl[key] != model[key]:
                failures.append(
                    f"row {index} key {key}: rtl={rtl[key]} model={model[key]}"
                )

    STABLE_CSV.parent.mkdir(parents=True, exist_ok=True)
    with STABLE_CSV.open("w", newline="", encoding="utf-8") as fh:
        fieldnames = list(model_rows[0].keys()) if model_rows else []
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rtl_rows)

    lines = [
        "# post-IQ CIC Golden Trace",
        "",
        f"Source trace: `{trace_path}`",
        "",
        "The checker models the current RTL non-blocking assignment timing, including:",
        "",
        "- 3-stage integrator and 3-stage comb data path.",
        "- Decimation using the pre-update integrator sample, matching the RTL register timing.",
        "- Legal APPLY flush, illegal APPLY preservation, explicit flush, and warmup suppression.",
        "- Sign-symmetric rounding, output saturation, and I/Q shared valid alignment.",
        "",
        f"Rows checked: {len(rtl_rows)}",
    ]
    if failures:
        lines.extend(["", "## Failures", ""])
        lines.extend(f"- {failure}" for failure in failures[:50])
    else:
        lines.extend(["", "PASS: post-IQ CIC golden trace matches RTL."])
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    if failures:
        for failure in failures[:20]:
            print(f"FAIL: {failure}")
        return 1

    print(f"PASS: post-IQ CIC golden trace rows={len(rtl_rows)}")
    print(f"report={REPORT}")
    print(f"stable_csv={STABLE_CSV}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
