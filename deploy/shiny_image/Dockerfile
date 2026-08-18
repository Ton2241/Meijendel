FROM rocker/shiny@sha256:70d09e27b5b9fe7aeeb4aa132f6dae39c84eb80cf10bd6638b6719be7c9f8c5a AS builder

ENV CRAN=https://p3m.dev/cran/__linux__/noble/latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    g++ \
    libcurl4-openssl-dev \
    libglpk-dev \
    libgmp3-dev \
    libssl-dev \
    libudunits2-dev \
    libuv1 \
    libxml2-dev \
    make \
    perl \
    && rm -rf /var/lib/apt/lists/*

COPY install_shiny_packages.R /tmp/install_shiny_packages.R
RUN Rscript /tmp/install_shiny_packages.R && rm -f /tmp/install_shiny_packages.R

FROM rocker/shiny@sha256:70d09e27b5b9fe7aeeb4aa132f6dae39c84eb80cf10bd6638b6719be7c9f8c5a AS runtime

ENV CRAN=https://p3m.dev/cran/__linux__/noble/latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4t64 \
    libgfortran5 \
    libglpk40 \
    libgmp10 \
    libssl3t64 \
    libstdc++6 \
    libudunits2-0 \
    libuv1t64 \
    libxml2 \
    perl \
    && apt-mark manual \
      libcurl4t64 libgfortran5 libglpk40 libgmp10 libssl3t64 libstdc++6 \
      libudunits2-0 libuv1t64 libxml2 perl \
    && apt-get purge -y --auto-remove \
      build-essential \
      cmake \
      g++ \
      gcc \
      gfortran \
      libc6-dev \
      libcurl4-openssl-dev \
      libglpk-dev \
      libgmp3-dev \
      libssl-dev \
      libudunits2-dev \
      libxml2-dev \
      linux-libc-dev \
      make \
      r-base-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/R/site-library/ /usr/local/lib/R/site-library/

RUN set -eu; \
    for package in build-essential cmake g++ gcc gfortran make r-base-dev \
      libc6-dev linux-libc-dev libcurl4-openssl-dev \
      libglpk-dev libgmp3-dev libssl-dev libudunits2-dev libxml2-dev; do \
      if dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | \
        grep -q '^ii'; then \
        echo "Bouwpakket hoort niet in de runtime: $package" >&2; \
        exit 1; \
      fi; \
    done; \
    if find /usr/local/lib/R/site-library -type f -name '*.so' \
      -exec env LD_LIBRARY_PATH=/usr/local/lib/R/lib ldd {} \; | \
      grep -F 'not found'; then \
      echo 'Een R-package mist een gekoppelde runtimebibliotheek.' >&2; \
      exit 1; \
    fi

RUN rm -f /srv/shiny-server/index.html && \
    mkdir -p /srv/shiny-server/shiny_meijendel/app_cache/sass && \
    chown -R shiny:shiny /srv/shiny-server
