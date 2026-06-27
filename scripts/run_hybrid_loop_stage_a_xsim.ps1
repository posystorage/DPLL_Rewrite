$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'D:\Xilinx\Vivado\2018.3\bin'
$OutDir = Join-Path $RepoRoot 'reports\xsim\hybrid_loop_stage_a_cli'

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $rtl = Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\hybrid_loop\hybrid_fll_pll_filter_stage_a.v'
    $tb = Join-Path $RepoRoot 'verification\rtl\hybrid_fll_pll_filter_stage_a_tb.v'

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl $tb
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xelab.bat') hybrid_fll_pll_filter_stage_a_tb -snapshot hybrid_fll_pll_filter_stage_a_tb
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xsim.bat') hybrid_fll_pll_filter_stage_a_tb -runall -log hybrid_fll_pll_filter_stage_a_xsim.log
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }

    $content = Get-Content -LiteralPath (Join-Path $OutDir 'hybrid_fll_pll_filter_stage_a_xsim.log') -Raw
    if ($content -match 'FAIL:') { throw 'xsim reported FAIL' }
    if ($content -notmatch 'PASS: hybrid_fll_pll_filter_stage_a_tb') { throw 'missing pass marker' }
}
finally {
    Pop-Location
}
