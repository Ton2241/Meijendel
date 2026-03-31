#!/bin/sh
set -eu

cd /Users/ton/Documents/GitHub/Meijendel/shiny_meijendel

(
  sleep 2
  open "http://127.0.0.1:3867" >/dev/null 2>&1 || true
) &

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
STATUS_OUTPUT=$("$TS_CLI" serve status)
TAILSCALE_URL=$(printf "%s\n" "$STATUS_OUTPUT" | awk 'NR==1 {print $1}')

printf "\nLokale URL:\n"
printf "http://127.0.0.1:3867\n"
printf "\nTailscale-URL:\n"
printf "%s\n\n" "$TAILSCALE_URL"
printf "Tailscale-configuratie:\n%s\n\n" "$STATUS_OUTPUT"

wait "$SHINY_PID"
