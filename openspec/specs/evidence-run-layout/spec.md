# evidence-run-layout Specification

## Purpose

本仕様は、リポジトリ内の全統計解析スキルおよび事前検分において、エビデンスの不変性・再現性・監査証跡を担保するための標準出力ルート規約、Run単位の物理的完全隔離、識別子正規化、および後方互換探索規約を定義する。

## Requirements

### Requirement: Canonical Recommended Output Root

システムは、各解析スキルに登録された安定slugを用いて `evidence_runs/<skill_slug>/` を正規出力rootとして使用しなければならない（MUST）。明示rootは当該スキルの正規root自身またはその配下に限定し、それ以外は書込み前に拒否しなければならない（MUST）。

#### Scenario: Default output root resolution

- **WHEN** 解析ランナー実行時に明示的な出力先が指定されない
- **THEN** システムは自動的に `evidence_runs/<skill_slug>/` を出力ルート（out_root）として採用する

#### Scenario: Explicit custom output root within skill namespace

- **WHEN** 利用者がスキル規定の出力インターフェースでrootを明示する
- **THEN** システムは、解決後rootが当該スキルの `evidence_runs/<skill_slug>/` 自身またはその配下にある場合に限り受理し、その配下にrun隔離ディレクトリを作成する。namespace外、親directory成分 `..`、またはsymlinkによる逸脱は書込み前に拒否する

#### Scenario: Stable slug registry

- **WHEN** 登録済み解析スキルが正規rootを解決する
- **THEN** 次の安定対応を使用する: `vcd-bayesian-evidence-analysis` → `vcd_bayesian`; `vcd-categorical-analysis` → `vcd_categorical`; `vcd-categorical-reporting` → `vcd_categorical_reporting`; `comparative-design-analysis` → `comparative_design`; `evidence-decision-review` → `evidence_decision_review`; `questionnaire-batch-analysis` → `questionnaire`; `sas-proc-freq` → `sas_proc_freq`; `sas-proc-means` → `sas_proc_means`

#### Scenario: Unregistered skill fails closed

- **WHEN** root台帳に未登録の解析スキルが永続出力しようとする
- **THEN** システムはslugを推測せず、ディレクトリやファイルを作成する前に未登録エラーで停止する

#### Scenario: Slug lifecycle

- **WHEN** スキル名が変更・廃止される、または出力契約が非互換に変更される
- **THEN** 互換性がある名称変更ではslugを維持し、廃止済みslugを別スキルへ再利用せず、必要な場合は移行規則とともに新slugを登録する

#### Scenario: Interface boundaries preserved by skill kind

- **WHEN** 各スキルが実行される
- **THEN** システムは各スキルの規定インターフェースを厳格に適用し（`sas-proc-*` は設定JSONのみ、`vcd-categorical` は許可引数 `--out`、`inspect_data.R` は `--out-dir`）、未定義なCLI上書きや不整合な引数投入を許容しない

#### Scenario: Pre-inspection backward-compatible default output

- **WHEN** 事前検分スクリプト（`inspect_data.R`）実行時に明示的な `--out-dir` または第2引数が指定されない
- **THEN** システムは既存の呼び出し元および対話的ワークフローの後方互換性を維持するためカレントディレクトリ（`.`）への出力を許容し、明示的に `--out-dir` が渡された場合は指定されたinspection directoryへ成果物を出力する（推奨: `evidence_runs/inspections/<project>/run_<id>/`）。inspectionは分析Skill root台帳と別の成果物であり、`inspect_data.R` は指定directoryを分析Skill rootとして解決しない

### Requirement: Run Isolation and No Root Leakage

すべての新規解析実行は、出力ルート直下ではなく、一意なRun物理ディレクトリ `run_<canonical_id>[_N]/` 配下に完全に隔離して成果物を出力しなければならない（MUST）。出力ルート直下への成果物書き込みは厳格に禁止する（MUST NOT）。

#### Scenario: Artifact isolation in run directory

- **WHEN** 解析実行が正常に開始される
- **THEN** システムは登録済み正規rootまたは許可されたcustom sub-root直下に解析結果ファイル（JSON, CSV, MD, HTML等）を書き込まず、必ず `run_<canonical_id>[_N]/` を作成し、その配下に全成果物を格納する

#### Scenario: Comparative design inference persistence ownership

- **WHEN** `comparative-design-analysis` の共有推論関数が呼び出される
- **THEN** 関数は結果オブジェクトを返し、run directoryや結果ファイルを直接作成しない。将来の永続化は呼び出し側がownerとなり、登録root `evidence_runs/comparative_design/` 配下へ共通run隔離を使って保存する

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

設定JSONとCLI引数の両方で出力先が指定可能なスキルにおいて、システムは優先順位を明確に解決し、解決された論理ID、物理Runディレクトリ、出力ルート、実行状態、およびパススキーマ版を `run_meta.json` に矛盾なく記録・封緘しなければならない（MUST）。`run_meta.json` は各Runディレクトリにおける唯一の統制メタデータであり、成果物ハッシュ整合性は `results_manifest.json` と連携して担保しなければならない（MUST）。また、`run_meta.json` 内のタイムスタンプ（`timestamps` オブジェクト）は、実行環境のローカルタイムゾーン設定にかかわらず、必ず日本標準時（JST / Asia/Tokyo、オフセット `+0900` を含む ISO 8601 形式）で記録しなければならない（MUST）。

#### Scenario: Run meta consistency

- **WHEN** 解析が完了し `run_meta.json` が生成される
- **THEN** `run_meta.json` 内の `logical_run_id`、`run_output_dir`、`out_root`、`run_state`、および `path_schema_version` がディスク上の実体と完全に一致し、`results_manifest_sha256` が `results_manifest.json` の実体ハッシュと一致して封緘され、`timestamps.created` が JST（`+0900`）で記録される

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
