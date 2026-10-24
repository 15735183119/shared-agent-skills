# 自动接管：用 Hook 让共享全自动

「装好即接管所有 skill，自动共享」需要 agent 在 skill 落盘后自动触发本分发器。这依赖
agent 的 hook 能力——本 skill 提供配置思路，具体注册方式由各 agent 的 hook 机制决定。

**核实状态**：本 skill 的官方文档中没有 hook 章节，下面的配置结构来自各工具的公开惯例，
未经官方文档逐字确认。注册前请以你所用 agent 的当期文档为准；若字段名不同，按官方文档
调整命令部分即可，思路不变。

## 通用思路

注册一个在「文件写入后」或「每轮对话开始时」触发的 hook，调用：

```
share_all   # 幂等：把本机所有 agent 里未共享的 skill 收编进共享根
```

`share_all` 是幂等的：已共享的跳过，未共享的收编，不会重复处理，所以频繁触发是安全的。

**触发点建议**：匹配所有写文件操作会让每次编辑都跑一遍全量扫描。更省事的做法是把触发
点收窄到「每轮对话开始」，或只在 skill 目录被写入时触发。

## WorkBuddy 示例（结构待官方文档确认）

WorkBuddy 的 hook 配置位置与字段名请以其当期文档为准。下面是按常见结构写的模板：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "command": "powershell -ExecutionPolicy Bypass -File \"$HOME/.shared-agent-skills/shared-agent-skills/scripts/share_all.ps1\""
      }
    ]
  }
}
```

注意命令里用 `powershell` 而不是 `pwsh`：Windows 自带的是前者，`pwsh` 只有装了
PowerShell 7 才有。macOS / Linux 上换成 `bash "$HOME/.shared-agent-skills/shared-agent-skills/scripts/share_all.sh"`。

## 其他 agent

- **Claude Code**：`~/.claude/settings.json` 里的 `hooks` 段，结构与上面类似。
- **Codex**：查阅其配置文档中与 hook / 工具调用相关的设置。
- **Cursor**：`.cursor/settings.json` 或项目 `.cursor/rules`。
- **OpenCode**：其 `opencode.jsonc` 配置里的相关段落。
- **Gemini / Windsurf / Copilot**：查阅各自 hook 文档，思路一致。

## 不依赖 hook 的兜底

若某 agent 不支持 hook，或不愿注册：在该 agent 装/建 skill 后，手动说一句「共享这个
skill」，agent 即调用 `share_skill <name>`。这仍满足协议，只是少一层自动化。

这条兜底路径不依赖任何 hook 能力，是本 skill 在各平台上都能落地的保证。
