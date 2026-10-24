#!/usr/bin/env bash
# unshare_skill.sh - remove all symlinks; optionally move canonical copy back to one agent (private).
# Usage: bash unshare_skill.sh <name> [-t <agent-id>] [-r <root>]
set -u
HOME_DIR="${HOME:-$USERPROFILE}"
ROOT="${ROOT:-$HOME_DIR/.shared-agent-skills}"
TO=""; NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    -t) TO="$2"; shift 2;;
    -r) ROOT="$2"; shift 2;;
    *) NAME="$1"; shift;;
  esac
done
[ -z "$NAME" ] && { echo "Usage: unshare_skill.sh <name> [-t <agent-id>]" >&2; exit 1; }

AGENT_DIRS=(
  "workbuddy|$HOME_DIR/.workbuddy/skills"
  "opencode|$HOME_DIR/.config/opencode/skills"
  "claude|$HOME_DIR/.claude/skills"
  "codex|$HOME_DIR/.codex/skills"
  "cursor|$HOME_DIR/.cursor/skills"
  "gemini|$HOME_DIR/.gemini/skills"
  "windsurf|$HOME_DIR/.codeium/windsurf/skills"
  "windsurf-alt|$HOME_DIR/.windsurf/skills"
  "copilot|$HOME_DIR/.agents/skills"
)
dest="$ROOT/$NAME"
for entry in "${AGENT_DIRS[@]}"; do
  d="${entry#*|}"
  link="$d/$NAME"
  # only remove the symlink itself; the canonical copy in the shared root stays untouched
  if [ -L "$link" ]; then rm -f "$link"; echo "UNLINKED: $link";
  elif [ -d "$link" ]; then echo "KEPT (real dir, not a link): $link"; fi
done
if [ -n "$TO" ]; then
  target=""
  for entry in "${AGENT_DIRS[@]}"; do
    agentId="${entry%%|*}"
    if [ "$agentId" = "$TO" ]; then target="${entry#*|}"; break; fi
  done
  [ -z "$target" ] && { echo "agent dir not found for: $TO" >&2; exit 1; }
  moveTo="$target/$NAME"
  if [ -e "$dest" ]; then
    if [ ! -e "$moveTo" ]; then mv "$dest" "$moveTo"; echo "MOVED canonical -> $moveTo (now private to $TO)";
    else echo "Target already has a copy; left canonical at $dest"; fi
  fi
else
  echo "Canonical remains at $dest (no agent links). Set scope: private in its frontmatter."
fi
