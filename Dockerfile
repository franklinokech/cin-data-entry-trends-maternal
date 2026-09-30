FROM rocker/r-ver:4.5.2

# Force IPv4 — some networks have broken IPv6 routing
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Africa/Nairobi
ENV RENV_CONFIG_CACHE_ENABLED=FALSE
ENV RENV_CONFIG_SANDBOX_ENABLED=FALSE

# System libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libicu-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff-dev \
    libjpeg-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libgit2-dev \
    libssh2-1-dev \
    libuv1-dev \
    pandoc \
    fonts-liberation \
    tzdata \
    curl \
    git \
    gdebi-core \
    && rm -rf /var/lib/apt/lists/*

# Timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Writable HOME for the non-root container user.
# Quarto, pandoc, and R all use $HOME / $XDG_* for their caches.
RUN mkdir -p /home/app/.cache/quarto /home/app/.local/share /home/app/.config \
 && chmod -R 777 /home/app
ENV HOME=/home/app
ENV XDG_CACHE_HOME=/home/app/.cache
ENV XDG_DATA_HOME=/home/app/.local/share
ENV XDG_CONFIG_HOME=/home/app/.config
ENV QUARTO_CACHE_DIR=/home/app/.cache/quarto

# Install Quarto CLI (still needed — the R package shells out to it)
ARG QUARTO_VERSION=1.5.57
RUN curl -sSL -o /tmp/quarto.deb \
      "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
 && dpkg -i /tmp/quarto.deb \
 && rm -f /tmp/quarto.deb \
 && quarto --version

# Install renv globally
RUN R -q -e 'install.packages("renv", repos = "https://cloud.r-project.org")'

WORKDIR /app

# Lockfile drives the package set
COPY renv.lock renv.lock

# Fail fast if the GITHUB_PAT secret is missing or empty
RUN --mount=type=secret,id=GITHUB_PAT \
    test -s /run/secrets/GITHUB_PAT \
      && echo "GITHUB_PAT secret present" \
      || (echo "ERROR: GITHUB_PAT secret missing or empty" && exit 1)

# Restore all pinned packages — including the private fork of REDCapR.
# GITHUB_PAT is mounted as a BuildKit secret, so it never appears in
# the build log or in `docker history`.
RUN --mount=type=secret,id=GITHUB_PAT \
    GITHUB_PAT=$(cat /run/secrets/GITHUB_PAT) \
    R -q -e 'renv::restore(prompt = FALSE, library = "/usr/local/lib/R/site-library")'

# Sanity check — fail the build if any key package is missing
RUN R -q -e 'pkgs <- c("REDCapR","tidyverse","rmarkdown","knitr", \
                       "officer","quarto"); \
             missing <- pkgs[!pkgs %in% rownames(installed.packages())]; \
             if (length(missing)) stop("Missing: ", paste(missing, collapse = ", ")); \
             cat("All R packages OK\n")'

# Give the container user ownership of /app so Quarto can create
# and remove staging directories inside it.
ARG UID=1000
ARG GID=1000
RUN chown -R ${UID}:${GID} /app

CMD ["bash", "generate_report.sh"]