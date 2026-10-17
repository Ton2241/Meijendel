#!/usr/bin/env bash
set -euo pipefail

assignments=""
config=""
dry_run=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --assignments) assignments="$2"; shift 2 ;;
    --config) config="$2"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    *) echo "Onbekend argument: $1" >&2; exit 2 ;;
  esac
done
[[ -f "$assignments" ]] || { echo "Toewijzingsbestand ontbreekt" >&2; exit 2; }

if [[ -n "$config" ]]; then
  [[ -f "$config" ]] || { echo "Workerconfiguratie ontbreekt" >&2; exit 2; }
  awk -F, '
    NR == 1 { next }
    $6 == "true" && $2 == "ssh" && ($3 == "" || $4 == "") {
      print "ingeschakelde SSH-worker mist ssh_target of remote_root" > "/dev/stderr"
      exit 4
    }
    $6 == "true" && $5 != "1" {
      print "max_workers moet voor iedere ingeschakelde worker 1 zijn" > "/dev/stderr"
      exit 4
    }
  ' "$config"
fi

awk -F, '
  NR == 1 { next }
  NF < 3 || $2 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+$/ || $2 > $3 { print "ongeldige_toewijzing" > "/dev/stderr"; exit 2 }
  {
    for (i = $2; i <= $3; i++) {
      if (seen[i]++) { print "replicatie-overlap: " i > "/dev/stderr"; exit 3 }
    }
  }
' "$assignments"

if [[ "$dry_run" == true ]]; then
  echo "DRY_RUN_OK"
  exit 0
fi
echo "Werkelijke dispatch vereist een lokale, niet-gevolgde workerconfiguratie en afzonderlijk akkoord." >&2
exit 4
