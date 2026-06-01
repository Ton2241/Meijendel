FROM rocker/shiny:latest

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
    chown -R shiny:shiny /srv/shiny-server
