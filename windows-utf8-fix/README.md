# windows-utf8-fix

> End-to-end GBK → UTF-8 fix for AI coding tools on Windows.
> Fixes mojibake in **Trae, Claude Code, Codex, Qoder, Cursor, VS Code, Windsurf, Zed** and more.

## Why this exists

AI tools (Trae, Claude Code, Codex, Qoder) running on Windows often output garbled Chinese characters like `ä¸­æ–‡` or `???`. Root cause: Windows non-Unicode subsystem defaults to GBK (code page 936), but AI tools emit UTF-8.

This wastes tokens — every garbled character costs you LLM budget.

## Quick start

### Plan A: AI runs it for you (recommended)

```powershell
# Diagnose
pwsh -NoProfile -File scripts\diagnose.ps1

# Apply fixes (idempotent)
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\install.ps1

# Verify
pwsh -NoProfile -File scripts\verify.ps1
```

Then **close and reopen all PowerShell windows and IDE instances**.

### Plan B: You run it manually (fallback)

If the AI's sandbox prevents writing:

1. Copy `scripts/install-standalone.ps1` to your desktop
2. Right-click → "Run with PowerShell"
3. Follow the prompts

### PowerShell 7 Download

If you don't have PowerShell 7:

| Method | Link / Command |
|---|---|
| **winget** (Win 11+) | `winget install --id Microsoft.PowerShell --source winget` |
| **GitHub MSI** | https://github.com/PowerShell/PowerShell/releases |
| **Microsoft Store** | https://apps.microsoft.com/detail/9mz1snwt0n5h |
| **Direct MSI** | https://aka.ms/powershell-release?tag=stable |

## What it does

| Layer | Action | PS 5.1 | PS 7 |
|---|---|---|---|
| 1. User env vars | `LC_ALL`, `LANG`, `PYTHONIOENCODING`, `PYTHONUTF8`, `JAVA_TOOL_OPTIONS`, `RUBYOPT` | ✅ | ✅ |
| 2. PowerShell profile | Force `[Console]::OutputEncoding = UTF8` (with backup) | ⚠️ | ✅ |
| 3. CMD autorun | Registry `chcp 65001` | ✅ | ✅ |
| 4. Git | `core.quotepath=false`, `i18n.*=utf-8` | ✅ | ✅ |
| 5. IDE + Terminal | Patch `settings.json` for 8+ editors | ✅ | ✅ |
| 6. System | Detect/recommend "Beta UTF-8" toggle | ✅ | ✅ |

## Supported IDEs

VS Code, VS Code Insiders, Trae CN, Cursor, Windsurf, Qoder, VSCodium, Zed, Windows Terminal, JetBrains (IntelliJ, PyCharm, WebStorm, GoLand), Aider, Continue.dev, GitHub Copilot CLI.

## Compatibility

| Platform | Status |
|---|---|
| Windows 10/11 + PowerShell 7+ | ✅ Full support |
| Windows 10/11 + PowerShell 5.1 | ⚠️ Partial (env vars + Git + CMD work; `[Console]::OutputEncoding` may not) |
| Windows Server 2019+ | ✅ Tested |
| macOS / Linux | ❌ Not needed |

## Uninstall

```powershell
pwsh -NoProfile -File scripts\uninstall.ps1
```

## Related

- [gkd2323c/charset-fix](https://github.com/gkd2323c/charset-fix) — POSIX-shell variant (Git Bash / MSYS2 / WSL)

## License

MIT