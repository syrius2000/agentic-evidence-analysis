# Markdown linter 簡易利用方法

created: 2026-09-20 20:10 (JST)
update: 2026-09-20 20:10 (JST)
author: Codex (GPT-5)

## 前提

Markdown linter は Homebrew で導入した `markdownlint-cli2` を使用する。リポジトリ内の `node_modules` は使用しない。

```bash
brew install markdownlint-cli2
```

ルートの `.markdownlint.json` が検査設定として使用される。`MD041`（先頭行を H1 にする規則）は無効化済みである。

## 通常の検査

リポジトリルートで次を実行する。

```bash
scripts/markdownlint/check.sh
```

対象は、archive を除く現行 OpenSpec である。

## docs 全体の検査

`docs` 以下のすべての Markdown を検査する。

```bash
scripts/markdownlint/check.sh --docs
```

Archive だけを確認する場合は次を使用する。

```bash
scripts/markdownlint/check.sh --docs-archives
```

OpenSpec と docs をまとめて検査する場合は次を使用する。

```bash
scripts/markdownlint/check.sh --all
```

## 安全な自動修正

自動修正の対象は、末尾空白、連続空行、ファイル末尾改行の3ルールに限定している。

まず dry-run で確認する。

```bash
scripts/markdownlint/fix-safe.sh --docs
```

問題がなければ、明示的に `--apply` を付けて修正する。

```bash
scripts/markdownlint/fix-safe.sh --docs --apply
```

見出し階層、表、数式、コードフェンス、OpenSpec の Requirement / Scenario は自動修正しない。修正後は次で差分を確認する。

```bash
git diff --check
git diff -- docs
```

## Git 除外

`node_modules/` はリポジトリの `.gitignore` と Git global ignore の両方で除外している。依存関係の正本は Homebrew の formula とする。
