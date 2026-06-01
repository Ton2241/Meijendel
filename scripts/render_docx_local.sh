#!/usr/bin/env bash
set -euo pipefail

PYTHON="${PYTHON:-/Users/ton/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3}"
RENDER_SCRIPT="${RENDER_SCRIPT:-/Users/ton/.codex/plugins/cache/openai-primary-runtime/documents/26.521.10419/skills/documents/render_docx.py}"
LIBREOFFICE_DIR="${LIBREOFFICE_DIR:-/Applications/LibreOffice.app/Contents/MacOS}"

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
