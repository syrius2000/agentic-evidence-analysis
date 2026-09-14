## Purpose

R スクリプトおよび解析実行パイプラインにおいて、実行時の無秩序な外部ネットワークアクセスや自動パッケージインストールを排除し、必要な依存関係を実行経路ごとに事前検証して不足時に安全かつ決定論的に Fail-Fast 停止する能力を提供する。

## ADDED Requirements

### Requirement: Prohibition of Runtime Automatic Package Installation
R 解析スクリプト、共有ヘルパー（`run_scope.R` 等）、レポート生成、およびテストコードは、実行時に `pacman::p_load()` や `utils::install.packages()` によるパッケージの暗黙的・動的な自動インストールを行ってはならない（SHALL NOT）。

#### Scenario: Missing package triggers fail-fast without network access
- **WHEN** 必要な R パッケージがインストールされていない状態で R エントリポイントが実行されたとき
- **THEN** システムは外部ネットワーク接続やパッケージダウンロードを試行せず、即座に非ゼロの終了コードで停止する

#### Scenario: Test suite runs in isolated environment without network
- **WHEN** テストスイート（`tests/` 配下）がオフライン環境またはサンドボックス内で実行されたとき
- **THEN** テストコードは外部リポジトリからのパッケージ取得を試みず、既存の環境のみで合否を判定する

### Requirement: Explicit Pre-flight Dependency Verification and Guidance
システムは実行開始時に必要な依存パッケージの存在を検証し、不足している場合は実行コンテキスト（計算系、レポート系等）、不足パッケージ一覧、および事前導入に必要なコマンドを明示した日本語エラーメッセージを出力しなければならない（SHALL）。

#### Scenario: Missing calculation dependency reports actionable message
- **WHEN** Pass 0 または Pass 1 の統計計算に必要なパッケージ（`jsonlite`, `digest` 等）が未導入の環境で実行されたとき
- **THEN** システムは不足パッケージ名と手動インストール用コマンド（`install.packages(...)`）を日本語で提示して処理を中断する

### Requirement: Separation of Execution-Path Dependencies
システムは、依存関係を実行経路（Pass 0/1 の統計計算系、Pass 2 のナラティブ系、Pass 3 のダッシュボード/レポート系）ごとに分離して定義しなければならない（SHALL）。レポート・ダッシュボード表示用の外部依存（`rmarkdown`, `DT`, `htmlwidgets`, `ggplot2` 等）が不足している場合でも、統計計算処理（Pass 1）の実行可能性を妨げてはならない（SHALL NOT）。

#### Scenario: Statistical computation succeeds without report dependencies
- **WHEN** 計算に必要なパッケージのみが存在し、HTML レポート描画用パッケージが未導入の環境で Pass 1（`analysis.R`）を実行したとき
- **THEN** Pass 1 の統計計算および `evidence_results.json` の出力は正常に完了する

### Requirement: Deterministic Environment Documentation and Reproducibility Baseline
正本リポジトリは、再現実行に必要な R バージョン、必須パッケージ、および R 外のシステム依存（Pandoc 等）を明文化し、オフライン環境下で既存ライブラリのみを用いて動作確認できる検証手順を提供しなければならない（SHALL）。

#### Scenario: Offline execution verification
- **WHEN** ネットワークが完全に切断された環境で、事前導入済みライブラリを用いて回帰テストまたは解析を実行したとき
- **THEN** 外部取得エラーを起こすことなく、本変更で定義された正規回帰テストスイート（`tests/run_regression_suite.R` に定義された23本）および主要解析スクリプト（Pass 1 統計計算）が決定論的に完了する
