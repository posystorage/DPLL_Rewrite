# Review P5 Multifrequency Validation

Date: 2026-06-28
Branch: `refactor/dpll-single-path`

## Scope

This checkpoint closes the remaining P5 datapath verification gap for the refactored single-clock DPLL core. It verifies that the active DPLL path uses the configured Xilinx IP-based datapath over multiple frequency words, rather than a hand-written shortcut path.

The change covers:

- `LO_DDS_H` DDS Compiler IP driving sine/cosine LO outputs.
- `input_multiplier` Multiplier Generator IP used for I/Q mixing.
- `post_iq_cic_stage_a` active post-I/Q CIC decimation with applied R/shift configuration.
- `angle_CORDIC` CORDIC IP used for phase/magnitude generation.
- FLL/PLL tracking output propagation through the single-clock core.

## RTL Fixes

File: `DPLL_Rewrite.srcs/sources_1/DigitalPLL/core/dpll_single_clock_core_stage_a.v`

- Added `nco_word_ready` so `LO_DDS_H` does not accept a zero/uninitialized frequency word during startup. The DDS phase input valid now asserts only after a nonzero `center_word` or correction tracking word has been loaded.
- Added `mixer_product_valid` to align downstream `mixer_valid` with the configured `input_multiplier` pipeline latency. The prior valid strobe was one cycle early for the Multiplier Generator output.

## New Automated Test

Files:

- `verification/rtl/dpll_multifrequency_path_tb.v`
- `scripts/run_dpll_multifrequency_path_xsim.ps1`

The testbench runs seven 48-bit frequency words at 125 MHz:

| Case | Frequency | Word |
| --- | ---: | --- |
| 0 | 5 kHz | `48'h0002_9f16_b11c` |
| 1 | 10 kHz | `48'h0005_3e2d_6239` |
| 2 | 20 kHz | `48'h000a_7c5a_c472` |
| 3 | 50 kHz | `48'h001a_36e2_eb1c` |
| 4 | 100 kHz | `48'h0034_6dc5_d639` |
| 5 | 150 kHz | `48'h004e_a4a8_c155` |
| 6 | 200 kHz | `48'h0068_db8b_ac71` |

Each case checks:

- At least 16 I/Q CIC outputs.
- At least 8 frequency-error outputs.
- At least 4 tracking-word updates.
- Nonzero I/Q activity.
- Phase-error activity.
- Nonzero tracking word.
- No CIC illegal-config or overflow latch.
- Applied CIC config remains `R=8`, `shift=4`.

## Verification Results

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_dpll_multifrequency_path_xsim.ps1
```

Result: PASS.

Observed PASS markers:

- `PASS_CASE: index=0 word=0x00029f16b11c iq=45 freq=43 tracking=43 state=6 loss=0 signal=1 phase_lock=1 freq_lock=1 locked=1 mag=215`
- `PASS_CASE: index=1 word=0x00053e2d6239 iq=45 freq=45 tracking=45 state=6 loss=0 signal=1 phase_lock=1 freq_lock=1 locked=1 mag=11`
- `PASS_CASE: index=2 word=0x000a7c5ac472 iq=45 freq=45 tracking=45 state=6 loss=0 signal=1 phase_lock=1 freq_lock=1 locked=1 mag=24`
- `PASS_CASE: index=3 word=0x001a36e2eb1c iq=45 freq=45 tracking=45 state=6 loss=0 signal=1 phase_lock=1 freq_lock=1 locked=1 mag=6`
- `PASS_CASE: index=4 word=0x00346dc5d639 iq=45 freq=45 tracking=45 state=6 loss=0 signal=1 phase_lock=1 freq_lock=1 locked=1 mag=7`
- `PASS_CASE: index=5 word=0x004ea4a8c155 iq=45 freq=45 tracking=45 state=6 loss=0 signal=1 phase_lock=1 freq_lock=1 locked=1 mag=35`
- `PASS_CASE: index=6 word=0x0068db8bac71 iq=45 freq=45 tracking=45 state=6 loss=0 signal=1 phase_lock=1 freq_lock=1 locked=1 mag=7`
- `PASS: dpll_multifrequency_path_tb`

Regression command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_single_clock_core_stage_a_xsim.ps1
```

Result: PASS with `PASS: dpll_single_clock_core_stage_a_tb`.

Clock cleanup audit command:

```powershell
python scripts\audit_clk_dpll_usage.py
```

Result: `active_clk_dpll_hits=0`.

Project synthesis command:

```powershell
D:\Xilinx\Vivado\2018.3\bin\vivado.bat -mode batch -source scripts\vivado_single_clock_core_stage_a_project_synth_check.tcl
```

Result: `synth_design Complete!`, `synth_progress=100%`.

The generated synthesis timing summary still reports timing violations:

- WNS: `-2.820 ns`
- TNS: `-2185.821 ns`
- Worst reported setup path is in `dpll_wrapper_inst/debug_dac_formatter_inst`.

This proves project synthesis completeness for the modified RTL path, but not timing closure.

## Limitations

- This is an RTL simulation checkpoint for the active single-clock DPLL datapath. It is not a board lock or analog performance signoff.
- Full routed timing is still tracked separately. The user explicitly excluded the direct system-bus `adc_clk -> pll_adc_clk` timing issue from required correction, but other reported timing violations remain open.
- Vivado 2018.3 reports known simulator warnings inside generated Xilinx IP libraries, plus an `xelab` cleanup-only obj-directory warning after snapshot creation. These warnings did not prevent the PASS markers above.
