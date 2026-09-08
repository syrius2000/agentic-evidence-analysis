## 1. 共有共通基盤（run_scope.R, finalize_run_stage.R）の改定

- [x] 1.1 親ディレクトリ検証関数 `assert_valid_out_root()` を実装し、予約名（`run_*` / `runs/*`）や既存 run 成果物が渡された際に自動読み替えせず FAIL-FAST 停止する診断ロジックを実装し、単体テストで検証する
- [x] 1.2 秒単位 JST タイムスタンプ衝突の原子的解決ロジックを実装し、`dir.create(candidate, recursive = FALSE)` の成否に基づく `_2`, `_3` 予約サフィックス付与により同一秒の 2 プロセスが別 run へ隔離されることを単体テストで検証する
- [x] 1.3 厳格パストラバーサルガード関数 `assert_path_within_run_dir()` を実装し、プレフィックス衝突（`paste0(run_root, "/")` チェック）、`../../` による親への逸脱、および外部シンボリックリンクを確実に拒絶するロジックを実装し、単体テストで検証する
- [x] 1.4 設定スナップショット保存関数（`analysis_config.json` / `question_config.csv`）、推測なし外部データ保護ロジック（`snapshot_policy: "hash_only"`）、複数入力配列 `inputs` の単一正本化および旧フィールド読み取りアダプター（`get_run_input_data()` 等）を実装し、単体テストで検証する
- [x] 1.5 3 スキル共通の統計成果物マニフェスト出力関数 `write_results_manifest()`（`artifacts` 配列を `path`, `role`, `question_id` 順に決定的一意ソート、スキーマ制約検証、固定 JSON 出力条件で一度だけ書き出し、実ファイルバイト列に対する SHA-256 を `results_manifest_sha256` として記録）および検証関数 `verify_results_manifest()`（実ファイルバイト列ハッシュおよび全登録成果物ハッシュの検証、POSIX 相対一意パス・role allowlist・question_id 一意性検証、論理正規化排除）を実装し、単体テストで検証する
- [x] 1.6 信頼境界検証付き run 外専用制御領域（`<out_root>/.run_locks/<run_lock_id>/`、`run_lock_id` は正規化済み絶対 run path の SHA-256 全 64 桁固定、`out_root` と `run_output_dir` の実パス一致検証、スキル別レイアウト整合性検証、symlink 拒絶）における stage 単位原子的排他ロック取得・解放関数 `acquire_stage_lock()` / `release_stage_lock()`、`lock_info.json` 記録、および明示的 `--recover-stale-lock` 回復ロジック（監査ログ `<out_root>/.run_locks/<run_lock_id>/audit.jsonl` 出力、PID 生存・ホスト不一致時の回復拒絶）を実装し、単体テストで検証する
- [x] 1.7 run 内 staging 領域（`staging/`）のライフサイクル制御（正式成果物集合外、追記限定は確定成果物限定、同一ファイルシステム rename による promotion、クラッシュ回復、本番 Pass 3 sealed 封印前の staging 空検証、sealed 後の staging 作成拒絶）を実装し、単体テストで検証する
- [x] 1.8 preview 成果物の一回限り生成制御（既存同名 preview がある場合の上書き拒絶、更新時の新規 supersede run 要求）を実装し、単体テストで検証する
- [x] 1.9 本番 Pass 2 確定関数 `finalize_pass2()`（信頼境界検証、run 外排他ロック保持、staging 成果物検証、promotion、`run_meta.json` 原子的更新、promotion 後クラッシュからの冪等回復、ハッシュ不一致時の上書き拒絶、`pending -> stub_generated -> completed` および `pending -> completed` 状態遷移、確定済み上書き拒絶、ロック解放）を実装し、単体テストで検証する
- [x] 1.10 Pass 3 確定関数 `finalize_pass3()`（信頼境界検証、run 外排他ロック保持、staging ダッシュボード検証、promotion、レンダリング前後の manifest / 考察ハッシュ再確認、由来ハッシュ記録、staging 空検証、`run_state = "sealed"` 封印、ロック解放による sealed 後 run 不変性保持）を実装し、単体テストで検証する
- [x] 1.11 共通確定 CLI ラッパー `.agents/shared/finalize_run_stage.R` を新規作成し、allowlist 検証（`--target-name` の basename 限定および skill/stage 導出一致検証、`--source-artifact` の staging 配下通常ファイル限定、symlink/run 外/同一指定拒絶）および確定実行ロジックを実装し、単体テストで検証する
- [x] 1.12 legacy run（v1.0）の読み取り・探索・診断・preview 生成限定モード（`--allow-legacy-run-meta`）を実装し、v1.0 に対する本番 Pass 2/3 確定、promotion、run_meta 更新、sealed 封印、および通常の `--supersedes-run` 元指定を拒絶するロジックを実装し、単体テストで検証する
- [x] 1.13 supersede 元 run 検証関数（`--supersedes-run` 引数処理、元 run 存在、`run_meta.json`、skill 一致、マニフェスト実ファイルバイト列ハッシュおよび全成果物実ハッシュ再計算・検証、自己参照・循環参照拒絶、`failed` run および legacy run 指定拒絶、`partial` run 整合性検証、`supersede_reason` および変更有無記録）を実装し、単体テストで検証する
- [x] 1.14 `cwd` 付き kind タグ付き機械可読ハンドオーバー `run_handover.json` 生成関数（`pass2_ai` に `input_manifest`, `expected_results_manifest_sha256`, `staging_output`, `output`, および `finalize` CLI アクションを含める）を実装し、単体テストで検証する
- [x] 1.15 `resolve_pass3_run_dir()` を改定し、暗黙 mtime 探索を廃止し、明示的互換フラグ `--discover-single-run` 指定時に親直下の成果物とサブディレクトリ候補を合算した有効総数をカウントして単一候補限定で警告付き採用（0件または2件以上時はエラー停止）するロジックを実装し、単体テストで検証する

## 2. Bayesian Evidence スキルテンプレートの改定

- [x] 2.1 `pass1_compute.R` および `analysis.R` にて、`results_manifest.json`（`evidence_results.json` 登録、スキーマ制約、決定的ソート、実ファイルバイト列ハッシュ記録）の生成、設定スナップショット保存、Pass 1 完了時の `cwd` 付き kind タグ付き `run_handover.json` 出力（`pass2_ai` に staging 確定対応 `finalize` アクション組み込み）、および `--supersedes-run` 対応を実装し、テスト実行で検証する
- [x] 2.2 `pass2_stub.R` にて、出力を `executive_summary_preview.md` に変更し、既存 preview 存在時の上書きを拒絶し、`--run-dir` 指定時にカレントディレクトリの既定ファイルを優先しないよう修正し、`pass2 = "stub_generated"` の記録、`validate_run_meta()` によるメタデータ検証、および `--allow-legacy-run-meta` 対応を組み込んでテストで検証する
- [x] 2.3 `render_dashboard.R` にて `--run-dir` による実 run 直接受け入れを標準とし、本番モードでの `stub_generated` 拒絶、`--preview` 指定時のプレビューダッシュボード出力（`dashboard_preview.html`、未封印維持、既存 preview 上書き拒絶、AI 考察未確定バナー表示）、本番ダッシュボード出力（`dashboard.html`、Pass 2 確定後、排他ロックおよび staging 経由 `finalize_pass3` による `sealed` 封印）を実装し、描画検証を行う
- [x] 2.4 `dashboard.Rmd` にて `self_contained: true` を明示し、渡された `params$run_dir` 直下を直接読み込み、二重探索ロジックをバイパス・廃止し、プレビュー実行時の明示的バナー表示および本番実行時の整合性検証を実装・検証する

## 3. Categorical Analysis スキルテンプレートの改定

- [x] 3.1 `analysis.R` にて、リポジトリ共通 4-Pass 体系との位置づけ（`--profile` を Pass 0 補助として consultation workspace に `data_profile.json` を出力し正式 run は作成しないこと、`--render --config ...` が唯一の正式 run 作成主体として原子的に予約すること）を是正し、既存の `claim_resumable_profile_run()` および `.render_claim` 機構を完全廃止し、親ディレクトリへの実 run 誤指定検知・停止、`results_manifest.json`（`categorical_results.json` 登録、スキーマ制約、決定的ソート、実ファイルバイト列ハッシュ記録）出力、設定スナップショット保存（データは hash_only）、`inputs` 配列・メタデータ v2.0 統合、および `--supersedes-run` 対応を実装し、単体テストで検証する
- [x] 3.2 Categorical 専用の薄型 CLI レンダラー `templates/render_dashboard.R` を新設・配置し、`--run-dir <path>` を受け取ってプレビュー（`dashboard_preview.html`、未封印）および本番（`dashboard.html`、排他ロックおよび staging 経由 `finalize_pass3` による `sealed` 封印）を実装・検証する
- [x] 3.3 `dashboard.Rmd` にて `self_contained: true` を明示し、公開 HTML のローカル一時アセット依存排除による単一ファイル完結性を確保して検証する
- [x] 3.4 `reserve_run_output_dir()` の衝突回避を維持し、`update_run_state()` は v2.0 の active / sealed と pass_status に移行する。旧 profile_complete / render_complete を新 run の状態として保存せず、既存 run-isolation テストを新契約へ改定して検証する

## 4. Questionnaire Batch Analysis スキルテンプレートの改定

- [x] 4.1 `batch_runner.R` にて、共通 4-Pass（Pass 1 batch compute）への位置づけを確立し、親直下出力を完全廃止して秒単位 JST タイムスタンプによる `runs/<id>` 構造への強制隔離、全設問結果に応じた 3 区分状態遷移（全成功で `completed`、一部失敗で `partial`、全失敗で `failed`）の実装、診断成果物（`summary.csv`、成功設問 `questionnaire_results.json`、`results_manifest.json`、`partial_failures` メタデータ）の出力・保持、成功設問と manifest の完全一致検証、確定実 run パスの `cwd` 付き kind タグ付き `run_handover.json` 出力、および `--supersedes-run` 対応（`partial` 許可、`failed` 拒絶）を実装し、テスト実行で検証する
- [x] 4.2 Questionnaire 専用の薄型 CLI レンダラー `templates/render_dashboard.R` を新設・配置し、`--run-dir <path>` を受け取って `partial` / `failed` run の本番レンダリング遮断、プレビュー（`dashboard_preview.html`、未封印）および本番（`dashboard.html`、排他ロックおよび staging 経由 `finalize_pass3` による `sealed` 封印）を実装・検証する
- [x] 4.3 `dashboard.Rmd` にて `self_contained: true` を明示し、公開 HTML のローカル一時アセット依存排除による単一ファイル完結性を確保して検証する
- [x] 4.4 設問横断考察成果物 `cross_question_summary.md` に対する排他ロックおよび staging 経由の `finalize_pass2()`、`finalize_run_stage.R` 確定処理を実装・検証する

## 5. 統合テスト・回帰検証および SKILL.md 文書化

- [x] 5.1 新規テストスイート `tests/test_run_scope_lifecycle.R` を作成し、以下を網羅して全アサーション通過を検証する：
  - 実 run 誤指定時の FAIL-FAST 停止
  - 同一秒 2 プロセスの原子的隔離（`_2` サフィックス）
  - 厳格パストラバーサルガード（プレフィックス衝突 `run_abc` vs `run_abc_external`、外部 symlink、`../../`）
  - 親直下＋サブディレクトリ合算探索（単一候補警告・複数候補停止）
  - 設定スナップショット保存と推測なし外部データコピー防止（hash_only ポリシー）
  - `inputs` 配列の単一正本化と読み取りアダプター動作
  - `results_manifest.json` のファイルバイト列ハッシュが作成時と検証時で一致することの検証
  - `results_manifest.json` のスキーマ制約検証（POSIX 相対一意パス、重複 path 拒絶、重複 question_id 拒絶、不正 role 拒絶、不正 hash 拒絶）
  - 3 スキル共通 `results_manifest.json` の決定的ソート出力および Questionnaire 複数設問 manifest の網羅的完全性検証
  - Categorical 結果が `results_manifest.json` に正しく登録されること
  - Categorical Pass 0 profile 出力（正式 run 非作成）と Pass 1 正式 run 原子的作成の完全分離検証（claim 機構廃止検証）
  - Pass 1 成果物が Pass 2 / 3 の実行後も完全に不変であることの検証
  - run 外排他ロックの信頼境界検証（改ざん `out_root` / `run_output_dir` の `run_meta.json` で外部ディレクトリへ一切作成されないことの検証）
  - run 外排他ロック（`<out_root>/.run_locks/<run_lock_id>/`、`run_lock_id` 全 64 桁）の同時実行競合検証（1 つだけ成功、置換なし、敗者エラー、`sealed` 後 run 内不変性維持）
  - stale ロック回復検証（`--recover-stale-lock`、PID 生存時拒絶、ホスト不一致拒絶、監査ログ出力）
  - legacy run（v1.0）に対する preview 生成許可および本番 finalizer / sealed 遷移の拒絶検証
  - staging 領域からの検証・promotion による成果物確定の動作検証
  - promotion 前の検証失敗で本番成果物が残らないこと、および promotion 後中断時に target と回復証跡を保持することの検証
  - promotion 完了後、run_meta 更新前の模擬クラッシュから冪等に回復できることの検証
  - 既存最終ファイルが存在しハッシュ不一致である場合に上書きを確実に拒絶することの検証
  - staging cleanup / sealed 前空検証（残存ファイルがある場合の封印拒絶）
  - `pass2_stub.R` によるスタブ生成（`executive_summary_preview.md`）後に本番 Pass 2（`executive_summary.md`）を確定できることの検証
  - preview 再実行時の既存同名 preview 上書き拒絶検証
  - Pass 2 における `pending -> stub_generated -> completed` および `pending -> completed` 状態遷移の検証、確定済み考察上書き拒絶の検証
  - プレビューダッシュボード生成（`dashboard_preview.html`）において run が sealed にならないことの検証
  - プレビューダッシュボード生成後に本番ダッシュボード（`dashboard.html`）を確定できることの検証
  - 3 スキルの `dashboard.Rmd` が `self_contained: true` であり公開 HTML がローカル一時アセットに依存しないことの検証
  - Questionnaire 部分失敗時の検証（`completed` / `partial` / `failed` 区分、診断成果物保持、失敗設問非登録、本番 Pass 2/3 確定遮断、`partial` の supersede 許可、`failed` の supersede 拒絶）
  - finalizer 引数の allowlist 攻撃的テスト（`../run_meta.json`、`unexpected.md`、他 skill 名、run 外 source、symlink、同一指定拒絶）
  - 共通 CLI ラッパー `finalize_run_stage.R` 経由で Pass 2 / Pass 3 が正常に確定できることの検証
  - 考察 Markdown 改ざん後の Pass 3 確定拒絶（由来ハッシュ不一致検知）
  - `finalize_pass3` によるダッシュボード確定、由来ハッシュ記録、および `run_state = "sealed"` への封印
  - `sealed` 状態となった run に対する追加成果物の書き込み・上書きが確実に拒絶されることの検証
  - `--supersedes-run` の厳格検証（自己参照拒絶、異なるスキル拒絶、成果物ハッシュが壊れた元 run の拒絶、`failed` run / legacy run 拒絶、正常な元 run からの実バイト列ハッシュ再計算と系統記録、入力・設定変更有無の記録）
  - `run_handover.json` の `cwd + argv` による任意カレントディレクトリからの再現実行
  - Questionnaire 親直下出力廃止と `runs/<id>` 強制隔離
  - 3 スキル共通の `render_dashboard.R --run-dir` によるダッシュボード生成
  - メタデータ v2.0 検証と `--allow-legacy-run-meta` レガシー互換フラグ動作
- [x] 5.2 各スキルの `SKILL.md`（`vcd-bayesian-evidence-analysis`, `vcd-categorical-analysis`, `questionnaire-batch-analysis`, `vcd-pass0-consultation`）に、CLI オプション体系、共通 4-Pass 正式対応表、Categorical claim 廃止、`results_manifest.json`（実ファイルバイト列ハッシュ・スキーマ制約）、信頼境界検証付き run 外排他ロック、staging 領域からの確定・promotion 規約、スタブ（`executive_summary_preview.md`）・プレビューダッシュボード（`dashboard_preview.html`）の分離と一回限り方針、legacy run 読み取り限定、Questionnaire 3 区分状態遷移、`self_contained: true` 単一ファイル契約、本番封印ライフサイクル、Pass 2/3 確定契約と共通 CLI ラッパー（allowlist 仕様）、クラッシュ回復、`--supersedes-run`、データ hash_only 原則、Questionnaire 移行ガイド、パス表現基準、AI 完了報告 4 大要素の記載を反映し、内容を確認する
- [x] 5.3 既存の全テストスイート（`tests/test_*.R`）を実行し、既存の統計計算およびモデル評価の振る舞いにリグレッションが発生していないことを確認する

### 既存タスクに含める最終受入条件

以下はタスク数を増やさず、対応タスクの完了判定へ含める。
- 1.6 / 1.8〜1.10: run 共通 → stage のロック順、所有 token 検証、preview と本番の競合、sealed 後公開拒絶、メタデータ更新消失防止。
- 1.7 / 1.9〜1.11: promotion 前の transaction_<stage>.json 記録、source 消失後の再実行、証跡欠損・不一致拒絶、staging 残存を promotion 前に拒絶。
- 1.12 / 2.2〜2.3 / 3.2 / 4.2: legacy の --preview-output-dir 必須と元 run 全ファイル不変性。
- 1.14 / 4.1: summary.csv 登録、設問別相対パス、partial / failed 非ゼロ終了、本番 next_actions 空配列、failed 時の診断出力不能ケース。
- 2.4 / 3.3 / 4.3: 一時アセット生成は許容し、公開 HTML がローカル一時アセットへ依存しないことを実描画で確認する。
- 5.3: 各 R テストを独立した Rscript プロセスで実行し、統計基盤サブディレクトリと関連 Python 契約テストも対象にする。既存失敗と新規失敗を区別して記録する。

### 修正実装の検証記録

検証指摘への修正と受入条件の実行結果は [実装完了報告](../../../docs/Artifacts/implementation_report_001_0909.md) を参照する。全Rテストを独立プロセスで順次実行し、今回の回帰は検出されなかった。修正前にも同じ失敗を再現した表示テスト3件と、対象スキル不在による1件のスキップは合格に含めない。
