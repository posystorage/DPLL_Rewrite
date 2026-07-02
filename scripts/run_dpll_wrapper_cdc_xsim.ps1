$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$VivadoBin = 'C:\Xilinx\Vivado\2018.3\bin'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$OutDir = Join-Path $RepoRoot "reports\xsim\dpll_wrapper_cdc_$RunStamp"
$IncludeDir = Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL'

python (Join-Path $RepoRoot 'scripts\generate_dpll_build_id.py')
if ($LASTEXITCODE -ne 0) { throw 'failed to generate DPLL build identity' }
python (Join-Path $RepoRoot 'scripts\generate_dpll_build_id.py') --check
if ($LASTEXITCODE -ne 0) { throw 'generated build identity is stale' }

New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $OutDir
try {
    & (Join-Path $VivadoBin 'xvhdl.bat') `
        (Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\Basic\parallel_bus_register.vhd')
    if ($LASTEXITCODE -ne 0) { throw "xvhdl failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin 'xvlog.bat') -i $IncludeDir `
        (Join-Path $RepoRoot 'DPLL_Rewrite.srcs\sources_1\DigitalPLL\dpll_wrapper.v') `
        (Join-Path $RepoRoot 'verification\rtl\dpll_wrapper_cdc_tb.v')
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $snapshot = 'dpll_wrapper_cdc_tb'
    $xelabLog = Join-Path $OutDir 'xelab_stdout.log'
    & (Join-Path $VivadoBin 'xelab.bat') $snapshot -snapshot $snapshot 2>&1 |
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
    $Text = Get-Content -LiteralPath (Join-Path $OutDir 'xsim.log') -Raw
    if ($Text -match 'FAIL:') { throw 'wrapper CDC simulation reported FAIL' }
    if ($Text -notmatch 'PASS: dpll_wrapper_cdc_tb') { throw 'missing wrapper CDC PASS marker' }
}
finally {
    Pop-Location
}
