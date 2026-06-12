<#
.SYNOPSIS
    Standalone Git UTF-8 config helper.

.DESCRIPTION
    Sets core.quotepath=false and i18n.*=utf-8 globally.
    Safe to re-run.

.EXAMPLE
    .\fix-git.ps1
#>

$ErrorActionPreference = 'Stop'

# Dot-source shared module
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$root\common.ps1"

$gitAvailable = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitAvailable) {
    Write-Err "Git 未安装,请先安装 Git: https://git-scm.com/"
    exit 1
}

Write-Host "=== Git UTF-8 编码修复 ===" -ForegroundColor Cyan

foreach ($k in $GitDefaults.Keys) {
    git config --global $k $GitDefaults[$k] 2>$null
    Write-Ok "git config --global $k = $($GitDefaults[$k])"
}

Write-Host "`n验证:" -ForegroundColor Cyan
git config --global --list | Select-String 'encoding|quotepath'

Write-Host "`n完成! Git 已配置为 UTF-8." -ForegroundColor Green