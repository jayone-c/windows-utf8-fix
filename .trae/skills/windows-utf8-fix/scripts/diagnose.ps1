<#
.SYNOPSIS
    Diagnose Windows terminal encoding for AI tools.

.DESCRIPTION
    Read-only probe of: PowerShell version, sandbox status, system Beta UTF-8,
    console encoding, code page, CMD autorun, Git i18n, Python/Node.js encoding,
    and a live Chinese echo test. Produces a color-coded report.

.EXAMPLE
    pwsh -NoProfile -File diagnose.ps1
#>

$ErrorActionPreference = 'Continue'

# Dot-source shared module
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$root\common.ps1"

function Test-Item([string]$label, [string]$expected, $actual) {
    $ok = "$expected" -eq "$actual"
    $color = if ($ok) { 'Green' } else { 'Yellow' }
    $icon  = if ($ok) { '✓' } else { '⚠' }
    Write-Host ("  {0} {1,-40} = {2}" -f $icon, $label, $actual) -ForegroundColor $color
    return $ok
}

$results = @()

# Layer 0: Environment
Write-Section "运行环境"
$psVer = $PSVersionTable.PSVersion
$psEditionName = if ($PSVersionTable.PSEdition -eq 'Core') { 'Core' } else { 'Desktop' }
$psLabel = "PowerShell $($psVer.Major).$($psVer.Minor) ($psEditionName)"
$results += Test-Item "PowerShell 版本" "7" $psVer.Major.ToString()

# Sandbox detection
$sandboxEnv = $env:TRAE_SANDBOX -or $env:CLAUDE_CODE_SANDBOX -or $env:CODEX_SANDBOX
$inSandbox = $sandboxEnv
$sandboxStatus = if ($inSandbox) { 'detected' } else { 'native' }
$results += Test-Item "终端沙盒" "native" $sandboxStatus

# System Beta UTF-8
$betaUtf8 = try {
    $acp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name 'ACP' -ErrorAction SilentlyContinue).ACP
    if ($acp -eq '65001') { 'enabled' } else { 'not enabled' }
} catch { 'unknown' }
$results += Test-Item "系统 UTF-8 Beta" "enabled" $betaUtf8

# Layer 1: PowerShell console
Write-Section "PowerShell 终端编码"
$results += Test-Item "Console.OutputEncoding"  "utf-8" ([Console]::OutputEncoding.WebName)
$results += Test-Item "Console.InputEncoding"   "utf-8" ([Console]::InputEncoding.WebName)
$results += Test-Item '$OutputEncoding'         "utf-8" ($OutputEncoding.WebName)
$chcp = (chcp) -replace '[\s\r\n]+', ' ' -replace '.*?(\d+).*', '$1'
$results += Test-Item "chcp"                   "65001" $chcp

# Layer 2: Environment variables (check User level, from shared defaults)
Write-Section "环境变量 (用户级)"
foreach ($k in $EnvDefaults.Keys) {
    $v = [Environment]::GetEnvironmentVariable($k, 'User')
    if (-not $v) { $v = (Get-Item "env:$k" -ErrorAction SilentlyContinue).Value }
    if (-not $v) { $v = '(未设置)' }
    $results += Test-Item $k $EnvDefaults[$k] $v
}

# Layer 3: CMD autorun
Write-Section "CMD 编码"
$cmdAutoRun = (Get-ItemProperty 'HKCU:\Software\Microsoft\Command Processor' -Name 'AutoRun' -ErrorAction SilentlyContinue).AutoRun
$cmdAutoRunLabel = if ($cmdAutoRun) { $cmdAutoRun } else { '(未设置)' }
$results += Test-Item "CMD AutoRun" "chcp 65001 > nul" $cmdAutoRunLabel

# Layer 4: Git (batch query — parse once)
Write-Section "Git 编码配置"
$gitList = git config --global --list 2>$null
$gitHash = @{}
if ($gitList) {
    $gitList -split "`n" | ForEach-Object {
        $parts = $_ -split '=', 2
        if ($parts.Count -eq 2) { $gitHash[$parts[0]] = $parts[1] }
    }
}
foreach ($k in $GitDefaults.Keys) {
    $v = $gitHash[$k]
    if (-not $v) { $v = '(未设置)' }
    $results += Test-Item $k $GitDefaults[$k] $v
}

# Layer 5: Python (deduplicate: skip `py` if same exe as `python`)
Write-Section "Python 编码"
$pySeen = @{}
foreach ($py in @('python', 'py')) {
    $exe = Get-Command $py -ErrorAction SilentlyContinue
    if ($exe) {
        $exePath = $exe.Source
        if ($pySeen.ContainsKey($exePath)) { continue }
        $pySeen[$exePath] = $true
        $encoding = & $py -c "import sys; print(sys.stdout.encoding)" 2>$null
        if (-not $encoding) { $encoding = '(Python 启动失败)' }
        $results += Test-Item "Python($py).stdout.encoding" "utf-8" $encoding
    }
}

# Layer 6: Node.js
Write-Section "Node.js 编码"
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $nodeEnc = (& node -e "process.stdout.write(process.stdout.encoding||'buffer')" 2>$null) -replace '\s+', ''
    if ($nodeEnc -eq 'buffer') {
        Write-Host "  ✓ Node.js stdout.encoding = buffer (OK — sandbox pipe, not real TTY)" -ForegroundColor Green
        $results += $true
    } else {
        $results += Test-Item "Node.js stdout.encoding" "utf-8" $nodeEnc
    }
}

# Layer 7: Live Chinese echo test
Write-Section "实况测试"
try {
    $echo = Write-Output "中文测试 ✓"
    Write-Host "  ✓ echo 测试通过: $echo" -ForegroundColor Green
    $results += $true
} catch {
    Write-Host "  ⚠ echo 测试失败: $($_.Exception.Message)" -ForegroundColor Yellow
    $results += $false
}

# Summary
Write-Host "`n=== 总结 ===" -ForegroundColor Cyan
$pass = ($results | Where-Object { $_ -eq $true }).Count
$total = $results.Count

if ($pass -eq $total) {
    Write-Host "  ✓ 全部通过 ($pass/$total) — 你的环境已正确配置 UTF-8" -ForegroundColor Green
    exit 0
} else {
    $fail = $total - $pass
    Write-Host "  ⚠ 通过 $pass / $total ($fail 项未通过)" -ForegroundColor Yellow

    if ($inSandbox) {
        Write-Host "`n  ℹ 检测到沙盒环境。如果修复后仍乱码,请尝试 Plan B:" -ForegroundColor Cyan
        Write-Host "    将 scripts\install-standalone.ps1 复制到桌面,手动右键运行。" -ForegroundColor Cyan
    }

    if ($psVer.Major -lt 7) {
        Write-Host "`n  ℹ PowerShell 5.1 部分功能受限,推荐安装 PowerShell 7:" -ForegroundColor Cyan
        Write-Host "    winget install --id Microsoft.PowerShell --source winget" -ForegroundColor Cyan
        Write-Host "    或: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Cyan
    }

    if ($cmdAutoRun -ne 'chcp 65001 > nul') {
        Write-Host "`n  ℹ CMD 编码未配置,运行 install.ps1 可自动修复" -ForegroundColor Cyan
    }

    Write-Host "`n  修复命令: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\install.ps1" -ForegroundColor White
    exit 1
}