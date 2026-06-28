$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

Push-Location $RepoRoot
try {
    powershell -ExecutionPolicy Bypass -File scripts\run_hybrid_loop_stage_a_xsim.ps1
    python verification\fixed_point\check_hybrid_loop_trace.py
}
finally {
    Pop-Location
}
