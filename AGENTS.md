# AGENTS.md — Alias of CLAUDE.md

> ⚠️ **This file is an alias of [`CLAUDE.md`](CLAUDE.md).**
>
> Different AI coding tools look for different project-context filenames:
> - **Claude Code** → `CLAUDE.md`
> - **Codex / 其他 agent** → `AGENTS.md` (newer convention)
>
> To keep both naming conventions working without duplicating content, this file
> is kept in sync with `CLAUDE.md`. If you edit one, **edit the other** to match
> (or run `sync-agents-md.ps1` below).

---

<!--
  BEGIN: auto-synced content with CLAUDE.md
  Last synced: 2026-06-12
  Source SHA: see `git log -1 -- CLAUDE.md`
-->

> 📖 **Read this first** if you are an AI coding agent (Claude Code, Codex, Qoder, Trae, etc.) working on the `windows-utf8-fix` project.

This file follows the [agent.md / CLAUDE.md convention](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) used by major AI coding tools. It contains project context, conventions, and guardrails you need to work effectively — without reading the entire codebase first.

---

## 🎯 Project Mission

**windows-utf8-fix** is an **Agent Skill** that automatically fixes Windows GBK/UTF-8 encoding issues for AI coding IDEs (Trae, Claude Code, Codex, Qoder, CodeBuddy, Cursor, Windsurf, etc.) and runtimes (Python, Java, Git, Node, Go, Rust, CMD).

**Why it exists**: When AI models receive garbled Chinese text from Windows terminals, they treat the garbled bytes as valid tokens — wasting context, lowering response quality, and increasing cost. This skill fixes the encoding so AI agents can actually read what their tools output.

**Primary user**: Chinese-speaking Windows developers using AI coding IDEs.

---

## 📁 Project Structure

```
.
├── README.md                    # Project landing page (GitHub)
├── CHANGELOG.md                 # Version history (Keep a Changelog)
├── LICENSE                      # MIT
├── CLAUDE.md                    # ⭐ This file (for AI agents)
├── AGENTS.md                    # ⭐ Alias of CLAUDE.md (for Codex etc.)
├── .gitignore                   # Excludes backups, OS junk, IDE files
├── .gitattributes               # Forces CRLF for .ps1, LF for .md
├── install.ps1                  # One-line iwr|iex entry point
│
└── windows-utf8-fix/            # ⭐ The actual agent skill
    ├── SKILL.md                 # Agent entry (frontmatter, when to invoke)
    ├── README.md                # Human usage doc
    ├── LICENSE
    ├── .gitattributes
    └── scripts/
        ├── common.ps1           # Shared module (dot-sourced by all)
        ├── diagnose.ps1         # Read-only probe
        ├── install.ps1          # 6-layer fixer
        ├── install-standalone.ps1 # Plan B (no external deps)
        ├── verify.ps1           # Post-fix acceptance test
        ├── uninstall.ps1        # Backup-restore uninstaller
        ├── fix-git.ps1          # Standalone Git config
        └── ide-patch.ps1        # 11+ IDE settings merger
```

---

## 🧩 Architectural Principles

### 1. **Single source of truth for configuration**
All env vars, IDE paths, Git settings, and PS profiles are defined in [`windows-utf8-fix/scripts/common.ps1`](windows-utf8-fix/scripts/common.ps1). When adding a new env var or IDE:
- Add it to the corresponding hashtable (`$EnvDefaults`, `$IDEPaths`, `$GitDefaults`, `$VSCodeSettings`)
- Do NOT hardcode in any other script

### 2. **6-layer repair mechanism**
Each layer is independent and idempotent. The order matters:

| Layer | File | Purpose |
|---|---|---|
| **L0** | `install.ps1` | Environment detection (PS version, sandbox, system UTF-8) |
| **L1** | `install.ps1` | User-level env vars (HKCU\Environment, with backup) |
| **L2** | `install.ps1` | PowerShell profile UTF-8 forcing (with backup) |
| **L3** | `install.ps1` | CMD chcp 65001 via registry AutoRun |
| **L4** | `install.ps1` | Git i18n config |
| **L5** | `install.ps1` → `ide-patch.ps1` | IDE settings.json / config.yaml patch |
| **L6** | `install.ps1` | System-level Beta UTF-8 prompt (manual user action) |

### 3. **Backup before mutate**
Every write operation that touches user files MUST call `Backup-File` first. Original values are stored in:
- File backups: `*.utf8fix-bak-<timestamp>` next to original
- Env var backups: `HKCU\Software\windows-utf8-fix\env-backup\<NAME>` registry keys
- PowerShell profile: single `Microsoft.PowerShell_profile.ps1.utf8fix-bak-<timestamp>` file

This enables `uninstall.ps1` to perfectly restore the user's original state.

### 4. **Idempotency first**
All scripts must be re-runnable without side effects. Use block markers like:
```powershell
$BLOCK_BEGIN = '# >>> windows-utf8-fix v1.3.0 BEGIN >>>'
$BLOCK_END   = '# >>> windows-utf8-fix v1.3.0 END >>>'
```
Before inserting, check for and remove old blocks.

### 5. **PowerShell 5.1 + 7+ compatibility**
- NEVER use `-AsHashtable` on `ConvertFrom-Json` (PS 7+ only) — use `ConvertTo-HashtablePS5` polyfill
- NEVER use ternary `cond ? a : b` (PS 7+ only)
- NEVER use `??` null-coalescing (PS 7+ only)
- Test with both `powershell.exe` (5.1) and `pwsh` (7+)

### 6. **CI-friendly verification**
`verify.ps1` returns exit code 0 only when ALL checks pass. Safe for CI:
```bash
pwsh -NoProfile -File windows-utf8-fix/scripts/verify.ps1 && echo "OK" || echo "FAIL"
```

---

## 🛠 Common Tasks for AI Agents

### Add a new IDE to support

1. Open [`windows-utf8-fix/scripts/common.ps1`](windows-utf8-fix/scripts/common.ps1)
2. Add entry to `$IDEPaths`:
   ```powershell
   @{ Name = 'NewIDE'; Kind = 'json'; Path = "$env:APPDATA\NewIDE\User\settings.json" }
   ```
3. If format is non-JSON, also add a settings hash (e.g. `$ZedSettings`) and a merge function (e.g. `Merge-SettingsYaml`)
4. Update `windows-utf8-fix/SKILL.md` IDE coverage table
5. Test: run `pwsh -NoProfile -File windows-utf8-fix/scripts/ide-patch.ps1`
6. Update CHANGELOG.md

### Add a new environment variable

1. Add to `$EnvDefaults` in `common.ps1`:
   ```powershell
   $script:EnvDefaults = @{
       'LC_ALL'           = 'C.UTF-8'
       'NEW_VAR'          = 'value'   # ← add here
   }
   ```
2. Update `windows-utf8-fix/SKILL.md` runtime support table
3. Test: run `install.ps1` (should add NEW_VAR) and `verify.ps1` (should pass)

### Bump version

1. Edit `windows-utf8-fix/scripts/common.ps1` → `$BLOCK_BEGIN` version string
2. Edit `windows-utf8-fix/SKILL.md` → `version:` frontmatter
3. Edit `CHANGELOG.md` → add new section at top
4. After merge, create a GitHub Release with tag `vX.Y.Z` (use the template from commit history)

### Debug an encoding issue on a user's machine

```powershell
# Step 1: read-only diagnose
pwsh -NoProfile -File windows-utf8-fix/scripts/diagnose.ps1

# Step 2: share the output with the user; identify failing layers

# Step 3: re-run with manual confirmation
pwsh -NoProfile -ExecutionPolicy Bypass -File windows-utf8-fix/scripts/install.ps1

# Step 4: verify
pwsh -NoProfile -File windows-utf8-fix/scripts/verify.ps1
```

If install fails in a sandbox (Trae/Claude Code), guide the user to `install-standalone.ps1` (Plan B).

---

## ⚠️ Things You Must NOT Do

| Action | Why |
|---|---|
| ❌ Modify `windows-utf8-fix/scripts/common.ps1` without dot-source testing | All other scripts depend on it |
| ❌ Hardcode env var names in `install.ps1` / `verify.ps1` | Use `$EnvDefaults` (single source) |
| ❌ Add `if (-not $PSScriptRoot)` checks in every script | It's a single line; just use the pattern in `install.ps1` |
| ❌ Use PS 7+ syntax (`-AsHashtable`, `??`, ternary) | Breaks PS 5.1 |
| ❌ Skip the `Backup-File` call before modifying user files | Breaks uninstall guarantee |
| ❌ Push directly to `main` | Use a feature branch + PR |
| ❌ Bump version in only one place | Must update: `common.ps1` block marker + `SKILL.md` frontmatter + `CHANGELOG.md` |
| ❌ Add emojis to source code comments | Keep code comments English / functional; emojis OK in user-facing output only |

---

## 🧪 Testing Checklist

Before committing changes, run ALL of these:

```powershell
# 1. Verify clean run
pwsh -NoProfile -File windows-utf8-fix/scripts/verify.ps1
# Expected: "✓ 全部通过 (14/14)"

# 2. Verify re-run is idempotent (run install twice)
pwsh -NoProfile -ExecutionPolicy Bypass -File windows-utf8-fix/scripts/install.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File windows-utf8-fix/scripts/install.ps1
# Expected: both runs succeed, no duplicate blocks

# 3. Verify PS 5.1 compat (if you have it)
powershell.exe -NoProfile -File windows-utf8-fix/scripts/diagnose.ps1
# Expected: no errors (some advanced features may report "not supported")

# 4. Verify uninstall restores state
pwsh -NoProfile -File windows-utf8-fix/scripts/uninstall.ps1
# Expected: all *.utf8fix-bak-* removed, env vars restored

# 5. Verify line endings
git ls-files '*.ps1' | xargs -I{} bash -c 'file {} | grep -q CRLF || echo "WRONG: {}"'
# Expected: no WRONG output
```

---

## 📚 Reference Documentation

| File | Purpose |
|---|---|
| [`README.md`](README.md) | Project landing page (humans) |
| [`windows-utf8-fix/SKILL.md`](windows-utf8-fix/SKILL.md) | Agent skill entry (frontmatter, triggers) |
| [`windows-utf8-fix/README.md`](windows-utf8-fix/README.md) | Skill user manual |
| [`CHANGELOG.md`](CHANGELOG.md) | Version history |
| [`windows-utf8-fix/scripts/common.ps1`](windows-utf8-fix/scripts/common.ps1) | ⭐ Read this first to understand data structures |
| [`windows-utf8-fix/scripts/install.ps1`](windows-utf8-fix/scripts/install.ps1) | ⭐ Read this to understand the 6-layer flow |

---

## 🤝 Contributing Etiquette

1. **Branch naming**: `feat/<short-name>`, `fix/<short-name>`, `docs/<short-name>`
2. **Commit messages**: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`)
3. **PR description**: Link any related GitHub issue; include `verify.ps1` output before/after
4. **Language**: Code comments in English, user-facing prompts in Chinese (matches target user base)
5. **License**: All contributions are MIT-licensed

---

## 🌍 Multi-IDE Compatibility Matrix

| IDE | Settings path format | Status |
|---|---|---|
| Trae CN / Trae Work / Trae Solo | `%APPDATA%\Trae*\User\settings.json` (JSON) | ✅ |
| Qoder | `%APPDATA%\Qoder\config.yaml` (YAML) | ✅ |
| CodeBuddy | `%USERPROFILE%\.codebuddy\settings.json` (JSON) | ✅ |
| Cursor / Windsurf / VS Code / VSCodium | `%APPDATA%\<Name>\User\settings.json` (JSON) | ✅ |
| Zed | `%APPDATA%\Zed\settings.json` (JSON, custom shape) | ✅ |
| JetBrains / Lingma / Comate | inherits user env vars | ✅ |
| Aider / Continue.dev | CLI — inherits env | ✅ |
| Windows Terminal | inherits env | ✅ |

When adding an IDE, verify it by:
1. Creating a settings file with sample content
2. Running `ide-patch.ps1` to confirm merge
3. Verifying the original content is preserved AND the UTF-8 keys are added

---

## 🔗 Quick Links

- **Repository**: https://github.com/jayone-c/windows-utf8-fix
- **Latest release**: https://github.com/jayone-c/windows-utf8-fix/releases/latest
- **Issues**: https://github.com/jayone-c/windows-utf8-fix/issues
- **Discussions**: https://github.com/jayone-c/windows-utf8-fix/discussions

---

## 📌 Last Verified

- **Date**: 2026-06-12
- **verify.ps1**: 14/14 passing
- **PowerShell versions tested**: 5.1, 7.6.2
- **Windows versions tested**: 10 22H2, 11 23H2
- **commit**: see `git log -1`

<!-- END: auto-synced content with CLAUDE.md -->
