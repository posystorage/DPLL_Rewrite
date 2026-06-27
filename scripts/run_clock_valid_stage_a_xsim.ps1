$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'D:\Xilinx\Vivado\2018.3\bin'
$OutDir = Join-Path $RepoRoot 'reports\xsim\clock_valid_stage_a_cli'

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $rtl = Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\clocking\dpll_clock_valid_stage_a.v'
    $tb = Join-Path $RepoRoot 'verification\rtl\dpll_clock_valid_stage_a_tb.v'

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl $tb
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xelab.bat') dpll_clock_valid_stage_a_tb -snapshot dpll_clock_valid_stage_a_tb
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xsim.bat') dpll_clock_valid_stage_a_tb -runall
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
