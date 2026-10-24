<div align="center">

# shared-agent-skills

**跨 Agent 的 Skill 共享分发器**
Cross-Agent Skill Sharing Dispatcher

装一次，本机所有 Agent 共享同一份 Skill 真身。
Install once, and every agent on this machine shares a single copy of each skill.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Agent Skill](https://img.shields.io/badge/Agent%20Skill-Agent%20Skills-blue.svg)](https://agentskills.io)

</div>

---

## 问题 / The problem

SKILL.md 已经是开放标准（[Agent Skills](https://agentskills.io)），Claude Code、Codex、
Cursor、Gemini、Windsurf、Copilot、OpenCode、WorkBuddy 等工具都读同一套格式。

SKILL.md is already an open standard that dozens of tools read identically.

但每个 Agent 只扫自己的目录：

But every agent scans only its own directory:

```
~/.workbuddy/skills/          ~/.claude/skills/          ~/.codex/skills/
  ├── my-skill/                 ├── my-skill/             ├── my-skill/
  └── ...                       └── ...                   └── ...
```

于是同一套方法论你在每台 Agent 里各装一份、各改各的、迟早漂移。

So the same skill ends up installed once per agent, edited independently, and
drifting apart over time.

---

## 解决 / The solution

**唯一真身 + 目录联接**。One canonical copy, linked from every agent.

```
                    ~/.shared-agent-skills/
                    ├── my-skill/          ← 唯一真身 / the only copy
                    ├── other-skill/
                    └── ...
                           ↑        ↑        ↑
                      联接      联接      联接
                    junction  symlink  symlink
                   WorkBuddy OpenCode Claude
```

改真身一处，所有 Agent 立刻生效。

Edit the canonical copy and every agent sees the change immediately.

---

## 安装 / Install

### 作为 WorkBuddy 插件

在 WorkBuddy 的技能设置中搜索并安装。

### 作为通用 Agent Skill

把 `skills/shared-agent-skills/` 放进你所用 Agent 的 skills 目录：

| Agent | 目录 |
|---|---|
| WorkBuddy | `~/.workbuddy/skills/` |
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| OpenCode | `~/.config/opencode/skills/` |
| Cursor | `~/.cursor/skills/` |
| Gemini CLI | `~/.gemini/skills/` |
| Windsurf | `~/.codeium/windsurf/skills/` |
| Copilot | `.agents/skills/` |

---

## 使用 / Usage

先跑一次收编，把本机已有的 Skill 全部纳入共享：

```
powershell scripts/share_all.ps1          # Windows
bash scripts/share_all.sh                 # macOS / Linux
```

查看本机检测到的 Agent：

```
powershell scripts/detect_agents.ps1
bash scripts/detect_agents.sh
```

只读环境检查（不安装、不登录、不改配置、不输出凭据）：

```
python scripts/check_environment.py
```

### 命令 / Commands

| 命令 | 作用 |
|---|---|
| `detect_agents` | 列出本机 Agent 及其 skills 目录 |
| `share_skill <name\|path>` | 把某个 Skill 收编进共享根并联接所有 Agent |
| `share_all` | 扫描所有 Agent，把未共享的 Skill 全部收编（幂等） |
| `unshare_skill <name> [-To <agent>]` | 撤掉所有联接，可选把真身迁回某个 Agent 变私有 |

---

## 无法跟随联接的 Agent / Agents that cannot follow a link

少数 Agent 运行在受限沙箱里，或落在不支持链接的文件系统上。这类 Agent 改用**私有
副本**，复制前脚本会说明原因并询问；**未确认不会复制**，无人值守运行时直接跳过。

A few agents run in restricted sandboxes or on filesystems without link support.
They receive a **private copy**. The script states the reason and asks first — it
never copies without confirmation, and skips when running unattended.

```
powershell scripts/share_skill.ps1 my-skill -CopyAgents claude
bash scripts/share_skill.sh my-skill -c claude
```

Agent id 取自 `detect_agents` 的输出第一列。

---

## 平台差异 / Platform notes

- **Windows** 用 junction，免管理员权限。
- **macOS / Linux** 用符号链接。脚本已避开 bash 4.0 才有的语法，macOS 自带的
  bash 3.2 可直接运行。
- 在 **Windows 的 Git Bash** 里运行 `.sh` 版本不会收敛：`ln -s` 产生普通目录副本。
  Windows 请用 `.ps1` 版本。

Windows uses junctions and needs no administrator rights. macOS and Linux use
symbolic links; the scripts avoid bash 4.0-only syntax so the bash 3.2 that ships
with macOS works fine. Running the `.sh` variants inside Git Bash on Windows does
not converge, because `ln -s` there produces plain directory copies — use the
`.ps1` variants on Windows.

---

## 删除操作的边界 / What deletion touches

- **删联接只删链接本身**，真身永远留在共享根里。
- **真身只移动，不删除**：收编时把 Skill 目录移进共享根，原位置换成联接。
- **遇到内容不一致的目录不覆盖**：用 `-Force` 采纳时旧的那份会改名保留为
  `.adopted-backup`，不会直接删掉。
- **`-Force` 会跳过复制前的询问**，仅在你已确认时使用。

Removing a link removes only the link; the canonical copy always stays in the
shared root. Adopting a divergent directory with `-Force` renames the old copy to
`.adopted-backup` rather than deleting it.

---

## 为新 Skill 标注能力边界 / Annotating new skills

新建或改写 Skill 时，在 frontmatter 标注范围与依赖，并在正文加一节降级说明：

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

仅某个工具自用的 Skill 标 `scope: private:<agent-id>`，不会被分发器扩散。

Frontmatter only accepts single-line `key: value`; put the dependency list on one
line, comma separated. Mark a tool-specific skill as `scope: private:<agent-id>`
so the dispatcher leaves it alone.

---

## 目录结构 / Layout

```
shared-agent-skills/
├── .codebuddy-plugin/plugin.json    ← WorkBuddy 插件清单
├── skills/shared-agent-skills/       ← Skill 本体
│   ├── SKILL.md
│   ├── README.md
│   ├── LICENSE
│   ├── skill-dependencies.json
│   ├── references/
│   │   ├── capability-matrix.md
│   │   ├── degradation-template.md
│   │   ├── hook-setup.md
│   │   └── setup-guide.md
│   └── scripts/
│       ├── check_environment.py
│       ├── detect_agents.ps1 / .sh
│       ├── share_skill.ps1 / .sh
│       ├── share_all.ps1 / .sh
│       └── unshare_skill.ps1 / .sh
└── README.md
```

---

## 安全 / Safety

脚本会移动和删除文件，但边界明确：

- 删除联接只删 reparse point，真身内容不受影响（脚本内有守卫，遇到真实目录直接拒绝）。
- 共享根内的目录只移动，不删除。
- 不读取任何凭据，不访问网络，不请求提权。
- 复制副本前必须取得确认。

The scripts move and delete files within explicit boundaries: removing a link
touches only the reparse point, canonical copies are moved rather than deleted,
no credentials are read, no network access happens, and copies require consent.

---

## 贡献 / Contributing

欢迎提 issue 和 PR。新增功能请保持两个平台的脚本行为一致，并同步更新
`skills/shared-agent-skills/references/` 下的对应文档。

Issues and pull requests are welcome. When adding features, keep the Windows
(`.ps1`) and Unix (`.sh`) variants behaviourally consistent, and update the
matching file under `skills/shared-agent-skills/references/`.

---

## 许可 / License

[MIT](skills/shared-agent-skills/LICENSE) © 王博超
