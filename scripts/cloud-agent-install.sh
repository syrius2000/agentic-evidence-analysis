#!/usr/bin/env bash
# =============================================================================
# scripts/cloud-agent-install.sh
# Cursor Cloud Agent 用の冪等な開発環境セットアップスクリプト。
#
# 本リポジトリ（agentic-evidence-analysis）の R 統計解析パイプラインを
# 実行するために必要なシステム依存（R, Pandoc, 描画系ライブラリ）と
# R パッケージ（README.md / references/dependencies.md の完全な和集合）を導入する。
#
# 鉄則1（実行時自動インストール禁止）に従い、解析スクリプト自体は一切
# パッケージを自動導入しない。本スクリプトは「事前導入」を担う専用の
# セットアップ経路であり、解析実行経路からは呼び出されない。
#
# 冪等性: 既に導入済みの apt パッケージ / R パッケージはスキップする。
# =============================================================================
set -euo pipefail

echo "[cloud-agent-install] 開始"

# ---------------------------------------------------------------------------
# 1. システム依存（R, Pandoc, 描画・フォント系ライブラリ）
# ---------------------------------------------------------------------------
APT_PKGS=(
  r-base r-base-dev
  pandoc
  libcurl4-openssl-dev libssl-dev libxml2-dev
  libfontconfig1-dev libfreetype-dev libharfbuzz-dev libfribidi-dev
  libpng-dev libtiff5-dev libjpeg-dev
  fonts-noto-cjk
)

missing_apt=()
for p in "${APT_PKGS[@]}"; do
  if ! dpkg -s "$p" >/dev/null 2>&1; then
    missing_apt+=("$p")
  fi
done

if [ "${#missing_apt[@]}" -gt 0 ]; then
  echo "[cloud-agent-install] apt パッケージを導入: ${missing_apt[*]}"
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends "${missing_apt[@]}"
else
  echo "[cloud-agent-install] apt パッケージは導入済み（スキップ）"
fi

# ---------------------------------------------------------------------------
# 2. R パッケージ（Posit Public Package Manager のバイナリで高速導入）
#    README.md「事前一括インストール用 R コマンド」の完全な和集合 + testthat。
#    testthat は回帰テストスイート（tests/）の実行に必須。
# ---------------------------------------------------------------------------
R_LIB="/usr/local/lib/R/site-library"
sudo mkdir -p "$R_LIB"

sudo Rscript - "$R_LIB" <<'RSCRIPT'
args <- commandArgs(trailingOnly = TRUE)
lib  <- args[[1]]

# noble 用 P3M バイナリリポジトリ（ソースコンパイルを回避し高速・決定論的に導入）
options(
  repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/noble/latest"),
  HTTPUserAgent = sprintf(
    "R/%s R (%s)",
    getRversion(),
    paste(getRversion(), R.version[["platform"]], R.version[["arch"]], R.version[["os"]])
  ),
  Ncpus = max(1L, parallel::detectCores())
)

pkgs <- c(
  # コア計算・データ検分（Pass 0 / Pass 1）
  "jsonlite", "digest", "dplyr", "readr", "tidyr", "effectsize", "vcd", "optparse",
  # レポート・描画（Pass 2 / Pass 3）
  "rmarkdown", "knitr", "DT", "htmltools", "htmlwidgets", "ggplot2", "gt", "katex",
  # 回帰テストスイート実行
  "testthat"
)

installed <- rownames(installed.packages())
need <- setdiff(pkgs, installed)
if (length(need) > 0L) {
  cat("[cloud-agent-install] R パッケージを導入:", paste(need, collapse = ", "), "\n")
  install.packages(need, lib = lib, dependencies = c("Depends", "Imports", "LinkingTo"))
} else {
  cat("[cloud-agent-install] R パッケージは導入済み（スキップ）\n")
}

missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1L), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("R パッケージの導入に失敗しました: ", paste(missing, collapse = ", "))
}
cat("[cloud-agent-install] 全 R パッケージの導入を確認しました。\n")
RSCRIPT

echo "[cloud-agent-install] 完了"
