#!/bin/sh
set -eu

cd /Users/ton/Documents/GitHub/Meijendel/shiny_meijendel

Rscript -e 'options(shiny.launch.browser=FALSE); shiny::runApp(host="127.0.0.1", port=3867)' &
SHINY_PID=$!

cleanup() {
  kill "$SHINY_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

TS_CLI="${TAILSCALE_CLI:-/usr/local/bin/tailscale}"
if [ ! -x "$TS_CLI" ] && [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
  TS_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

"$TS_CLI" serve --bg 3867
"$TS_CLI" serve status

wait "$SHINY_PID"
