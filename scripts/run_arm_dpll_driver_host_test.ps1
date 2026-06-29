$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$Gcc = 'D:\Xilinx\Vivado\2018.3\tps\mingw\6.2.0\win64.o\nt\bin\gcc.exe'
$OutDir = Join-Path $RepoRoot 'reports\arm_dpll_driver_host_test'
$Exe = Join-Path $OutDir 'dpll_driver_host_test.exe'
$Log = Join-Path $OutDir 'dpll_driver_host_test.log'
$Include = '-I' + (Join-Path $RepoRoot 'DPLL_Rewrite.sdk\DPLL_2COM\src')

New-Item -ItemType Directory -Force $OutDir | Out-Null
python (Join-Path $RepoRoot 'scripts\generate_dpll_build_id.py')
if ($LASTEXITCODE -ne 0) { throw 'failed to generate DPLL build identity' }
python (Join-Path $RepoRoot 'scripts\generate_dpll_build_id.py') --check
if ($LASTEXITCODE -ne 0) { throw 'generated build identity is stale' }
& $Gcc -std=c99 -Wall -Wextra -Werror $Include `
    (Join-Path $RepoRoot 'DPLL_Rewrite.sdk\DPLL_2COM\src\dpll_driver.c') `
    (Join-Path $RepoRoot 'verification\arm\dpll_driver_host_test.c') `
    -o $Exe
if ($LASTEXITCODE -ne 0) { throw "host GCC failed with exit code $LASTEXITCODE" }

$Output = & $Exe 2>&1
$ExitCode = $LASTEXITCODE
$Output | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $Log -Encoding ASCII
$Output
if ($ExitCode -ne 0) { throw "host driver test failed with exit code $ExitCode" }
$Text = Get-Content -LiteralPath $Log -Raw
if ($Text -notmatch 'PASS: dpll_driver_host_test') { throw 'missing host driver PASS marker' }
