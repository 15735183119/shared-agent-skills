# unshare_skill.ps1 - remove all links; optionally move the canonical copy back to one agent (making it private).
# Usage: powershell unshare_skill.ps1 <name> [-To <agent-id>] [-Root <dir>]
param([string]$Name, [string]$To, [string]$Root)
$ErrorActionPreference = 'Stop'
$h = $env:USERPROFILE
if (-not $Root) { $Root = Join-Path $h '.shared-agent-skills' }
if (-not $Name) { Write-Error 'Usage: unshare_skill.ps1 <name> [-To <agent-id>]'; exit 1 }

# id|dir pairs: ids are explicit so agent identity never depends on path shapes
$AgentDirs = @(
  @{ id='workbuddy';    dir=(Join-Path $h '.workbuddy/skills') },
  @{ id='opencode';     dir=(Join-Path $h '.config/opencode/skills') },
  @{ id='claude';       dir=(Join-Path $h '.claude/skills') },
  @{ id='codex';        dir=(Join-Path $h '.codex/skills') },
  @{ id='cursor';       dir=(Join-Path $h '.cursor/skills') },
  @{ id='gemini';       dir=(Join-Path $h '.gemini/skills') },
  @{ id='windsurf';     dir=(Join-Path $h '.codeium/windsurf/skills') },
  @{ id='windsurf-alt'; dir=(Join-Path $h '.windsurf/skills') },
  @{ id='copilot';      dir=(Join-Path $h '.agents/skills') }
)

function Remove-LinkOnly([string]$Path) {
  # Delete a junction/symlink without touching its target contents.
  # Remove-Item on a link is ambiguous across hosts (it may prompt or recurse into the
  # target), so the reparse point is removed through the .NET directory API instead.
  if (-not (Test-Path $Path)) { return }
  $item = Get-Item $Path -Force
  if (-not $item.LinkType) { throw "Refusing to remove '$Path': it is a real directory, not a link." }
  [System.IO.Directory]::Delete($Path)
}

$dest = Join-Path $Root $Name
# remove links everywhere
foreach ($a in $AgentDirs) {
  $link = Join-Path $a.dir $Name
  if (Test-Path $link) {
    $isLink = [bool](Get-Item $link -Force).LinkType
    if ($isLink) { Remove-LinkOnly $link; Write-Host "UNLINKED: $link" }
    else { Write-Host "KEPT (real dir, not a link): $link" }
  }
}
# move canonical back to a specific agent -> private
if ($To) {
  $target = $AgentDirs | Where-Object { $_.id -eq $To } | Select-Object -First 1
  if (-not $target) {
    Write-Error ("agent id not found: $To (available: " + (($AgentDirs | ForEach-Object { $_.id }) -join ', ') + ")")
    exit 1
  }
  $moveTo = Join-Path $target.dir $Name
  if (Test-Path $dest) {
    if (-not (Test-Path $moveTo)) { Move-Item $dest $moveTo -Force; Write-Host "MOVED canonical -> $moveTo (now private to $To)" }
    else { Write-Host "Target already has a copy; left canonical at $dest" }
  }
} else {
  Write-Host "Canonical remains at $dest (no agent links). Set scope: private in its frontmatter."
}
