$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'C:\Xilinx\Vivado\2018.3\bin'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$OutDir = Join-Path $RepoRoot "reports\xsim\single_clock_core_stage_a_cli_$RunStamp"

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $snapshot = 'dpll_single_clock_core_stage_a_tb'
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
        Join-Path $RepoRoot 'verification\rtl\dpll_single_clock_core_stage_a_tb.v'
    )

    & (Join-Path $VivadoBin 'xvhdl.bat') $vhdl
    if ($LASTEXITCODE -ne 0) { throw "xvhdl failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $xelabLog = Join-Path $OutDir 'xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') dpll_single_clock_core_stage_a_tb -snapshot $snapshot 2>&1 |
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
    if ($content -notmatch 'PASS: dpll_single_clock_core_stage_a_tb') { throw 'missing PASS marker' }
}
finally {
    Pop-Location
}
