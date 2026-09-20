#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
LINTER="$(command -v markdownlint-cli2 || true)"
CONFIG="$REPO_ROOT/scripts/markdownlint/safe-fix.json"

if [[ -z "$LINTER" || ! -x "$LINTER" ]]; then
  printf '%s\n' "markdownlint-cli2 が見つかりません。Homebrew で markdownlint-cli2 を導入してください。" >&2
  exit 127
fi

if [[ ! -f "$CONFIG" ]]; then
  printf '%s\n' "safe-fix 用設定が見つかりません。" >&2
  exit 2
fi

TARGET_MODE="active"
if [[ "${1:-}" == "--all" ]]; then
  TARGET_MODE="all"
  shift
elif [[ "${1:-}" == "--docs" ]]; then
  TARGET_MODE="docs"
  shift
elif [[ "${1:-}" == "--docs-archives" ]]; then
  TARGET_MODE="docs-archives"
  shift
fi

if [[ "${1:-}" != "--apply" ]]; then
  if [[ $# -gt 0 ]]; then
    printf '%s\n' "使用法: fix-safe.sh [--all|--docs|--docs-archives] [--apply]" >&2
    exit 2
  fi
  printf '%s\n' "dry-run: 安全な3ルール（MD009/MD012/MD047）の検出結果を表示します。" >&2
  APPLY_ARGS=()
else
  shift
  if [[ $# -gt 0 ]]; then
    printf '%s\n' "使用法: fix-safe.sh [--all|--docs|--docs-archives] [--apply]" >&2
    exit 2
  fi
  APPLY_ARGS=(--fix)
fi

cd "$REPO_ROOT"
if [[ "$TARGET_MODE" == "all" ]]; then
  FILES=()
  while IFS= read -r file; do FILES+=("$file"); done < <(rg --files openspec docs -g '*.md')
elif [[ "$TARGET_MODE" == "docs" ]]; then
  FILES=()
  while IFS= read -r file; do FILES+=("$file"); done < <(rg --files docs -g '*.md')
elif [[ "$TARGET_MODE" == "docs-archives" ]]; then
  FILES=()
  while IFS= read -r file; do FILES+=("$file"); done < <(rg --files docs/Archives -g '*.md')
else
  FILES=()
  while IFS= read -r file; do FILES+=("$file"); done < <(rg --files openspec/changes openspec/specs -g '*.md' -g '!openspec/changes/archive/**')
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/markdownlint-safe.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
overall_rc=0

for file in "${FILES[@]}"; do
  tmp_file="$TMP_DIR/$(basename "$file")"
  cp "$file" "$tmp_file"
  if [[ "${APPLY_ARGS[0]:-}" == "--fix" ]]; then
    if (cd "$TMP_DIR" && "$LINTER" "$(basename "$tmp_file")" --config "$CONFIG" --no-globs --fix); then
      rc=0
    else
      rc=$?
    fi
    cp "$tmp_file" "$file"
  else
    if (cd "$TMP_DIR" && "$LINTER" "$(basename "$tmp_file")" --config "$CONFIG" --no-globs); then
      rc=0
    else
      rc=$?
    fi
  fi
  if [[ $rc -ne 0 ]]; then overall_rc=$rc; fi
done

exit "$overall_rc"
