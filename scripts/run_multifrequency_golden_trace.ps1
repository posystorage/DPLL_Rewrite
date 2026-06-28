$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

Push-Location $RepoRoot
try {
    powershell -ExecutionPolicy Bypass -File scripts\run_dpll_multifrequency_path_xsim.ps1
    python verification\fixed_point\check_multifrequency_trace.py
}
finally {
    Pop-Location
}
