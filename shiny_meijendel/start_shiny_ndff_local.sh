#!/bin/zsh
set -eu

script_dir="${0:A:h}"
export NDFF_SECURE_LOCAL=1
export MEIJENDEL_RUNTIME=local
export NDFF_MYSQL_LOGIN_PATH=meijendel_ndff_shiny

cd "$script_dir"
exec Rscript -e 'shiny::runApp(host = "127.0.0.1", port = 3868, launch.browser = TRUE)'
