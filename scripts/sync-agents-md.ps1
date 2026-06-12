<#
.SYNOPSIS
    Sync AGENTS.md to match CLAUDE.md (or vice versa).
    Use after editing one to keep the other in sync.

.PARAMETER Direction
    'both' (default) — sync AGENTS.md ← CLAUDE.md
    'reverse'        — sync CLAUDE.md ← AGENTS.md
#>

param(
    [ValidateSet('both', 'reverse')]
    [string]$Direction = 'both'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$claude = Join-Path $root 'CLAUDE.md'
$agents = Join-Path $root 'AGENTS.md'

if (-not (Test-Path $claude)) { throw "CLAUDE.md not found: $claude" }
if (-not (Test-Path $agents)) { throw "AGENTS.md not found: $agents" }

function Extract-Body {
    param([string]$Path, [string]$Marker)
    $text = Get-Content $Path -Raw -Encoding UTF8
    $pattern = "(?s)<!--\s*BEGIN:\s*auto-synced content with $Marker\s*-->.*?<!--\s*END:\s*auto-synced content with $Marker\s*-->"
    $m = [regex]::Match($text, $pattern)
    if (-not $m.Success) {
        throw "Auto-sync block not found in $Path. Was it edited manually?"
    }
    return $m.Value
}

$claudeBody = Extract-Body -Path $claude -Marker 'AGENTS.md'
$agentsBody = Extract-Body -Path $agents -Marker 'CLAUDE.md'

$today = Get-Date -Format 'yyyy-MM-dd'

if ($Direction -eq 'both') {
    # Replace AGENTS.md's body block with CLAUDE.md's body block
    $agentsContent = Get-Content $agents -Raw -Encoding UTF8
    $newAgents = [regex]::Replace(
        $agentsContent,
        "(?s)<!--\s*BEGIN:\s*auto-synced content with CLAUDE.md\s*-->.*?<!--\s*END:\s*auto-synced content with CLAUDE.md\s*-->",
        $claudeBody
    )
    [System.IO.File]::WriteAllText($agents, $newAgents, [System.Text.UTF8Encoding]::new($false))
    Write-Host "✓ AGENTS.md ← CLAUDE.md synced ($today)" -ForegroundColor Green
} else {
    # Replace CLAUDE.md's body block with AGENTS.md's body block
    $claudeContent = Get-Content $claude -Raw -Encoding UTF8
    $newClaude = [regex]::Replace(
        $claudeContent,
        "(?s)<!--\s*BEGIN:\s*auto-synced content with AGENTS.md\s*-->.*?<!--\s*END:\s*auto-synced content with AGENTS.md\s*-->",
        $agentsBody
    )
    [System.IO.File]::WriteAllText($claude, $newClaude, [System.Text.UTF8Encoding]::new($false))
    Write-Host "✓ CLAUDE.md ← AGENTS.md synced ($today)" -ForegroundColor Green
}
