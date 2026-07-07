$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'C:\Xilinx\Vivado\2018.3\bin'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$OutDir = Join-Path $RepoRoot "reports\xsim\dpll_core_sine_sweep_$RunStamp"

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $snapshot = 'dpll_core_sine_sweep_tb'
    $vhdl = @(
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\Freq_Meter\DDC\ip\LO_DDS_H\synth\LO_DDS_H.vhd'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\DDC\ip\dpll_input_multiplier\synth\dpll_input_multiplier.vhd'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\DDC\ip\dpll_angle_CORDIC\synth\dpll_angle_CORDIC.vhd'
    )
    $rtl = @(
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\frontend\dc_blocker_valid_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\DDC\iq_mixer_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\DDC\post_iq_cic_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\DDC\post_iir_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\hybrid_loop\fll_phase_difference_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\DDC\cordic_word_serial_adapter.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\hybrid_loop\loop_state_manager_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\hybrid_loop\hybrid_fll_pll_filter_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\DDC\dpll_single_clock_core_stage_a.v'
        Join-Path $RepoRoot 'verification\rtl\dpll_core_sine_sweep_tb.v'
    )

    & (Join-Path $VivadoBin 'xvhdl.bat') $vhdl
    if ($LASTEXITCODE -ne 0) { throw "xvhdl failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $xelabLog = Join-Path $OutDir 'xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') $snapshot -snapshot $snapshot 2>&1 |
        Tee-Object -FilePath $xelabLog
    $xelabExit = $LASTEXITCODE
    $xelabText = Get-Content -LiteralPath $xelabLog -Raw
    $snapshotBuilt = $xelabText -match "Built simulation snapshot $snapshot"
    $cleanupOnly = $xelabText -match 'Could not remove the obj directory'
    if ($xelabExit -ne 0 -and -not ($snapshotBuilt -and $cleanupOnly)) {
        throw "xelab failed with exit code $xelabExit"
    }

    & (Join-Path $VivadoBin 'xsim.bat') $snapshot -runall -log xsim.log
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }

    $content = Get-Content -LiteralPath (Join-Path $OutDir 'xsim.log') -Raw
    if ($content -match 'FAIL:') { throw 'xsim reported FAIL' }
    if ($content -notmatch 'PASS: dpll_core_sine_sweep_tb') { throw 'missing PASS marker' }
    foreach ($case in 0..13) {
        if ($content -notmatch "PASS_CASE: sine_sweep index=$case") {
            throw "missing PASS_CASE marker for index $case"
        }
    }

    $trace = Join-Path $OutDir 'dpll_core_sine_sweep_trace.csv'
    python (Join-Path $RepoRoot 'verification\fixed_point\check_dpll_core_sine_sweep_trace.py') $trace
    if ($LASTEXITCODE -ne 0) { throw "DPLL core sine sweep checker failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
