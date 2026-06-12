# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-06-12

### Added
- 11+ IDE auto-patch support: Trae Work, Trae Solo, Qoder (YAML), CodeBuddy, Cursor, Windsurf, Zed, VS Code family
- YAML serializer (`ConvertFrom-SimpleYaml` / `ConvertTo-SimpleYaml`) and YAML merger (`Merge-SettingsYaml`)
- `%USERPROFILE%`-based config location support (for CodeBuddy)
- Each IDE annotated with `Kind` (json / yaml / zed) for format-aware merging
- Windows Terminal detection (inherits env vars)
- JetBrains / Lingma / Comate / Continue.dev note (inherit env or host IDE)
- `.gitattributes` for consistent line endings (PS1=CRLF, MD/YAML=LF)

### Changed
- Repository layout: moved skill from `.trae/skills/windows-utf8-fix/` to `windows-utf8-fix/` for proper GitHub presentation
- Added root-level `README.md` (project-level), `.gitignore`, and one-line `install.ps1`

### Security & Robustness
- PowerShell 5.1 + 7+ compatibility (`ConvertTo-HashtablePS5` polyfill)
- Plan B standalone installer with embedded IDE patching
- Backup + restore for `$PROFILE` and user env vars (uninstall)

## [1.2.0] - 2026-06-12

### Added
- 6-layer repair mechanism (env, profile, registry, Git, IDE, system hint)
- `common.ps1` shared module (eliminates code duplication)
- `uninstall.ps1` with backup restoration
- PS 5.1 / 7+ compatibility layer

## [1.1.0] - 2026-06-12

### Added
- Initial 8 IDE support
- `ide-patch.ps1` for settings.json merger
- `fix-git.ps1` for standalone Git config
- Sandbox detection + Plan B standalone installer

## [1.0.0] - 2026-06-12

### Added
- First release: `diagnose.ps1`, `install.ps1`, `verify.ps1`
- Basic PowerShell profile UTF-8 forcing
- Core env var injection (LC_ALL, LANG, PYTHONIOENCODING)
