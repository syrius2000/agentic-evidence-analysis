## Context

現在の R 実行基盤では、`pacman::p_load()` による実行時の CRAN からの自動インストール処理（`vcd-bayesian-evidence-analysis`, `vcd-categorical-analysis`, `render_dashboard.R` 等）や、共有モジュール `.agents/shared/run_scope.R` における `install.packages()`、さらにテストコード内でのパッケージ自動取得が混在している。
これにより、サンドボックス環境、イントラネット環境、書き込み権限が制限された環境において、ネットワーク遮断やパーミッションエラーでスクリプトが異常終了し、再現性や監査証跡が損なわれる原因となっている。
詳細は [proposal.md](proposal.md) および [specs/deterministic-r-dependencies/spec.md](specs/deterministic-r-dependencies/spec.md) を参照。

## Goals / Non-Goals

**Goals:**

- **実行時自動インストールの根絶**: 本番解析スクリプト、共有ランタイム、テストコードの全経路から `install.packages()` および `pacman::p_load()` を完全に排除する。
- **共有 Fail-Fast 機構の導入**: 共通モジュール `.agents/shared/dependency_check.R` を新設し、実行目的（Pass 0/1 計算、Pass 3 レポート、テスト等）に応じた事前依存チェックと、親切な手動導入案内（日本語）を提供する。
- **実行経路ごとの依存分離**: 統計計算（Pass 1）とレポート・ダッシュボード生成（Pass 3）の依存関係を分離し、可視化系パッケージの不足が統計計算の妨げにならないようにする。
- **名前空間の明示**: スクリプト本文で `jsonlite::`, `dplyr::` 等の名前空間修飾を徹底し、依存追跡性を高める。
- **決定論的再現性の確立**: 依存パッケージ一覧およびオフライン動作確認の基準を文書化・整備する。

**Non-Goals:**

- 統計解析コア（`vcd`, `effectsize`, `rmarkdown`, `DT` 等）の全面的な Base R 書き換え（統計量の定義・区間推定・既存回帰テストの一貫性を維持するため、現フェーズでは急がない）。
- CRAN へのパッケージ公開。
- 実行時の自動更新や動的パッケージマネジメント。

## Decisions

### 1. 共有依存検査モジュール `.agents/shared/dependency_check.R` の新設

各スクリプトに重複してチェック処理を記述するのではなく、リポジトリ共通の依存検査モジュールを新設する。

- **関数仕様**:

  ```r
  check_r_dependencies <- function(required, context = "実行")
  ```

  `requireNamespace(pkg, quietly = TRUE)` で判定し、未導入パッケージが存在する場合は、即座に手動インストール用コマンド（`install.packages(c(...))`）を案内して `stop(..., call. = FALSE)` で Fail-Fast 停止する。
- **代替案**:
  - *各ファイルへの関数コピー*: コード重複と保守性の悪化を招くため却下。
  - *`library()` のみの使用*: パッケージ不足時に標準の不親切なエラー（`there is no package called 'xxx'`）で落ち、ネットワーク遮断理由や対処コマンドが利用者に伝わらないため却下。

### 2. `.agents/shared/run_scope.R` およびテストコードの安全化

- `run_scope.R` 内の `install.packages("digest")` / `install.packages("jsonlite")` を削除し、`check_r_dependencies(c("jsonlite", "digest"), "Run隔離管理")` に置換する。
- `tests/` 配下のテストスクリプト（`test_narrative_claims_gate.R`, `test_three_way_computation_engine.R` 等）に残存する `pacman` インストール処理を削除し、オフラインサンドボックスで安全に完結させる。

### 3. 実行経路（Pass 0/1, Pass 2, Pass 3）に応じた依存の疎結合化

- **Pass 0 / Pass 1（計算系）**: `jsonlite`, `digest`, `dplyr`, `tidyr`（および必要に応じた `effectsize`）のみを必須とし、重い UI / レポート依存を要求しない。
- **Pass 2（ナラティブ・品質系）**: `jsonlite`（およびハッシュ計算用 `digest`）のみ。
- **Pass 3（ダッシュボード・HTML系）**: `rmarkdown`, `knitr`, `DT`, `htmltools`, `htmlwidgets`, `katex`, `ggplot2`。
- **効果**: ヘッドレスな計算環境や CI において、Pandoc や HTML レンダラーがない状態でも統計計算（Pass 1）と成果物 JSON 出力を正常に完了できる。

### 4. Base R 化の優先順位付け

- **直ちに実施**: CSV 読み込みや基礎集計における不要な tidyverse 依存の削減（例: `utils::read.csv` の活用）。
- **段階的維持**: `effectsize::cramers_v` や `vcd` によるモザイク図、`DT` による動的テーブル等のドメイン・表示コアは、安易に自作置換せずパッケージ依存として明示管理する。

## Risks / Trade-offs

- **[初期セットアップの手間]** → スクリプト実行時の「勝手にインストールしてくれる」利便性は失われる。
  - *Mitigation*: README および `references/dependencies.md` に、ワンライナーで全依存を事前導入できる `install.packages(...)` コマンドを明確に記載する。また、エラーメッセージ自体にコピー＆ペースト可能なコマンドを含める。
- **[環境ごとのコンパイル失敗]** → 一部のパッケージ（`effectsize` 等）が C/C++ コンパイルを要する場合がある。
  - *Mitigation*: ドキュメントにおいて「環境によっては OS ビルドツール（Xcode Command Line Tools や build-essential）が必要になる」旨を明記する。
- **[共有ランタイムのパス解決]** → `.agents/shared/dependency_check.R` を各スクリプトから確実に `source` できる必要がある。
  - *Mitigation*: 既存の `find_agent_repo()` / `run_scope.R` と同じ上位探索ロジックを用いて安全に解決する。

## Migration Plan

1. **Phase 1: 共有依存検査基盤の作成**
   - `.agents/shared/dependency_check.R` を作成。
   - `run_scope.R` から自動インストールコードを除去し、依存検査に切り替える。
2. **Phase 2: 各スキルテンプレートの脱 pacman / Fail-Fast 化**
   - `vcd-bayesian-evidence-analysis`（`analysis.R`, `render_dashboard.R`）
   - `vcd-categorical-analysis`（`analysis.R`）
   - `questionnaire-batch-analysis`（`batch_runner.R`）
   - `.agents/shared/inspect_data.R`
3. **Phase 3: テストコードおよびドキュメントの改修**
   - `tests/` 内の自動インストールを除去。
   - `README.md` および各 `dependencies.md` を手動セットアップ前提に更新。
   - 正規回帰スイート（`tests/run_regression_suite.R` の23本）の一括検証。

## Verification Scope and Residual Test Tracking

本変更においてオフライン決定論的実行を保証する検証対象境界は、正本仕様に合致する「正規回帰テストスイート（`tests/run_regression_suite.R` に定義された23本）」および Pass 1 主要解析保証を担う隔離テスト（`test_dependency_isolation_pass1.R`）とする。

リポジトリ内の残余テスト（数理エンジン刷新に伴うレガシーテスト、Pandoc/描画環境依存テスト、境界ストレステスト等）は、本変更（実行時自動インストール排除・決定論的依存管理）の合否判定対象外とし、詳細な分類台帳（`tests/test_inventory_manifest.csv`）に基づき将来のテスト現代化課題（Tech Debt）として追跡する。
