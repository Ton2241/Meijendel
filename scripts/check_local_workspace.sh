#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() {
  printf 'BLOKKADE: %s\n' "$*" >&2
  exit 1
}

report_dataless() {
  local path="$1"
  printf 'BLOKKADE: bestand is niet lokaal beschikbaar:\n%s\n\n' "$path" >&2
  printf "Kies in Finder 'Behoud download' voor de map GitHub en probeer opnieuw.\n" >&2
  exit 1
}

check_tree() {
  local path="$1"
  local result

  [[ -e "$path" ]] || return 0
  if ! result="$(/usr/bin/find "$path" -flags +dataless -print -quit 2>&1)"; then
    die "lokale-bestandscontrole mislukt voor $path: $result"
  fi
  [[ -z "$result" ]] || report_dataless "$result"
}

check_tracked_files() {
  local stats result

  if ! stats="$(
    cd "$REPO_DIR"
    git ls-files -z |
      /usr/bin/xargs -0 /usr/bin/stat -f '%Sf %N' -- 2>&1
  )"; then
    die "gevolgde bestanden konden niet worden gecontroleerd: $stats"
  fi
  result="$(printf '%s\n' "$stats" |
    /usr/bin/awk '$1 ~ /(^|,)dataless(,|$)/ { sub(/^[^ ]+ /, ""); print; exit }')"
  [[ -z "$result" ]] || report_dataless "$result"
}

if [[ -n "${VWG_LOCAL_CHECK_FORCE_DATALLESS:-}" ]]; then
  report_dataless "$VWG_LOCAL_CHECK_FORCE_DATALLESS"
fi

[[ "$(uname -s)" == "Darwin" ]] || exit 0
[[ "$(git -C "$REPO_DIR" rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] ||
  die "geen geldige Git-worktree gevonden in $REPO_DIR"
GIT_DIR="$(git -C "$REPO_DIR" rev-parse --absolute-git-dir 2>/dev/null)" ||
  die "Git-metadata kon niet worden bepaald voor $REPO_DIR"

check_tree "$REPO_DIR/.git"
[[ "$GIT_DIR" == "$REPO_DIR/.git" ]] || check_tree "$GIT_DIR"
check_tracked_files

for extra_path in "$@"; do
  check_tree "$extra_path"
done
