# share_skill.ps1 - adopt a skill into the shared root and link every detected agent.
# Usage: powershell share_skill.ps1 <name|path> [-Root <dir>] [-CopyAgents <ids>] [-Force] [-WhatIf]
#   -CopyAgents  comma-separated agent ids that cannot follow a link; they get a private
#                copy instead, and the copy is only made after the user confirms.
param(
  [string]$Name,
  [string]$Root,
  [string]$CopyAgents = '',
  [switch]$Force,
  [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
$h = $env:USERPROFILE
if (-not $Root) { $Root = Join-Path $h '.shared-agent-skills' }

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
$CopyIds = @()
if ($CopyAgents) { $CopyIds = $CopyAgents.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } }

function Remove-LinkOnly([string]$Path) {
  # Delete a junction/symlink without touching its target contents.
  # Remove-Item on a link is ambiguous across hosts (it may prompt or recurse into the
  # target), so the reparse point is removed through the .NET directory API instead.
  if (-not (Test-Path $Path)) { return }
  $item = Get-Item $Path -Force
  if (-not $item.LinkType) { throw "Refusing to remove '$Path': it is a real directory, not a link." }
  [System.IO.Directory]::Delete($Path)
}

if (-not $Name) { Write-Error 'Usage: share_skill.ps1 <name|path> [-Root <dir>] [-CopyAgents <ids>] [-Force] [-WhatIf]'; exit 1 }

# resolve source
$src = $null
if (Test-Path $Name) {
  $src = (Resolve-Path $Name).Path
} else {
  foreach ($a in $AgentDirs) {
    $c = Join-Path $a.dir $Name
    if (Test-Path $c) { $src = (Resolve-Path $c).Path; break }
  }
}
if (-not $src) { Write-Error "skill not found: $Name"; exit 1 }

$skillName = Split-Path $src -Leaf
$dest = Join-Path $Root $skillName
New-Item -ItemType Directory -Force -Path $Root | Out-Null

# already canonical? then there is nothing to move, but the agent links may still be
# missing, so continue to the linking stage instead of stopping here
if ($src -like "$Root*") {
  Write-Host "ALREADY SHARED: $src (ensuring agent links)"
} else {
  # move content to shared root (preserve)
  if (-not (Test-Path $dest)) {
    if ($WhatIf) { Write-Host "[WhatIf] MOVE $src -> $dest" }
    else { Move-Item $src $dest -Force; Write-Host "MOVED -> $dest" }
  }
}

# link into every agent
foreach ($a in $AgentDirs) {
  $d = $a.dir
  if (-not (Test-Path $d)) { continue }
  $agentId = $a.id
  $link = Join-Path $d $skillName
  $isLink = $false
  if (Test-Path $link) { $isLink = [bool](Get-Item $link -Force).LinkType }

  if ($CopyIds -contains $agentId) {
    # copy fallback: ask first, explain why a link cannot be used
    $reason = "Agent '$agentId' cannot follow a link into the shared root (sandboxed or filesystem limit), so it needs its own copy."
    if (-not $Force) {
      Write-Host "COPY REQUIRED for $agentId. Reason: $reason"
      # the confirmation prompt needs a terminal; when the script runs unattended
      # (agent automation, CI) there is nobody to answer, so the copy is not made
      $ans = $null
      try { $ans = Read-Host 'Copy a private copy into this agent? [y/N]' }
      catch { Write-Host "SKIPPED (no interactive terminal to confirm): $link"; continue }
      if ($ans -notmatch '^[yY]') { Write-Host "SKIPPED (no consent): $link"; continue }
    }
    if ($isLink) { Remove-LinkOnly $link }
    elseif (Test-Path $link) {
      Write-Host "SKIP (real dir present, not a link, left untouched): $link"
      continue
    }
    if ($WhatIf) { Write-Host "[WhatIf] COPY $dest -> $link" }
    else { Copy-Item $dest $link -Recurse -Force; Write-Host "COPIED (private) -> $link" }
    continue
  }

  if (Test-Path $link) {
    if ($isLink) {
      $cur = (Get-Item $link -Force).Target
      if ($cur -is [array]) { $cur = $cur[0] }
      if ($cur -and ((Resolve-Path $cur).Path -eq (Resolve-Path $dest).Path)) { Write-Host "LINK OK: $link"; continue }
      # the link points somewhere other than the canonical root; repoint it so every agent
      # reads the same single source of truth
      if ($WhatIf) { Write-Host "[WhatIf] RELINK $link -> $dest" }
      else {
        Remove-LinkOnly $link
        New-Item -ItemType Junction -Path $link -Target $dest | Out-Null
        Write-Host "RELINKED: $link -> $dest"
      }
      continue
    } else {
      # a real directory sits where the link should be
      if ($Force) {
        if ($WhatIf) { Write-Host "[WhatIf] ADOPT $link -> $dest"; continue }
        if (-not (Test-Path $dest)) {
          # this copy becomes the canonical one
          Move-Item $link $dest -Force
        } else {
          # a canonical copy already exists; keep the divergent one as a backup instead of
          # deleting it, so nothing the user wrote is lost
          $backup = "$link.adopted-backup"
          $n = 1
          while (Test-Path $backup) { $backup = "$link.adopted-backup.$n"; $n++ }
          Move-Item $link $backup -Force
          Write-Host "BACKED UP divergent copy -> $backup"
        }
        New-Item -ItemType Junction -Path $link -Target $dest | Out-Null
        Write-Host "ADOPTED: $link -> $dest"
        continue
      }
      Write-Host "SKIP (real divergent dir, use -Force to adopt): $link"
      continue
    }
  }
  if ($WhatIf) { Write-Host "[WhatIf] LINK $link -> $dest" }
  else { New-Item -ItemType Junction -Path $link -Target $dest | Out-Null; Write-Host "LINKED: $link" }
}
Write-Host "DONE: $skillName is shared from $dest"
