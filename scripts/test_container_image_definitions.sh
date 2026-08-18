#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shiny="$repo/deploy/shiny_image/Dockerfile"
mysql_971="$repo/deploy/mysql_image/Dockerfile.9.7.1"
mysql_950="$repo/deploy/mysql_image/Dockerfile.9.5.0"

grep -Eq '^FROM rocker/shiny@sha256:[0-9a-f]{64}$' "$shiny"

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
