$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'D:\Xilinx\Vivado\2018.3\bin'
$OutDir = Join-Path $RepoRoot 'reports\xsim\single_clock_core_stage_a_cli'

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $rtl = @(
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\frontend\tracking_phase_accumulator_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\frontend\iq_mixer_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\iq_cic\post_iq_cic_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\detector_fll\fll_phase_difference_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\hybrid_loop\hybrid_fll_pll_filter_stage_a.v'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\core\dpll_single_clock_core_stage_a.v'
        Join-Path $RepoRoot 'verification\rtl\dpll_single_clock_core_stage_a_tb.v'
    )

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xelab.bat') dpll_single_clock_core_stage_a_tb -snapshot dpll_single_clock_core_stage_a_tb
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xsim.bat') dpll_single_clock_core_stage_a_tb -runall -log xsim.log
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }

    $content = Get-Content -LiteralPath (Join-Path $OutDir 'xsim.log') -Raw
    if ($content -match 'FAIL:') { throw 'xsim reported FAIL' }
    if ($content -notmatch 'PASS: dpll_single_clock_core_stage_a_tb') { throw 'missing PASS marker' }
}
finally {
    Pop-Location
}
