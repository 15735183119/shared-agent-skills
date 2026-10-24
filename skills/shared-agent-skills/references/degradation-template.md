# 降级与专属能力边界模板（每个 skill 必填）

创建或被改写任何 skill 时，必须在 SKILL.md 中写入以下两处。本分发器在 `share_skill`
/ `share_all` 时不做强制校验（留给 `dna_lint` 类质检），但协议要求作者主动补齐。

## 1. frontmatter 增加字段

frontmatter 只支持单行的 `key: value`，多行列表写法会被部分工具的解析器拒绝，因此
依赖项用逗号分隔写在同一行：

```yaml
---
name: your-skill
description: 用一句话说清这个 skill 做什么、何时用
scope: shared
requires: ImageGen, VideoGen, Playwright MCP, 本地 ffmpeg
---
```

- `scope: shared`：可被本分发器扩散到所有 agent，真身存共享根。
- `scope: private:<agent-id>`：仅该 agent 自用，分发器**不会**扩散；原因写在正文。
- `requires`：列出运行所必需的外部能力，逗号分隔。任一缺失即触发降级。

## 2. 正文增加一节

在 SKILL.md 末尾加：

```markdown
## 降级与专属能力边界

- scope: shared | private:<agent>
- 依赖能力：ImageGen、VideoGen、Playwright MCP、本地 ffmpeg
- 降级行为：
  - 缺 ImageGen / VideoGen：本 skill 退化为「仅输出分析文档与提示词包」，跳过实际
    生成步骤，并提示用户切换到支持生成的 agent（如 WorkBuddy）。
  - 缺 Playwright MCP：抖音/网页类采集退化为「用户提供链接与文案」，不自动抓取。
  - 缺 ffmpeg：视频拼接/抽帧退化为「给出 ffmpeg 安装指引与手动命令」。
- 专属说明（private 时必填）：本 skill 依赖 <agent> 专有 API，拷贝到其他 agent 会
  因鉴权失败而失效，故标记为 private，不参与共享分发。
```

## 为什么必须写

- 联接解决了「读得到同一份」，但解决不了「跑得动」。某 agent 缺 skill 依赖的专属工具
  时，没有降级说明就会卡死在调不到的工具上。
- 写清 `scope` 后，本分发器能正确决策：shared 就扩散，private 就跳过并提示。
- 「某 agent 单独改了共享 skill」时，作者应意识到自己改的是真身（全机生效）；若只想
  特供，先 `unshare_skill` 变 private 再改，并在降级节说明差异来源。
