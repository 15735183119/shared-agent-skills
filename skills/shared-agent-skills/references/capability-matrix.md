# Agent 能力与联接兼容性矩阵

本分发器默认对检测到的每个 agent 建立「联接」（Windows junction / Unix symlink）。
下面列出已验证/常见的 agent 及其 skills 目录与联接兼容性。

## 默认支持联接（直接用 junction/symlink）

| Agent | skills 目录（相对 $HOME） | 联接兼容性 |
|-------|--------------------------|-----------|
| WorkBuddy | `.workbuddy/skills` | 完全支持 junction |
| OpenCode | `.config/opencode/skills` | 完全支持 junction |
| Claude Code | `.claude/skills` | 完全支持 symlink |
| Codex CLI | `.codex/skills` | 完全支持 symlink |
| Cursor | `.cursor/skills` | 完全支持 symlink |
| Gemini CLI | `.gemini/skills` | 完全支持 symlink |
| Windsurf | `.codeium/windsurf/skills` 或 `.windsurf/skills` | 完全支持 symlink |
| Copilot / 通用 | `.agents/skills`（项目级，跨 agent 通用） | 完全支持 symlink |

以上 agent 读取的是真实文件系统，联接对它们透明，无需复制。

## 需要复制副本的例外（复制前必须询问并说明原因）

以下情况本分发器**不**静默复制，而是暂停并提示用户：

1. **agent 运行在沙箱/网页环境**，其允许读取的根被限制在自己的配置目录内，跨目录的
   联接目标会被拒绝解析。判定方式：尝试解析联接失败，或该 agent 文档明确禁止
   out-of-root 读取。
2. **文件系统不支持联接**：如技能落在 FAT/exFAT 卷（U 盘、旧移动盘）。现代
   NTFS/APFS/ext4 均支持，此情况罕见。
3. **用户显式要求隔离副本**：例如想给某 agent 一份独立修改版。

遇到上述任一情况，用 `-CopyAgents <agent-id>`（bash 版为 `-c <agent-id>`）声明该 agent
走复制路径，脚本行为：

- 输出原因（例如「OpenCode 运行在受限沙箱，无法跟随指向共享根的联接，需复制一份到其
  skills 目录」）。
- 在非交互/未确认时**中止**，不复制，并把决定权交还用户。脚本无人值守运行时无法询问，
  同样跳过复制并说明原因。
- 仅在用户确认（或带 `-Force` 的可信自动化）后才复制。副本已脱离真身，不会再被同步，
  使用者需自行更新；建议在副本的 frontmatter 标注 `scope: private:<agent>` 并写入降级
  说明。

## agent id 清单

`detect_agents` 的输出第一列即为 agent id，可直接用于 `-CopyAgents`：

| agent id | skills 目录（相对用户主目录） |
|---|---|
| `workbuddy` | `.workbuddy/skills` |
| `opencode` | `.config/opencode/skills` |
| `claude` | `.claude/skills` |
| `codex` | `.codex/skills` |
| `cursor` | `.cursor/skills` |
| `gemini` | `.gemini/skills` |
| `windsurf` | `.codeium/windsurf/skills` |
| `windsurf-alt` | `.windsurf/skills` |
| `copilot` | `.agents/skills` |

## 如何新增一个 agent 到检测列表

编辑 `scripts/detect_agents.ps1` 与 `scripts/detect_agents.sh` 里的
`$AgentDirs` / `AGENT_DIRS` 数组，加入该 agent 的 skills 目录即可。其余逻辑通用。
