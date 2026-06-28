$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'D:\Xilinx\Vivado\2018.3\bin'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$OutDir = Join-Path $RepoRoot "reports\xsim\frontend_stage_a_cli_$RunStamp"

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    function Assert-PassLog {
        param(
            [string]$LogPath,
            [string]$PassText
        )

        $content = Get-Content -LiteralPath $LogPath -Raw
        if ($content -match 'FAIL:') { throw "xsim reported FAIL in $LogPath" }
        if ($content -notmatch [regex]::Escape($PassText)) { throw "missing pass marker '$PassText' in $LogPath" }
    }

    $phaseRtl = Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\frontend\tracking_phase_accumulator_stage_a.v'
    $mixerRtl = Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\frontend\iq_mixer_stage_a.v'
    $phaseTb = Join-Path $RepoRoot 'verification\rtl\tracking_phase_accumulator_stage_a_tb.v'
    $mixerTb = Join-Path $RepoRoot 'verification\rtl\iq_mixer_stage_a_tb.v'

    & (Join-Path $VivadoBin 'xvlog.bat') $phaseRtl $mixerRtl $phaseTb $mixerTb
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $phaseSnapshot = 'tracking_phase_accumulator_stage_a_tb'
    $phaseXelabLog = Join-Path $OutDir 'phase_xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') tracking_phase_accumulator_stage_a_tb -snapshot $phaseSnapshot 2>&1 |
        Tee-Object -FilePath $phaseXelabLog
    $phaseXelabExit = $LASTEXITCODE
    $phaseXelabText = Get-Content -LiteralPath $phaseXelabLog -Raw
    $phaseSnapshotBuilt = $phaseXelabText -match "Built simulation snapshot $phaseSnapshot"
    $phaseCleanupOnly = $phaseXelabText -match 'Could not remove the obj directory'
    if ($phaseXelabExit -ne 0 -and -not ($phaseSnapshotBuilt -and $phaseCleanupOnly)) {
        throw "phase xelab failed with exit code $phaseXelabExit"
    }

    & (Join-Path $VivadoBin 'xsim.bat') $phaseSnapshot -runall -log phase_xsim.log
    if ($LASTEXITCODE -ne 0) { throw "phase xsim failed with exit code $LASTEXITCODE" }
    Assert-PassLog -LogPath (Join-Path $OutDir 'phase_xsim.log') -PassText 'PASS: tracking_phase_accumulator_stage_a_tb'

    $mixerSnapshot = 'iq_mixer_stage_a_tb'
    $mixerXelabLog = Join-Path $OutDir 'mixer_xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') iq_mixer_stage_a_tb -snapshot $mixerSnapshot 2>&1 |
        Tee-Object -FilePath $mixerXelabLog
    $mixerXelabExit = $LASTEXITCODE
    $mixerXelabText = Get-Content -LiteralPath $mixerXelabLog -Raw
    $mixerSnapshotBuilt = $mixerXelabText -match "Built simulation snapshot $mixerSnapshot"
    $mixerCleanupOnly = $mixerXelabText -match 'Could not remove the obj directory'
    if ($mixerXelabExit -ne 0 -and -not ($mixerSnapshotBuilt -and $mixerCleanupOnly)) {
        throw "mixer xelab failed with exit code $mixerXelabExit"
    }

    & (Join-Path $VivadoBin 'xsim.bat') $mixerSnapshot -runall -log mixer_xsim.log
    if ($LASTEXITCODE -ne 0) { throw "mixer xsim failed with exit code $LASTEXITCODE" }
    Assert-PassLog -LogPath (Join-Path $OutDir 'mixer_xsim.log') -PassText 'PASS: iq_mixer_stage_a_tb'
}
finally {
    Pop-Location
}
