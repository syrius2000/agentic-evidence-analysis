# evidence-run-layout Specification

## Purpose

本仕様は、リポジトリ内の全統計解析スキルおよび事前検分において、エビデンスの不変性・再現性・監査証跡を担保するための標準出力ルート規約、Run単位の物理的完全隔離、識別子正規化、および後方互換探索規約を定義する。

## Requirements

### Requirement: Canonical Recommended Output Root

システムは、全解析スキルの推奨既定出力ルートとして `evidence_runs/<skill_slug>/` を提供しなければならない（MUST）。ただし利用者が明示した別の出力ルートは、パストラバーサル等の安全性検証を通過する限り尊重しなければならない（MUST）。

#### Scenario: Default output root resolution

- **WHEN** 解析ランナー実行時に明示的な出力先が指定されない
- **THEN** システムは自動的に `evidence_runs/<skill_slug>/` を出力ルート（out_root）として採用する

#### Scenario: Explicit custom output root

- **WHEN** 利用者が明示的にスキル規定のインターフェース（`vcd-*` / `questionnaire` の `--out` / `--output_dir`、または `sas-proc-*` の設定JSON `output_dir`）で検証可能な出力先を指定する
- **THEN** システムは指定された出力先を出力ルートとして採用し、その配下にRun隔離ディレクトリを作成する

#### Scenario: Interface boundaries preserved by skill kind

- **WHEN** 各スキルが実行される
- **THEN** システムは各スキルの規定インターフェースを厳格に適用し（`sas-proc-*` は設定JSONのみ、`vcd-categorical` は許可引数 `--out`、`inspect_data.R` は `--out-dir`）、未定義なCLI上書きや不整合な引数投入を許容しない

#### Scenario: Pre-inspection backward-compatible default output

- **WHEN** 事前検分スクリプト（`inspect_data.R`）実行時に明示的な `--out-dir` または第2引数が指定されない
- **THEN** システムは既存の呼び出し元および対話的ワークフローの後方互換性を維持するためカレントディレクトリ（`.`）への出力を許容し、明示的に `--out-dir` が渡された場合はその指定ディレクトリ配下（推奨: `evidence_runs/inspections/<project>/run_<id>/`）へ成果物を隔離出力する

### Requirement: Run Isolation and No Root Leakage

すべての新規解析実行は、出力ルート直下ではなく、一意なRun物理ディレクトリ `run_<canonical_id>[_N]/` 配下に完全に隔離して成果物を出力しなければならない（MUST）。出力ルート直下への成果物書き込みは厳格に禁止する（MUST NOT）。

#### Scenario: Artifact isolation in run directory

- **WHEN** 解析実行が正常に開始される
- **THEN** システムは出力ルート直下に解析結果ファイル（JSON, CSV, MD, HTML等）を直接書き込まず、必ず `run_<id>/` サブディレクトリを作成してその配下にのみ全成果物を格納する

### Requirement: Run Identifier Normalization and Collision Handling

システムは、指定された論理Run IDから物理ディレクトリ名を構成する際、先頭の `run_` プレフィックスを一度だけ正規化し、`run_run_*` のような二重プレフィックスを生成してはならない（MUST NOT）。また同名のRunディレクトリが既に存在する場合は、原子的予約により `_2`, `_3` 等のサフィックスを付与して既存成果物の上書きを防止しなければならない（MUST）。

#### Scenario: Normalization of run ID prefix

- **WHEN** 利用者または設定が `run_001` という論理IDを指定する
- **THEN** システムは物理ディレクトリ名として `run_run_001` ではなく `run_001` を生成する

#### Scenario: Unspecified questionnaire run ID

- **WHEN** `questionnaire-batch-analysis` 実行時に `--run-id` が未指定または既定値の場合
- **THEN** システムは曖昧な固定値（`run_default`）を使わず、JST時刻（`YYYYMMDD_HHMMSS`）を含む一意な論理IDを生成して隔離ディレクトリ `run_<YYYYMMDD_HHMMSS>/` に出力する

#### Scenario: Collision avoidance on identical run ID

- **WHEN** 指定されたRunディレクトリが既にディスク上に存在する
- **THEN** システムは既存ディレクトリを上書きせず、原子的予約処理により `run_<id>_2` のように一意な新規ディレクトリを確保して書き込む

### Requirement: Questionnaire Run Layout and Backward-Compatible Discovery

`questionnaire-batch-analysis` の新規解析出力は他スキルと同様に `evidence_runs/questionnaire/run_<id>/` に統一しなければならない（MUST）。ただし、過去に生成された既存の `runs/<id>/` 成果物は移動・改名・削除せず、読み取り専用の探索対象として解決可能に維持しなければならない（MUST）。

#### Scenario: New questionnaire run write

- **WHEN** `questionnaire-batch-analysis` で新規バッチ解析を実行する
- **THEN** 成果物は `evidence_runs/questionnaire/run_<id>/` 配下に出力され、設問別成果物は `<output_slug>/report.html` に格納される

#### Scenario: Backward-compatible reading of legacy runs

- **WHEN** 下流処理（レポート集約、ダッシュボード等）が旧形式の `runs/<id>/` パスまたは過去のRun成果物を参照する
- **THEN** システムは旧レイアウトを破壊せず、読取り専用として正しく成果物を探索・読み込みできる

### Requirement: Path Safety and Symbolic Link Traversal Guard

システムは、指定された出力パスおよび入力パスに対してパストラバーサル（`../` 等）や出力ルート外を指すシンボリックリンクを検証し、境界外アクセスを即座に拒否しなければならない（MUST）。

#### Scenario: Path traversal attempt rejected

- **WHEN** 出力先またはRun IDに `../` や不正な記号を含むパスが渡される
- **THEN** システムはファイル作成前にエラーを報告して即時停止する

### Requirement: Output Parameter Precedence and Run Meta Binding

設定JSONとCLI引数の両方で出力先が指定可能なスキルにおいて、システムは優先順位を明確に解決し、解決された論理ID、物理Runディレクトリ、出力ルート、およびパススキーマ版を `run_meta.json` に矛盾なく記録・封緘しなければならない（MUST）。

#### Scenario: Run meta consistency

- **WHEN** 解析が完了し `run_meta.json` が生成される
- **THEN** `run_meta.json` 内の `logical_run_id`、`run_output_dir`、`out_root`、および `path_schema_version` がディスク上の実体と完全に一致する
