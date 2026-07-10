$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = @('C:\Xilinx\Vivado\2018.3\bin', 'D:\Xilinx\Vivado\2018.3\bin') |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $VivadoBin) { throw 'Vivado 2018.3 bin directory was not found on C: or D:' }
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$OutDir = Join-Path $RepoRoot "reports\xsim\hybrid_loop_stage_a_cli_$RunStamp"

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $rtl = Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\hybrid_loop\hybrid_fll_pll_filter_stage_a.v'
    $tb = Join-Path $RepoRoot 'verification\rtl\hybrid_fll_pll_filter_stage_a_tb.v'

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl $tb
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $snapshot = 'hybrid_fll_pll_filter_stage_a_tb'
    $xelabLog = Join-Path $OutDir 'xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') hybrid_fll_pll_filter_stage_a_tb -snapshot $snapshot 2>&1 |
        Tee-Object -FilePath $xelabLog
    $xelabExit = $LASTEXITCODE
    $xelabText = Get-Content -LiteralPath $xelabLog -Raw
    $snapshotBuilt = $xelabText -match "Built simulation snapshot $snapshot"
    $cleanupOnly = $xelabText -match 'Could not remove the obj directory'
    if ($xelabExit -ne 0 -and -not ($snapshotBuilt -and $cleanupOnly)) {
        throw "xelab failed with exit code $xelabExit"
    }

    & (Join-Path $VivadoBin 'xsim.bat') $snapshot -runall -log hybrid_fll_pll_filter_stage_a_xsim.log
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }

    $content = Get-Content -LiteralPath (Join-Path $OutDir 'hybrid_fll_pll_filter_stage_a_xsim.log') -Raw
    if ($content -match 'FAIL:') { throw 'xsim reported FAIL' }
    if ($content -notmatch 'PASS: hybrid_fll_pll_filter_stage_a_tb') { throw 'missing pass marker' }
}
finally {
    Pop-Location
}
