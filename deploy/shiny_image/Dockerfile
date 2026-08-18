FROM rocker/shiny@sha256:70d09e27b5b9fe7aeeb4aa132f6dae39c84eb80cf10bd6638b6719be7c9f8c5a

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

RUN rm -f /srv/shiny-server/index.html && \
    mkdir -p /srv/shiny-server/shiny_meijendel/app_cache/sass && \
    chown -R shiny:shiny /srv/shiny-server
