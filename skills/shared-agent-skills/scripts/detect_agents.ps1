# detect_agents.ps1 - list agent skill dirs present on this machine
# Output: <agent-id>|<skills-dir>|<skill-count>
$ErrorActionPreference = 'SilentlyContinue'
$h = $env:USERPROFILE
$Agents = @(
  @{id='workbuddy';    dir=Join-Path $h '.workbuddy/skills'},
  @{id='opencode';     dir=Join-Path $h '.config/opencode/skills'},
  @{id='claude';       dir=Join-Path $h '.claude/skills'},
  @{id='codex';        dir=Join-Path $h '.codex/skills'},
  @{id='cursor';       dir=Join-Path $h '.cursor/skills'},
  @{id='gemini';       dir=Join-Path $h '.gemini/skills'},
  @{id='windsurf';     dir=Join-Path $h '.codeium/windsurf/skills'},
  @{id='windsurf-alt'; dir=Join-Path $h '.windsurf/skills'},
  @{id='copilot';      dir=Join-Path $h '.agents/skills'}
)
foreach ($a in $Agents) {
  if (Test-Path $a.dir) {
    $n = @(Get-ChildItem $a.dir -Directory -Force).Count
    "$($a.id)|$($a.dir)|$n"
  }
}
