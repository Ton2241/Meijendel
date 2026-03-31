#!/bin/sh
set -eu

cd /Users/ton/Documents/GitHub/Meijendel/shiny_meijendel
Rscript -e 'options(shiny.launch.browser=TRUE); shiny::runApp(host="127.0.0.1", port=3867)'
