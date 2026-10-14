# Spec Delta: two-way-evidence-analysis

## MODIFIED Requirements

### Requirement: 決定論的解析署名と拡張 Provenance

システムは、単一の決定論的SHA-256署名（Canonical Analysis Signature）を生成し、実行ディレクトリ、乱数シード導出、結果成果物、およびDashboardへ同一値を供給しなければならない（MUST）。Canonical signatureは、Pass 0で承認され、実ファイルSHAを再検証済みのcanonicalized入力・設定からのみ算出し、算出後に解析条件を変更してはならない。また、完全な監査再現性を担保するため、拡張provenance情報を `run_meta.json` および成果物に記録しなければならない。

#### Scenario: Canonical Signature の一意生成と伝播

- **WHEN** canonical解析実行を初期化する
- **THEN** 再検証済みの `engine_version`、実入力CSVの生ハッシュ `input_sha256`、正規化された解析設定ダイジェスト `canonical_config_sha256`（変数名、頻度列指定、入力モード、事前分布パラメータ、閾値設定を含む）、および成果物名に反映される `data_label` から `analysis_signature` を単一算出（SHA-256）し、ディレクトリ名（`run_<first16>`）、乱数シード、JSONメタデータ、Dashboardに同一値を埋め込む。label が異なる場合は異なる署名・別ディレクトリとして分離し、署名算出後にCLIまたは内部処理でこれらの値を変更してはならない

#### Scenario: 拡張 Provenance および環境情報の記録

- **WHEN** Canonical解析プロセスのライフサイクル（開始・失敗・成功）および解析結果成果物を生成する
- **THEN** `run_meta.json` に実行モード（`execution_mode: "canonical"`）、Pass 0 由来の検証状態（`provenance_status: "verified"`）、実入力ファイルSHA（`input_sha256`）、ディスク上の設定ファイル生ハッシュ（`config_file_sha256`）、共通 `environment` ブロック、およびタイムスタンプ（JST）を記録する。成果物JSONの既存 `provenance` ブロックへの整合を維持し、次Change（条件付き事後契約）へのハンドオフ境界とする

### Requirement: 成果物 Schema 不変量検証と Run State ライフサイクル管理

システムは、生成されるInterface 3.0成果物の構造および統計的一貫性を厳格に保証し、実行ライフサイクルの状態遷移を `run_meta.json` に記録しなければならない（MUST）。Canonical実行の失敗時は、失敗内容を監査可能に記録しつつ、正常完了を示すrun成果物を残してはならない。Runディレクトリ内の個別 `run_state.json` は廃止して `run_meta.json` の `run_state` に統合するが、Runディレクトリ作成前の早期失敗（ゲートウェイ段階）を記録する出力root直下の `run_state.json` は引き続き維持しなければならない（MUST）。

#### Scenario: 成果物 JSON の Cross-Field Invariant 検証

- **WHEN** 解析結果JSONをシリアライズする
- **THEN** serializerは canonical 実行専用とし（`execution_mode = "canonical"` のみ受入）、出力直前に推定結合確率の総和、結合確率の信用区間順序、条件付き事後の確率範囲・分位点順序・平均の総和、`evidence_profile.json` と `categorical_results.json` の `analysis_signature`・`run_id`・全セル識別キー集合、64桁の有効な `analysis_signature`・`input_sha256`・`config_sha256`（フォールバック代替生成の禁止。Canonical Core で再検証済みの `canonical_config_sha256` を受け取って記録すること）、および `provenance` ブロックの `execution_mode: "canonical"` を検証し、違反時は `SCHEMA_INVARIANT_VIOLATION` で停止する。Pass 0 承認ハッシュと最終成果物 `provenance.config_sha256` の一致は E2E 検証で保証する

#### Scenario: Run State ライフサイクルの確定記録

- **WHEN** 解析プロセスの各フェーズ（開始、失敗、成功）を遷移する
- **THEN** `run_meta.json` の `run_state`（`active / completed / failed / sealed`）を更新する。署名算出前の早期失敗時は出力root直下に `run_state.json` を作成し、`status: "failed"`、確定 `error_code`、`phase: "gateway"`、および明示的な `run_id: null`、`analysis_signature: null` を記録する。同一署名・同一出力 root の並行実行開始時は、出力root直下の予約ディレクトリ `<out_root>/.run_locks/<signature16>.lock`（`lock_info.json` 保持）による原子的署名ロックの取得を試みる。先行プロセスが実行中であれば後続プロセスは `status: "failed"`、`error_code: "CONCURRENT_RUN_IN_PROGRESS"`（エラーメッセージにロックパス、pid、取得時刻を明記）を出力root直下の `run_state.json` に記録して即時非ゼロ終了する。ロックディレクトリ自体の作成に失敗した場合は `CANNOT_CREATE_LOCK_DIR` として区別記録する。ロック取得成功後の実行開始時は `run_meta.json` の `run_state: "active"`、異常終了時は `run_state: "failed"` を記録する。正常完了時は `run_state: "completed"` を記録し、終了時に原子的署名ロックを確実に解放する。強制終了等でロックが残存（stale lock）した場合は手動削除により復旧する
