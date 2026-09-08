## Why

分析パイプライン（Pass 0 〜 Pass 3）において、各スキル（`vcd-bayesian-evidence-analysis`, `vcd-categorical-analysis`, `questionnaire-batch-analysis`, `vcd-pass0-consultation`）の間で出力先の決定権限、後続処理への引き継ぎルール、成果物の完全性保証、および状態遷移の定義が不十分であるため、以下の実務的リスクが存在します：

1. **暗黙的探索による結果取り違え**: Pass 2/3（考察・ダッシュボード描画）が親ディレクトリ配下のファイルの更新日時（mtime）や名前順から最新 run を自動探索（`resolve_pass3_run_dir`）する経路に依存しており、複数 run が存在する場合に意図しない別 run の結果を描画・統合する危険がある。また、親直下とサブディレクトリの合算候補数判定が未定義である。
2. **成果物構成の不統一と個別ファイル決め打ち**: 統計成果物の構成がスキルごとに異なり（Bayesian: `evidence_results.json`、Categorical: `categorical_results.json`、Questionnaire: `summary.csv` および設問別 `questionnaire_results.json`）、Pass 2/3 がファイル名を推測・決め打ちで参照しているため、バッチ成果物の網羅性検証が困難である。
3. **Categorical における run 作成主体の逆転・多重予約矛盾**: 現行 Categorical では Pass 0 補助の `analysis.R --profile` が正式な run を予約して `run_meta.json` を作成し、Pass 1 の `--render` がそれを再利用（claim）する構成となっている。これは「Pass 1 が実 run を決定・作成する唯一の主体である」というパイプライン共通原則と矛盾し、未完 run の放置や二重予約のリスクを生む。`--profile` は consultation workspace へのプロファイル出力に限定し、`--render --config` が唯一の正式 run 作成主体として原子的に予約しなければならない。
4. **Pass 3 CLI ラッパーの欠如とアセット外部化リスク**: Bayesian には `render_dashboard.R` が存在するが、Categorical や Questionnaire には独立した CLI ラッパーがなく、呼び出しインターフェースがスキル間で分断されている。また、ダッシュボードの単一ファイル完結性（`self_contained: true`）が明示されていないスキルがあり、外部アセットディレクトリ生成による atomic promotion 破綻リスクがある。
5. **スタブと本番考察の混同および Pass 2 確定主体の欠如**: `pass2_stub.R`（LLM 未使用のプレースホルダー）によって生成されたスタブ成果物が本番成果物と同名（`executive_summary.md`）であると、後続の Pass 3 が本番考察完了と誤認してしまう。スタブは `executive_summary_preview.md`、本番 AI 考察は `executive_summary.md` と明確に分離し、preview の存在によって本番追加が妨げられないようにする必要がある。また、プレビューの再実行による追記限定契約との衝突を防止するため、同一 run での preview 生成は一回限りとし、更新は新しい supersede run で行わなければならない。
6. **ライフサイクル定義の曖昧さ・上書き破壊リスクおよび確定前成果物の露出**: 単に「完全不変」と定義すると Pass 2/3 の成果物追加や状態更新と矛盾し、一方で自由な上書きを許すと新旧成果物の混在や破損を招く。また、Pass 2/3 の成果物を確定前に run 直下の最終ファイル名で直接書き込むと、処理途中の不完全なファイルが露出したり、失敗時にゴミ成果物が残存する。成果物は staging 領域へ出力した上で検証を経て promotion し、その後 `run_meta.json` を原子的更新する確定契約が不可欠である。さらにプレビューダッシュボード（`dashboard_preview.html`）は未封印・未確定バナー必須とし、本番ダッシュボード（`dashboard.html`）のみを封印（`run_state = "sealed"`）の契機とする必要がある。
7. **並行実行時の TOCTOU 競合と封印後不変性の破壊リスク**: 同一 run に対して 2 つの finalizer が同時に実行された場合、存在確認から rename までの間に競合が発生し、後勝ちで成果物やメタデータが破損するリスクがある。原子的ロックが必要であるが、run 内にロックを配置すると `run_state = sealed` への遷移後にロックを削除することになり、封印後の完全不変性契約と矛盾する。ロックは run 外（`out_root` 管理下）に配置し、封印との完全な整合性を確保する必要がある。
8. **run 外ロック作成時の信頼境界欠如**: `run_meta.json` 内の `out_root` を無条件に信用して外部ロックを作成すると、改ざんメタデータによって意図しない外部ディレクトリへロックが書き出される危険がある。ロック取得前に CLI の `--run-dir` との実パス完全一致、スキル別レイアウト整合性、symlink 検証を厳格に行わなければならない。
9. **legacy run における必須 manifest 検証との矛盾**: `--allow-legacy-run-meta` により v1.0 run の継続処理を許容すると、必須である `results_manifest.json` や由来ハッシュが存在せず本番確定が破綻する。legacy run に対する許容範囲を読み取り・診断・preview 生成に限定し、本番確定・sealed 遷移・supersede 元指定を拒絶する必要がある。
10. **Questionnaire 部分失敗時の状態管理の欠如**: 複数設問の一部の計算が失敗した場合、現行コードは `summary.csv` にエラーを記録しつつ終了コード 0 で終了する。これを無条件に `pass1 = completed` とみなすと、欠損した設問成果物を抱えたまま本番ダッシュボードが生成・封印されてしまう。全設問成功のみを `completed` とし、失敗混在時は `partial`、全失敗時は `failed` として本番後続処理を確実に遮断する契約が不可欠である。
11. **finalizer 引数 allowlist 制限の欠如**: `finalize_run_stage.R` が任意の `target-name` や `source-artifact` を無制限に受け付けると、意図しないファイルの上書きや run 外 symlink の混入を招く。stage と skill に応じた厳格な allowlist 検証が求められる。
12. **入力データ複製の禁止と推測排除**: コードが入力データの機微性を推測することは不可能かつ不適切であり、外部データ本体を不用意に run ディレクトリへ複製すると情報漏洩やアクセス制御迂回、ストレージ浪費を招く。設定ファイル（`analysis_config.json` 等）のみをスナップショット保存し、データ本体は一律でコピーしない（hash_only）原則を確立する必要がある。
13. **ハンドオーバーの作業ディレクトリ依存と AI の実行負荷**: `run_handover.json` のコマンドが実行カレントディレクトリに依存していると、リポジトリルート以外からの呼び出しで再現できない。また、AI エージェントが R の内部関数を組み立てて確定処理を行うのは誤りの温床となるため、共通 CLI ラッパーを通じた確定手順が求められる。
14. **パストラバーサル判定の脆弱性**: 単純な文字列前方一致（`startsWith`）では、`/output/run_abc` に対して `/output/run_abc_external/` を誤許可するプレフィックス衝突の脆弱性がある。
15. **Questionnaire の親直下出力による無言上書き**: `--run-id` 省略時に `--out` 直下へ出力する既存挙動があり、前回の `summary.csv` や成果物を無言上書きする破壊的リスクがある。

本変更は、**「Pass 1 を実 run ディレクトリの唯一の決定主体とし、秒単位衝突を防ぐ原子的ディレクトリ予約、実ファイルバイト列による決定的 results_manifest.json ハッシュ（POSIX相対一意パス・role allowlist）、信頼境界検証に基づく run 外管理領域（out_root/.run_locks/）での stage 単位原子的排他ロック、run 内 staging 領域からの検証・promotion・クラッシュ回復と sealed 前空検証、スタブ（executive_summary_preview.md）と本番考察（executive_summary.md）の完全分離、プレビューダッシュボード（dashboard_preview.html）と本番ダッシュボード（dashboard.html、run_state = sealed）の完全分離、Categorical における Pass 1 唯一 run 作成原則（resumable claim 廃止）、legacy run の読み取り・preview 限定（本番確定拒絶）、Questionnaire の 3 区分状態遷移（completed / partial / failed）と部分失敗時遮断、finalizer の skill/stage 導出 allowlist 制限、3 スキル共通 self_contained: true ダッシュボード単一ファイル契約、supersede 元 run の厳格な検証契約（--supersedes-run）、cwd 付き kind タグ付きハンドオーバー（run_handover.json）、全スキル統一 Pass 3 レンダラー、外部データの推測なし hash_only 原則、inputs 単一正本化、厳格なプレフィックス衝突防止、Questionnaire 親直下出力の完全廃止、および Categorical を含む真のリポジトリ 4-Pass 統合規約」** を確立することを目的とします。

## What Changes

- **Pass 1 の `output_dir` を「親ディレクトリ（out_root）」専用と定義し、実 run 誤指定を FAIL-FAST 停止**:
  - Pass 0 は `analysis_config.json` に親ディレクトリ（`output_dir`）と `run_id` を記録する。
  - Pass 1 の `--output-dir` は新規 run を作成する親ディレクトリ専用とする。実 run パスが誤って渡された場合は、自動補正せず診断メッセージと修正例を示して即座に停止する。
- **秒単位 JST タイムスタンプ衝突の原子的解決**:
  - run ID 省略時は秒単位 JST タイムスタンプ（`YYYYMMDD_HHMMSS`）を発行する。
  - 同一秒に起動した競合プロセスや同一 ID が既に存在する場合、`dir.create(..., recursive = FALSE)` の成否に基づく原子的予約を用いて `_2`, `_3` の予約サフィックスを付与し、完全なプロセス間隔離を担保する。
- **Categorical における Pass 1 唯一 run 作成原則の確立と claim 廃止**:
  - `analysis.R --profile` は Pass 0 の consultation workspace に `data_profile.json` を出力するのみとし、正式な `run_meta.json` や production run は作成しない。
  - `analysis.R --render --config` が必ず新しい正式 run を原子的に予約して作成する。
  - 既存の `claim_resumable_profile_run()` および `.render_claim` 制御を完全に廃止し、Pass 1 に対する既存 `--run-dir` 受入を排除する。
- **追記限定ライフサイクル、Pass 3 封印（sealed）、および supersede 系統管理**:
  - Pass 1 完了後は入力・設定・統計結果ファイルを不変（Immutable）とする。
  - Pass 1 から Pass 3 までは確定成果物の追加のみを認める追記限定（Append-only）ライフサイクルとし、`run_meta.json` はガードされた状態遷移のための可変制御ファイルとする。run 共通ファイルは直下に配置し、Questionnaire の設問別成果物は既存の設問別サブディレクトリを維持する。
  - 本番 Pass 3 確定時に `run_state = "sealed"` として run 全体を不変化（封印）する。`sealed` 状態の run に対する追加・変更・上書きは一切拒絶する。
  - 確定済み成果物の改定や再計算は、常に `--supersedes-run <path>` で新しい run を原子的に予約して実行する。
  - 元 run は当時の完全な成果物集合（不変監査証跡）として一切改ざんせず保持する。新 run は Pass 1 未完了から開始し、再計算の成否に応じて状態を決定する。共通ファイルは直下、設問成果物は設問別サブディレクトリに配置する。
- **3 スキル共通の `results_manifest.json` と決定的バイト列ハッシュ（`results_manifest_sha256`）**:
  - 統計成果物の構成を抽象化するため、Pass 1 完了時に実 run 直下へ `results_manifest.json` を出力する。
    - Bayesian: `evidence_results.json` を登録。
    - Categorical: `categorical_results.json` を登録。
    - Questionnaire: `summary.csv` および成功設問の `questionnaire_results.json` を登録。
  - スキーマ制約:
    - `path`: run 基準の正規化された相対 POSIX パス。絶対パス、空文字、`.`、`..`、run 外 escape、symlink を拒絶し、manifest 内で一意。
    - `sha256`: 小文字 64 桁 16 進数。
    - `role`: skill ごとの allowlist。
    - Questionnaire の `question_result`: `question_id` を必須かつ一意とし、同一 `question_id` が複数 path を指すことを拒絶。
  - `artifacts` 配列は `question_id` のない要素を空文字として扱い、`path`、`role`、`question_id` の順序で決定的に一意ソートする。
  - 固定した JSON 出力条件（キー順、インデント、改行）で `results_manifest.json` を一度だけ書き出す。
  - `results_manifest_sha256` は、保存された `results_manifest.json` の**実ファイルバイト列に対する SHA-256** とする。
- **run 外専用制御領域（`out_root/.run_locks/`）における信頼境界検証と排他ロック制御**:
  - 同一 run に対する finalizer の並行実行（TOCTOU 競合）を防止するため、確定開始時に stage ごとの排他ロックを取得する。
  - **信頼境界検証**: ロック作成前に、`run_meta.run_output_dir` の実パスが CLI の `--run-dir` と完全一致すること、スキル別レイアウト整合性（Bayesian/Categorical は `dirname(run_dir) == out_root`、Questionnaire は `dirname(dirname(run_dir)) == out_root` かつ中間階層が `runs`）、および symlink 不存在を検証し、不一致時は外部ロックを作成せず即時停止する。
  - **ロック配置**: `out_root` 直下の `.run_locks/<run_lock_id>/` 配下に `pass2.lock/`, `pass3.lock/` を配置する。**run ディレクトリ内にはロックファイルやディレクトリを一切作成しない**。
  - **`run_lock_id` の固定**: run の正規化済み絶対パスに対する SHA-256 全 64 桁に完全固定する。
  - **原子的取得**: `dir.create(lock_path, recursive = FALSE)` の成功のみをロック取得成功とし、失敗時は並行確定進行中として即時エラー停止する。
  - **封印との整合**: Pass 3 ロック保持中に `run_meta.json` を `sealed` へ更新し、事後検証完了後に run 外のロックを解放する。
  - **stale lock 回復**: ロックディレクトリ内に `lock_info.json` を記録。無条件自動削除は禁止し、明示的 `--recover-stale-lock` 指定時のみ回復する（監査ログは `<out_root>/.run_locks/<run_lock_id>/audit.jsonl` に保存）。
- **legacy run（v1.0）の読み取り・preview 限定と本番確定拒絶**:
  - `--allow-legacy-run-meta` は v1.0 run の読み取り、探索、診断、preview 生成だけに限定する。
  - v1.0 run に対する本番 Pass 2 確定、本番 Pass 3 確定、promotion、`run_meta.json` 更新、`sealed` 遷移は一切拒絶する。
  - 本番成果物が必要な場合は、元入力・設定から v2.0 Pass 1 を新しい run として再実行することを要求する。
  - legacy run は通常の `--supersedes-run` 元としても拒絶する。
- **run 内 staging 領域・検証・promotion およびクラッシュ回復契約**:
  - AI 考察やダッシュボードは、確定前に最終ファイル名で run 直下へ直接書き込んではならない。
  - run 直下の専用一時領域 `staging/` へ一時出力する。`staging/` は正式成果物集合には含めず、`run_meta.json` に登録しない。
  - finalizer が結果マニフェスト、全成果物ハッシュ、および staging 成果物を検証した上で、最終ファイル名へ同一ファイルシステム上の rename で promotion（昇格配置）する。
  - 成果物 promotion 完了後、`run_meta.json` を同一ファイルシステム一時ファイル経由の原子的 rename で更新する。
  - **クラッシュ回復**: 成果物 promotion 後・メタデータ更新前クラッシュ時、最終ファイルが存在し、期待ハッシュと完全一致する場合に限り、finalizer を冪等に再実行してメタデータを更新可能とする。既存ファイルが期待ハッシュと不一致の場合は上書きせずエラー停止する。
  - **sealed 前の staging 検証**: 本番 Pass 3 確定による封印前に、当該 run の staging 領域が空または不存在であることを検証し、残存ファイルがある場合は封印を拒絶する。sealed 後は staging の新規作成も拒絶する。
- **スタブ成果物と本番 AI 考察の完全分離および一回限り方針**:
  - `pass2_stub.R` の出力を `executive_summary_preview.md` とする。
  - 本番 AI 考察は `executive_summary.md` とする。
  - preview ファイルが存在しても、本番ファイルの追加・確定は妨げられない。
  - preview（`executive_summary_preview.md`, `dashboard_preview.html`）も同一 run では一度だけ生成を許可し、同名 preview が既に存在する場合は上書きを拒絶する（更新は新しい supersede run で行う）。
  - Pass 2 の状態遷移として `pending -> stub_generated -> completed` および `pending -> completed` の両方を許可する。`completed` 後の上書き・再確定は拒絶する。
- **プレビューダッシュボードと本番ダッシュボードの完全分離**:
  - プレビュー出力は `dashboard_preview.html` とする。
  - 本番出力は `dashboard.html` とする。
  - プレビュー経路では `finalize_pass3` を実行しない。
  - プレビュー経路では `pass3 = completed` または `run_state = sealed` に更新しない。
  - 本番 Pass 2 確定後に `dashboard.html` を一度だけ生成・確定して `run_state = sealed` へ進める。
  - `dashboard_preview.html` には AI 考察未確定である旨の明示的バナー表示を必須とする。
- **3 スキル共通 self_contained: true ダッシュボード単一ファイル契約**:
  - Bayesian, Categorical, Questionnaire の全 3 スキルにおいて、`dashboard.Rmd` のレンダリングオプションに `self_contained: true` を明示する。
  - `dashboard_files/` 等の一時アセットへの依存を公開 HTML から除去し、`dashboard.html` 単一ファイルとしての原子的 promotion を保証する。
- **Questionnaire の 3 区分状態遷移と部分失敗時の後続処理遮断**:
  - 全設問成功時のみ `pass1 = "completed"`。
  - 1 件以上成功かつ 1 件以上失敗（`status == "error"`）時は `pass1 = "partial"`。
  - 全設問失敗または基盤エラー時は `pass1 = "failed"`。
  - `partial` および `failed` は、いずれも本番 Pass 2 確定、本番 Pass 3 確定、`sealed` 封印を完全に遮断（拒絶）する。
  - 部分失敗 run でも診断成果物（`summary.csv`、成功設問の `questionnaire_results.json`、`results_manifest.json`、失敗情報メタデータ）を出力・保持する。
  - `results_manifest.json` にはsummary.csv と実在する成功設問の成果物を登録し、`summary.csv` の成功設問集合と manifest の `question_result` 集合の完全一致を検証する。
  - `partial` run は整合性検証後に `--supersedes-run` 元として許可する。`failed` run は supersede 元指定を拒絶する。
- **finalizer CLI 引数の allowlist 制限と検証（`finalize_run_stage.R`）**:
  - `--target-name`: basename のみ受け付け、パス区切り、`.`、`..`、絶対パスを拒絶。run_meta の skill / stage から期待値（Bayesian/Categorical: `executive_summary.md`、Questionnaire: `cross_question_summary.md`、Pass 3: `dashboard.html`）を導出して一致を検証。
  - `--source-artifact`: 正規化後に当該 run の専用 staging 領域配下にある通常ファイルのみ許可。symlink、ディレクトリ、FIFO、run 外パス、prefix 衝突、`../` escape、source/target 同一指定を拒絶。
- **supersede 元 run の厳格な検証契約（`--supersedes-run`）**:
  - 再計算・再実行時は `--supersedes-run <path>` で元 run を指定する。
  - 元 run のディレクトリ存在、`run_meta.json` 整合性、同一スキルであること、`results_manifest.json` の存在、および全成果物の実ハッシュを厳格に検証する。
  - `superseded_results_manifest_sha256` は元 run の実ファイルバイト列から再計算して記録し、外部指定値を信用しない。
  - 自己参照および循環参照を拒絶する。
  - `supersede_reason` および入力・設定変更の有無（`inputs_changed`, `config_changed`）を新 run の `run_meta.json` に記録する。
- **cwd 付き kind タグ付き機械可読ハンドオーバー（`run_handover.json`）**:
  - Pass 1 完了時、実 run 直下に `run_handover.json` を出力する。
  - `cwd` に正規化されたリポジトリルートを明記し、CLI コマンド（`kind: "command"`）の `argv` はリポジトリ相対パスの文字列配列として保持する。
  - `pass2_ai` には `input_manifest`, `expected_results_manifest_sha256`, `staging_output`, `output`, および staging 確定対応の `finalize` CLI アクション（`finalize_run_stage.R`）を明記する。
- **入力データの推測なし hash_only 原則と設定スナップショット保存**:
  - コードによるデータの機微性推測を完全に排除する。
  - `role: "data"` の外部入力ファイルは、出自にかかわらず**一律で既定 `snapshot_policy: "hash_only"`** とし、データ本体を run ディレクトリへコピーしない。元パスと 64 桁 SHA-256 のみを記録する。
  - `analysis_config.json`（正式分析は `pass0_file`、テスト・手動は実効引数から生成する `resolved_cli`）および `question_config.csv` のみ「設定スナップショット」として実 run 直下に保存し、64 桁 SHA-256 を記録する。
- **メタデータにおける `inputs` 配列の単一正本化**:
  - 保存上の正本を `inputs` 配列のみとし、旧トップレベルフィールド（`input_data` / `input_sha256`）は JSON ファイルへ直接書き込まない。旧コード向けには読み取りアダプターが `inputs[role == "data"]` から透過的に導出する。
- **3 スキル統一の Pass 3 CLI レンダラー（`render_dashboard.R`）の配置**:
  - Bayesian に加え、Categorical および Questionnaire にも薄い CLI ラッパー `templates/render_dashboard.R --run-dir <path>` を新設・配置し、全スキルで一貫した Pass 3 実行を可能にする。
  - レンダラーから Rmd へは確定済み実 run パス（`params$run_dir`）を直接伝達し、二重探索を完全排除する。
- **厳格なパストラバーサル防止ガード（プレフィックス衝突回避）**:
  - `target == run_root || startsWith(target, paste0(run_root, "/"))` により、`/output/run_abc_external` のようなプレフィックス衝突を確実に拒絶する。
- **Questionnaire 親直下出力の完全廃止（破壊的変更）**:
  - `--out` 直下への出力を完全に廃止し、run ID 省略時も JST タイムスタンプを発行して必ず `runs/<id>/` 配下へ隔離出力する。
- **親直下を含む厳格な互換探索（`--discover-single-run`）**:
  - 親直下の旧成果物とサブディレクトリ候補の合計有効候補数を算出し、ちょうど 1 件のみ警告採用、0 件または 2 件以上は停止する。

## Capabilities

### New Capabilities
- `run-output-lifecycle`: 分析パイプラインにおける出力親ディレクトリと実実行ディレクトリの厳密な責務分離、秒単位衝突を防ぐ原子的ディレクトリ予約、実ファイルバイト列による決定的 results_manifest.json ハッシュ（POSIX 相対一意パス・role allowlist）、信頼境界検証に基づく run 外管理領域（out_root/.run_locks/）での stage 単位原子的排他ロック、run 内 staging 領域からの検証・promotion・クラッシュ回復と sealed 前空検証、スタブ（executive_summary_preview.md）と本番考察（executive_summary.md）の完全分離、プレビューダッシュボード（dashboard_preview.html）と本番ダッシュボード（dashboard.html、run_state = sealed）の完全分離、Categorical における Pass 1 唯一 run 作成原則（resumable claim 廃止）、legacy run の読み取り・preview 限定（本番確定拒絶）、Questionnaire の 3 区分状態遷移（completed / partial / failed）と部分失敗時遮断、finalizer の skill/stage 導出 allowlist 制限、3 スキル共通 self_contained: true ダッシュボード単一ファイル契約、supersede 元 run の厳格な検証契約（--supersedes-run）、設定スナップショット保存と推測なしデータ保護（hash_only）、入力配列 `inputs` の単一正本化、3 スキル統一の `render_dashboard.R --run-dir` 提供、cwd 付きハンドオーバー（`run_handover.json`）、プレフィックス衝突を防ぐ厳格なパストラバーサル防止、Questionnaire 親直下出力の完全廃止、および Categorical を含む真のリポジトリ 4-Pass 統合規約。

### Modified Capabilities
<!-- 既存 Capability (cell-evidence-interpretation, three-way-model-assessment, three-way-validation-cases) の要件変更はなし。 -->

## Impact

- **共有共通スクリプト**:
  - `.agents/shared/run_scope.R`: 親ディレクトリ検証（FAIL-FAST）、原子的ディレクトリ予約（`dir.create`）、`results_manifest.json` の決定的ソート出力および実ファイルバイト列ハッシュ検証、信頼境界検証付き run 外排他ロック（`.run_locks/`、原子的取得・解放、stale lock 回復）、staging からの promotion、クラッシュ回復、staging 空検証、追記限定ライフサイクル・sealed 制御、`run_meta.json` 原子的更新、supersede 元 run 検証、Pass 2/3 確定関数（`finalize_pass2`, `finalize_pass3`）、厳格パストラバーサルガード、親直下合算カウント互換探索、`inputs` 単一正本化および読み取りアダプター、`cwd` 付き `run_handover.json` 生成。
  - `.agents/shared/finalize_run_stage.R` (新設): AI や外部ツールが安全に Pass 2 / Pass 3 の確定（信頼境界検証、排他ロック、staging からの promotion・allowlist 検証・メタデータ原子的更新・クラッシュ回復）を実行するための共通 CLI ラッパー。
- **スキルテンプレート**:
  - `.agents/skills/vcd-bayesian-evidence-analysis/`: `results_manifest.json` 出力、`render_dashboard.R` の `--run-dir` 改定、設定スナップショット保存、`run_handover.json` 出力、排他ロックおよび staging 経由の `finalize_pass2` / `finalize_pass3` 組み込み、`executive_summary_preview.md` 出力、`self_contained: true` 明示、スタブプレビューバナー付き `dashboard_preview.html`。
  - `.agents/skills/vcd-categorical-analysis/`: Pass 1 唯一 run 作成原則対応（`claim_resumable_profile_run()` と `.render_claim` 廃止、`--profile` は consultation workspace へのプロファイル出力限定、`--render --config` が正式 run 予約）、`results_manifest.json` 出力、新設 `render_dashboard.R` ラッパー配置、`inputs` 統合、排他ロックおよび staging 経由の `finalize_pass2` 組み込み、`self_contained: true` 明示、プレビュー成果物分離。
  - `.agents/skills/questionnaire-batch-analysis/`: 親直下出力の完全廃止と `runs/<id>` 強制隔離、バッチ複数設問対応の `results_manifest.json` 出力、部分失敗時状態遷移（`completed` / `partial` / `failed`）と診断成果物保持、`inputs` 配列管理、新設 `render_dashboard.R` ラッパー配置、`self_contained: true` 明示、`cross_question_summary.md` の排他ロックおよび staging 経由 `finalize_pass2` 組み込み、プレビュー成果物分離。
- **スキル指示文書 (SKILL.md)**:
  - 各スキルの 4-Pass 実行フロー、CLI オプション体系、`results_manifest.json`（実バイト列ハッシュ・スキーマ制約）、run 外排他ロックと信頼境界検証、staging 領域からの確定・promotion 規約、スタブ・プレビュー分離と一回限り方針、legacy run の読み取り限定、Questionnaire 3 区分状態遷移、追記限定と sealed ライフサイクル、データ hash_only 原則、Questionnaire 移行ガイド、AI 完了報告 4 大要素の明記。
- **テストスイート**:
  - 同一秒 2 プロセスの原子的隔離、Pass 1成果物の不変性、sealed 後の追加・上書き拒絶、Questionnaire複数設問manifest完全性、Categorical manifest登録、Categorical Pass 0 profile 出力と Pass 1 正式 run 原子的作成の分離検証（claim廃止検証）、パストラバーサル（prefix 衝突、symlink）、親直下合算探索、supersede 自己参照/skill不一致/壊れた元run拒絶、`results_manifest.json` の実ファイルバイト列ハッシュ一致検証、manifest スキーマ制約（重複 path, 重複 question_id, 不正 role, 不正 hash 拒絶）、run 外排他ロックの信頼境界検証（改ざん out_root / run_output_dir で外部ディレクトリ作成阻止）、同時実行競合（1つだけ成功、置換なし、敗者エラー、sealed 不変性維持）、stale ロック回復、legacy run の preview 許可・本番確定拒絶検証、staging からの promotion と確定、確定失敗時の run 直下ゴミ成果物残存防止、promotion 後クラッシュからの冪等回復、ハッシュ不一致時の上書き拒絶、sealed 前の staging 空検証、スタブ生成後の本番 Pass 2 確定、プレビュー再実行上書き拒絶、プレビューダッシュボード生成後の本番ダッシュボード確定、プレビュー時の未封印検証、Questionnaire 部分失敗（`partial` / `failed`、診断成果物、後続拒絶）、finalizer allowlist 攻撃的テスト、3 スキル `self_contained: true` ダッシュボード単一ファイル性、`finalize_run_stage.R` 経由の確定、`cwd + argv` による任意ディレクトリ実行再現、Questionnaire 親直下出力廃止の単体・統合テストの追加。

## 最終調整の範囲

共通 run ロックによる preview・本番更新の直列化、promotion 前のトランザクション記録による source 消失後の回復、Questionnaire の設問別配置維持と診断用 handover、legacy preview の元 run 外出力を含む。公開 HTML はローカル一時アセットへ依存しないことを受入条件とし、レンダリング中の一時ファイル生成は許容する。実装範囲と検証順序は [正式実装計画](../../../docs/Artifacts/implementation_plan_006_0908.md) に固定する。
