# Windows UTF-8 Fix for AI Coding IDEs

> 🛠 一键解决 Windows 平台 AI 工具（如 Trae、Claude Code、Codex、Qoder、CodeBuddy）常出现的中文乱码问题，节省 token，提升 AI 输出效率。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue)](https://github.com/PowerShell/PowerShell)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue)]()

---

## ✨ 这个项目解决什么问题？

在 Windows 上运行 AI 编程 IDE（Trae、Claude Code、Codex、Qoder、CodeBuddy 等）时，终端经常出现 **GBK 编码乱码**：

```
D:\Projects> npm test
[31mError[0m: .\345\234\260\346\226\207\346\226\207\344\273\266 (instead of: 中文文件)
```

这不仅让人看不懂输出，**更关键的是** AI 模型把乱码字符当成有效 token 重新处理，造成 **token 浪费**、**响应质量下降**。

本项目通过 **6 层自动修复**（PowerShell profile、用户环境变量、注册表、Git 配置、IDE settings.json、CMD chcp），将 Windows 终端从 GBK 全面切换到 UTF-8。

---

## 🚀 快速开始

### 方式一：一行命令安装（推荐）

```powershell
iwr -useb https://raw.githubusercontent.com/jayone-c/windows-utf8-fix/main/install.ps1 | iex
```

### 方式二：手动克隆

```powershell
git clone https://github.com/jayone-c/windows-utf8-fix.git
cd windows-utf8-fix
pwsh -NoProfile -ExecutionPolicy Bypass -File .\windows-utf8-fix\scripts\install.ps1
```

### 验证安装

```powershell
pwsh -NoProfile -File .\windows-utf8-fix\scripts\verify.ps1
```

应输出 `✅ 全部通过 (14/14)`。

---

## 📦 支持的 IDE / 工具

| 类别 | 工具 | 格式 | 自动修复 |
|---|---|---|---|
| **AI 编程 IDE** | Trae CN, Trae Work, Trae Solo, Claude Code, Codex, Qoder, CodeBuddy, Cursor, Windsurf | JSON | ✅ |
| **传统 IDE** | VS Code, VS Code Insiders, VSCodium, Zed, JetBrains (IntelliJ/PyCharm/WebStorm) | JSON / env | ✅ |
| **国内 AI 插件** | 通义灵码 (Lingma), 文心快码 (Comate), Continue.dev | 继承主 IDE | ✅ |
| **终端** | Windows Terminal, PowerShell 5.1/7+, CMD, Git Bash | — | ✅ |
| **运行环境** | Python, Java/JVM, Ruby, Node.js, Go, Rust, Git | env vars | ✅ |

> 完整路径对照表见 [`windows-utf8-fix/SKILL.md`](windows-utf8-fix/SKILL.md)

---

## 🛠 6 层修复机制

| 层 | 修复目标 | 修改文件 |
|---|---|---|
| **L1** | 用户级环境变量 | `HKCU\Environment` 注册表 |
| **L2** | PowerShell 7 配置 | `$PROFILE` (带备份) |
| **L3** | CMD 默认代码页 | `HKCU\...\Command Processor\AutoRun` |
| **L4** | Git 编码 | `~/.gitconfig` (4 项 i18n) |
| **L5** | IDE 终端设置 | `settings.json` / `config.yaml` (11+ IDE) |
| **L6** | 系统级提示 | 控制面板 → Beta UTF-8 选项 |

详见 [`windows-utf8-fix/SKILL.md`](windows-utf8-fix/SKILL.md)。

---

## 🔍 诊断与卸载

```powershell
# 只读诊断（不会修改任何东西）
pwsh -NoProfile -File .\windows-utf8-fix\scripts\diagnose.ps1

# 一键卸载（恢复原始环境变量）
pwsh -NoProfile -File .\windows-utf8-fix\scripts\uninstall.ps1
```

---

## 🧩 作为 AI Agent Skill 使用

本项目是符合 [Agent Skills 规范](https://github.com/anthropics/skills) 的 skill，可被以下 IDE 自动发现：

| Agent | 安装路径 |
|---|---|
| **Trae** | `~/.trae/skills/windows-utf8-fix/` |
| **Claude Code** | `~/.claude/skills/windows-utf8-fix/` |
| **Codex / Qoder** | `~/.codex/skills/` 或 `~/.qoder/skills/` |

详细元数据见 [`windows-utf8-fix/SKILL.md`](windows-utf8-fix/SKILL.md)。

---

## 📋 系统要求

- **操作系统**：Windows 10 (1809+) / Windows 11
- **PowerShell**：5.1 (内置) 或 7+ ([下载](https://github.com/PowerShell/PowerShell/releases))
- **磁盘空间**：< 1 MB
- **管理员权限**：**不需要**（仅修改用户级配置）

---

## 📜 许可证

本项目使用 [MIT 许可证](LICENSE)。

---

## 🤝 贡献

欢迎提交 Issue 和 PR！尤其是：
- 新的 IDE / 工具路径
- 新的运行环境编码配置
- 多语言 i18n
- 跨平台测试

---

## ⭐ Star History

如果这个项目帮你节省了 token 和时间，请给个 ⭐ 支持一下！
