<#
.SYNOPSIS
    Patch settings files for 8+ IDEs/terminals with UTF-8 config.
    Idempotent merge; preserves all other user settings.
    Supports JSON (VS Code family), YAML (Qoder), and Zed (JSON).
    PS 5.1 + 7+ compat.
#>

$ErrorActionPreference = 'Stop'

# Dot-source shared module
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$root\common.ps1"

$patched = 0

foreach ($ide in $IDEPaths) {
    $path  = $ide.Path
    $name  = $ide.Name
    $kind  = $ide.Kind

    if (-not (Test-Path $path)) {
        Write-Skip "${name}: not found ($path)"
        continue
    }

    # Skip Qoder for now (no settings to set; env vars are enough)
    if ($kind -eq 'yaml' -and $QoderSettings.Count -eq 0) {
        Write-Skip "${name}: yaml config present, but Qoder inherits env vars (Layer 1)"
        Write-Skip "  → env vars already set globally, no yaml patch needed"
        continue
    }

    # Determine desired settings
    $desired = if ($kind -eq 'zed') { $ZedSettings } else { $VSCodeSettings }

    try {
        if ($kind -eq 'yaml') {
            $result = Merge-SettingsYaml -Path $path -Desired $desired
        } else {
            $result = Merge-SettingsJson -Path $path -Desired $desired
        }

        if (-not $result.Changed) {
            Write-Skip "${name}: already has utf8-fix keys, skipped"
            continue
        }

        if ($kind -eq 'yaml') {
            Write-FileUtf8 -Path $path -Content $result.Content
        } else {
            Write-SettingsJson -Path $path -Hashtable $result.Json
        }

        Write-Ok "${name}: patched ($kind) → $path"
        $patched++
    } catch {
        Write-Warn "${name}: failed — $($_.Exception.Message)"
    }
}

# ─── Windows Terminal detection ──────────────────────────────────────────
$wtSettingsPattern = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json"
$wtSettings = Get-ChildItem -Path $wtSettingsPattern -ErrorAction SilentlyContinue | Select-Object -First 1
if ($wtSettings) {
    Write-Ok "Windows Terminal detected: $($wtSettings.FullName)"
    Write-Skip "  (Windows Terminal inherits user env vars; no patch needed)"
} else {
    Write-Skip "Windows Terminal (packaged): not found"
}

# ─── JetBrains note ──────────────────────────────────────────────────────
Write-Skip "JetBrains IDEs: inherit user env vars (Layer 1). No settings.json patch needed."
Write-Skip "  If garbled: File → Settings → Editor → File Encodings → UTF-8"

# ─── Lingma / Comate / Continue (VSCode-based) ───────────────────────────
Write-Skip "通义灵码 / 文心快码 / Continue: 作为 VS Code 插件运行,继承主 IDE 配置"

if ($patched -eq 0) {
    Write-Warn "No IDE settings.json was patched."
    Write-Warn "If you use an IDE with a terminal, open it once so the file is created, then re-run this script."
} else {
    Write-Ok "Patched $patched IDE settings file(s)."
}