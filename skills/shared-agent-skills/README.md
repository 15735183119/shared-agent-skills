# shared-agent-skills

跨 Agent 的 Skill 共享分发器 · Cross-Agent Skill Sharing Dispatcher

装一次，本机所有 Agent 共享同一份 Skill 真身。
Install once, and every agent on this machine shares a single copy of each skill.

---

## 这个 skill 解决什么 / What it solves

SKILL.md 已经是开放标准（Agent Skills），Claude Code、Codex、Cursor、Gemini、
Windsurf、Copilot、OpenCode、WorkBuddy 等工具都读同一套格式。但每个 Agent 只扫
自己的目录，于是同一套方法论你在每台 Agent 里各装一份、各改各的、迟早漂移。

SKILL.md is already an open standard (Agent Skills) that dozens of tools read
identically. But every agent scans only its own directory, so the same skill ends
up installed once per agent, drifting apart over time.

本 skill 的做法：**唯一真身 + 目录联接**。

This skill's approach: **one canonical copy, linked from every agent**.

```
                    ~/.shared-agent-skills/
                    ├── fangying-video-dna/   ← 唯一真身
                    ├── jianying-assistant/
                    └── ...
                           ↑        ↑        ↑
                      联接      联接      联接
                   WorkBuddy  OpenCode  Claude Code
```

改真身一处，所有 Agent 立刻生效。

Edit the canonical copy and every agent sees the change immediately.

---

## 安装 / Installation

把本目录放进任一 Agent 的 skills 目录，或直接安装到 WorkBuddy：

```
~/.workbuddy/skills/shared-agent-skills/
```

然后运行一次收编，把本机已有 skill 全部纳入共享：

```
powershell scripts/share_all.ps1          # Windows
bash scripts/share_all.sh                 # macOS / Linux
```

先看本机检测到哪些 Agent：

```
powershell scripts/detect_agents.ps1
bash scripts/detect_agents.sh
```

---

## 命令 / Commands

| 命令 | 作用 |
|---|---|
| `detect_agents` | 列出本机 Agent 及其 skills 目录 |
| `share_skill <name\|path>` | 把某个 skill 收编进共享根并联接所有 Agent |
| `share_all` | 扫描所有 Agent，把未共享的 skill 全部收编（幂等） |
| `unshare_skill <name> [-To <agent>]` | 撤掉所有联接，可选把真身迁回某个 Agent 变私有 |

Windows 用 `.ps1` 版本，macOS / Linux 用 `.sh` 版本。

Use the `.ps1` variants on Windows and the `.sh` variants on macOS and Linux.

---

## 无法跟随联接的 Agent / Agents that cannot follow a link

少数 Agent 运行在受限沙箱里，或落在不支持链接的文件系统上。这类 Agent 改用**私有
副本**，复制前脚本会说明原因并询问；**未确认不会复制**。

A few agents run in restricted sandboxes or on filesystems without link support.
They receive a **private copy** instead. The script explains why and asks first —
**it never copies without confirmation**.

```
powershell scripts/share_skill.ps1 my-skill -CopyAgents claude
bash scripts/share_skill.sh my-skill -c claude
```

Agent id 取自 `detect_agents` 的输出第一列：`workbuddy`、`opencode`、`claude`、
`codex`、`cursor`、`gemini`、`windsurf`、`windsurf-alt`、`copilot`。

---

## 平台差异 / Platform notes

- **Windows** 用 junction，免管理员权限。
- **macOS / Linux** 用符号链接。脚本已避开 bash 4.0 才有的语法，macOS 自带的
  bash 3.2 可直接运行。
- 在 **Windows 的 Git Bash** 里运行 `.sh` 版本不会收敛：`ln -s` 产生普通目录副本
  而非符号链接。Windows 请用 `.ps1` 版本。

Windows uses junctions and needs no administrator rights. macOS and Linux use
symbolic links, and the scripts avoid bash 4.0-only syntax so the bash 3.2 that
ships with macOS works fine. Running the `.sh` variants inside Git Bash on Windows
does not converge, because `ln -s` there produces plain directory copies rather
than symbolic links — use the `.ps1` variants on Windows.

---

## 删除操作的边界 / What deletion touches

- **删联接只删链接本身**，真身永远留在共享根里。
- **真身只移动，不删除**：收编时把 skill 目录移进共享根，原位置换成联接。
- **遇到内容不一致的目录不覆盖**：用 `-Force` 采纳时，旧的那份会改名保留为
  `.adopted-backup`，不会直接删掉。
- **`-Force` 会跳过复制前的询问**，仅在你已确认时使用。

Removing a link removes only the link; the canonical copy always stays in the
shared root. Adopting a divergent directory with `-Force` renames the old copy
to `.adopted-backup` rather than deleting it.

---

## 为新 skill 标注能力边界 / Annotating new skills

新建或改写 skill 时，在 frontmatter 标注范围与依赖，并在正文加一节降级说明：

```yaml
---
name: your-skill
description: 用一句话说清这个 skill 做什么、何时用
scope: shared
requires: ImageGen, VideoGen, 本地 ffmpeg
---
```

正文加一节：

```markdown
## 降级与专属能力边界

- scope: shared
- 依赖能力：ImageGen、VideoGen、本地 ffmpeg
- 降级行为：缺 ImageGen 时退化为仅输出分析文档与提示词包，跳过生成步骤
```

仅某个工具自用的 skill 标 `scope: private:<agent-id>`，不会被分发器扩散。

Frontmatter only accepts single-line `key: value`; put the dependency list on one
line, comma separated. Mark a tool-specific skill as `scope: private:<agent-id>`
so the dispatcher leaves it alone.

---

## 环境检查 / Environment check

```
python scripts/check_environment.py
```

只读探测，输出 JSON。不安装、不登录、不改配置、不输出任何凭据。

A read-only probe that prints JSON. It never installs, logs in, changes
configuration, or prints credential values.

---

## 回滚 / Rollback

```
powershell scripts/unshare_skill.ps1 <name> -To workbuddy
```

解除联接并把真身迁回指定 Agent，该 skill 变私有。

Removes the links and moves the canonical copy back to one agent, making that
skill private again.

---

## 许可 / License

MIT，见 [LICENSE](LICENSE)。

---

## 英文版 / English

**Why this exists.** SKILL.md is already an open standard (Agent Skills) that
Claude Code, Codex, Cursor, Gemini, Windsurf, Copilot, OpenCode, WorkBuddy and
others all read. But each agent scans only its own directory, so the same skill
gets installed once per agent and drifts over time.

**How it works.** One canonical copy lives in a user-level shared root
(`~/.shared-agent-skills/`). Every detected agent gets a link — a junction on
Windows, a symbolic link on macOS and Linux — pointing at that same copy.
Editing the canonical copy updates every agent at once.

**Getting started.** Install the package into any agent's skills directory, then
run `share_all` once to pull this machine's existing skills into the shared root.
`detect_agents` lists the agents it found and the agent ids you need for
`-CopyAgents`.

**Copy fallback.** Agents running in a restricted sandbox, or on a filesystem
without link support, get a private copy. The script states the reason and asks
before copying; without confirmation it skips, so you never get silent
duplicates. A copy does not track the canonical copy and needs manual syncing.

**Deleting things safely.** Removing a link removes only the link — the canonical
copy stays put. Adopting a divergent directory with `-Force` renames the old
copy to `.adopted-backup` instead of deleting it. `-Force` also skips the copy
confirmation prompt, so use it only when you have already decided.

**Platform notes.** Windows uses junctions and needs no administrator rights.
macOS and Linux use symbolic links; the scripts avoid bash 4.0-only syntax so the
bash 3.2 that ships with macOS works. Running the `.sh` variants inside Git Bash
on Windows does not converge, because `ln -s` there produces plain directory
copies — use the `.ps1` variants on Windows.

**Annotating skills you write.** Add `scope` and `requires` to the frontmatter
(single-line `key: value` only) and a `## 降级与专属能力边界` section to the body
describing what happens when a dependency is missing. Skills meant for one tool
only use `scope: private:<agent-id>` and are never spread by the dispatcher.

**Environment check.** `python scripts/check_environment.py` runs a read-only
probe and prints JSON. It never installs, logs in, changes configuration, or
prints credential values.

**License.** MIT — see [LICENSE](LICENSE).
