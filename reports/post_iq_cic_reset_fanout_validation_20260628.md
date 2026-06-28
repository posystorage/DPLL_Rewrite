# Post-IQ CIC Reset Fanout Validation

## Change

- Split the post-IQ CIC clear path into local registered clear groups for:
  - control and valid pipeline
  - I integrators
  - Q integrators
  - comb delay registers
  - comb pipeline
  - shift/output pipeline
- Kept legal APPLY semantics: active R/shift updates only on legal `config_apply`.
- Kept illegal APPLY behavior: flag error and do not flush active CIC state.
- Did not add false-path or multicycle constraints.

## Verification Run

| Check | Result |
|---|---|
| `python scripts\audit_review_closure.py` | PASS |
| `python scripts\audit_clk_dpll_usage.py` | PASS, active hits = 0 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_iq_cic_stage_a_xsim.ps1` | PASS |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_debug_dac_formatter_stage_a_xsim.ps1` | PASS |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_single_clock_core_stage_a_xsim.ps1` | PASS |
| `vivado.bat -mode batch -source scripts\vivado_full_bitstream_reports.tcl` | Bitstream generated, timing not closed |
| `python scripts\audit_full_timing_exceptions.py` | NOT_CLOSED, non-excluded timing remains |

## Timing Result

The full implementation report generated at `2026-06-28 13:18:39` produced:

| Clock pair | Before this fix | After this fix |
|---|---:|---:|
| `pll_adc_clk -> pll_adc_clk` failing endpoints | 1607 | 11 |
| `pll_adc_clk -> pll_adc_clk` TNS | -856.867 ns | -2.835 ns |
| `pll_adc_clk -> pll_adc_clk` WNS | -1.311 ns | -0.595 ns |

Remaining non-excluded failing clock pairs are tracked in `reports/full_timing_exception_audit_20260628.md`.

## Closure

This change improves the DPLL post-IQ CIC reset fanout path and preserves functional tests, but it does not complete full timing closure. The goal remains open because non-excluded timing failures still exist outside the explicitly allowed `adc_clk -> pll_adc_clk` exception.
