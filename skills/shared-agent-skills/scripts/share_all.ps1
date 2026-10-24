# share_all.ps1 - adopt every unshared skill on this machine into the shared root.
# Idempotent: already-shared skills are skipped.
param([string]$Root, [string]$CopyAgents = '', [switch]$Force, [switch]$WhatIf)
$ErrorActionPreference = 'Stop'
$h = $env:USERPROFILE
if (-not $Root) { $Root = Join-Path $h '.shared-agent-skills' }
$AgentDirs = @(
  (Join-Path $h '.workbuddy/skills'),
  (Join-Path $h '.config/opencode/skills'),
  (Join-Path $h '.claude/skills'),
  (Join-Path $h '.codex/skills'),
  (Join-Path $h '.cursor/skills'),
  (Join-Path $h '.gemini/skills'),
  (Join-Path $h '.codeium/windsurf/skills'),
  (Join-Path $h '.windsurf/skills'),
  (Join-Path $h '.agents/skills')
)
$seen = @{}
# the dispatcher itself lives one level above scripts/; never migrate it while running
$SelfName = Split-Path (Split-Path $PSScriptRoot -Parent) -Leaf
foreach ($d in $AgentDirs) {
  if (-not (Test-Path $d)) { continue }
  foreach ($s in (Get-ChildItem $d -Directory -Force)) {
    if ($s.Name -eq $SelfName) { continue }          # never migrate the dispatcher itself while running
    $item = Get-Item $s.FullName -Force
    if ($item.LinkType) {
      # a link already points at the canonical copy: read its real target
      $target = $item.Target
      if ($target -is [array]) { $target = $target[0] }
      if ($target -and (Split-Path $target -Leaf) -eq $s.Name -and (Test-Path $target)) {
        $real = (Resolve-Path $target).Path
      } else {
        $real = $s.FullName
      }
    } else {
      $real = $s.FullName
    }
    if ($real -like "$Root*") { continue }          # already shared
    if ($seen.ContainsKey($s.Name)) { continue }     # already queued
    $seen[$s.Name] = $real
  }
}

# The canonical copies in the shared root are the source of truth. A skill that only
# exists there still needs a link in every agent, so each canonical copy is checked
# against every agent directory and any missing link is (re)created.
if (Test-Path $Root) {
  foreach ($c in (Get-ChildItem $Root -Directory -Force)) {
    if ($c.Name -eq $SelfName) { continue }
    $canonical = Join-Path $Root $c.Name
    $needsLink = $false
    foreach ($d in $AgentDirs) {
      if (-not (Test-Path $d)) { continue }
      $probe = Join-Path $d $c.Name
      if (-not (Test-Path $probe)) { $needsLink = $true; break }
      $probeItem = Get-Item $probe -Force
      if (-not $probeItem.LinkType) { $needsLink = $true; break }
      $probeTarget = $probeItem.Target
      if ($probeTarget -is [array]) { $probeTarget = $probeTarget[0] }
      if (-not $probeTarget -or ((Resolve-Path $probeTarget).Path -ne (Resolve-Path $canonical).Path)) {
        $needsLink = $true; break
      }
    }
    if ($needsLink -and -not $seen.ContainsKey($c.Name)) {
      $seen[$c.Name] = $canonical
    }
  }
}

if ($seen.Count -eq 0) { Write-Host 'NOTHING TO SHARE (all skills already in shared root)'; exit 0 }
Write-Host "WILL SHARE: $($seen.Count) skill(s)"
foreach ($k in $seen.Keys) {
  & "$PSScriptRoot/share_skill.ps1" $seen[$k] -Root $Root -CopyAgents $CopyAgents -Force:$Force -WhatIf:$WhatIf
}
