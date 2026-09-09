#!/usr/bin/env bash
# Cloud Agent environment bootstrap for agentic-evidence-analysis.
#
# Installs the R toolchain, Pandoc, Japanese (CJK) fonts, every R package the
# 4-pass analysis pipeline and test suite depend on, and pytest for the Python
# contract tests. CRAN packages are pulled as prebuilt Ubuntu binaries via r2u
# so the install is fast and deterministic.
#
# Safe to run repeatedly: apt operations are idempotent and repo/key files are
# only written when missing.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

echo "[setup] configuring APT repositories (CRAN + r2u) for ${CODENAME}"
$SUDO apt-get update -qq
$SUDO apt-get install -y --no-install-recommends \
  software-properties-common dirmngr gnupg wget ca-certificates

# Base R from the official CRAN Ubuntu repository.
if [ ! -f /etc/apt/sources.list.d/cran_r.list ]; then
  wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
    | $SUDO tee /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc >/dev/null
  echo "deb [arch=amd64] https://cloud.r-project.org/bin/linux/ubuntu ${CODENAME}-cran40/" \
    | $SUDO tee /etc/apt/sources.list.d/cran_r.list >/dev/null
fi

# r2u: CRAN packages as prebuilt .deb binaries.
if [ ! -f /etc/apt/sources.list.d/cranapt.list ]; then
  wget -qO- https://eddelbuettel.github.io/r2u/assets/dirk_eddelbuettel_key.asc \
    | $SUDO tee /etc/apt/trusted.gpg.d/cranapt_key.asc >/dev/null
  echo "deb [arch=amd64] https://r2u.stat.illinois.edu/ubuntu ${CODENAME} main" \
    | $SUDO tee /etc/apt/sources.list.d/cranapt.list >/dev/null
fi

$SUDO apt-get update -qq

echo "[setup] installing R, Pandoc, CJK fonts, R packages, pytest"
$SUDO apt-get install -y --no-install-recommends \
  r-base-core pandoc \
  fonts-noto-cjk fonts-noto-cjk-extra \
  python3-pytest \
  r-cran-dplyr r-cran-jsonlite r-cran-readr r-cran-rmarkdown \
  r-cran-tidyr r-cran-vcd r-cran-dt r-cran-effectsize \
  r-cran-ggplot2 r-cran-gt r-cran-htmltools r-cran-htmlwidgets \
  r-cran-optparse r-cran-commonmark r-cran-digest r-cran-knitr \
  r-cran-pacman r-cran-systemfonts r-cran-testthat

echo "[setup] verifying R package availability"
Rscript -e 'pkgs <- c("dplyr","jsonlite","readr","rmarkdown","tidyr","vcd","DT","effectsize","ggplot2","gt","htmltools","htmlwidgets","optparse","commonmark","digest","knitr","pacman","systemfonts","testthat"); missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]; if (length(missing)) { stop("Missing R packages: ", paste(missing, collapse = ", ")) }; cat("[setup] all", length(pkgs), "R packages available\n")'

echo "[setup] done: R $(R --version | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+'), Pandoc $(pandoc --version | head -1)"
