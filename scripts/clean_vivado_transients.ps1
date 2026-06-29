param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

python (Join-Path $RepoRoot 'scripts\generate_dpll_build_id.py')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($DryRun) {
    git -C $RepoRoot clean -ndX
    exit $LASTEXITCODE
}

git -C $RepoRoot clean -fdX
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

python (Join-Path $RepoRoot 'scripts\generate_dpll_build_id.py') --check
exit $LASTEXITCODE
