<#
.SYNOPSIS
    Apply the 6-layer UTF-8 fix for Windows AI terminals. Idempotent.

.DESCRIPTION
    0. Detect PowerShell version, sandbox status, system Beta UTF-8 state.
    1. Set user-level environment variables (backup existing values in registry).
    2. Create / merge PowerShell $PROFILE with UTF-8 block (with backup).
    3. Set CMD autorun registry key to chcp 65001.
    4. Set Git global i18n + quotepath config.
    5. Patch 8+ IDE/terminal settings.json files (with error isolation).
    6. Print reminder for system-level "Beta UTF-8" toggle + restart.

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File install.ps1
#>

$ErrorActionPreference = 'Stop'

# Dot-source shared module (safe even when $PSScriptRoot is empty)
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$root\common.ps1"

# ─── 0. Environment detection ────────────────────────────────────────────
Write-Step "Layer 0/6: Environment detection"

$psVer = $PSVersionTable.PSVersion
$isPS7 = $psVer.Major -ge 7
$psEditionName = if ($PSVersionTable.PSEdition -eq 'Core') { 'Core' } else { 'Desktop' }
$psLabel = "PowerShell $($psVer.Major).$($psVer.Minor) ($psEditionName)"

# Detect sandbox
$isSandbox = ($env:TRAE_SANDBOX -or $env:CLAUDE_CODE_SANDBOX -or $env:CODEX_SANDBOX -or $false)
$sandboxHint = if ($isSandbox) { "detected" } else { "not detected (native terminal)" }

Write-Ok "$psLabel — sandbox: $sandboxHint"

# Detect system Beta UTF-8
$betaUtf8 = try {
    $acp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name 'ACP' -ErrorAction SilentlyContinue).ACP
    if ($acp -eq '65001') { 'enabled' } else { 'not enabled' }
} catch { 'unknown' }
Write-Ok "System Beta UTF-8: $betaUtf8"

if (-not $isPS7) {
    Write-Warn "PowerShell 5.1 部分功能受限,推荐安装 PowerShell 7:"
    Write-Warn "  winget install --id Microsoft.PowerShell --source winget"
    Write-Warn "  或下载: https://github.com/PowerShell/PowerShell/releases"
    Write-Warn "  (用户级环境变量和 Git 配置不受影响,仍会生效)"
}

# ─── 1. User-level environment variables ─────────────────────────────────
Write-Step "Layer 1/6: User environment variables"

# Backup original values to registry (for uninstall.ps1 restoration)
$backupRegPath = 'HKCU:\Software\windows-utf8-fix'
if (-not (Test-Path $backupRegPath)) {
    New-Item -Path $backupRegPath -Force | Out-Null
}

$envVars = $EnvDefaults
foreach ($k in $envVars.Keys) {
    $old = [Environment]::GetEnvironmentVariable($k, 'User')
    if ($old) {
        # Save original value for uninstall restoration
        Set-ItemProperty -Path $backupRegPath -Name "env_$k" -Value $old -Type String -ErrorAction SilentlyContinue
    }
    [Environment]::SetEnvironmentVariable($k, $envVars[$k], 'User')
    $new = [Environment]::GetEnvironmentVariable($k, 'User')
    if ($old -eq $new) {
        Write-Ok "[User] $k = $new (already set)"
    } else {
        Write-Ok "[User] $k = $new (was: $old)"
    }
}

# Also set in current process so the rest of this script benefits
foreach ($k in $envVars.Keys) {
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
    # Create backup before modification
    Backup-File $profilePath
    Get-Content $profilePath -Raw -Encoding UTF8
} else { '' }

$body = $PROFILE_BODY

if ($existing -match [regex]::Escape($BLOCK_BEGIN)) {
    Write-Ok "Profile already contains utf8-fix block, updating in place"
    $existing = [regex]::Replace(
        $existing,
        [regex]::Escape($BLOCK_BEGIN) + '.*?' + [regex]::Escape($BLOCK_END),
        ($body -replace '(?m)^\$', '$$').TrimStart("`n")
    )
    [System.IO.File]::WriteAllText($profilePath, $existing, $script:UTF8NoBOM)
} else {
    Write-Ok "Appending utf8-fix block to profile: $profilePath"
    Add-Content -Path $profilePath -Value $body -Encoding UTF8
}

if (-not $isPS7) {
    Write-Warn "PS 5.1: 请在启动后运行 '. $PROFILE' 或重启终端来加载 profile"
    Write-Warn "PS 5.1: 如果 [Console]::OutputEncoding 仍为 gb2312,请安装 PowerShell 7"
    Write-Warn "  下载: https://github.com/PowerShell/PowerShell/releases"
}

# ─── 3. CMD autorun (registry) ───────────────────────────────────────────
Write-Step "Layer 3/6: CMD autorun (chcp 65001)"

$cmdRegPath = 'HKCU:\Software\Microsoft\Command Processor'
$cmdRegName = 'AutoRun'
$cmdRegValue = 'chcp 65001 > nul'

if (-not (Test-Path $cmdRegPath)) {
    New-Item -Path $cmdRegPath -Force | Out-Null
}
$currentCmd = (Get-ItemProperty -Path $cmdRegPath -Name $cmdRegName -ErrorAction SilentlyContinue).$cmdRegName
if ($currentCmd -eq $cmdRegValue) {
    Write-Ok "CMD AutoRun already set to: chcp 65001"
} else {
    Set-ItemProperty -Path $cmdRegPath -Name $cmdRegName -Value $cmdRegValue -Type String
    Write-Ok "CMD AutoRun set to: chcp 65001 (was: $currentCmd)"
}

# ─── 4. Git config ───────────────────────────────────────────────────────
Write-Step "Layer 4/6: Git i18n"

$gitAvailable = Get-Command git -ErrorAction SilentlyContinue
if ($gitAvailable) {
    $gitConfig = $GitDefaults
    foreach ($k in $gitConfig.Keys) {
        git config --global $k $gitConfig[$k] 2>$null
        Write-Ok "git config --global $k = $($gitConfig[$k])"
    }
} else {
    Write-Warn "Git 未安装或不在 PATH 中,跳过 Git 配置"
}

# ─── 5. IDE settings.json patch (with error isolation) ──────────────────
Write-Step "Layer 5/6: IDE & Terminal settings.json"

try {
    & "$root\ide-patch.ps1"
} catch {
    Write-Warn "IDE 配置补丁失败: $($_.Exception.Message)"
    Write-Warn "这不影响核心 UTF-8 修复，可稍后重新运行安装脚本。"
}

# ─── 6. System reminder ──────────────────────────────────────────────────
Write-Step "Layer 6/6: System-level (manual)"

if ($betaUtf8 -eq 'enabled') {
    Write-Ok "System Beta UTF-8 已启用,无需手动操作!"
} else {
    Write-Host @"

  ⚠ 建议手动完成以下操作（可选但推荐）：

  1. 打开 设置 → 时间和语言 → 区域
  2. 点击 '其他日期、时间和区域设置' → '区域' → '管理' 选项卡
  3. 点击 '更改系统区域设置'
  4. 勾选 'Beta: 使用 Unicode UTF-8 提供全球语言支持'
  5. 重启电脑

  这是 Microsoft 官方的"治本"方案,完成后所有非 Unicode 程序默认 UTF-8。
"@ -ForegroundColor Yellow
}

# ─── Summary ──────────────────────────────────────────────────────────────
Write-Host "`n" -NoNewline
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  安装完成! 请执行以下操作:" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  1. 关闭所有 PowerShell 窗口和 IDE" -ForegroundColor White
Write-Host "  2. 重新打开终端" -ForegroundColor White
Write-Host "  3. 运行: pwsh -NoProfile -File scripts\verify.ps1" -ForegroundColor White
if (-not $isPS7) {
    Write-Host "  4. 建议安装 PowerShell 7:" -ForegroundColor Yellow
    Write-Host "     winget install --id Microsoft.PowerShell --source winget" -ForegroundColor Yellow
    Write-Host "     或: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
}
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""