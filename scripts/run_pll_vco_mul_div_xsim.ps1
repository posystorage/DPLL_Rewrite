$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'D:\Xilinx\Vivado\2018.3\bin'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$OutDir = Join-Path $RepoRoot "reports\xsim\pll_vco_mul_div_cli_$RunStamp"

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $snapshot = 'pll_vco_mul_div_tb'
    $vhdl = @(
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\VCO\mult_gen_pll\sim\mult_gen_pll.vhd'
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\VCO\div_gen_pll\sim\div_gen_pll.vhd'
    )
    $rtl = @(
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\VCO\PLL_VCO_MUL_DIV.v'
        Join-Path $RepoRoot 'verification\rtl\pll_vco_mul_div_tb.v'
    )

    & (Join-Path $VivadoBin 'xvhdl.bat') $vhdl
    if ($LASTEXITCODE -ne 0) { throw "xvhdl failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $xelabLog = Join-Path $OutDir 'xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') pll_vco_mul_div_tb -snapshot $snapshot 2>&1 |
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
    if ($content -notmatch 'PASS: pll_vco_mul_div_tb') { throw 'missing PASS marker' }
}
finally {
    Pop-Location
}
