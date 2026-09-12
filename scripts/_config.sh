#!/usr/bin/env bash
# Shared path resolution for the shell scripts in this directory. Sourced, never executed.
#
# Resolution order: environment variable > config.env > default.
# This file is the one home for the path rules (see docs/maintenance-workflow.md, rule 5).

_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$_REPO_ROOT/config.env" ]; then
  # Plain KEY=VALUE lines; existing environment variables win.
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    key="${line%%=*}"
    value="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
    [ -n "$key" ] || continue
    if [ -z "$(printenv "$key" || true)" ]; then
      export "$key=$value"
    fi
  done < "$_REPO_ROOT/config.env"
fi

AGENT_HOME="${AGENT_HOME:-$_REPO_ROOT/example-agent}"
AGENT_SKILLS_ROOT="${AGENT_SKILLS_ROOT:-$AGENT_HOME/skills}"
AGENT_BACKUP_DIR="${AGENT_BACKUP_DIR:-$_REPO_ROOT/.backups}"
AGENT_CONTEXT_FILES="${AGENT_CONTEXT_FILES:-IDENTITY.md USER.md MEMORY.md POINTERS.md}"
AGENT_SNAPSHOT_KEEP="${AGENT_SNAPSHOT_KEEP:-20}"
export AGENT_HOME AGENT_SKILLS_ROOT AGENT_BACKUP_DIR AGENT_CONTEXT_FILES AGENT_SNAPSHOT_KEEP

# Never overwrite a backup: file.ext -> file.ext-1 -> file.ext-2 ...
unique_path() {
  local candidate="$1" n=0
  while [ -e "$candidate" ]; do
    n=$((n + 1))
    candidate="$1-$n"
  done
  printf '%s' "$candidate"
}

require_positive_int() {  # $1 = value, $2 = flag name
  case "$1" in
    ''|*[!0-9]*) echo "[x] $2 needs a positive integer, got '$1'" >&2; return 2 ;;
  esac
  [ "$1" -ge 1 ] || { echo "[x] $2 must be at least 1" >&2; return 2; }
  return 0
}
