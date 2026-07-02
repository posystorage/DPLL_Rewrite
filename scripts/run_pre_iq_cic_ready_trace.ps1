$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'C:\Xilinx\Vivado\2018.3\bin'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$OutDir = Join-Path $RepoRoot "reports\xsim\pre_iq_cic_ready_cli_$RunStamp"

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir

try {
    $snapshot = 'pre_iq_cic_ready_tb'
    $vhdl = @(
        Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\DDC\ip\pre_iq_cic_40_125m_v1\pre_iq_cic_40_125m_v1\sim\pre_iq_cic_40_125m_v1.vhd'
    )
    $rtl = @(
        Join-Path $RepoRoot 'verification\rtl\pre_iq_cic_ready_tb.v'
    )

    & (Join-Path $VivadoBin 'xvhdl.bat') $vhdl
    if ($LASTEXITCODE -ne 0) { throw "xvhdl failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xvlog.bat') $rtl
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $xelabLog = Join-Path $OutDir 'xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') pre_iq_cic_ready_tb -snapshot $snapshot 2>&1 |
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
    if ($content -notmatch 'PASS: pre_iq_cic_ready_tb') { throw 'missing PASS marker' }

    $trace = Join-Path $OutDir 'pre_iq_cic_ready_trace.csv'
    python (Join-Path $RepoRoot 'verification\fixed_point\check_pre_iq_cic_ready_trace.py') $trace
    if ($LASTEXITCODE -ne 0) { throw "pre-IQ CIC ready checker failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
