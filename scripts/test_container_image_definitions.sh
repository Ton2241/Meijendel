#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shiny="$repo/deploy/shiny_image/Dockerfile"
shiny_rebuild="$repo/deploy/rebuild_shiny_image_vps.sh"
mysql_971="$repo/deploy/mysql_image/Dockerfile.9.7.1"
mysql_950="$repo/deploy/mysql_image/Dockerfile.9.5.0"
mysql_rebuild="$repo/deploy/rebuild_mysql_image_vps.sh"

[[ "$(grep -Ec '^FROM rocker/shiny@sha256:[0-9a-f]{64} AS (builder|runtime)$' "$shiny")" -eq 2 ]]
grep -Eq '^FROM rocker/shiny@sha256:[0-9a-f]{64} AS builder$' "$shiny"
grep -Eq '^FROM rocker/shiny@sha256:[0-9a-f]{64} AS runtime$' "$shiny"
grep -Fq 'COPY --from=builder /usr/local/lib/R/site-library/' "$shiny"
grep -Fq 'Bouwpakket hoort niet in de runtime' "$shiny"
grep -Fq 'dpkg-query -s "$package"' "$shiny"
grep -Fq -- "-name '*.so'" "$shiny"
grep -Fq 'LD_LIBRARY_PATH=/usr/local/lib/R/lib ldd' "$shiny"
grep -Fq 'https://p3m.dev/cran/__linux__/noble/2026-08-18' "$shiny"
! grep -Fq '/latest' "$shiny"
grep -Fq 'COPY renv.lock DESCRIPTION install_shiny_packages.R' "$shiny"
grep -Fq 'install_shiny_packages.R' "$shiny"
grep -Fq 'restore' "$shiny"

runtime_stage="$(sed -n '/ AS runtime$/,$p' "$shiny")"
runtime_packages="$(printf '%s\n' "$runtime_stage" | sed -n '/^RUN apt-get update/,/&& apt-mark manual/p')"
for package in build-essential cmake g++ gcc gfortran make r-base-dev libc6-dev \
  linux-libc-dev libcurl4-openssl-dev libglpk-dev libgmp3-dev libssl-dev \
  libudunits2-dev libxml2-dev; do
  if printf '%s\n' "$runtime_packages" | grep -Fq "    $package"; then
    printf 'FOUT: bouwpakket staat in de Shiny-runtimefase: %s.\n' "$package" >&2
    exit 1
  fi
done
grep -Fq 'apt-get purge -y --auto-remove' "$shiny"
for package in libcurl4t64 libgfortran5 libglpk40 libgmp10 libssl3t64 \
  libstdc++6 libudunits2-0 libuv1t64 libxml2 perl; do
  printf '%s\n' "$runtime_packages" | grep -Fq "    $package"
done

grep -Fq 'buildx build' "$shiny_rebuild"
grep -Fq -- '--pull --no-cache --load' "$shiny_rebuild"
grep -Fq -- '--image "$CANDIDATE_ID"' "$shiny_rebuild"
grep -Fq '127.0.0.1:3839:3838' "$shiny_rebuild"
grep -Fq 'remote_cleanup_or_rollback' "$shiny_rebuild"
grep -Fq 'chown -R "$(id -u):$(id -g)" /app_cache' "$shiny_rebuild"
grep -Fq 'docker image rm "$OLD_IMAGE_ID"' "$shiny_rebuild"
grep -Fq 'SWITCH_STARTED=0' "$shiny_rebuild"
grep -Fq 'docker image inspect "$OLD_IMAGE_ID"' "$shiny_rebuild"
grep -Fq 'expected_candidate_tag="AANDACHT|container-hygiene|onverwachte-imagetag=$CANDIDATE_TAG"' "$shiny_rebuild"
grep -Fq 'unexpected_tags" == "$expected_candidate_tag' "$shiny_rebuild"
grep -Fq 'VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl' "$shiny_rebuild"
grep -Fq 'LOCAL_LOCKFILE="$LOCAL_REPO/renv.lock"' "$shiny_rebuild"
grep -Fq '/opt/vwgm-build/renv.lock' "$shiny_rebuild"
grep -Fq -- '--candidate-only' "$shiny_rebuild"
grep -Fq -- '--activate-candidate=' "$shiny_rebuild"
grep -Fq -- '--candidate-image=' "$shiny_rebuild"
grep -Fq 'phase8-promotie|bewijs-en-image=exact' "$shiny_rebuild"
grep -Fq 'baseline_args+=(--image "$EXPECTED_CANDIDATE_ID" --allow-image-tag "$CANDIDATE_TAG")' "$shiny_rebuild"
grep -Fq -- '--allow-image-tag "$CANDIDATE_TAG"' "$shiny_rebuild"
grep -Fq 'sha256sum -c SHA256SUMS' "$shiny_rebuild"
grep -Fq 'PREVIOUS_TAG="vwgm-shiny:rollback-$short_commit"' "$shiny_rebuild"
grep -Fq 'phase8-rollback|tag=%s|image=%s|bewaard' "$shiny_rebuild"
grep -Fq 'production_activated=yes' "$shiny_rebuild"
grep -Fq 'candidate_remote_script="$(base64' "$shiny_rebuild"
grep -Fq "printf '%s' '\$candidate_remote_script' | base64 -d" "$shiny_rebuild"
grep -Fq "bash '\$remote_candidate_helper'" "$shiny_rebuild"
! grep -Fq 'bash -s" <<' "$shiny_rebuild"
grep -Fq '/usr/local/libexec/vwgm-admin/vulnerability-audit-root \' "$shiny_rebuild"
grep -Fq -- '--image "$CANDIDATE_ID" --allow-image-tag "$CANDIDATE_TAG"' "$shiny_rebuild"
grep -Fq 'production_activated=no' "$shiny_rebuild"
grep -Fq 'active_image_unchanged=' "$shiny_rebuild"
grep -Fq 'candidate.cdx.json' "$shiny_rebuild"
grep -Fq 'GROEN|phase8-sbom|componenten=' "$shiny_rebuild"
grep -Fq 'check_shiny_dashboard_parity.R' "$shiny_rebuild"
grep -Fq 'ServerAliveInterval=30' "$shiny_rebuild"
grep -Fq 'ServerAliveCountMax=20' "$shiny_rebuild"
grep -Fq 'timeout --signal=TERM --kill-after=30s 3600s' "$shiny_rebuild"
grep -Fq 'VOORTGANG|phase8-kandidaat|pariteit' "$shiny_rebuild"
grep -Fq 'BLOKKADE|phase8-kandidaat|pariteit-timeout-na-3600-seconden' "$shiny_rebuild"
grep -Fq -- '--entrypoint dpkg-query "$CANDIDATE_ID"' "$shiny_rebuild"
grep -Fq -- "-W '-f=\${binary:Package}\\t\${Version}\\n'" "$shiny_rebuild"
! grep -Fq -- '--entrypoint sh "$CANDIDATE_ID" -lc' "$shiny_rebuild"
grep -Fq 'cache=eerste-load-en-hergebruik' "$shiny_rebuild"
grep -Fq '[[ "$(docker inspect --format' "$shiny_rebuild"
candidate_scan_prelude="$(sed -n '/^CANDIDATE_ID=.*docker image inspect/,/^AUDIT_OUTPUT=/p' "$shiny_rebuild")"
grep -Fq 'docker buildx rm "$BUILDER_NAME"' <<<"$candidate_scan_prelude"
grep -Fq 'docker image rm moby/buildkit:buildx-stable-1' <<<"$candidate_scan_prelude"
candidate_finalization="$(sed -n '/^chmod 0644 .*EVIDENCE_DIR/,/GROEN|phase8-kandidaat|image=/p' "$shiny_rebuild")"
grep -Fq 'docker rm -f "$CANDIDATE_CONTAINER"' <<<"$candidate_finalization"
grep -Fq 'productie=ongewijzigd' <<<"$candidate_finalization"
! grep -Fq 'docker buildx rm "$BUILDER_NAME"' <<<"$candidate_finalization"
! grep -Fq 'docker image rm moby/buildkit:buildx-stable-1' <<<"$candidate_finalization"

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
grep -Fq 'ARG MYSQL_UID=1999' "$mysql_971"
grep -Fq 'ARG MYSQL_GID=1999' "$mysql_971"
grep -Fq 'groupmod --gid "$MYSQL_GID" mysql' "$mysql_971"
grep -Fq 'usermod --uid "$MYSQL_UID" --gid "$MYSQL_GID" mysql' "$mysql_971"
grep -Fq 'test "$(id -u mysql)" -eq "$MYSQL_UID"' "$mysql_971"
grep -Fq 'test "$(id -g mysql)" -eq "$MYSQL_GID"' "$mysql_971"
[[ -x "$mysql_rebuild" ]]
grep -Fq 'rebuild_mysql_image_vps.sh' "$repo/deploy/README_DEPLOY.md"

grep -Eq '^FROM mysql@sha256:[0-9a-f]{64}$' "$mysql_950"
grep -Fq -- '--disablerepo=mysqlinnovation-server-minimal' "$mysql_950"
grep -Fq "mysql --version | grep -Fq 'Ver 9.5.0 '" "$mysql_950"

printf 'OK: containerimages zijn versie- en digestvast en blokkeren MySQL-upgrades.\n'
