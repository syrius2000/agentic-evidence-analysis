# Design

## Context

全解析スキルにおいて出力ルートは `evidence_runs/<skill_slug>/` に統一されているが、Run内部のメタデータ表現、ライフサイクル状態、再現性メタデータの記録契約に不統一が存在する。
本設計では、`run_meta.json` を単一の実行統制メタデータ、`results_manifest.json` を成果物整合性メタデータとして位置づけ、冗長・個別なメタファイル（SASの `manifest.json`、VCDのrun内 `run_state.json`）を廃止・統合する。
また、出力ルート直下において過去実行を効率的に一覧・監査するための `runs_index.jsonl` と `latest.json` を導入し、同一署名並行実行の排他ロックを共通署名ロック（`.run_locks`）として規律化する。

## Goals / Non-Goals

**Goals:**
- `run_meta.json` をすべての解析スキルにおける唯一無二のRun統制メタデータとする。
- SASスキルの個別 `manifest.json` を廃止し、内容を `run_meta.json` および `results_manifest.json` の既存項目・新設 `environment` ブロックへ完全に移送する。
- `run_meta.json` のタイムスタンプ（`timestamps` オブジェクト）を JST（`Asia/Tokyo`、オフセット `+0900` 付き ISO 8601）で固定記録し、旧 `manifest.json` の JST 保証および AGENTS.md 契約を維持する。
- `vcd-categorical-analysis` のrun内 `run_state.json` を廃止し、ライフサイクル状態を `run_meta.json` の `run_state` フィールドへ一本化する（ただし、run未作成段階の早期失敗を記録する出力root直下の `run_state.json` は維持）。
- 単一パススキル（`vcd-categorical-reporting`, `evidence-decision-review`）が正常完了時に `run_state = "completed"` を明示記録するようにし、全単一パススキルで `completed` への遷移を統一する。
- `run_state` の語彙を `active / completed / failed / sealed` に統一し、不変状態 `sealed` への不可逆遷移を保証する。クラッシュ等で終了処理に至らなかった run は `active` のまま残る「中断された run」として定義する。
- 共通の実行環境情報（Rバージョン、OS platform、依存パッケージ名とバージョン、乱数シード、session_infoパス）を `run_meta.json` に記録し、完全な `session_info.txt` を生成してマニフェスト登録する。
- 出力ルート直下に追記専用の `runs_index.jsonl`（1行1確定事象の履歴ログ）と、原子的更新による `latest.json` を配備する。
- 出力ルート直下の予約ディレクトリ `.run_locks` による排他署名ロックの仕様を明文化し、run列挙処理では `run_*` フィルタリングを徹底する。

**Non-Goals:**
- 物理Runディレクトリ名の決定ロジックの変更（現行specおよび実装の規則を維持する）。
- 統計推定値、乱数生成数理、信頼区間計算式の変更。
- 主結果ファイル（JSON, CSV, MD, HTML）のデータ構造や命名規則の変更。
- 過去のアーカイブ、完了済みQAサイクル、歴史的fixtureの改変。
- 既存run（過去の `manifest.json` 等を持つディレクトリ）の自動破壊的マイグレーション。

## Decisions

### 1. 物理名決定規則の現状維持と事実確認 (H1)

各スキルの物理ディレクトリ名は `reserve_run_output_dir` および各ランナーが決定しており、当初の「明示IDをsha256化して物理名にする」という仮説は事実と異なるため撤回する。

| スキル | 物理ディレクトリ名（run_id）の決定規則 | logical_run_id |
|---|---|---|
| `questionnaire-batch-analysis` | 渡された `--run-id` の先頭16文字（未指定時はJST日時 `YYYYMMDD_HHMMSS`） | 指定された論理ID（未指定時は日時） |
| `sas-proc-freq` | 設定JSON `run_id` の先頭16文字 | 設定JSON `run_id` |
| `sas-proc-means` | 設定JSON `run_id` の先頭16文字 | 設定JSON `run_id` |
| `vcd-categorical-reporting` | 渡された `run_id` の先頭16文字（未指定時は物理名） | 指定された論理ID |
| `evidence-decision-review` | 渡された `run_id` の先頭16文字（未指定時はJST日時） | 指定された論理ID |
| `vcd-bayesian-evidence-analysis` | ID指定ありなら `sanitize_run_slug(id)`、ID未指定なら入力ファイルSHA-256先頭16文字 | 指定された論理ID（未指定時はNULL） |
| `vcd-categorical-analysis` | 解析署名（`analysis_signature`）の先頭16文字 | 設定上の論理ラベル |
| `comparative-design-analysis` | （in-memory推論器のため直接出力なし。将来callerが永続化） | （同左） |

- **結論**: 現行 spec（`evidence-run-layout`）に規定されている「論理ID `run_001` → 物理名 `run_001`」は上記スキル群で現行実装と整合しており、物理名の命名規則は一切変更しない。`logical_run_id` の `run_meta.json` への記録は現行 spec で既に要求済みである。

### 2. スキル別ライフサイクルと run_state 遷移契約 (M1, 決定1)

#### スキル別ライフサイクル表

| スキル | write_run_meta 呼出 | 書き込む run_state の値と時点（現状 → 改定後） | sealed に至るか | 備考 |
|---|---|---|---|---|
| `vcd-bayesian-evidence-analysis` | `analysis.R:517` | `"active"`（Pass 1 完了時。現状・改定後とも維持） | 至る（Pass 3 完了時） | マルチパス。Pass 1 は `"active"` のまま完了。Pass 2 で `pass_status$pass2="completed"`、Pass 3 確定時に `run_state="sealed"` へ遷移 |
| `vcd-categorical-analysis` | `analysis.R:75`, `526` | 早期失敗: `"failed"`<br>正常完了: `"completed"`（現状・改定後とも維持） | 現状至らない | 単一Pass実行。従来は run 内 `run_state.json` に二重記録していたが `run_meta.json` に一本化 |
| `vcd-categorical-reporting` | `comparative_reporting.R:1794` | 現状: `"active"`（既定値）<br>→ **改定後: 正常完了時に `"completed"` を明記** | 現状至らない | 単一パス一括バッチ生成。正常完了時に `completed` を記録するよう改修 |
| `questionnaire-batch-analysis` | `batch_runner.R:621` | 全設問成功: `"completed"`<br>一部・全問失敗: `"failed"`（現状・改定後とも維持） | 現状至らない | バッチ集約完了時に設問失敗有無に応じて判定 |
| `sas-proc-freq` | `run_freq.R:1297` | `"completed"`（現状・改定後とも維持） | 現状至らない | 3点セット生成完了時に呼出 |
| `sas-proc-means` | `run_means.R:683` | `"completed"`（現状・改定後とも維持） | 現状至らない | 3点セット生成完了時に呼出 |
| `evidence-decision-review` | `evidence_feature_extract.R:418` | 現状: `"active"`（既定値）<br>→ **改定後: 正常完了時に `"completed"` を明記** | 現状至らない | 単一パス特徴量抽出。正常完了時に `completed` を記録するよう改修 |
| `comparative-design-analysis` | 呼ばない | — | — | in-memory推論器。永続化ownerは不在 |

#### 許可遷移契約と「中断された run」の定義

`run_state` の許可遷移は以下の通り厳格に定義される：
- `active` → `completed`: 解析・主成果物出力が正常完了した時点。単一パススキルはすべてこの遷移を完了する。
- `active` → `failed`: 実行中に回復不能なエラーが発生し、スキルがエラーハンドラ内で失敗を正常記録した時点。
- `completed` → `sealed`: 完了したRunが改ざん防止・凍結処理された時点（不可逆）。
- `failed` および `sealed` は終端状態（Terminal State）であり、いかなる状態への遷移も禁止される。
- **マルチパス例外**: `vcd-bayesian-evidence-analysis` のように後続ステージ（Pass 2 / Pass 3）が存在するスキルでは、Pass 1 完了時点では未完了（後続処理可能）であることを示すため `run_state` は `"active"` を維持し、最終ステージ（Pass 3）完了時に `finalize_stage()` を経て直接 `"sealed"` へ遷移することが許容される。
- **「中断された run（active のまま残る run）」の扱い**:
  - プロセスの予期せぬクラッシュ、SIGKILL、ハードウェア障害等で終了処理（`completed` または `failed` の書き込み）に至らなかった run は、`active` のままディスク上に残存する。
  - `failed` はスキルが明示的にエラーを捕捉して記録できた場合にのみ設定されるため、`active` のまま残存している run は「中断された run（未完またはクラッシュ）」として識別・監査される。

#### runs_index.jsonl と latest.json の更新事象 (決定2)

- **`runs_index.jsonl` の追記時点とセマンティクス**:
  - 出力 root 直下の `runs_index.jsonl` は、「1行1run」ではなく**「1行1確定事象」の履歴ログ**である。
  - 各スキルの `write_run_meta()` 実行時、または `finalize_stage()` 実行時など、**Runの成果物とマニフェストが確定（確定フック呼び出し）した事象**において1行のJSONオブジェクトを追記する。
  - 従って、マルチパススキル等で同一 `run_id` が複数行記録されてよい（例: bayesian の Pass 1 確定時の行と、Pass 3 sealed 確定時の行）。
  - 下流の読み取り側は、`run_id` ごとの最後の行を、その run の最新の確定状態として採用する。
- **`latest.json` の更新時点**:
  - Runが正常に完了または確定した事象において更新する。
  - 条件: `run_state %in% c("completed", "sealed")`、またはマルチパススキルで主解析成果物（Pass 1）が確定し `results_manifest_sha256` が束縛された正常Run。異常終了（`failed`）のRunでは更新しない。
  - 単一パススキルである `vcd-categorical-reporting` および `evidence-decision-review` が正常終了時に `completed` を記録するよう改修されるため、全スキルの正常完了 run に対して `latest.json` の更新条件が矛盾なく成立する。

### 3. SAS PROC FREQ / MEANS における `manifest.json` 廃止と実在項目移送対応 (M2, M3, 決定3, LOW)

SAS PROC FREQ / MEANS で出力されていた `manifest.json` は廃止し、すべての監査項目を `run_meta.json`（実在項目）および `results_manifest.json`（実在項目）へ1対1で移送する。

| 旧 `manifest.json` 項目 | 移送先ファイル | 移送先の既存項目名 / 新設項目名 | 備考 |
|---|---|---|---|
| `manifest_version` | `results_manifest.json` | `interface_version` | 実在するスキーマ版項目（"1.0"） |
| `run_id` | `run_meta.json` | `run_id` および `logical_run_id` | 実在する物理ID・論理ID項目 |
| `timestamp_jst` | `run_meta.json` | `timestamps.created` | 実在するタイムスタンプ項目。**JST（Asia/Tokyo、+0900）で固定記録する（write_run_meta の変更を伴う）** |
| `input_file.path` | `run_meta.json` | `inputs[].source_path` | 実在する入力ソースパス項目（role="data" の要素） |
| `input_file.sha256` | `run_meta.json` | `inputs[].sha256` | 実在する入力ハッシュ項目（role="data" の要素） |
| `artifacts.<name>.path` | `results_manifest.json` | `artifacts[].path` | 実在する成果物相対パス配列 |
| `artifacts.<name>.sha256` | `results_manifest.json` | `artifacts[].sha256` | 実在する成果物SHA-256 |
| `r_environment.version` | `run_meta.json` | `environment.r_version` | 新設 `environment` ブロック |
| `r_environment.platform` | `run_meta.json` | `environment.platform` | 新設 `environment` ブロック（`R.version$platform`。r_versionとの重複を排す） |
| (新設) 依存パッケージ一覧 | `run_meta.json` | `environment.packages` | 新設 `environment` ブロック（`[{name, version}]`） |
| (新設) 乱数シード | `run_meta.json` | `environment.seed` | 新設 `environment` ブロック（乱数を使うスキルはシードを記録、使わないスキルは `null`） |
| (新設) session_info | `results_manifest.json` / run配下 | `session_info.txt` | `sessionInfo()` 出力テキスト（絶対パスをファイル名に置換してマニフェスト登録） |

- **Monte Carlo 項目（Seed, 反復回数, アルゴリズム）の記録先事実 (M2)**:
  - 調査の結果、旧 `manifest.json` には Monte Carlo 項目は元々記録されておらず、`freq_results.json` 内の各層別 `fisher` オブジェクト（`mc_sampling_algorithm`, `replications`, `seed`）および設定写し `analysis_config.json` に記録されている。
  - 従って、`run_meta.json` にこれらの項目を新設する要件は設けず、実態に合わせて `freq_results.json` および `analysis_config.json` を正本記録先として規定する。

### 4. `vcd-categorical-analysis` の `run_state.json` 統合と早期失敗記録の維持

- **決定**: runディレクトリ内部に生成されていた `run_state.json` は廃止し、`run_meta.json` の `run_state` に一本化する。
- **入力検証関数（`validate_input_table`）の責務純化**:
  - `validate_input_table` から `run_dir` 引数および内部での `run_state.json` ファイル直接書き込みを完全撤廃し、純粋な入力検証・例外送出関数（`[ERROR_CODE] メッセージ` 形式で `stop()`）とする。
  - `analysis.R` の呼出元で例外を捕捉し、エラーコード抽出（`^[A-Z0-9_]+`）の上 `record_run_failure()` 経由で `run_meta.json`（`run_state="failed"`, `error_code`, `failure_reason`）を記録する。コードが抽出できない非構造化例外のフォールバックエラーコードは `INPUT_VALIDATION_FAILED` とする。
- **旧 `run_state.json` 項目と新しい格納先の対応表**:

| 旧 `run_state.json` 項目 | 新しい格納先 | 記録キー・パス | 備考 |
|---|---|---|---|
| `status` ("completed" / "failed") | `run_meta.json` | `run_state` | ライフサイクル状態に統一 |
| `phase` ("completed" / "gateway") | `run_meta.json` | `extra$pass_status` / 早期失敗 root | 段階状態は `pass_status`（pass1: "completed"等）で表現 |
| `error_code` | `run_meta.json` | `extra$error_code` | 失敗時のみ記録（未抽出フォールバック: `INPUT_VALIDATION_FAILED`） |
| `message` / `failure_reason` | `run_meta.json` | `extra$failure_reason` | 失敗理由 |
| `analysis_signature` | `run_meta.json` | `extra$analysis_signature` | 正常完了時および署名確定後失敗時 |
| `execution_mode` ("canonical") | `run_meta.json` | `extra$execution_mode` | 実行モード |
| `provenance_status` ("verified") | `run_meta.json` | `extra$provenance_status` | Pass 0 プロベナンス検証状態 |
| `config_file_sha256` | `run_meta.json` | `extra$config_file_sha256` | 実設定ファイルSHA-256（完了・失敗時） |
| `input_sha256` | `run_meta.json` / `categorical_results.json` | `inputs[[1]]$sha256` / `provenance$input_sha256` | 既存契約により完全保持 |
| `canonical_config_sha256` | `run_meta.json` / `categorical_results.json` | `extra$canonical_config_sha256` / `provenance$config_sha256` | 完了時・失敗時のメタデータおよび主結果に格納 |
| `timestamp_jst` | `run_meta.json` | `timestamps$created` 等 | JSTタイムスタンプ統一契約 |

- **`running` 状態の記録廃止の扱い**:
  - 旧実装は run ディレクトリ予約直後に `status: running` を書き込んでいたが、新実装ではメタデータは確定時または例外補足時にのみ書き込まれる。プロセス強制終了時（kill 等）はメタなしの空 run ディレクトリが残り得るが、失敗状態は例外経路でのみ `run_state="failed"` として記録する。
- **`dashboard.Rmd` のフォールバック挙動**:
  - `dashboard.Rmd` は `run_meta.json` が存在する場合はその `provenance_status` を最優先で参照する。`run_meta.json` が存在しながら `provenance_status` を持たない場合は「未確認」と表示し、旧 `run_state.json` は `run_meta.json` 自体が存在しないレガシー環境でのみフォールバックとして参照される。
- **早期失敗記録の維持**: runディレクトリ予約前に発生する入力境界エラー、Pass 0プロベナンス不一致、および並行排他競合（`CONCURRENT_RUN_IN_PROGRESS`, `CANNOT_CREATE_LOCK_DIR`）については、runディレクトリが存在しないため、出力root直下の `run_state.json` にフェイルファスト記録を残す契約を維持する。

### 5. 排他署名ロック（`.run_locks`）の規律とrun列挙フィルタ

- **決定**: 同一解析署名の並行実行排他は、出力root直下の予約ディレクトリ `<out_root>/.run_locks/<signature16>.lock` を用いて原子的（`dir.create`）に取得する。
- **メタデータ**: ロックディレクトリ内には `lock_info.json`（pid, hostname, token, acquired_at）を記録する。
- **障害区別**: 取得失敗時は、既存ロック存在による競合（`CONCURRENT_RUN_IN_PROGRESS`、メッセージにpid・取得時刻を付与）と、パーミッション不足等の作成不能（`CANNOT_CREATE_LOCK_DIR`）を明確に区別する。
- **run列挙規則**: 出力root直下に `.run_locks` が配備されるため、出力root直下の子ディレクトリを走査・インデックス化するすべての処理は、必ず `run_*`（正規表現: `^run_`）でフィルタリングしなければならない。

### 6. 横断索引（`runs_index.jsonl`）と最新実行ポインタ（`latest.json`）(H1, 決定2)

- **`runs_index.jsonl`**:
  - 各スキル出力root直下に配置する。
  - 各runの確定事象（成果物とマニフェスト確定時）に、1行1JSONオブジェクトとして追記（`file(..., "a")`）する。
  - 含むべきフィールド: `run_id`, `logical_run_id`, `run_dir`, `timestamp_jst`, `run_state`, `manifest_sha256`, `skill`。
  - **`run_dir` の定義 (H1)**: 最新 run の物理ディレクトリ名（出力 root からの相対パス。`basename(run_output_dir)`）。`dir.exists(file.path(out_root, event$run_dir))` で実在を担保する。
- **`latest.json` (H1)**:
  - 最新の完了・正常確定runを指すポインタJSON。
  - シンボリックリンクは使用せず、原子的更新（tmp→rename）により書き換える。
  - **`path` の定義 (H1)**: 最新 run の物理ディレクトリ名（出力 root からの相対パス。`basename(run_output_dir)`、例: `"run_20261014_010000"`）。`run_id`（例: `"qa_probe"`）ではなく、`dir.exists(file.path(out_root, latest$path))` で実在するディレクトリ名を格納する。

### 7. session_info.txt の環境依存パス置換と results_manifest_sha256 (M1)

- **パス置換（Redaction）契約**:
  - `session_info.txt` に含まれる BLAS, LAPACK 等の環境依存絶対パス（空白または `;` に続く `/` 始まりの複数階層パス、Windows のドライブパス）は、ファイル名（`basename`）のみに置き換え、R のバージョン、OS、ロケール、タイムゾーン、パッケージ一覧等の再現性情報は残す。
- **results_manifest_sha256 の環境依存性**:
  - `session_info.txt` は `results_manifest.json` の登録対象成果物（role: `"environment_info"`）である。
  - パスをファイル名に置換しても、プラットフォームごとの共有ライブラリ名差（例: macOS の `libRblas.0.dylib` vs Linux の `libRblas.so` vs Windows の `Rblas.dll`）、ロードされるパッケージのバージョン差、R のマイナーバージョン差により、`session_info.txt` の内容（ひいては sha256）は実行環境（OS・Rビルド）に依存する。
  - したがって、`session_info.txt` をマニフェストに含む結果として、`results_manifest_sha256` も環境依存となる。これは同一環境における完全再現性・改ざん検知を目的とするものであり、異種環境間での完全バイナリ一致を保証するものではないことを明記する。

### 8. スキル別の乱数使用と environment.seed 記録表 (M2)

- 乱数を使用するスキルは、実際に使用するシード値を `write_run_meta()` の `extra$seed` に渡して `environment.seed` に記録する。乱数を使用しないスキルは `null` を記録する。
- スキル別の乱数使用およびシード対応表:

| スキル | 乱数使用有無 | シードの由来と値 | `environment.seed` の記録形式 | 備考 |
|---|---|---|---|---|
| `vcd-categorical-analysis` | あり | `analysis_signature`（Pass 0 確定設定）から決定論的に生成される 32-bit 整数シード（`deterministic_seed`） | 単一整数（例: `12345678`） | `compute_dirichlet_posterior` で使用 |
| `vcd-bayesian-evidence-analysis` | あり | Pass 1 実行時シード `20260906`（将来設定化可能な定数） | 単一整数（`20260906`） | `compute_conditional_rate_view` の Dirichlet サンプリングで使用 |
| `vcd-categorical-reporting` | あり | 引数 `seed`（既定値 `42L`） | 単一整数（`42`） | 各対比の独立シード生成起点 |
| `sas-proc-freq` | 条件付きあり | 設定 `cfg$tables[[i]]$fisher$mc_seed`（既定 `20260913L`） | Monte Carlo 実行時: 単一値なら整数、異なる値が複数なら整数の配列（`unique(mc_seeds)`）。Fisher exact のみ / MC 未実行時: `null` | 実装事実・旧仕様と完全整合 |
| `sas-proc-means` | なし | 乱数不使用（決定論的要約統計量） | `null` | — |
| `questionnaire-batch-analysis` | なし | 乱数不使用（決定論的集計・検定） | `null` | — |
| `evidence-decision-review` | なし | 乱数不使用（決定論的特徴量抽出） | `null` | — |
| `comparative-design-analysis` | in-memory | （直接の run_meta 出力なし） | — | — |

## Risks / Trade-offs

- **[Risk] 下流ツール・テストによる `manifest.json` 参照の破壊**:
  - **Mitigation**: `tests/` 内の全テストを棚卸しし、`run_meta.json` および `results_manifest.json` を参照するよう追随改修する。
- **[Risk] パッケージ収集（`collect_run_environment`）による実行オーバーヘッド**:
  - **Mitigation**: `loadedNamespaces()` を起点に `getNamespaceVersion()` で高速に収集する。
- **[Trade-off] 出力ファイル数増加**:
  - `session_info.txt`, `runs_index.jsonl`, `latest.json` が加わる。決定論的再現性・監査追跡性のために受容する。

## Open Questions

以下の項目は設計判断の選択肢と推奨を提示するが、本Changeでは決定せず未決事項（Open Questions）として記録する：

1. **既存run（過去バージョンの成果物）の読み取り互換性 (LOW)**:
   - **論点**: `environment` ブロックを持たない旧 `run_meta.json`（v2.0以前）や、`run_meta.json` を持たず `manifest.json` のみを持つ古いSAS runディレクトリを `read_run_control()` で読み込む際の挙動。
   - **選択肢**:
     - 選択肢A: 厳格モード（Strict）。必須フィールド欠落時は一律エラー。
     - 選択肢B: 寛容モード（Lenient / 推奨）。新規に作成するRunでは `environment` を必須とするが、過去の既存Run読み取りにおいては `environment` や `results_manifest_sha256` が存在しなくても読み込みを許可し、未設定項目は `NULL` + 警告（Warning）とする。
     - 選択肢C: オンデマンド自動移行（既存ファイルの書き換えリスクあり）。
   - **推奨**: 選択肢B。「新規Runでは必須、旧Runの読み取りは寛容」と明確に切り分ける。

2. **`runs_index.jsonl` の不整合修復（Rebuild）コマンドの要否**:
   - **論点**: プロセスクラッシュやディスク障害により `runs_index.jsonl` に未記録または重複が生じた際の再構築ツールの提供。
   - **選択肢**:
     - 選択肢A: 自動修復なし。手動メンテとする。
     - 選択肢B: 将来タスクとして `rebuild_run_index(out_root)` CLI/スクリプトを別Changeで提供する（推奨）。

3. **`run_meta.json` のバージョン番号（interface_version / path_schema_version）の扱い (M4)**:
   - **論点**: `environment` ブロック追加および JST タイムスタンプ固定に伴い、`interface_version`（現在 "2.0"）や `path_schema_version`（現在 "2.0"）をインクリメント（例: "2.1"）すべきか否か。
   - **選択肢**:
     - 選択肢A: "2.0" のまま維持（推奨）。`write_run_meta()` が書き込む新規Runでは `environment` を必須項目として常に出力し、読み取り側は寛容とする。下流パーサーのバージョン不一致による不要な破壊的エラーを防ぐ。
     - 選択肢B: "2.1" へ引き上げ。`environment` ブロックの存在をスキーマバージョンで厳格に識別する。
     - 選択肢C: `environment_schema_version: "1.0"` をブロック内に個別付与する。
   - **推奨**: 選択肢A（"2.0" を維持し、新規書き込みで `environment` を必須化）。
