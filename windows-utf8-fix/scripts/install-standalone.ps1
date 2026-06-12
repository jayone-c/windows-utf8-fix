<#
.SYNOPSIS
    Standalone UTF-8 fix script. No external dependencies.
    Copy this file to the user's desktop and run it from PowerShell.

.DESCRIPTION
    This is Plan B — the user runs this script manually outside the AI sandbox.
    It performs the same 6-layer fix as install.ps1 but is fully self-contained.
    Includes inline IDE patching (no dependency on ide-patch.ps1).

.EXAMPLE
    # Copy to desktop, then:
    cd $env:USERPROFILE\Desktop
    .\fix-utf8.ps1
#>

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "Windows UTF-8 Fix — Installing..."

# Dot-source shared module
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$root\common.ps1"

Write-Host @"
====================================================
  Windows UTF-8 Fix — Standalone Installer
  Plan B: 手动运行模式
====================================================
  此脚本将:
  1. 设置 $($EnvDefaults.Count) 个用户级环境变量
  2. 配置 PowerShell profile (UTF-8)
  3. 配置 CMD 自动 chcp 65001
  4. 配置 Git 编码
  5. 补丁 IDE/终端 settings.json
  6. 检测系统级 UTF-8 Beta 设置

  按 Enter 继续, Ctrl+C 取消...
"@ -ForegroundColor Cyan
Read-Host | Out-Null

# ─── 0. Environment detection ────────────────────────────────────────────
Write-Step "检测环境"

$psVer = $PSVersionTable.PSVersion
$isPS7 = $psVer.Major -ge 7
Write-Ok "PowerShell $($psVer.Major).$($psVer.Minor) ($($PSVersionTable.PSEdition))"

# System Beta UTF-8
$betaUtf8 = try {
    $acp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name 'ACP' -ErrorAction SilentlyContinue).ACP
    if ($acp -eq '65001') { 'enabled' } else { 'not enabled' }
} catch { 'unknown' }
Write-Ok "System Beta UTF-8: $betaUtf8"

if (-not $isPS7) {
    Write-Warn "建议安装 PowerShell 7 以获得最佳体验:"
    Write-Warn "  winget install --id Microsoft.PowerShell --source winget"
    Write-Warn "  或下载: https://github.com/PowerShell/PowerShell/releases"
}

# ─── 1. User-level environment variables ─────────────────────────────────
Write-Step "Layer 1/6: 用户环境变量"

$backupRegPath = 'HKCU:\Software\windows-utf8-fix'
if (-not (Test-Path $backupRegPath)) {
    New-Item -Path $backupRegPath -Force | Out-Null
}

$envVars = $EnvDefaults
foreach ($k in $envVars.Keys) {
    $old = [Environment]::GetEnvironmentVariable($k, 'User')
    if ($old) {
        Set-ItemProperty -Path $backupRegPath -Name "env_$k" -Value $old -Type String -ErrorAction SilentlyContinue
    }
    [Environment]::SetEnvironmentVariable($k, $envVars[$k], 'User')
    Write-Ok "[User] $k = $($envVars[$k])"
    Set-Item -Path "env:$k" -Value $envVars[$k]
}

# ─── 2. PowerShell profile ───────────────────────────────────────────────
Write-Step "Layer 2/6: PowerShell profile"

$profilePath = $PROFILE
$profileDir  = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Ok "Created directory: $profileDir"
}

$existing = if (Test-Path $profilePath) {
    Backup-File $profilePath
    Get-Content $profilePath -Raw -Encoding UTF8
} else { '' }

$body = $PROFILE_BODY

if ($existing -match [regex]::Escape($BLOCK_BEGIN)) {
    Write-Ok "Profile already has utf8-fix block, updating"
    $newContent = [regex]::Replace(
        $existing,
        [regex]::Escape($BLOCK_BEGIN) + '.*?' + [regex]::Escape($BLOCK_END),
        ($body -replace '(?m)^\$', '$$').TrimStart("`n")
    )
    [System.IO.File]::WriteAllText($profilePath, $newContent, $script:UTF8NoBOM)
} else {
    Write-Ok "Appending utf8-fix block to profile"
    Add-Content -Path $profilePath -Value $body -Encoding UTF8
}

# ─── 3. CMD autorun ──────────────────────────────────────────────────────
Write-Step "Layer 3/6: CMD 自动编码"

$cmdRegPath = 'HKCU:\Software\Microsoft\Command Processor'
$cmdRegName = 'AutoRun'
$cmdRegValue = 'chcp 65001 > nul'

if (-not (Test-Path $cmdRegPath)) { New-Item -Path $cmdRegPath -Force | Out-Null }
$currentCmd = (Get-ItemProperty -Path $cmdRegPath -Name $cmdRegName -ErrorAction SilentlyContinue).$cmdRegName
if ($currentCmd -eq $cmdRegValue) {
    Write-Ok "CMD AutoRun already set"
} else {
    Set-ItemProperty -Path $cmdRegPath -Name $cmdRegName -Value $cmdRegValue -Type String
    Write-Ok "CMD AutoRun set to: chcp 65001"
}

# ─── 4. Git config ───────────────────────────────────────────────────────
Write-Step "Layer 4/6: Git 编码"

if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitConfig = $GitDefaults
    foreach ($k in $gitConfig.Keys) {
        git config --global $k $gitConfig[$k] 2>$null
        Write-Ok "git config --global $k = $($gitConfig[$k])"
    }
} else {
    Write-Warn "Git 未安装,跳过"
}

# ─── 5. IDE / Terminal settings (inline, no dependency) ──────────────────
Write-Step "Layer 5/6: IDE & Terminal settings.json"

$idePatched = 0
foreach ($ide in $IDEPaths) {
    $path = $ide.Path
    $name = $ide.Name

    if (-not (Test-Path $path)) {
        Write-Skip "${name}: not found"
        continue
    }

    $desired = if ($name -eq 'Zed') { $ZedSettings } else { $VSCodeSettings }

    try {
        $result = Merge-SettingsJson -Path $path -Desired $desired
        if (-not $result.Changed) {
            Write-Skip "${name}: already configured"
            continue
        }
        Write-SettingsJson -Path $path -Hashtable $result.Json
        Write-Ok "${name}: patched"
        $idePatched++
    } catch {
        Write-Warn "${name}: failed — $($_.Exception.Message)"
    }
}

if ($idePatched -eq 0) {
    Write-Warn "No IDE settings.json found. Open your IDE once, then re-run."
}

# ─── 6. System reminder ──────────────────────────────────────────────────
Write-Step "Layer 6/6: 系统级设置"

if ($betaUtf8 -eq 'enabled') {
    Write-Ok "System Beta UTF-8 已启用,无需手动操作!"
} else {
    Write-Host @"

  ⚠ 建议手动完成:

  设置 → 时间和语言 → 区域 → 其他日期/时间/区域设置
  → 区域 → 管理 → 更改系统区域设置
  → 勾选 "Beta: 使用 Unicode UTF-8 提供全球语言支持"
  → 重启电脑

"@ -ForegroundColor Yellow
}

# ─── Verify ───────────────────────────────────────────────────────────────
Write-Step "验证"

$ok = 0; $total = 0
$total++; if ([Console]::OutputEncoding.WebName -eq 'utf-8') { $ok++; Write-Host "  ✓ OutputEncoding = utf-8" -ForegroundColor Green } else { Write-Host "  ✗ OutputEncoding = $([Console]::OutputEncoding.WebName)" -ForegroundColor Red }
$total++; $chcpNum = (chcp) -replace '.*?(\d+).*', '$1'; if ($chcpNum -eq '65001') { $ok++; Write-Host "  ✓ chcp = 65001" -ForegroundColor Green } else { Write-Host "  ✗ chcp = $chcpNum" -ForegroundColor Red }
$total++; if ([Environment]::GetEnvironmentVariable('PYTHONIOENCODING','User') -eq 'utf-8') { $ok++; Write-Host "  ✓ PYTHONIOENCODING = utf-8" -ForegroundColor Green } else { Write-Host "  ✗ PYTHONIOENCODING 未设置" -ForegroundColor Red }

Write-Host "`n====================================================" -ForegroundColor Green
Write-Host "  完成! $ok / $total 项通过" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  请关闭所有终端窗口和 IDE,重新打开后生效。" -ForegroundColor White
Write-Host ""
Write-Host "  Press Enter to exit..." -ForegroundColor DarkGray
Read-Host | Out-Null