---
name: "windows-utf8-fix"
description: "Fixes GBK/UTF-8 mojibake (garbled Chinese text) in Windows AI terminals including Trae, Claude Code, Codex, Qoder, Cursor, and VS Code. Invoke when user reports Chinese garbled text, mojibake, encoding issues, sees □ or weird characters, or runs commands that show encoding mismatches on Windows. Triggers on phrases like '乱码', 'mojibake', 'GBK', 'UTF-8', 'chcp 65001', '中文乱码'."
allowed-tools: "Bash Read Write Edit Glob Grep"
metadata:
  tags: windows, encoding, utf-8, gbk, powershell, python, git, chinese, localization
  version: "1.3.0"
  author: "windows-utf8-fix contributors"
  license: "MIT"
  platforms: "windows"
---

# Windows UTF-8 Fix

End-to-end fix for Chinese mojibake in AI coding tools running on Windows. Unlike `charset-fix` (which targets POSIX shells like Git Bash), this skill targets the **PowerShell / Windows Terminal stack** that AI coding tools actually use.

## ⚠️ Critical: AI terminal sandbox awareness

AI coding tools (Trae, Claude Code, Codex, Qoder, Cursor) wrap terminal commands in a **sandbox** (e.g. `trae-sandbox 'command'`). This skill is designed to work **through the sandbox** — the scripts write to the real filesystem and registry because the sandbox runs as the user's identity.

**However**, if the sandbox is unusually restrictive or the user is on a different AI tool, always offer **Plan B**:

| Plan | Mechanism | When to use |
|---|---|---|
| **Plan A** | Run `install.ps1` through the sandbox (default) | Works on Trae, Claude Code, Codex with standard sandbox |
| **Plan B** | Generate a standalone script, user runs it manually outside the sandbox | Sandbox is blocked, or user prefers manual control |
| **Plan C** | Step-by-step manual commands | Air-gapped or minimal environment |

### How to detect sandbox issues

If after running `install.ps1` the user reports that `[Console]::OutputEncoding` is still `gb2312`, or env vars are missing, or the profile wasn't written — the sandbox is likely blocking writes. **Immediately fall back to Plan B**.

## When to use this skill

Invoke this skill when ANY of the following occur on Windows:

- Terminal shows `□□□`, `???`, `ä¸­æ–‡`, `ä¸­`, or other garbled characters
- `chcp` returns `936` (GBK) instead of `65001` (UTF-8)
- `[Console]::OutputEncoding.WebName` is `gb2312` / `cp936` / `gbk` instead of `utf-8`
- `python -c "print('中文')"` outputs `ä¸–æ–‡` or `???`
- `node -e "console.log('中文')"` outputs garbled text
- `git log` shows `\346\226\260\346` octal escapes
- User mentions 乱码, mojibake, GBK, UTF-8, encoding, 中文显示
- Fresh Windows install / new dev box needs UTF-8 baseline

## PowerShell version requirements

| PowerShell version | Default on | Support level | Notes |
|---|---|---|---|
| **PowerShell 7+** (`pwsh.exe`) | User-installed | ✅ Full — all features work | **Recommended.** The skill will guide installation if missing. |
| **PowerShell 5.1** (`powershell.exe`) | Windows 10/11 built-in | ⚠️ Partial — `[Console]::OutputEncoding` may be silently ignored | Still works for env vars, Git, IDE. Upgrade to 7 for best results. |
| **Windows PowerShell ISE** | Legacy | ❌ Not supported | ISE has its own encoding quirks. Use VS Code or Windows Terminal. |

### How to install PowerShell 7

Choose one method:

| Method | Command / Link | Best for |
|---|---|---|
| **winget** (Win 11+) | `winget install --id Microsoft.PowerShell --source winget` | Fastest, auto-updates |
| **GitHub releases** | https://github.com/PowerShell/PowerShell/releases | Download `.msi` for Windows 10, offline, enterprise |
| **Microsoft Store** | https://apps.microsoft.com/detail/9mz1snwt0n5h | Simple GUI install |
| **Direct MSI** | https://aka.ms/powershell-release?tag=stable | Stable channel, sysadmin deployment |

On Windows 10 without winget, use the GitHub MSI download. If the user is on a locked-down corporate machine, use the MSI installer.

## What this skill does

Performs a 6-layer fix in priority order:

| Layer | Action | Reversible | PS 5.1 | PS 7 |
|---|---|---|---|---|
| 1. User env vars | `LC_ALL`, `LANG`, `PYTHONIOENCODING`, `PYTHONUTF8`, `JAVA_TOOL_OPTIONS`, `RUBYOPT` | Yes (backup + restore) | ✅ | ✅ |
| 2. PowerShell profile | Create/merge `$PROFILE` with UTF-8 block | Yes (delete block + backup) | ⚠️ | ✅ |
| 3. CMD autorun | Registry `Command Processor\AutoRun` = `chcp 65001` | Yes (delete key) | ✅ | ✅ |
| 4. Git | `git config --global` for i18n + quotepath | Yes (unset) | ✅ | ✅ |
| 5. IDE + Terminal | Patch `settings.json` for 8+ IDEs/terminals | Yes (undo) | ✅ | ✅ |
| 6. System | Detect/recommend "Beta: Use Unicode UTF-8" toggle | Yes (UI) | ✅ | ✅ |

## Workflow

### Plan A: Run through AI sandbox (try first)

#### Step 1: Diagnose

```powershell
pwsh -NoProfile -File ".trae/skills/windows-utf8-fix/scripts/diagnose.ps1"
```

If `pwsh` is not found, fall back to:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".trae/skills/windows-utf8-fix/scripts/diagnose.ps1"
```

Expected report:
- `PowerShell 版本: 7.x` ✅
- `系统 UTF-8 Beta: enabled` ✅
- `Console.OutputEncoding : utf-8` ✅
- `chcp : 65001` ✅
- `Git i18n.commitencoding : utf-8` ✅
- `Python stdout.encoding : utf-8` ✅
- `Node.js encoding : utf-8` ✅
- `Test echo: 中文测试 ✓` ✅

#### Step 2: Apply fixes

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ".trae/skills/windows-utf8-fix/scripts/install.ps1"
```

The installer is idempotent — safe to re-run. It will:
1. Set 8 user-level environment variables (LC_ALL, LANG, PYTHONIOENCODING, PYTHONUTF8, JAVA_TOOL_OPTIONS, NODE_OPTIONS, GOFLAGS, RUBYOPT)
2. Create `$PROFILE` if missing, append UTF-8 block (detects existing block, won't duplicate)
3. Set CMD autorun to `chcp 65001` (registry, user-level)
4. Set Git global config (core.quotepath, i18n.*, gui.encoding)
5. Patch `settings.json` of any installed IDE (12+ editors supported)
6. Print remaining manual step (system-level UTF-8 toggle + restart)

#### Step 3: Verify

Close ALL PowerShell windows and IDE instances, reopen, then:

```powershell
pwsh -NoProfile -File ".trae/skills/windows-utf8-fix/scripts/verify.ps1"
```

### Plan B: Generate standalone script (fallback)

If Plan A fails, copy the self-contained script to the user's desktop:

```powershell
Copy-Item ".trae/skills/windows-utf8-fix/scripts/install-standalone.ps1" "$env:USERPROFILE\Desktop\fix-utf8.ps1"
```

Then tell the user:

> **请在桌面找到 `fix-utf8.ps1`，右键 → "使用 PowerShell 运行"**，或者打开 PowerShell 执行：
> ```powershell
> cd $env:USERPROFILE\Desktop
> .\fix-utf8.ps1
> ```
> 执行完毕后关闭所有终端窗口，重新打开即可。

### Plan C: Manual step-by-step (last resort)

Guide the user through each command:

1. **Set user env vars**: Open "系统属性 → 环境变量 → 用户变量", add LC_ALL=C.UTF-8, LANG=C.UTF-8, PYTHONIOENCODING=utf-8, PYTHONUTF8=1
2. **PowerShell profile**: Run `notepad $PROFILE`, paste the UTF-8 block from `scripts/install.ps1`
3. **CMD**: Run `reg add "HKCU\Software\Microsoft\Command Processor" /v AutoRun /t REG_SZ /d "chcp 65001 > nul" /f`
4. **Git**: Run `git config --global core.quotepath false` and similar commands
5. **System UTF-8**: Settings → 区域 → 管理 → 勾选 Beta UTF-8 → 重启

### Uninstall

To remove all changes made by this skill:

```powershell
pwsh -NoProfile -File ".trae/skills/windows-utf8-fix/scripts/uninstall.ps1"
```

This removes the profile block, env vars, Git config, and CMD autorun. IDE settings.json changes are NOT reverted (they're safe defaults).

### Step 4: If still broken after all plans

Walk the fallback chain:

1. **PowerShell 5.1** — `[Console]::OutputEncoding` may be silently ignored. Install PowerShell 7 (see download links above).
2. **System level** — open `intl.cpl` → Administrative → check "Beta: Use Unicode UTF-8" → restart. This is the ultimate fix.
3. **IDE terminal profile** — ensure the IDE uses `pwsh` not legacy `powershell.exe` as the default terminal.
4. **Font** — terminal font must contain CJK glyphs (Cascadia Code NF, Sarasa Mono SC, Microsoft YaHei UI).
5. **Sandbox override** — some AI tools add `-NoProfile` to terminal args, bypassing the fix. Check IDE settings.
6. **ConPTY** — some terminals use ConPTY which has its own encoding. Windows Terminal >= 1.18 fixed this.

## Supported IDEs and terminals

The `ide-patch.ps1` script detects and patches `settings.json` / `config.yaml` for:

| IDE / Terminal | Config path | Format | Patches |
|---|---|---|---|
| **VS Code** | `%APPDATA%\Code\User\settings.json` | JSON | terminal env, files.encoding |
| **VS Code Insiders** | `%APPDATA%\Code - Insiders\User\settings.json` | JSON | terminal env, files.encoding |
| **VSCodium** | `%APPDATA%\VSCodium\User\settings.json` | JSON | terminal env, files.encoding |
| **Cursor** | `%APPDATA%\Cursor\User\settings.json` | JSON | terminal env, files.encoding |
| **Windsurf** | `%APPDATA%\Windsurf\User\settings.json` | JSON | terminal env, files.encoding |
| **Trae CN** (国内版) | `%APPDATA%\Trae CN\User\settings.json` | JSON | terminal env, files.encoding |
| **Trae Work** (国际版, 前身 TRAE SOLO) | `%APPDATA%\Trae Work\User\settings.json` | JSON | terminal env, files.encoding |
| **Trae Solo** (legacy) | `%APPDATA%\Trae Solo\User\settings.json` | JSON | terminal env, files.encoding |
| **Qoder** (Alibaba) | `%APPDATA%\Qoder\config.yaml` | YAML | env vars (Layer 1 only) |
| **CodeBuddy** (Tencent) | `%USERPROFILE%\.codebuddy\settings.json` | JSON | terminal env, files.encoding |
| **Zed** | `%APPDATA%\Zed\settings.json` | JSON | terminal env |
| **Windows Terminal** | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json` | JSON | (inherits env) |
| **JetBrains** (IntelliJ/PyCharm/WebStorm) | N/A | — | (inherits env) |
| **通义灵码 / 文心快码** (VSCode plugins) | inherit host IDE | — | (inherits host) |
| **Aider / Continue.dev** | N/A (CLI tools) | — | (covered by system env vars) |

JetBrains IDEs (IntelliJ IDEA, PyCharm, WebStorm, GoLand, etc.) do NOT have a JSON settings file for terminal encoding. They inherit the user environment variables set in Layer 1, which is sufficient for their built-in terminal.

## Runtime-specific encoding fixes

### Python

```powershell
# User env var (set by install.ps1)
PYTHONIOENCODING=utf-8
```

Python reads `PYTHONIOENCODING` before initializing `sys.std*` streams. This is the most reliable method.

### Node.js

Node.js uses UTF-8 by default for `console.log()`. The `LC_ALL=C.UTF-8` environment variable (Layer 1) ensures `process.stdout.encoding` is `utf-8` rather than `buffer` in TTY-attached terminals. No additional Node-specific flags are needed.

### Java / JVM

```powershell
# User env var (set by install.ps1)
JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8
```

This affects all JVM processes on the machine. For Gradle specifically, add `org.gradle.jvmargs=-Dfile.encoding=UTF-8` to `gradle.properties`.

### Go

Go source code is UTF-8 by specification. Build tools (`go build`, `go test`) inherit the system locale. The `LC_ALL=C.UTF-8` env var covers edge cases. No Go-specific flags are needed.

### Ruby

```powershell
# User env var (set by install.ps1)
RUBYOPT=-Eutf-8
```

Ruby uses locale for default external encoding. `RUBYOPT=-Eutf-8` forces UTF-8 for all Ruby processes.

### Rust / Cargo

Rust and Cargo use UTF-8 natively. No additional env vars needed. The `LC_ALL=C.UTF-8` from Layer 1 covers edge cases.

## Reference: why each fix works

### Why `[Console]::OutputEncoding` MUST be explicit

PowerShell reads the **OEM code page at process launch** and caches it in `[Console]::OutputEncoding`. Running `chcp 65001` only changes the child console; the cached value persists. Both `[Console]::InputEncoding` and `$OutputEncoding` must be reassigned in `$PROFILE`.

> **PowerShell 5.1 caveat**: In Windows PowerShell (5.1), `[Console]::OutputEncoding` assignment may be silently ignored when the console host is not a traditional console window. This is a known .NET Framework limitation. PowerShell 7+ (built on .NET Core) does not have this issue.

### Why CMD needs a registry autorun

`cmd.exe` does not have a profile system like PowerShell. The only way to auto-execute `chcp 65001` on every CMD launch is through the `HKCU\Software\Microsoft\Command Processor\AutoRun` registry key. This is safe and user-level only.

### Why Git needs `core.quotepath = false`

Git on Windows quotes non-ASCII paths as `\nnn` octal escapes when stdout is not a TTY or when the locale isn't UTF-8. The fix is two-fold: `core.quotepath=false` (don't escape) + `i18n.logoutputencoding=utf-8` (read logs as UTF-8).

### Why Python is affected even with chcp 65001

Python's `sys.stdout.encoding` is set at startup from `GetConsoleOutputCP()`. If you set `chcp 65001` AFTER Python starts, it's too late. The fix is `PYTHONIOENCODING=utf-8` in the env, which Python honors before initialization.

### Why user-level env vars (not just process-level)

AI tools spawn child processes that inherit the user's environment. Setting env vars at the **User** level (via `[Environment]::SetEnvironmentVariable`) ensures:
- New PowerShell/CMD windows inherit them
- IDE-spawned terminals inherit them
- Python, Node, Java, Go, Ruby subprocesses inherit them
- They survive reboots

## Bundled scripts

| Script | Purpose | Safe to run? |
|---|---|---|
| `scripts/common.ps1` | Shared module — constants, helpers, PS 5.1 compat layer. Dot-sourced by all other scripts. | ✅ Yes (library) |
| `scripts/diagnose.ps1` | Read-only probe. Reports PS version, sandbox, system UTF-8, encoding, Git, Python, Node. | ✅ Yes |
| `scripts/install.ps1` | Idempotent 6-layer fixer. Writes to $PROFILE (with backup), env vars (with backup), registry, Git, IDE settings. | ✅ Yes (idempotent) |
| `scripts/install-standalone.ps1` | Self-contained for Plan B. Includes inline IDE patching. No external script dependency except common.ps1. | ✅ Yes |
| `scripts/verify.ps1` | Post-fix acceptance test covering all env vars, Git, CMD. Exit code 0 = all good. | ✅ Yes |
| `scripts/uninstall.ps1` | Removes all changes, restores original env var values from backup. | ✅ Yes |
| `scripts/fix-git.ps1` | Standalone Git config helper (uses shared GitDefaults). | ✅ Yes |
| `scripts/ide-patch.ps1` | 11+ IDE/terminal settings merger. Supports JSON + YAML + Zed formats. PS 5.1 + 7+ compat. | ✅ Yes |

## Out of scope

- Non-Windows systems (use system locale tools)
- Code page conversions for individual files (use `Get-Content -Encoding`)
- Font installation (manual — but the SKILL.md will guide the user)
- WSL encoding issues (WSL defaults to UTF-8; if broken, check `/etc/locale.conf`)
- SSH remote encoding (set `LANG=zh_CN.UTF-8` on the remote server)
- CI/CD runners (GitHub Actions, GitLab CI — set env vars in workflow YAML)

## References

- [Microsoft: Beta UTF-8 setting](https://learn.microsoft.com/en-us/windows/win32/intl/code-page-identifiers)
- [PowerShell 7 GitHub Releases](https://github.com/PowerShell/PowerShell/releases)
- [PowerShell 7 Microsoft Store](https://apps.microsoft.com/detail/9mz1snwt0n5h)
- [PowerShell $PROFILE docs](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles)
- [Git i18n.commitencoding](https://git-scm.com/docs/git-config#Documentation/git-config.txt-i18ncommitEncoding)
- [Python PEP 540 — UTF-8 mode](https://peps.python.org/pep-0540/)
- [Node.js character encoding](https://nodejs.org/api/process.html#processstdout)
- [Java file.encoding](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/System.html#getProperties())
- Related skill: [gkd2323c/charset-fix](https://github.com/gkd2323c/charset-fix) (POSIX-shell variant)

## License

MIT