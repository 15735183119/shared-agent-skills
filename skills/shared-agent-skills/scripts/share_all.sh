#!/usr/bin/env bash
# share_all.sh - adopt every unshared skill on this machine into the shared root (idempotent).
set -u
HOME_DIR="${HOME:-$USERPROFILE}"
ROOT="${ROOT:-$HOME_DIR/.shared-agent-skills}"
FORCE=0; WHATIF=0
while [ $# -gt 0 ]; do
  case "$1" in
    -r) ROOT="$2"; shift 2;;
    -f) FORCE=1; shift;;
    --whatif) WHATIF=1; shift;;
    *) shift;;
  esac
done
AGENT_DIRS=(
  "$HOME_DIR/.workbuddy/skills"
  "$HOME_DIR/.config/opencode/skills"
  "$HOME_DIR/.claude/skills"
  "$HOME_DIR/.codex/skills"
  "$HOME_DIR/.cursor/skills"
  "$HOME_DIR/.gemini/skills"
  "$HOME_DIR/.codeium/windsurf/skills"
  "$HOME_DIR/.windsurf/skills"
  "$HOME_DIR/.agents/skills"
)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# the dispatcher itself lives one level above scripts/; never migrate it while running
SELF="$(basename "$(dirname "$SCRIPT_DIR")")"
# plain string lists instead of associative arrays: macOS ships bash 3.2 which lacks declare -A
seen_names=""
seen_paths=""
for d in "${AGENT_DIRS[@]}"; do
  [ -d "$d" ] || continue
  for s in "$d"/*/; do
    [ -d "$s" ] || continue
    bn="$(basename "$s")"
    [ "$bn" = "$SELF" ] && continue
    real="$(readlink -f "$s" 2>/dev/null || echo "$s")"
    case "$real" in "$ROOT"*) continue;; esac
    # a copy that already mirrors the canonical one counts as shared; this keeps the
    # script idempotent on hosts where `ln -s` produces a directory copy instead of a
    # symbolic link
    if [ -d "$ROOT/$bn" ]; then
      if diff -rq "$s" "$ROOT/$bn" >/dev/null 2>&1; then continue; fi
      # an empty directory is the shell of a failed `ln -s`; it must be rebuilt
      if [ -z "$(ls -A "$s" 2>/dev/null)" ]; then :; else continue; fi
    fi
    case " $seen_names " in *" $bn "*) continue;; esac
    seen_names="$seen_names $bn"
    seen_paths="$seen_paths
$real"
  done
done

# The canonical copies in the shared root are the source of truth. A skill that only
# exists there still needs a link in every agent, so each canonical copy is checked
# against every agent directory and any missing link is (re)created.
if [ -d "$ROOT" ]; then
  for c in "$ROOT"/*/; do
    [ -d "$c" ] || continue
    cn="$(basename "$c")"
    [ "$cn" = "$SELF" ] && continue
    needs=0
    for d in "${AGENT_DIRS[@]}"; do
      [ -d "$d" ] || continue
      probe="$d/$cn"
      if [ ! -e "$probe" ] && [ ! -L "$probe" ]; then needs=1; break; fi
      if [ ! -L "$probe" ]; then needs=1; break; fi
      ptarget="$(readlink -f "$probe" 2>/dev/null || echo "$probe")"
      creal="$(readlink -f "$c" 2>/dev/null || echo "$c")"
      if [ "$ptarget" != "$creal" ]; then needs=1; break; fi
    done
    if [ $needs -eq 1 ]; then
      case " $seen_names " in *" $cn "*) ;; *) seen_names="$seen_names $cn"; seen_paths="$seen_paths
$c";; esac
    fi
  done
fi

if [ -z "$(echo "$seen_names" | tr -d ' ')" ]; then
  echo "NOTHING TO SHARE (all skills already in shared root)"
  exit 0
fi
echo "WILL SHARE: $(echo "$seen_names" | wc -w | tr -d ' ') skill(s)"
OLDIFS="$IFS"
IFS='
'
for p in $seen_paths; do
  [ -n "$p" ] || continue
  if [ $FORCE -eq 1 ]; then
    "$SCRIPT_DIR/share_skill.sh" "$p" -r "$ROOT" -f
  elif [ $WHATIF -eq 1 ]; then
    "$SCRIPT_DIR/share_skill.sh" "$p" -r "$ROOT" --whatif
  else
    "$SCRIPT_DIR/share_skill.sh" "$p" -r "$ROOT"
  fi
done
IFS="$OLDIFS"
