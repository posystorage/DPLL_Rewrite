$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'C:\Xilinx\Vivado\2018.3\bin'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$OutDir = Join-Path $RepoRoot "reports\xsim\fast_frequency_accumulator_$RunStamp"

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $snapshot = 'fast_frequency_accumulator_tb'
    $rtl = @(
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\Freq_Meter\fast_frequency_accumulator.v'
        Join-Path $RepoRoot 'verification\rtl\fast_frequency_accumulator_tb.v'
    )

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $xelabLog = Join-Path $OutDir 'xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') fast_frequency_accumulator_tb -snapshot $snapshot 2>&1 |
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
    if ($content -notmatch 'PASS: fast_frequency_accumulator_tb') { throw 'missing PASS marker' }
}
finally {
    Pop-Location
}
