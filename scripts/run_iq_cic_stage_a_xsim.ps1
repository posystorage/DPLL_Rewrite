$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'D:\Xilinx\Vivado\2018.3\bin'
$OutDir = Join-Path $RepoRoot 'reports\xsim\iq_cic_stage_a_cli'

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $rtl = Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\iq_cic\post_iq_cic_stage_a.v'
    $tb = Join-Path $RepoRoot 'verification\rtl\post_iq_cic_stage_a_tb.v'

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl $tb
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xelab.bat') post_iq_cic_stage_a_tb -snapshot post_iq_cic_stage_a_tb
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xsim.bat') post_iq_cic_stage_a_tb -runall -log post_iq_cic_stage_a_xsim.log
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }

    $content = Get-Content -LiteralPath (Join-Path $OutDir 'post_iq_cic_stage_a_xsim.log') -Raw
    if ($content -match 'FAIL:') { throw 'xsim reported FAIL' }
    if ($content -notmatch 'PASS: post_iq_cic_stage_a_tb') { throw 'missing pass marker' }
}
finally {
    Pop-Location
}
