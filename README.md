# reasflow

Reasoning workflow toolkit: scaffold reasflow agents/skills/tools for **opencode** and **codex**.

## 一句话安装

**macOS / Linux**（需要 sh）：

```bash
curl -fsSL https://raw.githubusercontent.com/sillyDaibo/reasflow-release/main/install.sh | sh
```

**Windows**（PowerShell，无需 bash）：

```powershell
irm https://raw.githubusercontent.com/sillyDaibo/reasflow-release/main/install.ps1 | iex
```

然后：

```bash
cd my-paper-project
reasflow init            # 默认同时生成 opencode + codex 配置
# 或仅其一：
reasflow init --target opencode
reasflow init --target codex
```

`reasflow init` 会把内置的 agents/skills 解包到当前目录，写出 `opencode.json`、`AGENTS.md`、`.opencode/`、`.codex/`。之后直接：

- **opencode**：运行 `opencode`，选 `meta` agent 或 `/reasflow`
- **codex**：运行 `codex`；sub-agents 在 `.codex/agents/`

## 安装选项

macOS / Linux（`install.sh`）：

| 环境变量 | 默认 | 说明 |
|---|---|---|
| `INSTALL_DIR` | `~/.local/bin` | 二进制安装目录 |

```bash
INSTALL_DIR=/usr/local/bin curl -fsSL .../install.sh | sh
```

Windows（`install.ps1`）：

| 参数 | 默认 | 说明 |
|---|---|---|
| `-InstallDir` | `$env:LOCALAPPDATA\Programs\reasflow` | 二进制安装目录 |

```powershell
& ([scriptblock]::Create((irm https://.../install.ps1)) -InstallDir "D:\tools\reasflow")
```

## 二进制是自包含的

所有 agents/skills 在编译期内嵌进 `reasflow` 二进制，运行时解包到 `~/.local/share/reasflow/pack`。无需额外文件、无需克隆源码。

## 平台支持

| 平台 | asset |
|---|---|
| Linux x86_64 | `reasflow-v*-x86_64-linux.tar.gz` |
| macOS (Apple Silicon + Intel) | `reasflow-v*-universal2-macos.tar.gz` |
| Windows x86_64 | `reasflow-v*-x86_64-windows.zip` |

每个 release 附带 `sha256sums.txt`，安装器会自动校验。

## 验证安装

```bash
reasflow --version
reasflow skills --filter survey
```

---

源码私有。本仓仅用于发布二进制与安装器。问题反馈请提 issue。
