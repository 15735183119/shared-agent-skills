# 配置指南

本 skill 只依赖操作系统自带的脚本运行时，不读取任何凭据、不访问网络、不下载任何
第三方内容。下面说明各平台需要确认什么，以及怎么验证。

## 依赖清单

| 依赖 id | 类型 | 必需 | 用途 |
|---|---|---|---|
| `windows-powershell` | 运行时 | Windows 上必需 | 执行 `scripts/*.ps1`，用 junction 建立联接 |
| `unix-bash` | 运行时 | macOS / Linux 上必需 | 执行 `scripts/*.sh`，用符号链接建立联接 |

两者在各自平台上是"必需"，在另一个平台上不必需：Windows 用 `.ps1` 版即可，macOS 与
Linux 用 `.sh` 版即可。

## Windows：确认 PowerShell

Windows 10 与 Windows 11 自带 Windows PowerShell 5.1，通常无需安装。

1. 在任意终端运行 `powershell -Command "$PSVersionTable.PSVersion"`，确认版本不低于
   5.1。
2. 官方文档：
   - 概览：https://learn.microsoft.com/en-us/powershell/scripting/overview
   - 安装：https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell
3. 若系统没有 `powershell` 命令，安装 PowerShell 7 后命令名为 `pwsh`。本 skill 的
   `.ps1` 脚本在两个版本下都能运行，脚本内部不依赖 7.x 专有语法。

**安全说明**：只使用系统自带解释器，不从网络下载可执行文件，也不修改系统的执行策略。
脚本以 `powershell -ExecutionPolicy Bypass -File <script>` 单次调用运行，该参数只对
本次进程生效。

## macOS / Linux：确认 bash

macOS 自带 bash 3.2。本 skill 的 `.sh` 脚本已避开 bash 4.0 才有的语法（例如关联数组
`declare -A`），因此在 3.2 上可直接运行。

1. 运行 `bash --version`，确认版本不低于 3.2。
2. 官方文档：
   - 主页：https://www.gnu.org/software/bash/
   - 手册：https://www.gnu.org/software/bash/manual/
3. 若 bash 缺失，通过系统包管理器安装，例如 Debian/Ubuntu 使用 `apt install bash`。

**安全说明**：只使用系统自带解释器，不下载远程脚本。脚本不读取凭据、不发起网络请求。

## 确认共享根可写

共享根默认位于用户主目录下的 `.shared-agent-skills/`。

- 目录不存在时脚本会自动创建。
- 目录已存在时脚本需要能读写它。
- 若该目录不可写，所有收集与共享操作都会失败，此时应先修复目录权限，而不是改用
  复制副本绕过——复制副本同样需要写权限。

## 权限说明

本 skill 需要在以下位置读写：

- 共享根目录（默认 `~/.shared-agent-skills/`）：创建、移动 skill 目录。
- 各 agent 的 `skills/` 目录：创建联接、删除联接。
- agent 目录下的既有独立目录：仅在用户显式要求采纳（`-Force`）时读取，且旧内容会被
  改名保留为 `.adopted-backup`，不会删除。

不需要管理员权限：Windows 上的 junction 创建对普通用户开放。若你的环境限制了对用户
主目录之外路径的写入，那是环境策略所致，脚本不会尝试提权。

## 验证

装好后按顺序执行：

1. `python scripts/check_environment.py` —— 输出 `status` 字段：
   - `ready`：运行时可用、脚本齐全、agent 目录可读，直接进入下一步。
   - `partial`：运行时可用，但有脚本缺失或 agent 目录不可读，看输出里的
     `scripts_missing` 与 `agents_unreachable` 两项。
   - `needs_setup`：两类运行时都不可用，按上面两节安装对应解释器。
   - `unavailable`：检查本身失败（极端情况），此时不会有任何配置被改动。
2. `powershell scripts/detect_agents.ps1`（或 `bash scripts/detect_agents.sh`）——
   列出本机检测到的 agent 及其 skills 目录，第一列即 agent id。
3. `powershell scripts/share_skill.ps1 <skill-name>` —— 把一个 skill 收编进共享根
   并在各 agent 建立联接。

## 凭据与轮换

本 skill 不涉及任何账号、Token、Key 或 OAuth，因此没有凭据需要配置、存储、轮换或
撤销。

## 撤销配置

删除共享根目录即可解除全部共享关系：

1. 先用 `unshare_skill` 逐个解除联接（只删链接，真身保留在共享根）。
2. 确认各 agent 目录已无残留联接后，删除共享根目录。

在 Windows 上直接删除共享根目录会留下各 agent 侧指向空处的断链，建议先按上面第 1 步
解除。
