# Spec Delta: evidence-run-layout

## MODIFIED Requirements

### Requirement: Output Parameter Precedence and Run Meta Binding

設定JSONとCLI引数の両方で出力先が指定可能なスキルにおいて、システムは優先順位を明確に解決し、解決された論理ID、物理Runディレクトリ、出力ルート、実行状態、およびパススキーマ版を `run_meta.json` に矛盾なく記録・封緘しなければならない（MUST）。`run_meta.json` は各Runディレクトリにおける唯一の統制メタデータであり、成果物ハッシュ整合性は `results_manifest.json` と連携して担保しなければならない（MUST）。また、`run_meta.json` 内のタイムスタンプ（`timestamps` オブジェクト）は、実行環境のローカルタイムゾーン設定にかかわらず、必ず日本標準時（JST / Asia/Tokyo、オフセット `+0900` を含む ISO 8601 形式）で記録しなければならない（MUST）。

#### Scenario: Run meta consistency

- **WHEN** 解析が完了し `run_meta.json` が生成される
- **THEN** `run_meta.json` 内の `logical_run_id`、`run_output_dir`、`out_root`、`run_state`、および `path_schema_version` がディスク上の実体と完全に一致し、`results_manifest_sha256` が `results_manifest.json` の実体ハッシュと一致して封緘され、`timestamps.created` が JST（`+0900`）で記録される

## ADDED Requirements

### Requirement: Standardized Run State Lifecycle Vocabulary

システムは、すべての解析スキルにおけるRun実行ライフサイクルの状態語彙を `active / completed / failed / sealed` の4値に統一し、不変状態 `sealed` への不可逆遷移を保証しなければならない（MUST）。単一パス解析スキル（`vcd-categorical-reporting`, `evidence-decision-review`, `sas-proc-freq`, `sas-proc-means` 等）は正常完了時に明示的に `"completed"` を記録しなければならず（MUST）、プロセス異常終了やクラッシュにより終了処理に至らなかったRunは `"active"` のまま残る「中断されたRun」として扱わなければならない（MUST）。

#### Scenario: Run state transitions during execution lifecycle

- **WHEN** 解析処理が開始される
- **THEN** システムは `run_meta.json` の `run_state` を `"active"` として記録する
- **WHEN** すべての解析および成果物出力が正常に完了する
- **THEN** システムは `run_state` を `"completed"` へ更新する（ただしマルチパス解析スキル `vcd-bayesian-evidence-analysis` の Pass 1 等、後続描画ステージを要する初期完了は `"active"` を維持し得る）
- **WHEN** 処理中に回復不能なエラーが発生して異常終了する
- **THEN** システムがエラーを捕捉して正常に終了処理を行える場合は `run_state` を `"failed"` へ更新する。予期せぬ SIGKILL やクラッシュで終了処理が行われなかった場合は `run_state` は `"active"` のまま残存し、中断されたRunとして識別される
- **WHEN** 完了したRun成果物がアーカイブまたは封緘される
- **THEN** システムは `run_state` を `"sealed"` へ更新し、これ以降の状態変更や成果物の上書きを禁止する

### Requirement: Execution Environment Reproducibility Metadata

システムは、新規解析実行時の完全な再現性を担保するため、`run_meta.json` 内に標準化された `environment` ブロックを必須記録し、かつ環境依存の絶対パスをファイル名のみに置換したセッション情報を `session_info.txt` としてRunディレクトリ配下に出力して `results_manifest.json` に登録しなければならない（MUST）。ただし過去バージョンで生成された既存Runの読み取りにおいては、`environment` ブロックが存在しない場合でも寛容に読み取りを許可しなければならない（MUST）。

#### Scenario: Capturing runtime execution environment

- **WHEN** 新規解析が実行され `run_meta.json` が生成される
- **THEN** `run_meta.json` は `environment` オブジェクトを含み、そこには `r_version`（R文字列）、`platform`（OSプラットフォーム文字列 `R.version$platform`）、`packages`（ロード済みパッケージ名とバージョンの配列）、`seed`（乱数を使うスキルはシード値、使わないスキルは `null`）、および `session_info_path`（相対パス `"session_info.txt"`）が漏れなく記録される。また `session_info.txt` は `sessionInfo()` の出力から絶対パス（BLAS, LAPACK 等）をファイル名に置換したテキストとして出力され、環境依存の絶対パスを含まない形で `results_manifest.json` に登録される

### Requirement: Output Root Run Index and Latest Pointer

システムは、各解析スキルの出力ルート（`evidence_runs/<skill_slug>/`）直下に、過去のRun履歴を一覧する追記専用台帳 `runs_index.jsonl` と、最新の完了Runを指す原子的更新ポインタ `latest.json` を配置しなければならない（MUST）。`runs_index.jsonl` は「1行1確定事象」の履歴ログであり、同一Runが複数行に記録されることを許容し、読み取り側は `run_id` ごとの最終行を現在状態として採用しなければならない（MUST）。また `latest.json` の `path` および `runs_index.jsonl` の各行の `run_dir` は、出力 root からの相対パスとして実在する Run ディレクトリ名を指さなければならない（MUST）。

#### Scenario: Appending completed run to runs index as event log

- **WHEN** 解析Runの成果物またはマニフェストが確定（Pass 1確定、ステージ確定、封緘等）する
- **THEN** システムは出力ルート直下の `runs_index.jsonl` に対し、当該確定事象のサマリー（`run_id`、`logical_run_id`、`run_dir`（実在ディレクトリ名）、`timestamp_jst`、`run_state`、`manifest_sha256` 等）を1行のJSONオブジェクトとして追記（アペンド）する。同一Runについて後続の確定事象（例: bayesian の Pass 3 sealed）が発生した場合は新たな行として追記され、下流のインデックス読み取り処理は `run_id` ごとの末尾行を当該Runの最新状態として解釈する

#### Scenario: Atomically updating latest pointer

- **WHEN** 解析Runが正常完了（`completed` または `sealed`、あるいはPass 1確定等で最新と判定されるRun）する
- **THEN** システムは出力ルート直下の `latest.json` をシンボリックリンクを使わずに原子的ファイル置換（一時ファイル作成後のリネーム）により更新し、最新Runディレクトリへの相対パス（`path`: 実在する物理ディレクトリ名）およびメタデータを記録する。異常終了（`failed`）のRunでは `latest.json` を更新してはならない

