# P4 Legacy 3.125 MHz Valid Generator Removal - 2026-06-28

## Scope

This change removes the remaining active `dpll_clock_valid_stage_a` instance
from `dpll_wrapper`. The instance no longer fed the DPLL datapath after the
pre-IQ Xilinx CIC was connected, but it still generated a legacy 3.125 MHz
valid pulse in the wrapper.

## RTL Change

- Removed `sample_3m125_valid_stage_a_unused`.
- Removed `dpll_clock_valid_stage_a_inst`.
- Replaced its reset output with a two-flop reset synchronizer in the `clk1`
  domain.
- Removed `clocking/dpll_clock_valid_stage_a.v` from the active Vivado project
  source list.

The `dpll_clock_valid_stage_a.v` file and its standalone test remain in the
repository as historical verification scaffolding, but it is no longer part of
the active DPLL build.

## Verification

Commands:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_single_clock_core_stage_a_xsim.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_dpll_multifrequency_path_xsim.ps1
python scripts\audit_clk_dpll_usage.py
```

Results:

```text
PASS: dpll_single_clock_core_stage_a_tb
PASS: dpll_multifrequency_path_tb
active_clk_dpll_hits=0
```

## Constraints

- No `clk_dpll` source was reintroduced.
- No false path or multicycle exception was added.
- No register ABI was changed.
- The active pre-IQ sample cadence remains driven by `cic_compiler_0`
  `m_axis_data_tvalid`, not by a wrapper-local /40 pulse generator.
