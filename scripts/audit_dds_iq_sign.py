from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DDS_XCI = ROOT / "DPLL_Rewrite.srcs" / "sources_1" / "Freq_Meter" / "DDC" / "ip" / "LO_DDS_H" / "LO_DDS_H.xci"
CORE_RTL = ROOT / "DPLL_Rewrite.srcs" / "sources_1" / "DigitalPLL" / "DDC" / "dpll_single_clock_core_stage_a.v"


def main() -> int:
    dds_text = DDS_XCI.read_text(encoding="utf-8")
    core_text = CORE_RTL.read_text(encoding="utf-8")

    checks = {
        "LO_DDS_H Negative_Sine=true": 'referenceId="PARAM_VALUE.Negative_Sine">true<' in dds_text,
        "Q mixer uses lo_sin_r1 directly": ".B(lo_sin_r1)" in core_text,
        "Q mixer does not double-negate lo_sin_r1": ".B(-lo_sin_r1)" not in core_text,
    }

    failed = [name for name, passed in checks.items() if not passed]
    for name, passed in checks.items():
        print(f"{'PASS' if passed else 'FAIL'}: {name}")

    if failed:
        print("DDS/IQ sign audit failed:")
        for name in failed:
            print(f"  - {name}")
        return 1

    print("PASS: dds_iq_sign_audit")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
