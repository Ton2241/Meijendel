#!/usr/bin/env bash
set -euo pipefail

PYTHON="${PYTHON:-/Users/ton/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3}"
if [[ -z "${RENDER_SCRIPT:-}" ]]; then
  shopt -s nullglob
  render_candidates=(/Users/ton/.codex/plugins/cache/openai-primary-runtime/documents/*/skills/documents/render_docx.py)
  shopt -u nullglob
  if [[ "${#render_candidates[@]}" -ne 1 ]]; then
    printf 'FOUT: verwacht exact één documentrenderer, gevonden: %s. Stel RENDER_SCRIPT expliciet in.\n' "${#render_candidates[@]}" >&2
    exit 1
  fi
  RENDER_SCRIPT="${render_candidates[0]}"
fi
LIBREOFFICE_DIR="${LIBREOFFICE_DIR:-/Users/ton/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/override}"

if [ ! -x "$PYTHON" ]; then
  printf 'FOUT: Python-runtime ontbreekt: %s\n' "$PYTHON" >&2
  exit 1
fi

if [ ! -f "$RENDER_SCRIPT" ]; then
  printf 'FOUT: render_docx.py ontbreekt: %s\n' "$RENDER_SCRIPT" >&2
  exit 1
fi

if [ ! -x "$LIBREOFFICE_DIR/soffice" ]; then
  printf 'FOUT: LibreOffice soffice ontbreekt: %s\n' "$LIBREOFFICE_DIR/soffice" >&2
  exit 1
fi

PATH="$LIBREOFFICE_DIR:$PATH" "$PYTHON" "$RENDER_SCRIPT" "$@"
