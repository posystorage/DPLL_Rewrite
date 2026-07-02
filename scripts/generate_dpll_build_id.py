#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERILOG_HEADER = ROOT / "DPLL_Rewrite.srcs/sources_1/DigitalPLL/dpll_build_id.vh"
ARM_HEADER = ROOT / "DPLL_Rewrite.sdk/DPLL_2COM/src/dpll_build_id.h"
ABI_VERSION = 0x00000002
CONFIG_VERSION = 0x00010004
EXCLUDED = {VERILOG_HEADER.resolve(), ARM_HEADER.resolve()}
SOURCE_PREFIXES = (
    "DPLL_Rewrite.srcs/",
    "DPLL_Rewrite.sdk/DPLL_2COM/src/",
    "scripts/",
    "verification/",
)
SOURCE_SUFFIXES = {".v", ".vh", ".vhd", ".vhdl", ".xci", ".xdc", ".c", ".h", ".py", ".ps1", ".tcl"}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def source_paths() -> list[Path]:
    names = set(git("ls-files").splitlines())
    untracked = git("ls-files", "--others", "--exclude-standard")
    if untracked:
        names.update(untracked.splitlines())
    paths: list[Path] = []
    for name in sorted(names):
        normalized = name.replace("\\", "/")
        path = (ROOT / normalized).resolve()
        if path in EXCLUDED or not path.is_file():
            continue
        if not normalized.startswith(SOURCE_PREFIXES):
            continue
        if path.suffix.lower() not in SOURCE_SUFFIXES:
            continue
        paths.append(path)
    return paths


def compute_source_digest() -> bytes:
    digest = hashlib.sha256()
    for path in source_paths():
        relative = path.relative_to(ROOT).as_posix().encode("utf-8")
        digest.update(relative)
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.digest()


def render() -> tuple[str, str, dict[str, int | str]]:
    sha = git("rev-parse", "HEAD")
    porcelain = git("status", "--porcelain", "--untracked-files=all")
    dirty = 1 if porcelain else 0
    source_digest = compute_source_digest()
    values: dict[str, int | str] = {
        "sha": sha,
        "git_hash": int.from_bytes(source_digest[4:8], "big"),
        "build_id": int.from_bytes(source_digest[:4], "big"),
        "dirty": dirty,
    }
    verilog = f"""`ifndef DPLL_BUILD_ID_VH
`define DPLL_BUILD_ID_VH
`define DPLL_GENERATED_ABI_VERSION 32'h{ABI_VERSION:08X}
`define DPLL_GENERATED_CONFIG_VERSION 32'h{CONFIG_VERSION:08X}
`define DPLL_GENERATED_BUILD_ID 32'h{values['build_id']:08X}
`define DPLL_GENERATED_GIT_HASH 32'h{values['git_hash']:08X}
`define DPLL_GENERATED_DIRTY 1'b{dirty}
`endif
"""
    arm = f"""#ifndef DPLL_BUILD_ID_H
#define DPLL_BUILD_ID_H
#define DPLL_GENERATED_ABI_VERSION 0x{ABI_VERSION:08X}U
#define DPLL_GENERATED_CONFIG_VERSION 0x{CONFIG_VERSION:08X}U
#define DPLL_GENERATED_BUILD_ID 0x{values['build_id']:08X}U
#define DPLL_GENERATED_GIT_HASH 0x{values['git_hash']:08X}U
#define DPLL_GENERATED_DIRTY {dirty}U
#endif
"""
    return verilog, arm, values


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    verilog, arm, values = render()
    expected = ((VERILOG_HEADER, verilog), (ARM_HEADER, arm))
    if args.check:
        stale = [str(path.relative_to(ROOT)) for path, text in expected if not path.exists() or path.read_text() != text]
        if stale:
            print("FAIL: stale generated build identity: " + ", ".join(stale))
            return 1
    else:
        for path, text in expected:
            path.write_text(text, encoding="ascii", newline="\n")
    print(
        f"build_id=0x{values['build_id']:08X} git_hash=0x{values['git_hash']:08X} "
        f"dirty={values['dirty']} sha={values['sha']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
