#!/usr/bin/env bash
# share_skill.sh - adopt a skill into the shared root and symlink every detected agent.
# Usage: bash share_skill.sh <name|path> [-r <root>] [-c <agent-ids>] [-f] [--whatif]
#   -c <ids>   comma-separated agent ids that cannot follow a link; they get a private
#              copy instead, and the copy is only made after the user confirms.
set -u
HOME_DIR="${HOME:-$USERPROFILE}"
ROOT="${ROOT:-$HOME_DIR/.shared-agent-skills}"
FORCE=0; WHATIF=0; NAME=""; COPY_IDS=""
while [ $# -gt 0 ]; do
  case "$1" in
    -r) ROOT="$2"; shift 2;;
    -c) COPY_IDS="$2"; shift 2;;
    -f) FORCE=1; shift;;
    --whatif) WHATIF=1; shift;;
    *) NAME="$1"; shift;;
  esac
done
[ -z "$NAME" ] && { echo "Usage: share_skill.sh <name|path> [-r <root>] [-c <agent-ids>] [-f] [--whatif]" >&2; exit 1; }

# id|dir pairs: ids are explicit so agent identity never depends on path shapes
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

agent_dir() {
  case "$1" in
    workbuddy) echo "$HOME_DIR/.workbuddy/skills";;
    opencode) echo "$HOME_DIR/.config/opencode/skills";;
    claude) echo "$HOME_DIR/.claude/skills";;
    codex) echo "$HOME_DIR/.codex/skills";;
    cursor) echo "$HOME_DIR/.cursor/skills";;
    gemini) echo "$HOME_DIR/.gemini/skills";;
    windsurf) echo "$HOME_DIR/.codeium/windsurf/skills";;
    windsurf-alt) echo "$HOME_DIR/.windsurf/skills";;
    copilot) echo "$HOME_DIR/.agents/skills";;
    *) return 1;;
  esac
}

needs_copy() {
  case ",$COPY_IDS," in
    *",$1,"*) return 0;;
    *) return 1;;
  esac
}

# resolve source
src=""
if [ -e "$NAME" ]; then
  src="$(readlink -f "$NAME" 2>/dev/null || echo "$NAME")"
else
  for entry in "${AGENT_DIRS[@]}"; do
    d="${entry#*|}"
    if [ -e "$d/$NAME" ]; then src="$(readlink -f "$d/$NAME" 2>/dev/null || echo "$d/$NAME")"; break; fi
  done
fi
[ -z "$src" ] && { echo "skill not found: $NAME" >&2; exit 1; }

skillName="$(basename "$src")"
dest="$ROOT/$skillName"
mkdir -p "$ROOT"
# already canonical? then there is nothing to move, but the agent links may still be
# missing, so continue to the linking stage instead of stopping here
case "$src" in
  "$ROOT"*) echo "ALREADY SHARED: $src (ensuring agent links)";;
  *)
    if [ ! -e "$dest" ]; then
      if [ $WHATIF -eq 1 ]; then
        echo "[WhatIf] MOVE $src -> $dest"
      else
        mv "$src" "$dest"
        echo "MOVED -> $dest"
      fi
    fi
    ;;
esac

for entry in "${AGENT_DIRS[@]}"; do
  agentId="${entry%%|*}"
  d="${entry#*|}"
  [ -d "$d" ] || continue
  link="$d/$skillName"

  if needs_copy "$agentId"; then
    reason="Agent '$agentId' cannot follow a link into the shared root (sandboxed or filesystem limit), so it needs its own copy."
    if [ $FORCE -eq 0 ]; then
      echo "COPY REQUIRED for $agentId. Reason: $reason"
      # the confirmation prompt needs a terminal; when the script runs unattended
      # (agent automation, CI) there is nobody to answer, so the copy is not made
      if [ ! -t 0 ]; then
        echo "SKIPPED (no interactive terminal to confirm): $link"
        continue
      fi
      printf 'Copy a private copy into this agent? [y/N] ' >&2
      read -r ans
      case "$ans" in [yY]*) ;; *) echo "SKIPPED (no consent): $link"; continue;; esac
    fi
    if [ -L "$link" ]; then
      rm -f "$link"
    elif [ -d "$link" ]; then
      echo "SKIP (real dir present, not a link, left untouched): $link"
      continue
    fi
    if [ $WHATIF -eq 1 ]; then
      echo "[WhatIf] COPY $dest -> $link"
    else
      cp -R "$dest" "$link"
      echo "COPIED (private) -> $link"
    fi
    continue
  fi

  if [ -L "$link" ] || [ -e "$link" ]; then
    cur="$(readlink -f "$link" 2>/dev/null || echo "$link")"
    destreal="$(readlink -f "$dest" 2>/dev/null || echo "$dest")"
    if [ "$cur" = "$destreal" ]; then echo "LINK OK: $link"; continue; fi
    if [ -L "$link" ]; then
      if [ $WHATIF -eq 1 ]; then
        echo "[WhatIf] RELINK $link -> $dest"
      else
        rm -f "$link"
        ln -s "$dest" "$link"
      fi
      echo "RELINKED: $link -> $dest"
      continue
    fi
    # an empty directory here is the shell of a failed `ln -s`; it holds nothing worth
    # keeping, so it can be replaced by the real link
    if [ -d "$link" ] && [ -z "$(ls -A "$link" 2>/dev/null)" ]; then
      if [ $WHATIF -eq 1 ]; then
        echo "[WhatIf] REPLACE empty dir $link -> $dest"
      else
        rmdir "$link" 2>/dev/null || rm -rf "$link"
        ln -s "$dest" "$link"
      fi
      echo "LINKED: $link"
      continue
    fi
    # a real directory sits where the link should be
    if [ $FORCE -eq 1 ]; then
      if [ $WHATIF -eq 1 ]; then
        echo "[WhatIf] ADOPT $link -> $dest"
        continue
      fi
      if [ ! -e "$dest" ]; then
        # this copy becomes the canonical one
        mv "$link" "$dest"
      else
        # a canonical copy already exists; keep the divergent one as a backup instead of
        # deleting it, so nothing the user wrote is lost
        backup="$link.adopted-backup"
        n=1
        while [ -e "$backup" ]; do backup="$link.adopted-backup.$n"; n=$((n+1)); done
        mv "$link" "$backup"
        echo "BACKED UP divergent copy -> $backup"
      fi
      ln -s "$dest" "$link"
      echo "ADOPTED: $link -> $dest"
      continue
    fi
    echo "SKIP (real divergent dir, use -f to adopt): $link"
    continue
  fi
  if [ $WHATIF -eq 1 ]; then
    echo "[WhatIf] LINK $link -> $dest"
  else
    ln -s "$dest" "$link"
  fi
  echo "LINKED: $link"
done
echo "DONE: $skillName is shared from $dest"
