## MODIFIED Requirements

### Requirement: 入力受入境界と構造的ゼロの禁止

システムは、完全な2次元名義分割表（Complete 2-way contingency table）のみを入力として受入・処理しなければならない（MUST）。次元数が3以上、各軸水準数が2未満、総度数が0、いずれかの行和または列和が0（ゼロマージン）、または度数が有限非負整数でない入力はフェイルファストで拒否しなければならない。また、理論的・生理学的に発生不可能な構造的ゼロ（不完全分割表）は本エンジンの対象外（OutOfScope）とし、入力禁止として扱わなければならない。Canonical実行は、Pass 0で確定した設定と入力を唯一の解析条件とし、あらゆるデータ集約・モデル適合・解析署名算出に先行してprovenance検証と入力テーブル検証を完了しなければならない。

#### Scenario: 3次元以上の入力に対するフェイルファスト拒否と正本委譲

- **WHEN** 3次元以上の分割表（arity \(\ge 3\)）が入力される
- **THEN** 解析計算を行わずに即時停止し、`run_state.json` に `status: "failed"` および `error_code: "INVALID_INPUT_ARITY"` を記録し、3次元以上の解析は正本スキル `vcd-bayesian-evidence-analysis` を使用すべき旨のエラーメッセージを出力する

#### Scenario: 構造的ゼロ指定時のフェイルファスト拒否

- **WHEN** 入力データまたは設定において構造的ゼロ（発生不能セル）が指定される
- **THEN** 即時停止し、`run_state.json` に `status: "failed"` および `error_code: "STRUCTURAL_ZERO_NOT_SUPPORTED"` を記録し、準独立モデル等専用の解析手続きを案内する

#### Scenario: ゼロマージン表のフェイルファスト拒否

- **WHEN** いずれかの行和または列和が0である分割表（空カテゴリが存在する表）が入力される
- **THEN** 即時停止し、`run_state.json` に `status: "failed"` および `error_code: "ZERO_MARGIN_DETECTED"` を記録し、空水準の除外または再定義を案内する

#### Scenario: 入力度数形式の検証

- **WHEN** 負の度数、非有限値（NA/NaN/Inf）、非整数重み度数、または総度数 \(N=0\) の表が入力される
- **THEN** 入力検証段階で即時停止し、該当するエラーコード（`NON_INTEGER_COUNTS`, `ZERO_TOTAL_COUNT` 等）を記録して終了する

#### Scenario: Pass 0 必須契約およびプロベナンス先行検証

- **WHEN** canonical実行（`vcd-categorical-analysis`）を開始する
- **THEN** `analysis_config.json` の指定を必須とし、設定未指定時は `MISSING_REQUIRED_CONFIG` で即時停止する。指定時は共有Pass 0 provenance契約により、設定で参照された入力CSVのSHA-256、設定内の `input_sha256`、Pass 0 inspectionの入力SHA-256、および対象スキル `vcd-categorical-analysis` の一致を、解析署名算出前に検証する。ハッシュ不一致時は `PROVENANCE_SHA_MISMATCH`、スキル不一致時は `TARGET_SKILL_MISMATCH` で即時停止する

#### Scenario: Pass 0 確定設定の整合性検証（運用上の信頼済み正本照合）

- **WHEN** Pass 0 確定後に `analysis_config.json` 内の解析設定（`vars`、`freq`、`input_mode`、`practical_delta` 等）が変更された状態で canonical 実行が呼び出される
- **THEN** Pass 0 検分成果物（`inspection_results.json`）を運用上の信頼済み正本とみなし、Core 内部で現在の解析パラメータから再算出した `canonical_config_sha256` が、設定ファイル内の `pass0_provenance$canonical_config_sha256` および `inspection_results.json` 内の承認値 `approved_config$canonical_config_sha256` の両方と一致することを検証する。いずれかの未束縛または不一致時は `PROVENANCE_CONFIG_MISMATCH` で即時停止し、解析署名算出および `run_<signature>` ディレクトリ作成を一切行わない

#### Scenario: Canonical CLI 上書きおよび未知引数のホワイトリスト拒否

- **WHEN** canonical実行（`analysis.R`）において、ホワイトリスト許可引数（`--config`, `--out`, `--label`, `--help`）以外の引数（`--data`, `--vars`, `--freq`, `--input-mode`, `--prior-alpha`, `--practical-delta` 等の解析変更型引数、および未知引数）が指定される
- **THEN** システムは `CANONICAL_CONFIG_OVERRIDE_FORBIDDEN` を記録して非ゼロ終了し、解析署名、`run_<signature>` ディレクトリ、集約済みデータ、結果JSON、Dashboardを一切生成してはならない。失敗状態の記録は、指定出力root直下の `run_state.json` に限定する

#### Scenario: input_mode 安全契約と誤入力の即時遮断

- **WHEN** 入力データの集約モード（`input_mode`）を判定・検証する
- **THEN** 解析署名算出および `run_<signature>` ディレクトリ作成に先行して以下の規則を厳格に適用し、暗黙のフォールバック（`Freq=1`）を一切行わずに即時停止する：
  1. `input_mode: "aggregated"` の場合：頻度列（freq列）の指定が必須。未指定、タイポ、不在時は即時停止し、出力root直下の `run_state.json` に `status: "failed"` および `error_code: "MISSING_FREQUENCY_COLUMN"` を記録する。
  2. `input_mode: "individual"` の場合：頻度列の指定は明示的に禁止（PROHIBITED）。頻度列が設定で指定された場合、または列として検出された場合は誤設定検知として即時停止し、出力root直下の `run_state.json` に `status: "failed"` および `error_code: "FREQUENCY_COLUMN_NOT_PERMITTED"` を記録する（無視や暗黙除外は行わない）。
  3. `input_mode` が未指定、欠損、または未知値の場合は即時停止し、出力root直下の `run_state.json` に `status: "failed"` および `error_code: "INVALID_INPUT_MODE"` を記録する。

#### Scenario: データ集約処理に先行する入力検証

- **WHEN** `--render` パスで解析を実行する
- **THEN** `sum(..., na.rm=TRUE)` 等による集約やプロファイリングを行う前に `validate_input_table()` を実行し、不正な度数データによる情報の暗黙喪失を防止する

### Requirement: 決定論的解析署名と拡張 Provenance

システムは、単一の決定論的SHA-256署名（Canonical Analysis Signature）を生成し、実行ディレクトリ、乱数シード導出、結果成果物、およびDashboardへ同一値を供給しなければならない（MUST）。Canonical signatureは、Pass 0で承認され、実ファイルSHAを再検証済みのcanonicalized入力・設定からのみ算出し、算出後に解析条件を変更してはならない。また、完全な監査再現性を担保するため、拡張provenance情報を `run_state.json` および成果物に記録しなければならない。

#### Scenario: Canonical Signature の一意生成と伝播

- **WHEN** canonical解析実行を初期化する
- **THEN** 再検証済みの `engine_version`、実入力CSVの生ハッシュ `input_sha256`、正規化された解析設定ダイジェスト `canonical_config_sha256`（変数名、頻度列指定、入力モード、事前分布パラメータ、閾値設定を含む）、および成果物名に反映される `data_label` から `analysis_signature` を単一算出（SHA-256）し、ディレクトリ名（`run_<first16>`）、乱数シード、JSONメタデータ、Dashboardに同一値を埋め込む。label が異なる場合は異なる署名・別ディレクトリとして分離し、署名算出後にCLIまたは内部処理でこれらの値を変更してはならない

#### Scenario: 拡張 Provenance および環境情報の記録

- **WHEN** Canonical解析プロセスのライフサイクル（開始・失敗・成功）および解析結果成果物を生成する
- **THEN** `run_state.json` に実行モード（`execution_mode: "canonical"`）、Pass 0 由来の検証状態（`provenance_status: "verified"`）、実入力ファイルSHA（`input_sha256`）、ディスク上の設定ファイル生ハッシュ（`config_file_sha256`）、タイムスタンプ（JST）を記録する。成果物JSONの既存 `provenance` ブロックへの整合を維持し、次Change（条件付き事後契約）へのハンドオフ境界とする

### Requirement: 成果物 Schema 不変量検証と Run State ライフサイクル管理

システムは、生成されるInterface 3.0成果物の構造および統計的一貫性を厳格に保証し、実行ライフサイクルの状態遷移を `run_state.json` に記録しなければならない（MUST）。Canonical実行の失敗時は、失敗内容を監査可能に記録しつつ、正常完了を示すrun成果物を残してはならない。

#### Scenario: 成果物 JSON の Cross-Field Invariant 検証

- **WHEN** 解析結果JSONをシリアライズする
- **THEN** シリアライザは出力直前に以下の不変量を検証し、違反時はフェイルファストで停止する：
  1. 推定結合確率の総和が \(1.0 \pm 10^{-6}\) であること。
  2. 事後信用区間において \(\text{Q2.5} \le \text{median} \le \text{Q97.5}\) が全セルで成立すること。
  3. `evidence_profile.json` と `categorical_results.json` のキー整合性（`analysis_signature`, `run_id`, 全セル識別キー集合の一致）が保たれていること。違反時はエラーコード `SCHEMA_INVARIANT_VIOLATION` でフェイルファスト停止する。

#### Scenario: Run State ライフサイクルの確定記録

- **WHEN** 解析プロセスの各フェーズ（開始、失敗、成功）を遷移する
- **THEN** `run_state.json` を更新し、署名算出前の早期失敗時は出力root直下に `status: "failed"`、確定 `error_code`、`phase: "gateway"`、および明示的な `run_id: null`、`analysis_signature: null` を記録する。同一署名・同一出力 root の並行実行開始時は原子的排他ロック（`.run_lock`）の取得を試み、先行プロセスが実行中であれば後続プロセスは `status: "failed"`、`error_code: "CONCURRENT_RUN_IN_PROGRESS"` を出力root直下に記録して即時非ゼロ終了する。ロック取得成功後の実行開始時は `status: "running"`、異常終了時は `status: "failed"` を記録する。正常完了時は `status: "completed"`、`run_id`、および成果物ファイル一覧を記録し、終了時に原子的ロックを解放する。強制終了等でロックが残存（stale lock）した場合は手動削除により復旧する

## ADDED Requirements

### Requirement: 実行モード分離と Development 境界

システムは、canonical 解析実行と内部テスト専用の development 実行を厳格に分離しなければならない（MUST）。development 実行モードはインメモリ専用とし、本番成果物や `run_<signature>` ディレクトリをディスク上に一切生成してはならない。また、Canonical Core は呼び出し元のフラグのみに依存せず、独立した三者 SHA 再検証を行わなければならない。

#### Scenario: Development 実行モードによる本番成果物および run ディレクトリ生成の抑止

- **WHEN** コア関数が内部開発・テスト用として `execution_mode: "development"` で呼び出される
- **THEN** ディスク上に本番成果物（`categorical_results.json`、`evidence_profile.json`、Dashboard HTML 等）および `run_<signature>` ディレクトリを一切生成せず、インメモリの計算結果リストのみを返す。本番 Canonical 成果物との混同や誤認を防止する

#### Scenario: Canonical Core における偽造フラグおよび未検証設定の拒否

- **WHEN** `execution_mode: "canonical"` でコア関数が呼び出される
- **THEN** 呼び出し元のフラグのみに依存せず、Core 内部で必ず Pass 0 inspection、設定、実入力ファイルの独立三者 SHA 再検証を実行する。検証未完了、SHA 不一致、または偽造フラグが付与された設定が渡された場合は、即座に `PROVENANCE_SHA_MISMATCH` または `CANONICAL_CONFIG_VERIFICATION_REQUIRED` でフェイルファスト停止する
