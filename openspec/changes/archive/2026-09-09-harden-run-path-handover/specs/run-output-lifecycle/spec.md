# 実行成果物ライフサイクルと実行パス引き継ぎ契約

## Purpose

分析パイプライン（Pass 0 〜 Pass 3）において、出力親ディレクトリの決定、秒単位衝突を防ぐ原子的ディレクトリ予約、実ファイルバイト列による決定的 results_manifest.json ハッシュ（POSIX 相対一意パス・role allowlist）、信頼境界検証に基づく run 外管理領域（out_root/.run_locks/）での stage 単位原子的排他ロック、run 内 staging 領域からの検証・promotion・クラッシュ回復と sealed 前空検証、スタブ（executive_summary_preview.md）と本番考察（executive_summary.md）の完全分離、プレビューダッシュボード（dashboard_preview.html）と本番ダッシュボード（dashboard.html、run_state = sealed）の完全分離、Categorical における Pass 1 唯一 run 作成原則（resumable claim 廃止）、legacy run の読み取り・preview 限定（本番確定拒絶）、Questionnaire の 3 区分状態遷移（completed / partial / failed）と部分失敗時遮断、finalizer の skill/stage 導出 allowlist 制限、3 スキル共通 self_contained: true ダッシュボード単一ファイル契約、Pass 1成果物の不変性・追記限定ライフサイクル・Pass 3封印（run_state = sealed）、supersede 元 run の厳格な検証契約（--supersedes-run）、設定スナップショット保存と推測なしデータ保護（hash_only）、入力配列 `inputs` の単一正本化、3 スキル共通の Pass 3 レンダラー（`render_dashboard.R`）提供、cwd 付きハンドオーバー（`run_handover.json`）、親直下を含む厳格な互換探索、二重探索の解消、プレフィックス衝突を防ぐ厳格なパストラバーサル防止、Questionnaire 親直下出力の完全廃止、および Categorical を含む真のリポジトリ 4-Pass 統合規約を定め、結果の取り違えや無言上書きを防止して分析の再現性と運用安全性を担保する。

## ADDED Requirements

### Requirement: 出力親ディレクトリと実実行ディレクトリの明確な責務分離
分析パイプラインは、設定上の親ディレクトリと実際に計算成果物を格納する実行ディレクトリの責務を明確に分離しなければならない（MUST）。Pass 0 は案件および分析種別に応じた出力親ディレクトリ（`output_dir`）と実行識別子（`run_id`）を `analysis_config.json` に確定し、Pass 1 は親ディレクトリと `run_id` から実実行ディレクトリ（`run_output_dir`）を決定する唯一の決定主体でなければならない（MUST）。Pass 1 の `--output-dir` は新規 run を作成する親ディレクトリ専用とし、渡されたパスの末尾が実行ディレクトリ命名規則（`run_*` または `runs/*`）に一致し、かつ既存の `run_meta.json` や成果物ファイルが存在するなど実実行ディレクトリである疑いがある場合、自動で読み替えて処理を継続してはならず（SHALL NOT）、診断メッセージと修正例を示して即座にエラー停止しなければならない（MUST）。

#### Scenario: 通常の親ディレクトリから新規実実行ディレクトリを決定する
- **WHEN** `analysis_config.json` の `output_dir` に親ディレクトリ（例: `output/my_study/vcd_bayesian`）および `run_id`（例: `abc12345def67890`）が指定される
- **THEN** Pass 1 は親ディレクトリ直下に正規の実行プレフィックスを付与した実実行ディレクトリ（例: `output/my_study/vcd_bayesian/run_abc12345def67890`）を一意に決定・作成する

#### Scenario: 実実行ディレクトリが誤って親ディレクトリに渡された場合の自動補正拒絶と即時停止
- **WHEN** Pass 1 の `--output-dir` または `analysis_config.json` の `output_dir` に、既存の成果物や `run_meta.json` を含む実実行ディレクトリパスが指定される
- **THEN** パイプラインは二重階層化や既存 run の暗黙採用を行わず、親ディレクトリの誤指定である旨の診断メッセージと、親ディレクトリの指定方法および再実行の修正例を出力して即座に処理を停止する

### Requirement: Categorical における Pass 1 唯一 run 作成原則と claim 廃止
Categorical 分析において、実実行ディレクトリの作成主体は Pass 1 でなければならない（MUST）。Pass 0 補助処理（`analysis.R --profile`）は、consultation workspace（または指定出力先）に `data_profile.json` を出力するのみとし、正式な `run_meta.json` や production run ディレクトリを作成してはならない（SHALL NOT）。
Pass 1（`analysis.R --render --config`）は、必ず新しい正式 run を原子的に予約して作成しなければならない（MUST）。既存の `claim_resumable_profile_run()` および `.render_claim` 機構は完全に廃止し、Pass 1 が既存 run ディレクトリを再利用することを拒絶しなければならない（MUST）。

#### Scenario: Categorical Pass 0 profile 出力と正式 run 非作成
- **WHEN** `analysis.R --profile` が実行される
- **THEN** データ構造プロファイル `data_profile.json` が出力されるが、正式な `run_meta.json` や production run は作成されない

#### Scenario: Categorical Pass 1 による正式 run の新規原子的予約
- **WHEN** `analysis.R --render --config analysis_config.json` が実行される
- **THEN** 既存の profile run を claim することなく、親ディレクトリ配下に新しい実 run ディレクトリが原子的に予約され、Pass 1 成果物および `run_meta.json` が出力される

### Requirement: 秒単位 JST タイムスタンプ衝突の原子的解決
Pass 1 は `run_id` が省略された場合、秒単位の JST タイムスタンプ（`YYYYMMDD_HHMMSS`）を発行して実実行ディレクトリを決定しなければならない（MUST）。同一 ID が既に存在する場合、または同一秒に複数プロセスが同時に起動した場合、`dir.create(candidate, recursive = FALSE)` の成否に基づく原子的予約を用いて `_2`, `_3` の予約サフィックスを付与し、競合プロセス同士を別個の実実行ディレクトリへ確実に隔離しなければならない（MUST）。

#### Scenario: 同一秒に起動した 2 プロセスの原子的隔離
- **WHEN** 同一秒に 2 つの Pass 1 プロセスが `run_id` 省略で同一親ディレクトリに向けて実行を開始する
- **THEN** 一方が `run_YYYYMMDD_HHMMSS`（または `runs/YYYYMMDD_HHMMSS`）を確保し、もう一方は原子的予約の競合を検知して `run_YYYYMMDD_HHMMSS_2` を確保し、成果物が混ざることなく安全に隔離される

### Requirement: 追記限定ライフサイクル、Pass 3 封印（sealed）、および supersede 系統管理
実実行ディレクトリは、Pass 1 完了後は入力・設定・統計計算成果物を不変（Immutable）とし、Pass 1 から Pass 3 までは確定成果物の追加のみを認める追記限定（Append-only）ライフサイクルに従わなければならない（MUST）。run 共通ファイルは直下に配置し、Questionnaire の設問別成果物は既存の設問別サブディレクトリを維持する。`run_meta.json` はガードされた状態遷移のための可変制御ファイルとして機能し、本番 Pass 3 確定時に `run_state = "sealed"` として run 全体を不変化（封印）しなければならない（MUST）。
`sealed` 状態となった run に対しては、いかなる成果物の追加・上書き・メタデータの更新も拒絶しなければならない（MUST）。
確定済み成果物の改定や Pass 1 の再計算が要求された場合は、同一 run 内での上書きや複数世代管理を行ってはならず（SHALL NOT）、常に新しい run ディレクトリを原子的に予約して実行しなければならない（MUST）。
元 run は当時の完全な成果物集合（不変監査証跡）として一切改ざんせず保持し、新 run は `pass1 = "pending"`, `pass2 = "pending"`, `pass3 = "pending"` から開始し、Pass 1 の再計算結果に応じて completed / partial / failed を記録しなければならない（MUST）。

#### Scenario: 追記限定ライフサイクルにおける確定成果物追加と Pass 1 成果物の保護
- **WHEN** Pass 1 が完了した実 run に対し、Pass 2（考察追加）および Pass 3（ダッシュボード追加）が順次実行される
- **THEN** Pass 1 で出力された入力スナップショット、設定、および統計結果ファイルは一切変更されず、考察およびダッシュボード確定成果物が追記され、`run_meta.json` の状態が安全に更新される

#### Scenario: 本番 Pass 3 完了による封印（sealed）と以降の変更拒絶
- **WHEN** 本番 Pass 3 のダッシュボード（`dashboard.html`）生成と確定が成功する
- **THEN** `run_meta.json` の `run_state` が `sealed` に更新され、以降その run に対するいかなる追加書き込みや上書きもエラーとして拒絶される

#### Scenario: 確定済み成果物改定における supersede run 予約
- **WHEN** 既に確定済みの考察やダッシュボードの改定、またはパラメータ変更による再計算が要求される
- **THEN** 元 run は従前の状態（active または sealed）のまま変更されず、新しい実 run ディレクトリが作成されて `supersedes_run` 系統が記録される

### Requirement: 3 スキル共通 results_manifest.json とスキーマ制約・決定的実ファイルバイト列ハッシュ
Pass 1 は統計計算が正常に完了した際、実実行ディレクトリ直下に 3 スキル共通の統計成果物マニフェストファイル `results_manifest.json` を出力しなければならない（MUST）。
各スキルは以下のように成果物をマニフェストに登録しなければならない（MUST）：
- `vcd-bayesian-evidence-analysis`: `evidence_results.json`（`role: "primary_results"`）
- `vcd-categorical-analysis`: `categorical_results.json`（`role: "primary_results"`）
- `questionnaire-batch-analysis`: `summary.csv`（`role: "summary_table"`）および計算に成功したすべての設問の `questionnaire_results.json`（`role: "question_result"`）

マニフェストの出力およびハッシュ算出は以下のスキーマ制約および決定性規則に厳格に従わなければならない（MUST）：
1. `path` は run 基準の正規化された相対 POSIX パスでなければならない（MUST）。絶対パス、空文字、`.`、`..`、run 外 escape、symlink を拒絶し、manifest 内で一意でなければならない（MUST）。
2. `sha256` は小文字 64 桁 16 進数でなければならない（MUST）。
3. `role` はスキルごとに定義された allowlist に合致しなければならない（MUST）。
4. Questionnaire の `question_result` では `question_id` を必須かつ一意とし、同一 `question_id` が複数 path を指すことを拒絶しなければならない（MUST）。
5. `artifacts` 配列内の各要素は、`question_id` のない要素を空文字として扱い、`path`、`role`、`question_id` の順序で決定的に一意ソートされなければならない（MUST）。
6. 固定した JSON 出力条件（キー順、インデント、改行コード）で `results_manifest.json` を一度だけ書き出さなければならない（MUST）。
7. `results_manifest_sha256` は、保存された `results_manifest.json` の**実ファイルバイト列に対する SHA-256** として算出し、`run_meta.json` に記録しなければならない（MUST）。
8. 後続の Pass 2 / Pass 3 確定処理は、`results_manifest.json` の実ファイルバイト列ハッシュと、manifest に登録された全成果物の実ファイル SHA-256 の双方を検証しなければならない（MUST）。改行、空白、JSON 再シリアライズによる論理正規化を行ってはならない（SHALL NOT）。

#### Scenario: 決定的実ファイルバイト列ハッシュによる結果マニフェストの検証
- **WHEN** Pass 1 が `results_manifest.json` を書き出し、後続処理がマニフェストを検証する
- **THEN** 保存された実ファイルバイト列の SHA-256 が記録された `results_manifest_sha256` と完全一致し、全登録成果物の実ハッシュも完全に一致して検証に合格する

#### Scenario: マニフェストにおける不正パス・重複エントリの拒絶
- **WHEN** manifest に重複した `path`、絶対パス、symlink、または重複した `question_id` が含まれる
- **THEN** パイプラインはスキーマ違反として即座にエラー停止する

### Requirement: Pass 2 / Pass 3 finalizer の stage 単位排他ロック制御（run 外配置と信頼境界検証）
パイプラインは、同一 run に対する finalizer の並行実行（TOCTOU 競合）を防止するため、確定開始時に stage ごとの排他ロックを原子的に取得しなければならない（MUST）。
排他ロックは以下の規則を順守しなければならない（MUST）：
1. **ロック作成前の信頼境界検証**: ロック作成前に、`run_meta.run_output_dir` の実パスが CLI の `--run-dir` と完全一致すること、スキル別レイアウト整合性（Bayesian/Categorical は `dirname(run_dir) == out_root`、Questionnaire は `dirname(dirname(run_dir)) == out_root` かつ中間階層が `runs`）、および祖先パスに想定外の symlink がないことを検証しなければならない（MUST）。不一致または異常を検知した場合は、ロックディレクトリを作成することなく即座にエラー停止しなければならない（MUST）。
2. **ロック配置（run 外）**: stage 単位ロックは、対象 run の外にある、`out_root` 直下の専用制御領域 `.run_locks/<run_lock_id>/` 配下に配置しなければならない（MUST）。run ディレクトリ内にロックファイルやロックディレクトリを作成してはならない（SHALL NOT）。
3. **`run_lock_id` の完全固定**: run の正規化済み絶対パスに対する SHA-256 全 64 桁に完全固定しなければならない（MUST）。
4. **原子的取得**: `dir.create(lock_path, recursive = FALSE)` の成否に基づく原子的取得を行わなければならない（MUST）。取得に失敗したプロセスは、並行処理進行中として即座にエラー停止しなければならない（MUST）。
5. **ロック情報記録**: ロックディレクトリ直下に `lock_info.json`（PID、hostname、token、開始時刻、run_dir、stage）を記録しなければならない（MUST）。
6. **封印との整合性**: Pass 3 ロック保持中に `run_meta.json` を `sealed` へ更新し、事後検証完了後に run 外のロックを解放しなければならない（MUST）。これにより `sealed` 後の run ディレクトリに変更を発生させてはならない（SHALL NOT）。
7. **stale lock 回復規則**: 通常の finalizer は既存ロックを自動削除してはならない（SHALL NOT）。明示的な `--recover-stale-lock` 指定時のみ、hostname 一致、PID 不在、最低経過時間超過を検証して回復し、監査ログを `<out_root>/.run_locks/<run_lock_id>/audit.jsonl` に保存しなければならない（MUST）。

#### Scenario: 同一 stage finalizer 同時実行時の排他制御
- **WHEN** 同一 run に対し、内容の異なる 2 つの staging 成果物を使って同じ stage の finalizer が同時に実行される
- **THEN** 一方のみが排他ロックを取得して確定に成功し、もう一方はロック競合を検知して即座にエラー停止し、既存成果物が後勝ち置換されない

#### Scenario: 改ざんされた out_root による外部ロック作成の阻止
- **WHEN** `run_meta.json` 内の `out_root` が改ざんされ、`run_dir` の実階層と一致しない状態で finalizer が実行される
- **THEN** 信頼境界検証が不整合を検知し、外部ディレクトリへロックを作成することなく即座にエラー停止する

#### Scenario: sealed 封印後の run ディレクトリ不変性保持
- **WHEN** Pass 3 確定処理が run を `sealed` に封印して終了する
- **THEN** ロック解放は run 外の `.run_locks/` 配下で行われ、`sealed` 状態となった run ディレクトリ内には一切の削除・変更が発生しない

### Requirement: 既存メタデータ v1.0 のレガシー互換モード（読み取り・preview 限定）
Pass 2 および Pass 3 は、既定では `interface_version: "2.0"` のメタデータを要求しなければならない（MUST）。過去に実行された v1.0 形式の実行ディレクトリを処理する場合、明示的な `--allow-legacy-run-meta` オプションが指定された場合のみ警告付きで読み取りを許容する。
ただし、その許容範囲は読み取り、探索、診断、および preview 生成（`executive_summary_preview.md`, `dashboard_preview.html`）に限定しなければならない（MUST）。
v1.0 run に対する本番 Pass 2 確定（`finalize_pass2`）、本番 Pass 3 確定（`finalize_pass3`）、promotion、`run_meta.json` の確定更新、`run_state = sealed` への封印、および通常の `--supersedes-run` 元としての指定は一切拒絶しなければならない（MUST）。本番成果物が必要な場合は、元入力と設定から v2.0 Pass 1 を新しい run として再実行することを要求しなければならない（MUST）。

#### Scenario: legacy run に対する preview 生成の許容
- **WHEN** v1.0 形式の run に対し、`--allow-legacy-run-meta` と `--preview` を指定してダッシュボード生成を実行する
- **THEN** スクリプトは警告を出力しつつ、`dashboard_preview.html` を正常に生成する

#### Scenario: legacy run に対する本番確定の拒絶
- **WHEN** v1.0 形式の run に対し、本番 finalizer（`finalize_run_stage.R --stage pass2` または `pass3`）を実行する
- **THEN** 成果物マニフェストおよび由来ハッシュが存在しないため、確定処理は拒絶されエラー停止する

### Requirement: staging 領域のライフサイクル境界と sealed 前検証
パイプラインは、未確定の作業ファイルと正式な確定成果物の境界を厳格に管理しなければならない（MUST）。
1. `staging/` は未確定の一時作業領域であり、正式な run 成果物集合には含めず、`run_meta.json` の `artifacts` に登録してはならない（SHALL NOT）。
2. AI 考察やダッシュボードは、確定前に最終ファイル名で実 run 直下へ直接書き込んではならない（SHALL NOT）。
3. finalizer は staging 成果物を検証した上で、同一ファイルシステム上の rename により最終ファイル名へ promotion し、その後 `run_meta.json` を原子的更新しなければならない（MUST）。
4. promotion 完了後・メタデータ更新前のクラッシュ時、既存最終ファイルが存在し期待ハッシュと完全一致する場合に限り、finalizer の冪等な再実行を許可しなければならない（MUST）。ハッシュ不一致時は上書きを拒絶してエラー停止しなければならない（MUST）。
5. 本番 Pass 3 確定による `run_state = sealed` 遷移前に、当該 run の staging 領域が空または不存在であることを検証しなければならない（MUST）。未処理ファイルが残存している場合は封印を拒絶しなければならない（MUST）。sealed 後は staging の新規作成を拒絶しなければならない（MUST）。

#### Scenario: staging 領域からの正常な検証と promotion
- **WHEN** AI 考察が staging 領域へ書き出され、`finalize_run_stage.R --stage pass2` が実行される
- **THEN** 結果マニフェスト、全成果物ハッシュ、および staging 成果物が検証され、同一ファイルシステム rename により `executive_summary.md` へ promotion され、`run_meta.json` がアトミックに更新される

#### Scenario: staging にファイルが残存している場合の封印拒絶
- **WHEN** Pass 3 確定時に staging 領域内に未処理の一時ファイルが残存している
- **THEN** finalizer は run の封印（`run_state = "sealed"`）を拒絶し、エラー停止する

### Requirement: スタブ成果物と本番 AI 考察の完全分離および一回限り方針
パイプラインは、スタブ成果物と本番 AI による考察成果物を完全に分離し、プレビュー成果物の生成を一回限りとしなければならない（MUST）。
1. `pass2_stub.R` の出力を `executive_summary_preview.md` とし、本番成果物と同名（`executive_summary.md`）で出力してはならない（SHALL NOT）。
2. 本番 AI 考察の出力は `executive_summary.md`（Questionnaire は `cross_question_summary.md`）とする。
3. preview ファイル（`executive_summary_preview.md`）の存在によって、本番 AI 考察の追加・確定が妨げられてはならない（MUST NOT）。
4. preview（`executive_summary_preview.md`, `dashboard_preview.html`）は同一 run では一度だけ生成を許可し、同名 preview が既に存在する場合は上書きを拒絶しなければならない（MUST）。更新が必要な場合は新規 supersede run を使用しなければならない（MUST）。
5. Pass 2 の状態遷移として `pending -> stub_generated -> completed` および `pending -> completed` を許可しなければならない（MUST）。
6. `completed` 状態に達した後の考察成果物の上書き・再確定は拒絶しなければならない（MUST）。

#### Scenario: スタブ生成後に本番 AI 考察を確定する
- **WHEN** `pass2_stub.R` により `executive_summary_preview.md` が生成され `pass2 = "stub_generated"` となった後、本番 AI 考察が staging 領域に出力されて Pass 2 確定が実行される
- **THEN** 本番 AI 考察が `executive_summary.md` として promotion され、`pass2` が `completed` に更新される

#### Scenario: 既存 preview に対する上書き再実行の拒絶
- **WHEN** 既に `executive_summary_preview.md` が存在する run に対して再度 `pass2_stub.R` を実行する
- **THEN** スクリプトは追記限定契約に基づき既存 preview の上書きを拒絶し、エラー停止する

### Requirement: プレビューダッシュボードと本番ダッシュボードの完全分離および封印契機
パイプラインは、プレビューダッシュボードと本番ダッシュボードを分離し、本番ダッシュボード確定のみを封印契機としなければならない（MUST）。
1. プレビュー実行時の出力は `dashboard_preview.html` としなければならない（MUST）。
2. 本番実行時の出力は `dashboard.html` としなければならない（MUST）。
3. プレビュー経路では `finalize_pass3` を実行してはならず（SHALL NOT）、`pass3 = "completed"` や `run_state = "sealed"` への更新を行ってはならない（SHALL NOT）。
4. `dashboard_preview.html` には、AI 考察が未確定である旨の明示的な警告バナー表示を必須としなければならない（MUST）。
5. 本番 Pass 2 確定（`pass2 == "completed"`）後にのみ、`dashboard.html` を一度だけ生成・確定して `run_state = "sealed"` に封印しなければならない（MUST）。

#### Scenario: プレビューダッシュボード生成時の未封印維持
- **WHEN** `--preview` を指定して `render_dashboard.R` を実行する
- **THEN** `dashboard_preview.html` が警告バナー付きで生成され、`finalize_pass3` は実行されず、`run_state` は `active` のまま維持される

#### Scenario: プレビューダッシュボード生成後の本番ダッシュボード確定と sealed 封印
- **WHEN** `dashboard_preview.html` が存在する状態で本番 Pass 2 が完了し、本番 `render_dashboard.R` が実行される
- **THEN** `dashboard.html` が生成されて確定され、`pass3 = "completed"` および `run_state = "sealed"` に更新される

### Requirement: 3 スキル統一 self_contained ダッシュボード単一ファイル契約
`vcd-bayesian-evidence-analysis`、`vcd-categorical-analysis`、および `questionnaire-batch-analysis` の全 3 スキルにおいて、ダッシュボードの Rmd テンプレートは `self_contained: true` を明示しなければならない（MUST）。
公開 HTML は外部ローカルアセットディレクトリ（`dashboard_files/` 等）に依存してはならず（SHALL NOT）、単一ファイル `dashboard.html`（プレビュー時は `dashboard_preview.html`）として完結して原子的 promotion を担保しなければならない（MUST）。

#### Scenario: 3 スキルにおける self_contained ダッシュボードの生成
- **WHEN** いずれの分析スキルに対しても `render_dashboard.R` が実行される
- **THEN** 外部依存アセットが HTML 内部にインライン化され、追加のディレクトリを伴わずに単一の HTML ファイルとして完結出力される

### Requirement: Questionnaire 状態機械と部分失敗時の後続処理遮断
Questionnaire バッチ分析において、パイプラインは全設問の計算結果に応じて明確な 3 区分状態判定を実施しなければならない（MUST）：
1. **`completed`**: 全設問が `status == "success"` の場合のみ `pass1 = "completed"` とする。
2. **`partial`**: 1 件以上の設問が成功し、かつ 1 件以上の設問が失敗（`status == "error"`）した場合は `pass1 = "partial"` とする。
3. **`failed`**: 成功した設問が 0 件の場合、または `summary.csv` / `results_manifest.json` を安全に生成できなかった場合は `pass1 = "failed"` とする。
4. `partial` および `failed` の run に対する本番 Pass 2 確定、本番 Pass 3 確定、および `run_state = "sealed"` への遷移は完全に遮断・拒絶しなければならない（MUST）。
5. 部分失敗 run でも診断成果物（`summary.csv`、成功設問の `questionnaire_results.json`、`results_manifest.json`、および失敗設問メタデータ）を出力・保持しなければならない（MUST）。
6. `results_manifest.json` にはsummary.csv と実在する成功設問の成果物を登録し、`summary.csv` の成功設問集合と manifest の `question_result` 集合の完全一致を検証しなければならない（MUST）。
7. `partial` run は整合性検証後に `--supersedes-run` 元として許可するが、`failed` run は supersede 元指定を拒絶しなければならない（MUST）。

#### Scenario: 部分失敗 run における診断成果物保持と本番確定遮断
- **WHEN** Questionnaire バッチ分析で一部の設問がエラーとなる
- **THEN** `summary.csv` にエラー情報が記録され、成功設問のみが manifest に登録され、`pass1` は `partial` となり、本番 Pass 2 / 3 確定の実行はエラー停止して遮断される

#### Scenario: 部分失敗 run の supersede 再実行許可
- **WHEN** 設問設定を修正し、前回の `partial` run を `--supersedes-run` に指定して再分析を実行する
- **THEN** 元 run の診断成果物と manifest の整合性が検証され、正常に supersede run が開始される

### Requirement: finalizer 引数の allowlist 制限と厳格パス検証
共通確定 CLI ラッパー `.agents/shared/finalize_run_stage.R` は、引数の厳格な allowlist 検証を実施しなければならない（MUST）。
1. `--target-name`: basename のみを受け付け、パス区切り文字（`/`, `\`）、`.`、`..`、絶対パスを拒絶しなければならない（MUST）。また、`run_meta.json` の skill と stage から期待値を導出し、完全一致することを検証しなければならない（MUST）：
   - Pass 2 + Bayesian: `executive_summary.md`
   - Pass 2 + Categorical: `executive_summary.md`
   - Pass 2 + Questionnaire: `cross_question_summary.md`
   - Pass 3: `dashboard.html`
2. `--source-artifact`: 正規化後に当該 run の専用 staging 領域（`<run_dir>/staging/`）配下にある通常ファイルのみを許可しなければならない（MUST）。symlink、ディレクトリ、FIFO、device、run 外パス、prefix 衝突、`../` escape を拒絶しなければならない（MUST）。
3. source と target が同一パスである場合は拒絶しなければならない（MUST）。
4. target が既に存在する場合、クラッシュ回復条件（期待ハッシュ一致）以外は上書きを拒絶しなければならない（MUST）。

#### Scenario: 不正な target-name の拒絶
- **WHEN** `--target-name ../run_meta.json` や `--target-name unexpected.md` を指定して finalizer を実行する
- **THEN** allowlist 検証により即座にエラー停止する

#### Scenario: staging 外または symlink の source-artifact 拒絶
- **WHEN** run 外のファイルや staging 内から外部を指す symlink を `--source-artifact` に指定する
- **THEN** パス検証により外部逸脱として即座にエラー停止する

### Requirement: run_handover.json における pass2_ai と共通確定 CLI アクション
Pass 1 は統計計算完了時、実実行ディレクトリ直下に `run_handover.json` を生成しなければならない（MUST）。`cwd` には正規化されたリポジトリルートを明記し、`next_actions` 配下のアクションは必ず `kind` を持たなければならない（MUST）。
`pass2_ai` アクションには、以下の属性を明記しなければならない（MUST）：
- `kind`: `"agent_action"`
- `input_manifest`: `"results_manifest.json"`
- `expected_results_manifest_sha256`: 64 桁の実ファイルバイト列 manifest ハッシュ
- `output`: 最終考察成果物ファイル名（Bayesian/Categorical: `"executive_summary.md"`、Questionnaire: `"cross_question_summary.md"`）
- `staging_output`: staging 一時出力パス（例: `"staging/executive_summary.md"`）
- `finalize`: 確定コマンド。共通 CLI ラッパー `.agents/shared/finalize_run_stage.R` を用いた実行可能な `argv`（`--source-artifact` および `--target-name` を含む）

#### Scenario: run_handover.json における pass2_ai の出力
- **WHEN** Pass 1 が完了して `run_handover.json` が生成される
- **THEN** `pass2_ai` に `input_manifest`, `expected_results_manifest_sha256`, `staging_output`, `output`, および staging 確定対応の `finalize` アクションが正確に記録される

### Requirement: supersede 元 run の厳格な検証契約（--supersedes-run）
再計算、再分析、または確定済み成果物の改定を行う場合、CLI 引数 `--supersedes-run <path>` で元 run ディレクトリを指定しなければならない（MUST）。
パイプラインは元 run に対して以下の厳格な検証を実施しなければならない（MUST）：
1. 元 run ディレクトリの存在、および `run_meta.json` の妥当性を検証する。
2. 元 run の `skill` が現在実行中のスキルと完全一致することを検証する（異なるスキルの run を supersede することを拒絶する）。
3. 元 run の `results_manifest.json` の存在、および実ファイルバイト列 SHA-256、全登録成果物の実ハッシュを元 run から再計算して検証する。
4. `superseded_results_manifest_sha256` は元 run の実ファイルバイト列から自ら再計算して新 run の `run_meta.json` に記録し、外部引数の指定値を信用してはならない（SHALL NOT）。
5. 自己参照（指定パスが新規 run 自身と同じ）および循環参照（過去の supersede 系統チェーンに自身が含まれる）を拒絶する。
6. `pass1 == "failed"` の run および v1.0 legacy run に対する supersede を拒絶する（MUST）。
7. `supersede_reason`（改定理由）を記録し、入力データおよび設定ファイルのハッシュ比較に基づいて `inputs_changed`（真偽値）および `config_changed`（真偽値）を新 run の `run_meta.json` に記録しなければならない（MUST）。

#### Scenario: 正常な supersede 元 run の検証と系統記録
- **WHEN** 有効な過去 run を `--supersedes-run` に指定して再分析を実行する
- **THEN** 元 run の整合性・スキル一致・成果物ハッシュが検証され、新 run の `run_meta.json` に `supersedes_run`, `superseded_results_manifest_sha256`, `supersede_reason`, `inputs_changed`, `config_changed` が記録される

#### Scenario: 不正な元 run（スキル不一致・ハッシュ破損・自己参照・failed run・legacy run）の拒絶
- **WHEN** スキルが異なる run、成果物が改ざんされた壊れた run、自分自身、`failed` run、または legacy run を `--supersedes-run` に指定する
- **THEN** パイプラインは即座にエラー停止し、不正な supersede run の作成を防止する

### Requirement: 入力データの推測なし hash_only 原則と設定スナップショット保存
Pass 1 は、コードによるデータの機微性（RWD、公開、合成等）の推測を一切排除し、以下の明確なスナップショットポリシーを適用しなければならない（MUST）：
1. **外部データファイル（`role: "data"`）**: 出自や内容にかかわらず、**一律で既定 `snapshot_policy: "hash_only"`** とし、データ本体を run ディレクトリ内へコピーしてはならない（SHALL NOT）。元パスおよび 64 桁 SHA-256 のみを記録する（データ本体コピーのオプトイン機能は提供しない）。
2. **`analysis_config.json`**: 設定スナップショットとして実 run 直下に保存する。正式分析（`config_origin: "pass0_file"`）では元ファイルをコピーし、手動試行・自動テスト（`config_origin: "resolved_cli"`）では実効引数から生成して保存し、64 桁 SHA-256 を記録する。
3. **`question_config.csv`**: 設定スナップショットとして実 run 直下に保存し、64 桁 SHA-256 を記録する。
4. **組み込みデータ**: `source_kind: "builtin"` とし、データフレームハッシュを記録する（スナップショット不要）。

#### Scenario: 外部データファイルの推測なし hash_only 記録
- **WHEN** 任意の CSV やデータファイルを指定して Pass 1 を実行する
- **THEN** コードはデータの機微性を推測せず、データ本体を実 run 直下にコピーすることなく、元パスと 64 桁 SHA-256 のみを `inputs` 配列に記録する

#### Scenario: 設定ファイルのスナップショット保存
- **WHEN** Pass 1 が実行される
- **THEN** 実 run 直下に `analysis_config.json`（および Questionnaire の場合は `question_config.csv`）が確実に保存され、その 64 桁 SHA-256 が記録される

### Requirement: メタデータにおける inputs 配列の単一正本化
実行メタデータ（`run_meta.json`）は、分析を構成するすべての入力を役割付きオブジェクト配列 `inputs` として記録し、これを保存上の唯一の正本としなければならない（MUST）。旧トップレベルフィールド（`input_data` / `input_sha256`）は JSON ファイルへ直接永続化してはならず（SHALL NOT）、旧コード向けには読み取りアダプター関数が `inputs[role == "data"]` から透過的に値を導出しなければならない（MUST）。

#### Scenario: inputs 配列の保存と旧フィールド直接永続化の排除
- **WHEN** Pass 1 が `run_meta.json` を出力する
- **THEN** `inputs` 配列のみが書き出され、旧トップレベルフィールドは JSON に重複出力されない

### Requirement: Pass 2 および Pass 3 への実実行ディレクトリの直接引き継ぎ
Pass 2（AI 考察・スタブ作成）および Pass 3（ダッシュボード生成）は、Pass 1 が確定した実実行ディレクトリのパスを引数 `--run-dir <path>` で直接受け取り、指定された実行ディレクトリ直下の成果物（`results_manifest.json`、`evidence_results.json`、`analysis_config.json` 等）のみを読み込んで同一ディレクトリ直下へ成果物（`executive_summary.md`、`dashboard.html` 等）を出力しなければならない（MUST）。明示指定された `--run-dir` よりもカレントディレクトリ内の既定ファイルパスを暗黙的に優先してはならない（SHALL NOT）。

#### Scenario: 実実行ディレクトリを直接指定した Pass 2 考察作成
- **WHEN** Pass 2 スクリプトに `--run-dir <path>` が指定される
- **THEN** スクリプトはカレントディレクトリの既定ファイルを無視し、指定された実行ディレクトリ直下の成果物マニフェストおよび結果を読み込み、成果物を staging 経由で確定配置する

### Requirement: 3 スキル共通の薄い Pass 3 レンダラー（render_dashboard.R）提供
`vcd-bayesian-evidence-analysis`、`vcd-categorical-analysis`、および `questionnaire-batch-analysis` の 3 スキルすべてにおいて、統一された薄い CLI ラッパー `templates/render_dashboard.R` を配置しなければならない（MUST）。このラッパーは `--run-dir <path>` で実実行ディレクトリを受け取り、下位の `dashboard.Rmd` に対し確定済みパス（`params$run_dir`）を直接伝達してレンダリングを実行し、Rmd 内部での再探索を完全排除しなければならない（MUST）。

#### Scenario: 3 スキルにおける統一 CLI レンダラーの実行
- **WHEN** いずれの分析スキルに対しても `Rscript templates/render_dashboard.R --run-dir <path>` が実行される
- **THEN** 各スキルのダッシュボードが同一の CLI インターフェースで一貫して生成され、二重探索を起こさず実 run 直下に `dashboard.html` が出力される

### Requirement: 暗黙的 mtime 探索の廃止と親直下を含む厳格な単一互換探索
分析パイプラインの通常実行経路において、親ディレクトリ配下のファイル更新日時（mtime）、ディレクトリ更新日時、またはディレクトリ名順に基づいて最新 run を暗黙的に自動選択してはならない（SHALL NOT）。過去スクリプトとの互換性が必要な場合に限り、明示的な互換オプション（`--discover-single-run`）が指定された場合のみ親ディレクトリ探索を許容する。互換探索では、「親ディレクトリ直下の成果物」および「親配下の run サブディレクトリ候補」の合計有効候補数を算出し、合計が「ちょうど 1 件」の場合に限り警告メッセージを伴って採用し、合計が 0 件または「2 件以上」存在する場合は暗黙的な選択を拒絶してエラー停止しなければならない（MUST）。

#### Scenario: 通常実行における親ディレクトリ探索の拒絶
- **WHEN** 明示的な互換フラグなしに親ディレクトリが Pass 2 または Pass 3 に渡される
- **THEN** パイプラインは親ディレクトリ配下の自動探索を行わず、`--run-dir` で実実行ディレクトリを直接指定することを要求して停止する

#### Scenario: 親直下とサブディレクトリの合計が複数存在する場合の暗黙選択拒絶
- **WHEN** `--discover-single-run` フラグが指定され、親直下に 1 件、サブディレクトリに 1 件など、合計 2 件以上の有効候補が存在する
- **THEN** パイプラインはいずれか一方を優先・自動選択せず、曖昧性を排除するために `--run-dir` で対象 run を一意に指定するよう促してエラー停止する

### Requirement: プレフィックス衝突を防ぐ厳格なパストラバーサル防止
パイプライン処理は、実行メタデータ（`run_meta.json`）の `artifacts` や `config_snapshot` などに記録された相対パスを解決する際、共通ガード関数 `assert_path_within_run_dir()` を通じて検証しなければならない（MUST）。判定は `target == run_root || startsWith(target, paste0(run_root, "/"))` に従い、`/output/run_abc_external` のようなプレフィックス衝突を確実に拒絶しなければならない（MUST）。既存ファイルは symlink を解決して実パスを検証し、未作成の出力ファイルは存在する親ディレクトリを正規化して検証しなければならない（MUST）。

#### Scenario: プレフィックス衝突パスの拒絶
- **WHEN** `run_output_dir` が `/output/run_abc` のとき、対象パスが `/output/run_abc_external/file.json` である
- **THEN** 共通ガード関数がこれを検知し、同一プレフィックスであってもディレクトリ外への逸脱としてエラー停止する

### Requirement: Questionnaire 親直下出力の完全廃止（破壊的変更）
`questionnaire-batch-analysis` において、`--out` 親ディレクトリ直下への出力は完全に廃止しなければならない（MUST）。`--run-id` が省略された場合であっても秒単位 JST タイムスタンプを発行し、必ず `runs/<id>/` 配下の独立した実行ディレクトリを作成・隔離しなければならない（MUST）。
これは破壊的変更（Breaking Change）であり、親直下の `summary.csv` を直接参照していた既存の自動化スクリプトは、確定した `runs/<id>/summary.csv` を参照するよう移行しなければならない（MUST）。

#### Scenario: run ID 省略時における runs/ への完全隔離
- **WHEN** Questionnaire バッチ分析で `--run-id` が明示されない
- **THEN** 親直下には何も出力されず、`runs/YYYYMMDD_HHMMSS/` 配下に `summary.csv`, `results_manifest.json` および各設問の実行成果物が安全に隔離出力される

### Requirement: リポジトリ共通 4-Pass 正式対応と Categorical の是正
分析成果物の配置および実行フローは、リポジトリ共通の 4-Pass 体系に厳格に対応づけられなければならない（MUST）：
- **Pass 0 (Consultation)**: 相談・次元削減・設定確定（`analysis_config.json`）。Categorical の `--profile` は構造確認のための **Pass 0 補助** として consultation workspace に出力し、正式 run は作成しない。
- **Pass 1 (Compute)**: 統計計算・モデル適合・成果物マニフェスト（`results_manifest.json`）生成・正式 run 原子的予約。Bayesian: `pass1_compute.R`、Categorical: `analysis.R --render --config ...`（度数集計・モデル計算・`categorical_results.json` 出力）、Questionnaire: `batch_runner.R`。
- **Pass 2 (Narrative)**: 専門家 AI 考察（Bayesian/Categorical: `executive_summary.md`、Questionnaire: `cross_question_summary.md`）。staging 出力から `finalize_pass2` による確定。
- **Pass 3 (Report/Dashboard)**: 各スキルの統一 CLI `render_dashboard.R --run-dir <path>` による統合ダッシュボード描画。本番確定時に `finalize_pass3` により封印（`sealed`）。

#### Scenario: Categorical における真の 4-Pass 連携
- **WHEN** Categorical 分析において `--render --config <path>` が実行される
- **THEN** 統計計算が行われて `categorical_results.json` および `results_manifest.json` が生成され、Pass 1 完了（`pass_status$pass1 = "completed"`）として `run_handover.json` が出力される

### Requirement: 相対リンク・絶対パスの明確な基準と AI 完了報告の提示
パイプラインおよび AI エージェントは、パスおよびリンクの表現基準を厳格に順守しなければならない（MUST）：
- リポジトリ内の成果物: リポジトリルート基準の相対リンク（Markdown 相対パス）
- リポジトリ外の成果物: 正規化された絶対パス
- `run_meta.json` 内の `artifacts`: 実実行ディレクトリ基準の相対パス
- AI 完了報告: 以下の 4 大要素を Markdown リンクとして開ける形式で明確に提示する：
  1. メインレポート（HTML/Markdown）への直接リンク（リポジトリ内は相対、外部は絶対）
  2. 実実行ディレクトリのパス
  3. 設定スナップショット、結果マニフェスト、結果 JSON、メタデータ、およびハンドオーバーファイルへの直接リンク
  4. パイプライン進行状態（Pass 1 完了、Pass 2 考察完了、Pass 3 ダッシュボード生成完了、封印状態等）

#### Scenario: パイプライン全完了時の 4 大要素報告
- **WHEN** Pass 3 までのダッシュボード生成が正常に完了し、AI が完了を報告する
- **THEN** 4 大要素が定義されたパス基準に従って整然と提示され、利用者が成果物および実行コンテキストを即座に確認できる

### Requirement: 確定トランザクションと回復証跡
パイプラインは stage ロックに加え、同一 run のメタデータ更新と成果物公開を直列化する run 共通ロックを run 外の `.run_locks/<run_lock_id>/run.lock/` に設けなければならない（MUST）。ロック取得順は run 共通、stage の順、解放は逆順とする。preview 公開と stub 状態更新も共通ロックを使用し、取得後に状態を再読して completed から stub_generated への逆戻りと sealed 後の書き込みを拒絶する。レンダリング中の一時ファイルは呼び出しごとに別の領域へ生成し、検証対象を確定してから公開する。

promotion 前に、run 外制御領域へ `transaction_<stage>.json` を原子的に保存しなければならない（MUST）。run、stage、source、target、成果物 SHA-256、期待 manifest SHA-256、Pass 3 の期待 narrative SHA-256 を記録する。rename 後は source が消えていても、この証跡と target の実ハッシュから回復しなければならない（MUST）。証跡が欠損・不一致の場合は target を信用せず停止する。通常実行の source 通常ファイル必須条件は、この証跡に基づく回復時だけ例外とする。

Pass 3 は対象 staging ファイル以外の残存を promotion 前に拒絶し、対象を promotion した後に staging が空であることを確認して sealed を記録する。promotion 前の失敗では本番ファイルを作成しない。promotion 後の中断では本番ファイルと回復証跡を保持し、未登録成果物を後続処理が利用してはならない（SHALL NOT）。メタデータ確定済みの再実行は書き込みせず既存の再確定拒絶規則に従う。

#### Scenario: source 消失後の回復
- **WHEN** promotion 後、メタデータ更新前にプロセスが終了し、source が存在しない状態で同じ finalizer を再実行する
- **THEN** 保存済みトランザクションと target および由来ハッシュが一致する場合だけメタデータを確定し、target を上書きしない

#### Scenario: preview と本番封印の競合
- **WHEN** preview 公開と本番 Pass 3 確定が同じ run で競合する
- **THEN** 共通ロックで直列化され、封印が先に完了した場合の preview 公開は拒絶され、メタデータ更新が失われない

#### Scenario: 回復証跡がない既存成果物
- **WHEN** target は存在するが対応するトランザクションが欠損または不一致である
- **THEN** 未確定成果物を取り込まず、既存 target を変更せずに停止する

### Requirement: 診断経路と出力状態の整合
Questionnaire は summary.csv を manifest に登録し、question_result のみを成功設問集合に限定しなければならない（MUST）。partial / failed は非ゼロ終了し、診断用 handover の本番 next_actions を空にし、停止理由を記録する。failed で出力自体が不可能な場合は成果物生成を保証せず、終了コードと可能な診断ログで失敗を通知する。

legacy preview は `--preview-output-dir <path>` で明示された元 run 外の領域へ出力し、元 run の成果物・メタデータを変更してはならない（SHALL NOT）。manifest 検証済みと表示せず、本番確定対象にしない。v2.0 preview は本番用 finalizer を使用しないが、共通ロック下で一度だけ公開する。

#### Scenario: 部分失敗の機械可読な引き継ぎ
- **WHEN** Questionnaire が partial 状態で終了する
- **THEN** summary.csv と成功設問 JSON を含む manifest、停止理由付き handover、非ゼロ終了コードが得られ、本番確定アクションは提示されない

#### Scenario: legacy preview の出力隔離
- **WHEN** legacy 許可と preview 出力先を明示して実行する
- **THEN** 元 run を変更せず指定先に警告付き preview を生成し、既存同名ファイルは上書きしない
