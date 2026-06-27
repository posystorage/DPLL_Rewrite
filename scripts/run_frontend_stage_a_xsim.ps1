$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'D:\Xilinx\Vivado\2018.3\bin'
$OutDir = Join-Path $RepoRoot 'reports\xsim\frontend_stage_a_cli'

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

    & (Join-Path $VivadoBin 'xelab.bat') tracking_phase_accumulator_stage_a_tb -snapshot tracking_phase_accumulator_stage_a_tb
    if ($LASTEXITCODE -ne 0) { throw "phase xelab failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xsim.bat') tracking_phase_accumulator_stage_a_tb -runall -log phase_xsim.log
    if ($LASTEXITCODE -ne 0) { throw "phase xsim failed with exit code $LASTEXITCODE" }
    Assert-PassLog -LogPath (Join-Path $OutDir 'phase_xsim.log') -PassText 'PASS: tracking_phase_accumulator_stage_a_tb'

    & (Join-Path $VivadoBin 'xelab.bat') iq_mixer_stage_a_tb -snapshot iq_mixer_stage_a_tb
    if ($LASTEXITCODE -ne 0) { throw "mixer xelab failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xsim.bat') iq_mixer_stage_a_tb -runall -log mixer_xsim.log
    if ($LASTEXITCODE -ne 0) { throw "mixer xsim failed with exit code $LASTEXITCODE" }
    Assert-PassLog -LogPath (Join-Path $OutDir 'mixer_xsim.log') -PassText 'PASS: iq_mixer_stage_a_tb'
}
finally {
    Pop-Location
}
