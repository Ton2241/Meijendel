#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shiny="$repo/deploy/shiny_image/Dockerfile"
shiny_rebuild="$repo/deploy/rebuild_shiny_image_vps.sh"
mysql_971="$repo/deploy/mysql_image/Dockerfile.9.7.1"
mysql_950="$repo/deploy/mysql_image/Dockerfile.9.5.0"

[[ "$(grep -Ec '^FROM rocker/shiny@sha256:[0-9a-f]{64} AS (builder|runtime)$' "$shiny")" -eq 2 ]]
grep -Eq '^FROM rocker/shiny@sha256:[0-9a-f]{64} AS builder$' "$shiny"
grep -Eq '^FROM rocker/shiny@sha256:[0-9a-f]{64} AS runtime$' "$shiny"
grep -Fq 'COPY --from=builder /usr/local/lib/R/site-library/' "$shiny"
grep -Fq 'Bouwpakket hoort niet in de runtime' "$shiny"
grep -Fq -- "-name '*.so' -exec ldd" "$shiny"

runtime_stage="$(sed -n '/ AS runtime$/,$p' "$shiny")"
runtime_packages="$(printf '%s\n' "$runtime_stage" | sed -n '/^RUN apt-get update/,/rm -rf/p')"
for package in cmake g++ make linux-libc-dev libcurl4-openssl-dev libglpk-dev \
  libgmp3-dev libssl-dev libudunits2-dev libxml2-dev; do
  if printf '%s\n' "$runtime_packages" | grep -Fq "    $package"; then
    printf 'FOUT: bouwpakket staat in de Shiny-runtimefase: %s.\n' "$package" >&2
    exit 1
  fi
done
for package in libcurl4t64 libgfortran5 libglpk40 libgmp10 libssl3t64 \
  libstdc++6 libudunits2-0 libuv1t64 libxml2 perl; do
  printf '%s\n' "$runtime_packages" | grep -Fq "    $package"
done

grep -Fq 'buildx build' "$shiny_rebuild"
grep -Fq -- '--pull --no-cache --load' "$shiny_rebuild"
grep -Fq -- '--image "$CANDIDATE_ID"' "$shiny_rebuild"
grep -Fq '127.0.0.1:3839:3838' "$shiny_rebuild"
grep -Fq 'remote_cleanup_or_rollback' "$shiny_rebuild"
grep -Fq 'docker image rm "$OLD_IMAGE_ID"' "$shiny_rebuild"
grep -Fq 'VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl' "$shiny_rebuild"

for file in "$mysql_971" "$mysql_950"; do
  grep -Eq '^FROM golang@sha256:[0-9a-f]{64} AS gosu-builder$' "$file"
  grep -Fq '6456aaa0f3c854d199d0f037f068eb97515b7513' "$file"
  grep -Fq 'microdnf remove -y mysql-shell' "$file"
  grep -Fq -- '--disablerepo=mysql-tools-community' "$file"
  grep -Fq 'gosu nobody id -u | grep -qx 65534' "$file"
done

grep -Eq '^FROM mysql@sha256:[0-9a-f]{64}$' "$mysql_971"
grep -Fq -- '--disablerepo=mysql9.7-server-minimal' "$mysql_971"
grep -Fq "mysql --version | grep -Fq 'Ver 9.7.1 '" "$mysql_971"

grep -Eq '^FROM mysql@sha256:[0-9a-f]{64}$' "$mysql_950"
grep -Fq -- '--disablerepo=mysqlinnovation-server-minimal' "$mysql_950"
grep -Fq "mysql --version | grep -Fq 'Ver 9.5.0 '" "$mysql_950"

printf 'OK: containerimages zijn versie- en digestvast en blokkeren MySQL-upgrades.\n'
