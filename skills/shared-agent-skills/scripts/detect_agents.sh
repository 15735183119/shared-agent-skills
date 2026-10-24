#!/usr/bin/env bash
# detect_agents.sh - list agent skill dirs present on this machine
# Output: <agent-id>|<skills-dir>|<skill-count>
HOME_DIR="${HOME:-$USERPROFILE}"
AGENTS=(
  "workbuddy:$HOME_DIR/.workbuddy/skills"
  "opencode:$HOME_DIR/.config/opencode/skills"
  "claude:$HOME_DIR/.claude/skills"
  "codex:$HOME_DIR/.codex/skills"
  "cursor:$HOME_DIR/.cursor/skills"
  "gemini:$HOME_DIR/.gemini/skills"
  "windsurf:$HOME_DIR/.codeium/windsurf/skills"
  "windsurf-alt:$HOME_DIR/.windsurf/skills"
  "copilot:$HOME_DIR/.agents/skills"
)
for entry in "${AGENTS[@]}"; do
  id="${entry%%:*}"; dir="${entry#*:}"
  if [ -d "$dir" ]; then
    # count entries that are directories or symlinks to directories
    n=$(find "$dir" -maxdepth 1 -mindepth 1 \( -type d -o -type l \) 2>/dev/null | wc -l | tr -d ' ')
    echo "$id|$dir|$n"
  fi
done
