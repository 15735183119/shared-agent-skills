---
name: shared-agent-skills
description: 跨 Agent 的 Skill 共享分发器。安装后本机所有 agent（WorkBuddy、OpenCode、Claude Code、Codex、Cursor、Gemini、Windsurf、Copilot）的 skill 安装与创建都按统一协议处理：单一真身存放在用户级共享根，各 agent 通过目录联接自动读取同一份，改一处全机生效；无法跟随联接的 agent 退化为私有副本且复制前先询问并说明原因；创建或改写 skill 时必须标注专属能力边界与降级方式。当用户说"共享这个 skill""装到所有 agent""所有人都能用""统一分发 skill"，或安装、新建、复制、迁移任何 skill 时触发。
version: 1.1.0
agent_created: true
---

# 跨 Agent Skill 共享分发器

## 你为什么需要它

SKILL.md 已经是开放标准（Agent Skills，agentskills.io 维护），Claude Code、
Codex、Cursor、Gemini、Windsurf、Copilot、OpenCode、WorkBuddy 等 40+ 工具都读
同一套格式。但每个 agent 只扫自己的目录，没有"全局公共目录"被所有家认。结果：同一套
方法论你在每台 agent 里各装一份、各改各的、迟早漂移。

本 skill 解决这件事：**装一次，全机所有 agent 共享同一份真身。**

## 核心协议（装好即生效）

1. **唯一真身**：所有被共享的 skill 只存一份，位于用户级共享根
   `~/.shared-agent-skills/<skill-name>/`。这是跨平台路径（Windows / macOS /
   Linux 都展开 `$HOME`）。
2. **自动联接**：本机检测到的每个 agent 的 `skills/` 目录，都用联接指向共享根里的
   同一份（Windows 用 junction，macOS/Linux 用 symlink）。应用层完全透明，读到的
   就是真身。
3. **改一处，全机生效**：因为所有 agent 指向同一份真身，谁改了内容，其他 agent 立刻
   看到。这是设计目标，不是副作用。
4. **例外才复制，且先问**：只有"该 agent 无法跟随联接"（沙箱禁止跨目录读取、或
   FAT 等不支持联接的文件系统）时才退化为复制副本。复制前**必须**向用户说明原因并
   取得确认，绝不静默复制。
5. **创建即标注边界**：新建或被改写（含某 agent 单独改了共享 skill）时，必须写入
   `## 降级与专属能力边界` 一节，声明 `scope`（shared / private:<agent>）与
   `requires`（依赖的能力/工具），并写明缺失时的降级行为。仅某工具自用的 skill 标
   为 `private:<agent>`，不会被本分发器扩散。

## 触发方式

- 用户显式说"共享 / 装到所有 agent / 所有人都能用 / 统一分发" → 调用 `share_skill`。
- 用户安装或新建任意 skill 后 → 调用 `share_skill` 把它纳入共享根。
- 想一次性把本机已有 skill 全部收编 → 调用 `share_all`。
- 想让某 skill 退回"仅某 agent 私有" → 调用 `unshare_skill`。
- **完全自动接管**：把本 skill 提供的 hook（见 `references/hook-setup.md`）注册到
  各 agent，之后任何 skill 落盘都会自动触发共享，无需手动说。hook 是 agent 能力，
  本 skill 提供配置模板与注册指引，不等同于魔法拦截。

## 命令（脚本在 scripts/）

| 命令 | 作用 |
|------|------|
| `detect_agents` | 列出本机检测到的 agent 及其 skills 目录 |
| `share_skill <name\|path>` | 把某个 skill 收编进共享根并联接所有 agent |
| `share_all` | 扫描所有 agent，把未共享的 skill 全部收编（幂等） |
| `unshare_skill <name> [-To <agent>]` | 撤掉所有联接，可选把真身迁回某个 agent 变私有 |

Windows 用 `scripts/*.ps1`，macOS/Linux 用 `scripts/*.sh`。

**平台差异**：Windows 侧用 junction（免管理员权限），Unix 侧用符号链接。macOS 自带的
bash 是 3.2，脚本已避开 4.0 才有的关联数组等语法，可在 3.2 上直接运行。若在 Windows
的 Git Bash 里运行 `.sh` 版本，`ln -s` 不会创建符号链接而是普通目录副本，共享不会自动
收敛——Windows 请用 `.ps1` 版本。

示例（PowerShell）：
```powershell
# 探测本机 agent
powershell scripts/detect_agents.ps1
# 把刚装的 fangying-video-dna 共享给全机
powershell scripts/share_skill.ps1 fangying-video-dna
# 一次性收编全部
powershell scripts/share_all.ps1
# 指定某个 agent 无法跟随联接，改用私有副本（会先询问）
powershell scripts/share_skill.ps1 fangying-video-dna -CopyAgents claude
```

## 无法跟随联接的 agent 怎么办

少数 agent 运行在受限沙箱里，或落在不支持链接的文件系统上，此时无法读取共享根里的
真身。这类 agent 改用**私有副本**：

- 通过 `-CopyAgents <agent-id>`（bash 版为 `-c <agent-id>`）声明，逗号分隔多个。
- 脚本会先说明原因再询问是否复制；**未确认不会复制**。脚本无人值守运行时（agent 自动
  化、CI）无法询问，此时会跳过复制并说明原因，不会静默产生副本。
- 副本是独立副本，不再随真身更新，使用者需自行同步。
- agent id 取自 `detect_agents` 的输出：`workbuddy`、`opencode`、`claude`、`codex`、
  `cursor`、`gemini`、`windsurf`、`windsurf-alt`、`copilot`。

## 降级与专属能力边界（创建 skill 的强制项）

每个被本分发器管理的 skill 必须包含这一节，模板见
`references/degradation-template.md`。要点：

- frontmatter 增加 `scope: shared` 或 `scope: private:<agent-id>`（单行写法）。
- 声明 `requires:`，列出依赖的能力/工具（如 ImageGen、VideoGen、Playwright MCP、
  本地 ffmpeg），逗号分隔。
- 写清"缺能力时怎么退"：例如"在缺少 ImageGen 的 agent 中，本 skill 退化为仅输出分析
  文档，跳过生成步骤，并提示用户切换到支持的 agent"。
- `private:<agent>` 的 skill 明确"不会被 shared-agent-skills 分发，原因：依赖该
  agent 专有 API"，并写明若被强制拷贝过去会如何失效。

## 重要边界（本 skill 不负责）

- **读得到 ≠ 跑得动**：联接只解决"各 agent 能看到同一份"。若某 agent 缺 skill 依赖的
  专属工具，靠降级说明兜底，本分发器不替你改 skill 逻辑。
- **别在联接里改共享 skill 却不告知**：你改的是真身，全机都会变。若只想给某 agent 特
  供，先 `unshare_skill` 变私有再改。
- **hook 注册是 agent 侧动作**：本 skill 给模板，但能否自动触发取决于各 agent 是否
  支持 hook 以及你是否注册了它。

## 删除操作的边界

脚本会移动和删除文件，规则如下：

- **删联接只删链接本身**：联接通过系统的目录 API 移除，只摘掉链接，不触碰真身内容。
  真身永远留在共享根里。
- **真身只移动，不删除**：收编时是把 skill 目录移进共享根，原位置换成联接。
- **遇到内容不一致的目录不覆盖**：若某个 agent 位置已经是一份独立目录，`share_all`
  会跳过并提示；用 `-Force` 采纳时，若共享根已有同一份，旧的那份会被改名保留为
  `.adopted-backup`，不会直接删掉。
- **`-Force` 会跳过复制前的询问**：仅在你已经确认过的情况下使用。

## 回滚

删掉某 agent `skills/` 下的联接即可，真身不受影响；要彻底撤销共享，跑
`unshare_skill <name> -To <agent>` 把真身迁回并清除其余联接。
