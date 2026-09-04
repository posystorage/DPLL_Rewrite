$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$Tcl = Join-Path $RepoRoot 'scripts\vivado_dpll_integrated_flow_sim.tcl'
$VivadoCandidates = @(
    'C:\Xilinx\Vivado\2018.3\bin\vivado.bat',
    'D:\Xilinx\Vivado\2018.3\bin\vivado.bat',
    'E:\Xilinx\Vivado\2018.3\bin\vivado.bat'
)
$Vivado = $VivadoCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $Vivado) {
    throw "Vivado 2018.3 not found. Checked: $($VivadoCandidates -join ', ')"
}

python (Join-Path $RepoRoot 'scripts\generate_dpll_build_id.py')
if ($LASTEXITCODE -ne 0) { throw 'failed to generate DPLL build identity' }
python (Join-Path $RepoRoot 'scripts\generate_dpll_build_id.py') --check
if ($LASTEXITCODE -ne 0) { throw 'generated DPLL build identity is stale' }

Push-Location $RepoRoot
try {
    & $Vivado -mode batch -source $Tcl
    if ($LASTEXITCODE -ne 0) { throw "Vivado simulation launch failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
