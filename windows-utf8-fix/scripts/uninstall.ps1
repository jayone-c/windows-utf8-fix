<#
.SYNOPSIS
    Remove all changes made by install.ps1. Restores original env var values.

.DESCRIPTION
    1. Remove the utf8-fix block from PowerShell $PROFILE.
    2. Restore user-level environment variables to original values (from registry backup).
    3. Remove CMD autorun registry key.
    4. Unset Git global config.
    5. (IDE settings.json is NOT reverted — the settings are safe defaults.)

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
#>

$ErrorActionPreference = 'Stop'

# Dot-source shared module
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$root\common.ps1"

# ─── 1. PowerShell profile ───────────────────────────────────────────────
Write-Step "Layer 1/4: Remove PowerShell profile block"

$profilePath = $PROFILE
if (Test-Path $profilePath) {
    $existing = Get-Content $profilePath -Raw -Encoding UTF8
    if ($existing -match [regex]::Escape($BLOCK_BEGIN)) {
        Backup-File $profilePath
        $newContent = [regex]::Replace(
            $existing,
            "`n?" + [regex]::Escape($BLOCK_BEGIN) + '.*?' + [regex]::Escape($BLOCK_END)
        )
        $newContent = $newContent -replace '\n{3,}', "`n`n"  # collapse extra blank lines
        [System.IO.File]::WriteAllText($profilePath, $newContent.TrimEnd("`n") + "`n", $script:UTF8NoBOM)
        Write-Ok "Removed utf8-fix block from $profilePath"
    } else {
        Write-Skip "No utf8-fix block found in profile"
    }
} else {
    Write-Skip "Profile not found ($profilePath)"
}

# ─── 2. Restore environment variables (with original values) ─────────────
Write-Step "Layer 2/4: Restore user environment variables"

$backupRegPath = 'HKCU:\Software\windows-utf8-fix'

foreach ($k in $EnvDefaults.Keys) {
    # Try to restore original value from backup
    $original = try {
        (Get-ItemProperty -Path $backupRegPath -Name "env_$k" -ErrorAction SilentlyContinue)."env_$k"
    } catch { $null }

    $current = [Environment]::GetEnvironmentVariable($k, 'User')

    if ($original) {
        # Restore original value
        [Environment]::SetEnvironmentVariable($k, $original, 'User')
        Write-Ok "[User] $k restored to: $original (was: $current)"
    } else {
        # No original backup — remove entirely
        if ($current) {
            [Environment]::SetEnvironmentVariable($k, $null, 'User')
            Write-Ok "[User] $k removed (was: $current)"
        } else {
            Write-Skip "[User] $k: already unset"
        }
    }
}

# Clean up backup registry key
if (Test-Path $backupRegPath) {
    Remove-Item -Path $backupRegPath -Force -Recurse -ErrorAction SilentlyContinue
    Write-Ok "Cleaned up backup registry key"
}

# ─── 3. CMD autorun ──────────────────────────────────────────────────────
Write-Step "Layer 3/4: Remove CMD autorun"

$cmdRegPath = 'HKCU:\Software\Microsoft\Command Processor'
$cmdRegName = 'AutoRun'
if (Test-Path $cmdRegPath) {
    $current = (Get-ItemProperty -Path $cmdRegPath -Name $cmdRegName -ErrorAction SilentlyContinue).$cmdRegName
    if ($current) {
        Remove-ItemProperty -Path $cmdRegPath -Name $cmdRegName -ErrorAction SilentlyContinue
        Write-Ok "Removed CMD AutoRun (was: $current)"
    } else {
        Write-Skip "CMD AutoRun: already unset"
    }
}

# ─── 4. Git config ───────────────────────────────────────────────────────
Write-Step "Layer 4/4: Unset Git config"

$gitAvailable = Get-Command git -ErrorAction SilentlyContinue
if ($gitAvailable) {
    foreach ($k in $GitDefaults.Keys) {
        $current = git config --global --get $k 2>$null
        if ($current) {
            git config --global --unset $k 2>$null
            Write-Ok "git config --global --unset $k (was: $current)"
        } else {
            Write-Skip "git config --global $k: already unset"
        }
    }
} else {
    Write-Warn "Git 未安装或不在 PATH 中,跳过 Git 清理"
}

# ─── Summary ──────────────────────────────────────────────────────────────
Write-Host "`n" -NoNewline
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  卸载完成! 原始环境变量已恢复。" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  IDE settings.json 未还原 (保留的 UTF-8 设置是安全的默认值)" -ForegroundColor Yellow
Write-Host "  请关闭所有终端窗口并重新打开" -ForegroundColor White
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""