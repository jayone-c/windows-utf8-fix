<#
.SYNOPSIS
    One-line installer for windows-utf8-fix.
    Usage: iwr -useb https://raw.githubusercontent.com/jayone-c/windows-utf8-fix/main/install.ps1 | iex
#>

$ErrorActionPreference = 'Stop'

$repoUrl = 'https://github.com/jayone-c/windows-utf8-fix.git'
$targetDir = Join-Path $env:USERPROFILE 'windows-utf8-fix'

Write-Host ""
Write-Host "==> windows-utf8-fix installer" -ForegroundColor Cyan
Write-Host "    Target: $targetDir" -ForegroundColor Gray
Write-Host ""

# 1. Clone or update
if (Test-Path $targetDir) {
    Write-Host "[1/2] Updating existing installation..." -ForegroundColor Yellow
    Push-Location $targetDir
    try {
        git pull --rebase --autostash 2>&1 | Out-Null
    } catch {
        Write-Warning "git pull failed: $($_.Exception.Message)"
        Write-Warning "Will try to use existing files."
    }
    Pop-Location
} else {
    Write-Host "[1/2] Cloning repository..." -ForegroundColor Yellow
    git clone $repoUrl $targetDir
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed. Make sure Git is installed: https://git-scm.com"
    }
}

# 2. Run installer
Write-Host "[2/2] Running installer..." -ForegroundColor Yellow
& pwsh -NoProfile -ExecutionPolicy Bypass -File "$targetDir\windows-utf8-fix\scripts\install.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Warning ""
    Write-Warning "Installer exited with code $LASTEXITCODE"
    Write-Warning "Try running the standalone version:"
    Write-Warning "  pwsh -NoProfile -ExecutionPolicy Bypass -File \"$targetDir\windows-utf8-fix\scripts\install-standalone.ps1\""
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "==> Done! Open a NEW PowerShell window and run verify.ps1 to confirm:" -ForegroundColor Green
Write-Host "    pwsh -NoProfile -File \"$targetDir\windows-utf8-fix\scripts\verify.ps1\"" -ForegroundColor Cyan
Write-Host ""
