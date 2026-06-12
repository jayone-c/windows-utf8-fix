<#
.SYNOPSIS
    Post-install acceptance test. Exit code 0 = all good.

.DESCRIPTION
    Reloads profile, checks Console encoding, chcp, env vars, CMD autorun,
    Git config, and runs a live echo test. Designed for CI-style pass/fail.

.EXAMPLE
    pwsh -NoProfile -File verify.ps1
#>

$ErrorActionPreference = 'Continue'

# Dot-source shared module
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$root\common.ps1"

# Reload profile in current session
if (Test-Path $PROFILE) { . $PROFILE }

$fails = 0
$total = 0

function Assert-Equal([string]$label, [string]$expected, $actual) {
    $script:total++
    if ("$expected" -eq "$actual") {
        Write-Host "  ✓ $label" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $label : expected '$expected', got '$actual'" -ForegroundColor Red
        $script:fails++
    }
}

Write-Host "=== Post-install verification ===" -ForegroundColor Cyan

Assert-Equal 'Console.OutputEncoding' 'utf-8' ([Console]::OutputEncoding.WebName)
Assert-Equal '$OutputEncoding'        'utf-8' ($OutputEncoding.WebName)

$chcpNum = (chcp) -replace '.*?(\d+).*', '$1'
Assert-Equal 'chcp'                  '65001' $chcpNum

# User env vars (from shared defaults)
foreach ($k in $EnvDefaults.Keys) {
    Assert-Equal "[User] $k" $EnvDefaults[$k] ([Environment]::GetEnvironmentVariable($k, 'User'))
}

# CMD autorun
$cmdAutoRun = (Get-ItemProperty 'HKCU:\Software\Microsoft\Command Processor' -Name 'AutoRun' -ErrorAction SilentlyContinue).AutoRun
Assert-Equal 'CMD AutoRun' 'chcp 65001 > nul' $cmdAutoRun

# Git
foreach ($k in $GitDefaults.Keys) {
    Assert-Equal "git $k" $GitDefaults[$k] (git config --global --get $k 2>$null)
}

# Live echo
$echo = Write-Output "中文测试 ✓"
Write-Host "  echo test: $echo" -ForegroundColor Green

if ($fails -eq 0) {
    Write-Host "`n✅ All checks passed ($total/$total). UTF-8 environment is healthy." -ForegroundColor Green
    exit 0
} else {
    $pass = $total - $fails
    Write-Host "`n✗ $pass/$total passed, $fails failed." -ForegroundColor Red
    Write-Host "  Try:" -ForegroundColor Yellow
    Write-Host "    1. Close and reopen all PowerShell windows and IDEs" -ForegroundColor Yellow
    Write-Host "    2. Re-run: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\install.ps1" -ForegroundColor Yellow
    Write-Host "    3. Or manually: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\install-standalone.ps1" -ForegroundColor Yellow
    exit 1
}