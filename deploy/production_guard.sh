#!/usr/bin/env bash

# Gedeelde productiebeveiliging voor aanvullende Meijendel-deployscripts.
# De aanroeper zet LOCAL_REPO, VPS, SSH_KEY en optioneel REMOTE_BASE.

REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
DEPLOY_STATE_DIR="${MEIJENDEL_DEPLOY_STATE_DIR:-$REMOTE_BASE/deploy-state}"
DEPLOY_STATE_FILE="$DEPLOY_STATE_DIR/Meijendel.commit"
DEPLOY_GLOBAL_LOCK="$DEPLOY_STATE_DIR/production.lock"
DEPLOY_LOCK_HELD=0
DEPLOY_LOCAL_COMMIT=""
DEPLOY_PREVIOUS_COMMIT=""

guard_die() { printf 'BLOKKADE: %s\n' "$*" >&2; exit 1; }
guard_remote() { ssh -i "$SSH_KEY" "$VPS" "$@"; }

guard_baseline() {
  cd "$LOCAL_REPO"
  "$LOCAL_REPO/scripts/check_local_workspace.sh"
  [[ -z "$(git status --porcelain)" ]] || guard_die "werkboom is niet schoon."
  [[ "$(git branch --show-current)" == "main" ]] || guard_die "productiedeploy mag alleen vanaf main."
  git fetch origin --prune
  DEPLOY_LOCAL_COMMIT="$(git rev-parse HEAD)"
  [[ "$DEPLOY_LOCAL_COMMIT" == "$(git rev-parse origin/main)" ]] || guard_die "lokale main is niet exact gelijk aan origin/main."
  DEPLOY_PREVIOUS_COMMIT="$(guard_remote "cat '$DEPLOY_STATE_FILE' 2>/dev/null || true")"
  [[ "$DEPLOY_PREVIOUS_COMMIT" =~ ^[0-9a-f]{40}$ ]] || guard_die "geldige productiestatus ontbreekt in $DEPLOY_STATE_FILE."
  git cat-file -e "$DEPLOY_PREVIOUS_COMMIT^{commit}" 2>/dev/null || guard_die "geregistreerde productiecommit is lokaal onbekend."
  git merge-base --is-ancestor "$DEPLOY_PREVIOUS_COMMIT" "$DEPLOY_LOCAL_COMMIT" || guard_die "productiecommit is geen voorouder van main."
  printf 'Main-commit: %s\nProductiecommit: %s\n' "$DEPLOY_LOCAL_COMMIT" "$DEPLOY_PREVIOUS_COMMIT"
}

guard_acquire_lock() {
  if ! guard_remote "mkdir -p '$DEPLOY_STATE_DIR' && mkdir '$DEPLOY_GLOBAL_LOCK'"; then
    guard_die "een andere productie-deploy houdt de globale VPS-lock vast."
  fi
  DEPLOY_LOCK_HELD=1
  current="$(guard_remote "cat '$DEPLOY_STATE_FILE' 2>/dev/null || true")"
  [[ "$current" == "$DEPLOY_PREVIOUS_COMMIT" ]] || guard_die "productiestatus veranderde tijdens preflight; begin opnieuw."
}

guard_write_state() {
  guard_remote "tmp='$DEPLOY_STATE_FILE.tmp.\$\$'; printf '%s\\n' '$DEPLOY_LOCAL_COMMIT' > \"\$tmp\"; mv \"\$tmp\" '$DEPLOY_STATE_FILE'"
}

guard_release_lock() {
  if [[ "$DEPLOY_LOCK_HELD" -eq 1 ]]; then
    guard_remote "rmdir '$DEPLOY_GLOBAL_LOCK' 2>/dev/null || true" || true
    DEPLOY_LOCK_HELD=0
  fi
}
