#!/bin/sh
set -eu

cd /Users/ton/Documents/GitHub/Meijendel/shiny_meijendel

(
  sleep 2
  open "http://127.0.0.1:3867" >/dev/null 2>&1 || true
) &

Rscript -e 'options(shiny.launch.browser=FALSE); shiny::runApp(host="127.0.0.1", port=3867)'
