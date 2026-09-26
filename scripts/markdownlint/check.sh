#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
LINTER="$(command -v markdownlint-cli2 || true)"
CONFIG="$REPO_ROOT/.markdownlint.json"

if [[ -z "$LINTER" || ! -x "$LINTER" ]]; then
  printf '%s\n' "markdownlint-cli2 が見つかりません。Homebrew で markdownlint-cli2 を導入してください。" >&2
  exit 127
fi

if [[ ! -f "$CONFIG" ]]; then
  printf '%s\n' ".markdownlint.json が見つかりません。" >&2
  exit 2
fi

if [[ "${1:-}" == "--all" ]]; then
  shift
  TARGETS=("openspec/**/*.md" "docs/**/*.md")
elif [[ "${1:-}" == "--docs" ]]; then
  shift
  TARGETS=("docs/**/*.md")
elif [[ "${1:-}" == "--docs-archives" ]]; then
  shift
  TARGETS=("docs/Archives/**/*.md")
else
  TARGETS=("openspec/changes/**/*.md" "#openspec/changes/archive/**/*.md" "openspec/specs/**/*.md")
fi

if [[ $# -gt 0 ]]; then
  printf '%s\n' "使用法: check.sh [--all|--docs|--docs-archives]" >&2
  exit 2
fi

cd "$REPO_ROOT"
exec "$LINTER" "${TARGETS[@]}" --config "$CONFIG"
