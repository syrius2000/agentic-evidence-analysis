# 実装タスクリスト 001（Haiku 向け長時間実行用）

親計画: [implementation_plan_001_1013.md](implementation_plan_001_1013.md)（決定事項と確認マトリクスの正本）
作業ブランチ: `feat/skills-quality-hardening`（開始時 `main` @ `8298116`）

## 0. 作業ルール（必ず守る）

1. 各タスクは「テストを先に書く → 失敗を確認 → 最小実装 → 通過を確認」の順（TDD）。
2. タスク完了ごとにチェックボックスを `[x]` にし、根拠（実行したコマンドと結果の要点）を 1 行で `## 進捗ログ`（本ファイル末尾）に追記する。
3. フェーズ末に commit（1 フェーズ 1 commit）。メッセージは `<type>: <description>`（feat/fix/refactor/docs/test/chore）。`git push`、`git merge`、`git rebase`、`git reset --hard`、`rm -rf`、リモート操作は**行わない**。
4. 既存のユーザー変更・無関係な差分・未追跡ファイルは触らない。
5. R パッケージを実行時にインストールしない。不足は `check_r_dependencies()` の案内で停止する。
6. 生成するレポートの文言は日本語、時刻は JST。HTML は外部 CDN・外部 CSS/JS・外部フォント・絶対パスを参照しない。
7. テスト実行: 個別は `Rscript tests/<file>.R`、全体は `Rscript tests/run_regression_suite.R`。新規テストは `tests/run_regression_suite.R` の `official_tests` に追記する。
8. 一時ファイルは `/tmp/` または `tempdir()` のみ。リポジトリ外・`evidence_runs/` 外への解析出力はしない。

## 0.1 停止条件（検出したら作業を止め、状況を報告して指示を待つ）

- 統計値（JSON の数値、summary.csv の値）が変わる差分が出たとき
- 既存の成果物ファイル名・スキーマを、タスクに書かれていない形で変更する必要が出たとき
- spec（`openspec/specs/`）を、Change の delta 以外の方法で直接編集する必要が出たとき
- 回帰テストが想定外に失敗し、原因を 2 回の修正で特定できないとき
- 計画にない大規模な差分（1 タスクで 300 行超の変更など）が必要になったとき
- AGENTS.md と矛盾する作業が必要になったとき

---

## Phase 1: 検証（読み取りと一時ディレクトリのみ。製品コードは変更しない）

- [x] **T1.0 ベースライン取得**: `Rscript tests/run_regression_suite.R` を実行し、結果（通過/失敗）を進捗ログに記録する。失敗が既にあるなら、それを「既存の失敗」として一覧化する（以後の判定の基準）。
- [x] **T1.1 run_state 不整合の実確認**: `/tmp/probe/` に R スクリプトを作り、`.agents/shared/run_scope.R` を `source` して次を確認する。
  - `run_state` が `completed` / `failed` の `run_meta.json`（interface_version 2.0）を `read_run_control()` に渡すと `[ERROR] 不正なrun_state` になるか（`run_scope.R:510`）。
  - 書込側: `run_freq.R:1291`、`run_means.R:677`、`batch_runner.R:596`、`analysis.R:508` が `write_run_meta(extra=list(run_state=...))` で何を書くかを、実際に各スキルを fixture で実行して `run_meta.json` から確認する。
  - 結果（再現手順・出力）を `docs/Artifacts/plans/findings_001_1013.md` に記録する。バグ確定なら Phase 2 の T2.4 を有効化する。
- [x] **T1.2 ヘッドレス Chrome で MathML 描画確認**: bayesian の既存 fixture（`tests/fixtures/vcd_bayesian_dashboard/`）から `katex::katex_mathml("x^2")` を埋め込んだ最小 HTML を `/tmp` に作り、ヘッドレス Chrome（`mcp__claude-in-chrome` もしくは `chrome --headless --screenshot`）で描画して崩れがないか確認する。結果を findings に記録する。使えない環境なら「未検証」と記録して続行。
- [x] **T1.3 pass2_stub の呼び出し元確認**: `grep -rn "pass2_stub" .agents tests docs` で呼び出し元を列挙し、現行のワークフローで使われているかを findings に記録する。
- [x] **T1.4 出力先の確認**: `vcd-categorical-analysis/templates/analysis.R:54,388`（`target_dir`、`lock_dir`）と `batch_runner.R` の `q_out`（309, 420 行付近）が run ディレクトリ配下に限定されるかを読み取って確認し、findings に記録する。
- [x] **T1.5 spec 一致監査**: `openspec/specs/` の 19 件について、`run_state` / `run_meta` / `results_manifest` / `manifest.json` / `run_state.json` / `.run_lock` / MathML / KaTeX / `self_contained` / 外部 URL に関する記述を grep し、`implementation_plan_001_1013.md` §2.6 の表に載っていない衝突がないか確認する。見つかれば表に追記する。`changes/archive/` は編集しない。
- [x] **T1.6 Phase 1 commit**: 次をまとめて commit する（`docs: add implementation plan and phase 1 verification findings`）。
  - `docs/Artifacts/plans/implementation_plan_001_1013.md`
  - `docs/Artifacts/plans/implementation_tasks_001_1013.md`（進捗ログ込み）
  - `docs/Artifacts/plans/findings_001_1013.md`
  - `.claude/settings.json`（実行権限。リポジトリに残したくない場合はユーザーが指示した時点で `.claude/settings.local.json` へ移す）
  いずれも未追跡で作成済み。製品コードは含めない。

## Phase 2: バグ修正（TDD）

- [x] **T2.1 subset_expr の fail-fast（テスト）**: `tests/test_questionnaire_subset_expr_failure.R` を新規作成。不正な `subset_expr`（構文エラー、存在しない変数、非 logical、長さ不一致）を含む設問 CSV を使い、次を検証する: 当該設問が `failed` になり理由が記録される / 他設問は成功する / 全行 TRUE にフォールバックしない。`official_tests` に追記し、失敗を確認する。
- [x] **T2.2 subset_expr の fail-fast（実装）**: `questionnaire-batch-analysis/templates/batch_runner.R:285-288` の `tryCatch` フォールバックと、非 logical・長さ不一致の黙殺（286 行）を、`stop()` に変更する。外側の設問単位 `tryCatch`（281 行）が `failed` と理由を記録することを確認する。`SKILL.md` のアンチパターン記述と整合させる。
- [x] **T2.3 pass2_stub の旧スコア文言削除**: テスト `tests/test_pass2_stub_no_legacy_score.R` を先に作り（出力 MD に「Evidence Score」による偏り記述が無いこと）、`vcd-bayesian-evidence-analysis/templates/pass2_stub.R:75,91` を現行のセル診断用語（`SKILL.md` と `docs/reference/skill_responsibilities.md` §4 で確認）へ置換する。T1.3 で未使用と判明した場合は報告して判断を仰ぐ（削除はしない）。
- [x] **T2.4 run_state 語彙の統一**（T1.1 でバグ確定の場合のみ）: 語彙を `active / completed / failed / sealed` と定め、`read_run_control`（`run_scope.R:510`）の許可リストを拡張し、`RUN_SCOPE_RUN_STATES` のような定数にまとめる。`tests/test_skill_run_isolation.R:226,325,393` などの期待値を確認し、不足分を追加する。状態遷移（sealed への遷移は一方向）を壊さないこと。
- [x] **T2.5 categorical の `.run_lock` を共通ロックへ**: `analysis.R:386-398` の独自 `.run_lock` を廃止し、`run_scope.R` の `acquire_stage_lock` / `release_stage_lock` を使う。spec（`two-way-evidence-analysis`）の「同一署名・同一出力 root の並行実行は `CONCURRENT_RUN_IN_PROGRESS` で失敗」を満たすため、署名単位でロックを取る。**これは挙動が変わるため、実装前に設計案を進捗ログに書き、停止条件に該当しないか自己点検する**。テストは 2 プロセス同時実行（`system2` の背景起動）で後続が失敗することを検証する。
- [x] **T2.6 lock_info の原子的書込**: `run_scope.R:852` 付近で、`lock_info.json` を tmp に書いてから `rename` する。取得失敗時にロックディレクトリを残さないこと。テストを `tests/test_run_scope_lock.R` に追加（既存のロックテストがあれば追記）。
- [x] **T2.7 回帰テスト**: `Rscript tests/run_regression_suite.R`。T1.0 の基準と比較し、新規の失敗が無いこと。
- [x] **T2.8 レビューと commit**: code-reviewer エージェントで差分をレビューし、CRITICAL / HIGH を修正する。`fix: ...` で commit。**ここでユーザーへ中間報告（結論先出し）を出し、レビューを受ける。**

## Phase 2R: Phase 2 レビュー指摘への再実装（2026-10-13 中間レビュー）

決定済み: H2 は (a) 共通 `acquire_stage_lock` へ寄せる。独自ロック（`out_root/.run_locks/<署名>.lock`）は廃止する。
残骸掃除（`evidence_runs/` の削除）は完了済み。以後、テストは自分の出力を必ず後始末する。

- [x] **R1 [H1] run_state 受理テスト（RED→GREEN）**: `tests/test_run_scope_run_state.R` を新規作成し `official_tests` に登録。`read_run_control` が `active / completed / failed / sealed` を受理し、不正値（例 `bogus`）と `run_state` 欠損を拒絶することを検証する。**`RUN_SCOPE_RUN_STATES` を元の `c("active","sealed")` に戻した状態で RED になることを確認してから、現行に戻して GREEN にする**。確認手順を進捗ログに書く。
- [x] **R2 [H2] categorical のロックを共通ロックへ**:
  - `analysis.R:383-407` の独自ロック（`.run_locks/<prefix16>.lock` と `on.exit`）を廃止する。
  - 同一署名・同一出力 root の並行実行を排他するため、署名を区別できる単位で `acquire_stage_lock` を使う。ロック取得の対象ディレクトリと stage 名の設計案を**実装前に進捗ログへ書く**（`acquire_stage_lock(run_dir, stage, ...)` は run ディレクトリ単位のため、`reserve_run_output_dir` 前に署名単位でロックを取る方法の可否を `run_scope.R:739-868` で確認する）。共通ロックで署名単位の排他が実現できない場合は**停止して報告**し、判断を仰ぐ。
  - spec（`two-way-evidence-analysis`）は「同一署名の並行実行は `CONCURRENT_RUN_IN_PROGRESS` で失敗、`run_state.json`（out root 直下）に記録、強制終了時の stale lock は手動削除で復旧」。この挙動を維持する。
  - 失敗メッセージに**ロックの場所**を含め、`SIGKILL` 後の復旧手順（どのディレクトリを手動削除するか）を `SKILL.md` か `references/` に記載する。
  - 既存の並行実行テスト（`tests/test_vcd_categorical_run_isolation.R` の Test 6）が通ること。あわせて「ロックが残存している状態で再実行すると `CONCURRENT_RUN_IN_PROGRESS` になり、メッセージにロックパスが含まれる」を検証するテストを追加する。
- [x] **R3 [M1] ロックテストの修正**: `tests/test_run_scope_lock.R` を `official_tests` に登録する。`lock_info.json` の書込が失敗するケース（`atomic_run_json` を一時的に失敗するよう差し替える等）を作り、**ロックディレクトリが残らないこと**を検証する。`run_scope.R` の未使用変数 `write_ok` を削除する。
- [x] **R4 [M2] テストの後始末**: `tests/test_questionnaire_subset_expr_failure.R` のトップレベル `on.exit` を、スクリプト末尾と失敗時（`tryCatch` / `finally`）の双方で明示的に `unlink(out_dir, recursive = TRUE)` する形へ変更する。**`evidence_runs/` 配下に、テスト終了後に残るものがないこと**を、実行前後の `find evidence_runs` の差分で確認する。ほかの新規テストにも同様の後始末が必要か確認する。
- [x] **R5 [M3] pass2_stub の整理**: `pass2_stub.R` の未使用変数 `score_val` を削除する。`row$Score` のような data.frame 行の部分一致を避け、`[["Residual"]]` のように明示的に取り出す。`tests/test_pass2_stub_no_legacy_score.R` に、出力に「Residual」が含まれることの検証を追加する。
- [x] **R6 全体回帰と報告**: `Rscript tests/run_regression_suite.R` を実行する。**ベースライン（main: 47 PASS / 3 FAIL、同じ 3 本）との比較**を進捗ログに記録する。実行前後で `evidence_runs/` に残骸が増えていないことも確認する。fix: で commit し、**中間報告を出して停止**する。

## Phase 2R-2: Phase 2R レビュー指摘の追加修正（2026-10-13 再レビュー。Phase 2B の前に実施）

承認済み: categorical の署名ロックは、`run_scope.R` の兄弟 API（`acquire_signature_lock` / `release_signature_lock`）で実現する（`acquire_stage_lock` は run ディレクトリが前提で使えないため）。stale 回復は持たず、手動削除で復旧する。

- [x] **R7-1 [M-a]** `tests/test_vcd_categorical_run_isolation.R` の Test 6 から削除されたアサーション `assert(file.exists(file.path(suffixed_run, "categorical_results.json")), "suffix付きrunに成果物が保存される")` を復元する（ロック残存の新しい検査は残す）。
- [x] **R7-2 [M-b]** 進捗ログ R2 の記述を訂正する: `acquire_signature_lock` は stale 回復を持たず、回復は手動削除のみ。`acquire_stage_lock` が使えない理由（run ディレクトリが予約前に存在しない）を1行で記録する。
- [x] **R7-3 [M-c]** `acquire_signature_lock` で `dir.create` が失敗したとき、`dir.exists(lock_path)` で原因を区別する。存在しない場合（権限不足など）は `CONCURRENT_RUN_IN_PROGRESS` ではなく別のエラーにする。失敗メッセージには、`lock_info.json` から読める pid と取得時刻を含める（読めなければ省略）。`vcd-categorical-analysis/SKILL.md` の復旧手順に「削除前に `lock_info.json` の pid が生存していないこと（`ps -p <pid>`）を確認する」を追記する。
- [x] **R7-4 [LOW]** `release_signature_lock` の token 不一致は `stop()` ではなく `warning()` にする（`on.exit` 内で元のエラーを隠さないため）。`tests/test_run_scope_lock.R` に、署名ロックの `lock_info.json` 書込失敗時にロックが残らないことと、token 改ざん時の挙動の検証を追加する。
- [x] **R7-5** 全体回帰を実行し、結果（期待: 54 PASS 以上 / 既知 3 FAIL）を進捗ログに記録する。`fix:` で commit し、中間報告を出して停止する。

## Phase 2B: 既存の失敗テスト 3 本の修復（別タスク。Phase 2R のレビュー後に実施）

原因: テストが名前空間外の一時ディレクトリを `--out` に渡しており、`[OUTPUT_ROOT_OUTSIDE_SKILL_NAMESPACE]` で停止する（`73ad8fc` で導入された名前空間制限にテストが追随していない。main でも同じ）。今回改修した `batch_runner.R` の正常系を覆うため、修復する。製品コードは変更せず、**テスト側のみ**を直す。

- [x] **B1** `tests/test_questionnaire_batch_smoke.R`: `--out` を `evidence_runs/questionnaire` 配下の一意なディレクトリにし、終了時に明示的に削除する。
- [x] **B2** `tests/test_summary_csv_new_columns.R`: 同上。
- [x] **B3** `tests/test_vcd_categorical_input_boundary.R`: 3 件の失敗内容を特定し、同じ名前空間制限が原因か確認する。別の原因なら**停止して報告**する。
- [x] **B5 [M-d]** 全体スイート実行後に `evidence_runs/` へ残骸を残す既存テストの後始末を、**テスト側だけ**で直す。対象: `symlink_escape`、`duplicate_slug`（questionnaire）、`sas_proc_means` の `test_*`、`vcd_categorical_reporting` の `test_*` と `schema_batch_*`、`vcd_bayesian` の `.test_pass1_*`、`evidence_decision_review` の `.test_edr_*`。トップレベルの `on.exit` は使わず、明示的な `unlink`（`tryCatch(finally=)`）にする。**確認:** `git archive HEAD` のクリーン展開で全体スイートを実行した後、`find evidence_runs -mindepth 2` が 0 件であること。
- [x] **B4** 3 本とも、実行前後で `evidence_runs/` に残骸が残らないことを確認する。全体回帰で 52 本すべて PASS になることを確認し、`test:` で commit、中間報告を出して停止する。

## Phase 3: run 基盤の統一（OpenSpec Change「unify-run-metadata」）

- [x] **T3.0 Change の起こし方**: `openspec/changes/archive/2026-10-06-standardize-evidence-run-output-contract/` を構造の見本として読み、`openspec change` / `openspec list` の使い方を `openspec --help` で確認する。Change 名は `unify-run-metadata`。proposal、design（必要なら）、tasks、delta specs を作る。
- [x] **T3.1 delta spec の作成**（`evidence-run-layout`）: ADDED/MODIFIED で次を規定する。
  - 物理名の規則は**現行のまま維持**する（`run_001` → `run_001`）。`run_001` 例を訂正しない。`logical_run_id` の記録は現行 spec で要求済みで、新規要件にしない（Q18=a は撤回。計画書 §2.7 参照）
  - `run_state` の語彙と遷移
  - `run_meta.json` が唯一のメタであること（sas の `manifest.json`、run 内の `run_state.json` は廃止）。出力 root 直下の早期失敗記録 `run_state.json` は維持
  - `environment` ブロック（`r_version, platform, packages[{name,version}], seed, session_info_path`）
  - `runs_index.jsonl`（追記専用）と `latest.json`（原子的更新、symlink 不使用）
- [x] **T3.2 delta spec の作成**（`sas-proc-freq` / `sas-proc-means` / `two-way-evidence-analysis`）: `manifest.json` の記述を `run_meta.json` / `results_manifest.json` に置換。two-way は run 内 `run_state.json` の廃止と root 直下の早期失敗記録の維持、`.run_lock` を共通ロックで実効化する旨を明確化。
- [x] **T3.3 `openspec validate`**: Change が検証を通ること。
- [ ] **T3.4 `environment` ブロック（テスト→実装）**: `write_run_meta`（`run_scope.R:1340-1372`）に `environment` を追加する共通関数 `collect_run_environment()` を `.agents/shared/` に実装。テストで必須キーの存在と、パッケージ版が実際の `packageVersion()` と一致することを検証。`sessionInfo()` は `session_info.txt` に出力し `results_manifest` に登録する。
- [ ] **T3.5 メタ統合（sas）**: `run_freq.R:1241-1273` と `run_means.R` の `manifest.json`（`manifest_version`, `artifacts`, `r_environment`）の内容を `run_meta.json` / `results_manifest.json` へ移し、`manifest.json` の出力を廃止する。**移す項目の対応表を先に進捗ログに書く**（落とさない）。sas の既存テストを更新し、下流で `manifest.json` を参照している箇所を `grep -rn "manifest.json"` で全て洗い出して更新する。
- [ ] **T3.6 メタ統合（categorical）**: run 内の `run_state.json`（`analysis.R:404-416`）を `run_meta.json` に統合。`validate_input.R:15` と `analysis.R:57,82` の root 直下の早期失敗記録は維持。
- [ ] **T3.7 runs_index / latest**: `append_run_index()` と `write_latest()` を `run_scope.R`（または新規 `.agents/shared/run_index.R`）に実装。追記は `file(..., "a")` の 1 行書込、`latest.json` は tmp→rename。全スキルの run 確定時に呼ぶ。複数 run のテストを追加。
- [ ] **T3.8 ID 方式の確認（実装変更なし）**: 各スキルの物理名の決め方（呼び出し側）を一覧化し、`logical_run_id` が全スキルの `run_meta.json` に記録されていることを確認する。**物理名の生成ロジックは変えない**（変える必要が出たら停止）。
- [ ] **T3.9 回帰とレビュー**: 全テスト、code-reviewer。統計値が不変であることを fixture の JSON 差分で確認。commit。**ユーザーへ中間報告。**

## Phase 4: HTML・数式（OpenSpec Change「harden-dashboard-html-contract」）

- [ ] **T4.0 Change の起こし方**: T3.0 と同様。delta spec: `shared-dashboard-presentation`（数式の native MathML 契約、画像は run 内相対参照可、検査の共有化、`embed_images`）、`three-way-dashboard-reporting`（検査項目の追加）。`comparative-evidence-reporting` は変更なし。
- [ ] **T4.1 共有検査 `check_html_self_contained()`**（テスト→実装）: `.agents/shared/html_contract_check.R`。検出項目: `url(`、`@import`、`<script|link|img ... src=http`、絶対パス（`/Users/`、`C:\`）、`katex-html` クラス、`@font-face`、`<img src>` の `..` 逸脱と run 外参照、参照先ファイルの不在。警告として返し、呼び出し側が表示する。`render_dashboard.R:169-182` の既存検査を置き換え、categorical・questionnaire・reporting からも呼ぶ。
- [ ] **T4.2 `render_math(tex, display)` 共有ラッパー**: `.agents/shared/render_math.R`。`katex` が使えれば `katex::katex_mathml()`、使えなければ `<code class="tex-fallback">`。フォールバックが発動した回数を返し、ダッシュボードに「数式の簡易表示（フォールバック）を使用しました」を明示する。テスト: `katex` あり/なし（`requireNamespace` をモック）。
- [ ] **T4.3 bayesian の数式差し替え**: `dashboard.Rmd:133-146` の `katex_html` を `render_math()` に変更。`katex.min.css` の埋込（`:269-282`）と `templates/assets/katex.min.css` を削除し、参照箇所（`grep -rn katex.min.css`）を全て更新。出力に `<math` が含まれ `katex-html` が含まれないことをテスト。**数式の内容（TeX 文字列）は変更しない。**
- [ ] **T4.4 categorical の数式確認**: `dashboard.Rmd:9`（`--mathml`）と `report.Rmd:450`（`$$...$$`）が MathML で出力されることをテスト。`report.Rmd` に `--mathml` 指定が無ければ追加する。
- [ ] **T4.5 画像の検査と `embed_images`**: questionnaire の `report.html` の `<img src="figures/...">` を T4.1 の検査対象にし、画像を `results_manifest` に登録する。`analysis_config` に任意の `embed_images`（既定 false）を追加し、true のとき base64 data URI にする（`config_validation.R` / schema に追加）。
- [ ] **T4.6 共有ヘルパー `html_*`**: `.agents/shared/html_components.R` に、`htmltools::tags` を使う関数（`html_card()`、`html_badge()`、`html_details()`、`html_note()` など、既存の直書きから実際に繰り返されているものだけ）を作る。**先に重複の多い箇所を `grep` で洗い出して一覧化し、必要最小限に絞る。** エスケープは `tags` に任せ、手動 `htmlEscape` を置換する。
- [ ] **T4.7 tags 移行（小単位）**: 次の順に、**1 ファイルずつ**移行する。各ファイルごとに「移行前の HTML を fixture で保存 → 移行 → 正規化して差分比較 → 意味のある差分が無いこと」を確認してから次へ。
  1. `.agents/shared/dashboard_glossary.R`
  2. `questionnaire-batch-analysis/templates/dashboard.Rmd`
  3. `vcd-bayesian-evidence-analysis/templates/dashboard.Rmd`
  4. `vcd-categorical-analysis/templates/dashboard.Rmd`（疎表抑制文言の 6 回の繰り返しは関数 1 つにまとめる）
  比較は、空白と属性順を正規化した上で、テキスト内容・タグ構造・`class` が一致すること。差分が出たら、意図しない変更か整形のみかを進捗ログに書く。**統計値の表示が変わる場合は停止。**
- [ ] **T4.8 回帰、レビュー、commit**: 全テスト、code-reviewer、`security-reviewer`（HTML エスケープ）。

## Phase 5: 完了処理

- [ ] **T5.1 最終回帰**: `Rscript tests/run_regression_suite.R`。基準（T1.0）との差を報告する。
- [ ] **T5.2 ドキュメント更新**: 影響を受ける `SKILL.md`、`docs/reference/skill_responsibilities.md`、`README.md`、`docs/Artifacts/README.md` を更新（run 出力の構成、数式方針、`embed_images`）。
- [ ] **T5.3 完了報告**: 結論先出しで、次を区別して報告する: 構文確認 / 静的確認 / テスト / 解析実行 / 独立 QA（未実施）/ Owner 判断 / commit / push（未実施）。未検証事項（ヘッドレス描画など）を明記する。
- [ ] **T5.4 OpenSpec アーカイブ**: **ユーザーの指示があるまで `openspec archive` は実行しない。**

---

## 進捗ログ

（各タスクの完了時に追記する）

- [2026-10-13 18:53:51 JST] T1.0: `Rscript tests/run_regression_suite.R` 実行完了 (50本中47 PASS, 3 FAIL: test_vcd_categorical_input_boundary.R, test_questionnaire_batch_smoke.R, test_summary_csv_new_columns.R。既存の出力ルート名前空間制限等による既知の失敗として記録)
- [2026-10-13 18:54:53 JST] T1.1: `read_run_control()` で `run_state` が `completed` / `failed` の時に `[ERROR] 不正なrun_state` となるバグを実機で再現・確認。T2.4 を有効化決定
- [2026-10-13 18:55:43 JST] T1.2: ヘッドレス Chrome による MathML レンダリングスクリーンショット採取 (`/tmp/mathml_probe.png`) 完了。崩れなく正常描画を確認
- [2026-10-13 18:56:05 JST] T1.3: `pass2_stub.R` 呼び出し元調査完了。`vcd-bayesian` の Pass 2 骨子生成として現役稼働中であることを確認
- [2026-10-13 18:56:20 JST] T1.4: `analysis.R` および `batch_runner.R` の出力先確認完了。run 配下・適切な早期失敗 root 記録の契約を確認
- [2026-10-13 18:56:28 JST] T1.5: `openspec/specs/` 全 19 件の一致監査完了。計画書 §2.6 の記載と完全に整合していることを確認
- [2026-10-13 18:57:27 JST] T1.6: Phase 1 成果物を commit (5116b20: `docs: add implementation plan and phase 1 verification findings`)
- [2026-10-13 19:01:09 JST] T2.1: `tests/test_questionnaire_subset_expr_failure.R` 作成・`run_regression_suite.R` 登録。RED状態（不正なsubset_exprがsuccessになってしまうバグ）を確認
- [2026-10-13 19:01:53 JST] T2.2: `batch_runner.R` の subset_expr を fail-fast (`stop()`) に改修。GREEN確認（該当設問のみerror記録、他設問続行）
- [2026-10-13 19:03:10 JST] T2.3: `test_pass2_stub_no_legacy_score.R` 作成(RED)→`pass2_stub.R` の「Evidence Score」文言をセル診断・標準化残差用語へ改修(GREEN)
- [2026-10-13 19:04:58 JST] T2.4: `run_scope.R` に `RUN_SCOPE_RUN_STATES` (`active`, `completed`, `failed`, `sealed`) を新設し `read_run_control` 許可リストを拡張。`test_skill_run_isolation.R` (86 tests PASS) 含む全状態の受容を確認
- [2026-10-13 19:08:00 JST] T2.5設計自己点検: 署名単位ロックは同一署名並行実行の排他 (`CONCURRENT_RUN_IN_PROGRESS`) を保証するため、`reserve_run_output_dir` 前に `out_root/.run_locks/<signature>.lock` を `dir.create` で原子的取得し、`base::on.exit` で解放。停止条件（統計値、スキーマ、成果物名、spec直接編集、AGENTS.md）への抵触なしと点検完了
- [2026-10-13 19:08:35 JST] T2.5: `analysis.R` の排他ロックを `reserve_run_output_dir` 先行の署名ロックに移行。`test_vcd_categorical_run_isolation.R` Test 6 で並行プロセス遮断 (status=1, `CONCURRENT_RUN_IN_PROGRESS`) を確認 (52 PASS)
- [2026-10-13 19:05:41 JST] T2.6: `run_scope.R` の `acquire_stage_lock` で `lock_info.json` 書込失敗時にロックディレクトリを即時クリーンアップする例外安全性を確保。`tests/test_run_scope_lock.R` にて検証完了
- [2026-10-13 19:10:23 JST] T2.7: `run_regression_suite.R` 再実行完了 (52本中49 PASS, 3 FAIL)。新規失敗0件、新規追加テスト2本ともPASS確認
- [2026-10-13 19:48:10 JST] R1: `tests/test_run_scope_run_state.R` 新規作成・`run_regression_suite.R` 登録。`RUN_SCOPE_RUN_STATES` を旧定義 `c("active","sealed")` に戻して RED（2 FAIL）確認後、現行（4状態）に戻し GREEN（8 PASS: active/completed/failed/sealed 受理、bogus/running/NULL/NA 拒絶）を確認
- [2026-10-13 19:51:30 JST] R2設計案: categorical の排他ロックは同一署名の並行実行遮断のため、out_root/.run_locks/<prefix16> を共通 run_control_dir / acquire_stage_lock と類似の構造・メタデータ形式（lock_info.json: pid, token, stage='run' 等、例外安全性クリーンアップ、自動stale回復は持たず手動削除復旧）を備えた共通 API として run_scope.R に `acquire_signature_lock(out_root, skill, signature)` / `release_signature_lock(lock_obj)` を新設して統合（run ディレクトリが予約前に存在しないため acquire_stage_lock は使用不可）。analysis.R 内の生 dir.create / unlink 独自実装を完全撤廃し共通基盤へ一本化。排他失敗時は CONCURRENT_RUN_IN_PROGRESS を out_root 直下 run_state.json に記録し、エラーメッセージにロックディレクトリパスを明記。停止条件への抵触なし。
- [2026-10-13 19:53:10 JST] R2: `analysis.R` の排他ロックを共通 `acquire_signature_lock` / `release_signature_lock` へ移行。`SKILL.md` に SIGKILL 復旧手順を追記。`test_vcd_categorical_run_isolation.R` (54 PASS) で並行排他遮断およびロック残存時拒絶（メッセージ内のロックパス含有）を検証完了
- [2026-10-13 19:54:05 JST] R3: `tests/test_run_scope_lock.R` を `official_tests` に登録。`run_scope.R` から未使用変数 `write_ok` を削除。`atomic_run_json` 擬似障害注入によるロックディレクトリ残存防止例外安全性を検証完了 (14 PASS)
- [2026-10-13 19:55:00 JST] R4: `tests/test_questionnaire_subset_expr_failure.R` および `test_vcd_categorical_run_isolation.R` の後始末を `tryCatch(..., finally = { unlink(...) })` および明示的クリーンアップに改修。テスト実行前後の `find evidence_runs` で残骸が一切残らない（0件）ことを確認
- [2026-10-13 19:55:40 JST] R5: `pass2_stub.R` の不要変数 `score_val` を削除し、行アクセスを `row[["Residual"]]` に厳格化。`test_pass2_stub_no_legacy_score.R` に「Residual」出力の含有検証を追加し GREEN 確認
- [2026-10-13 19:58:30 JST] R6: `Rscript tests/run_regression_suite.R` 実行完了 (54本中51 PASS, 3 FAIL)。ベースライン（main: 47 PASS / 3 FAIL）と完全同一の3本（`test_vcd_categorical_input_boundary.R`, `test_questionnaire_batch_smoke.R`, `test_summary_csv_new_columns.R`）のみの失敗であることを確認。新規追加テスト（R1: run_state, R3: lock）含む51本すべてPASS。実行後の `evidence_runs/` も完全消去確認。Phase 2R 完了。
- [2026-10-13 21:03:30 JST] R7-1: `tests/test_vcd_categorical_run_isolation.R` Test 6 に削除されていた `assert(file.exists(file.path(suffixed_run, "categorical_results.json")), "suffix付きrunに成果物が保存される")` を復元し、単体実行 PASS (55 PASS / 0 FAIL) を確認
- [2026-10-13 21:01:42 JST] R7-2: 進捗ログ R2 の記述を訂正（stale 回復なし・手動削除復旧のみ、run ディレクトリ未存在による acquire_stage_lock 使用不可の理由を明記）
- [2026-10-13 21:02:30 JST] R7-3: `run_scope.R` の `acquire_signature_lock` で `dir.create` 失敗時に `dir.exists` で原因を区別（非存在時は CANNOT_CREATE_LOCK_DIR）、競合時は `lock_info.json` の pid と acquired_at を取得し `analysis.R` のエラーメッセージに付与。`vcd-categorical-analysis/SKILL.md` の手動復旧手順に `ps -p <pid>` 生存確認を追記
- [2026-10-13 21:02:50 JST] R7-4: `run_scope.R` の `release_signature_lock` で token 不一致時に `stop()` ではなく `warning()` を発出し `invisible(FALSE)` とするよう改修。`tests/test_run_scope_lock.R` に署名ロックの書込失敗時クリーンアップと token 改ざん時 warning 検証を追加 (20 PASS / 0 FAIL)
- [2026-10-13 21:05:00 JST] R7-5: `Rscript tests/run_regression_suite.R` 全体回帰実行完了 (54本中51 PASS, 3 FAIL: 既知の同一3本のみ)。新規失敗0件、Phase 2R-2 追加検証すべてGREEN。Phase 2R-2 完了。
- [2026-10-13 21:28:54 JST] Phase 2B 追加作業: `tests/test_run_scope_lock.R` に実 lock_info.json 配置時の競合メタデータ（pid, acquired_at）取得検証、および読取専用ディレクトリに対する CANNOT_CREATE_LOCK_DIR 検証を追加し GREEN 確認 (27 PASS / 0 FAIL)
- [2026-10-13 21:29:21 JST] B1: `tests/test_questionnaire_batch_smoke.R` の `--out` を `evidence_runs/questionnaire` 配下の一意なパスに変更し、tryCatch(finally=) で明示的クリーンアップを実装。単体 GREEN (22 PASS / 0 FAIL) 確認
- [2026-10-13 21:30:30 JST] B2: `tests/test_summary_csv_new_columns.R` の `--out` を `evidence_runs/questionnaire` 配下の一意なパスに変更し、tryCatch(finally=) で明示的クリーンアップを実装。単体 GREEN (17 PASS / 0 FAIL) 確認
- [2026-10-13 21:32:12 JST] B3: `tests/test_vcd_categorical_input_boundary.R` の Test 14, 15, 16 の `--out` を `evidence_runs/vcd_categorical` 配下の一意なパスに変更し、tryCatch(finally=) で明示的クリーンアップを実装。単体 GREEN (55 PASS / 0 FAIL) 確認
- [2026-10-13 21:35:03 JST] B5: `tests/test_questionnaire_symlink_escape.R`, `test_questionnaire_duplicate_output_slug.R`, `test_sas_proc_means_numerical_parity.R`, `test_vcd_categorical_reporting.R`, `test_comparative_schemas.R`, `test_dependency_isolation_pass1.R`, `test_evidence_feature_extract.R` の残骸生成箇所をトップレベル on.exit から明示的 tryCatch(finally=) クリーンアップへ改修
- [2026-10-13 21:37:05 JST] B4: `Rscript tests/run_regression_suite.R` 全体回帰実行完了。全54本中 54 PASS / 0 FAIL を達成。スイート実行後の `find evidence_runs -mindepth 2` が 0 件であることを確認。Phase 2B 完了。
- [2026-10-13 23:15:44 JST] T3.0-T3.3: OpenSpec Change `unify-run-metadata` の文書作成（.openspec.yaml, proposal.md, design.md, tasks.md, delta specs 4件: evidence-run-layout, sas-proc-freq, sas-proc-means, two-way-evidence-analysis）を完了。`openspec validate unify-run-metadata --strict` による厳格検証 PASS（終了コード 0, "Change 'unify-run-metadata' is valid"）を確認。Phase 3A 完了。
- [2026-10-13 23:34:50 JST] Phase 3A レビュー修正: H1（物理名sha256化の事実誤認撤回・現行spec維持）、M1（スキル別ライフサイクル表・許可遷移表・runs_index追記およびlatest更新事象の厳密化）、M2（sas-proc-freqのMonte Carlo記録先事実反映・freq_results.json/analysis_config.json）、M3（旧manifest項目と実在項目の一対一対応表への是正）、M4（session_info.txtマニフェスト登録順・manifest_roles許可タスク・対象スキル7件の棚卸し明記・run_meta版未決事項追加）、LOW（新規run必須と旧run読取寛容の明確化）を反映完了。`openspec validate unify-run-metadata --strict` 終了コード 0 PASS 確認。
- [2026-10-13 23:45:50 JST] Phase 3A 再レビュー修正: 決定1（vcd-categorical-reporting/evidence-decision-reviewの正常終了時completed明記と中断されたrun注記）、決定2（runs_index.jsonlを1行1確定事象の履歴ログとしrun_idごと最終行が現在状態）、決定3（run_meta.jsonのtimestampsをAsia/Tokyo JST固定記録とする仕様・タスク追加）、LOW（inputs[].source_path/sha256記法是正）を反映完了。`openspec validate unify-run-metadata --strict` 終了コード 0 PASS 確認。
- [2026-10-14 00:09:14 JST] Phase 3B-1 Step 1 ベースライン取得完了: `Rscript tests/run_regression_suite.R` 全54本中 54 PASS / 0 FAIL（87.93秒）。主要スキルの主結果（sas-proc-freq: freq_results.json, sas-proc-means: means_results.json, questionnaire: summary.csv, vcd-categorical: categorical_results.json）を /tmp/baseline_snapshot_3b1 に退避完了。
- [2026-10-14 00:13:30 JST] Phase 3B-1 session_info 登録設計案: manifest_roles() 各スキルに "environment_info" を追加。write_results_manifest(run_output_dir, skill, artifacts) 内で、artifacts 内に "environment_info" が含まれていない場合、write_run_environment_session_info(run_output_dir) を呼び出し session_info.txt を物理生成した上で artifacts 配列に list(path="session_info.txt", role="environment_info") を自動補完・統合する。これにより、7スキルすべての個別ランナー改修を不要とし、write_results_manifest の共通エントリポイントで上書き防止契約を完全に満たしつつ一括実現する。
- [2026-10-14 00:27:35 JST] Phase 3B-1 実装・TDD完了:
  - 1.1〜1.2: `tests/test_run_scope_environment.R` (RED→GREEN 22 PASS)。`run_scope.R` に `collect_run_environment()`, `manifest_roles()` 各スキルへの `"environment_info"` 追加、`write_results_manifest()` での `session_info.txt` 自動補完・生成を実装。
  - 1.3: `tests/test_run_scope_timestamp_jst.R` (RED→GREEN 15 PASS)。`write_run_meta()` の created, pass1_completed および `finalize_stage()` の pass2_completed, pass3_completed, sealed を JST (Asia/Tokyo `+0900`) 固定化。
  - 2.1〜2.2: `tests/test_run_scope_index.R` (RED→GREEN 14 PASS)。`append_run_index()`, `read_run_index()`, `write_latest()` 実装および確定時フック統合。
  - 2.3: 静的監査完了。出力root直下走査の `^run_` フィルタ徹底確認。
  - 4.1: `tests/test_single_pass_completed_state.R` (RED→GREEN 2 PASS)。`comparative_reporting.R` および `evidence_feature_extract.R` の `write_run_meta()` で `run_state = "completed"` を明示記録。
  - `tests/run_regression_suite.R` の `official_tests` に新規4テストを登録。
  - `tests/test_questionnaire_subset_expr_failure.R` の out_root サブディレクトリ単離。
  - 作業ツリー全体回帰: 全58本中 58 PASS / 0 FAIL（89.21秒）。
  - クリーン展開（git archive HEAD）全体回帰: 全58本中 58 PASS / 0 FAIL（88.48秒）。実行後 `find evidence_runs -mindepth 2` が 0 件であることを確認。
  - 統計値不変性検証: sas-proc-freq (tables 一致), sas-proc-means (tables 一致), questionnaire summary.csv (全25解析列完全一致), vcd-categorical (posterior, cramers_v, n_total 完全一致) を確認。Phase 3B-1 完了。
- [2026-10-14 00:58:00 JST] Phase 3B-1 レビュー対応 Step 0 ベースライン取得完了: `Rscript tests/run_regression_suite.R` 全58本中 58 PASS / 0 FAIL（90.36秒）。主要スキルの主結果（sas-proc-freq, sas-proc-means, questionnaire, vcd-categorical）を `/tmp/baseline_snapshot_3b1_review` に保存完了。
- [2026-10-14 01:27:00 JST] Phase 3B-1 レビュー指摘（H1, M1, M2, M3）対応完了:
  - H1: `latest.json` の `path` を `run_id` ではなく出力 root からの相対パス（`basename(run_output_dir)`、例: `run_20261014_...`）に修正。`runs_index.jsonl` に `run_dir` 列を追加。実スキル統合テスト `tests/test_latest_pointer_real_path.R` を新規追加（RED→GREEN 24 PASS）。
  - M1: `session_info.txt` 内の環境依存絶対パス（BLAS, LAPACK等）をファイル名のみに置換（Redaction）。`tests/test_run_scope_environment.R` で絶対パストークン非存在を検証（RED→GREEN 25 PASS）。
  - M2: 乱数使用スキル（`vcd-categorical-analysis`: `post_res$deterministic_seed`, `vcd-categorical-reporting`: `seed`, `vcd-bayesian-evidence-analysis`: `20260906L`, `sas-proc-freq`: Monte Carlo 実行時 `mc_seed_val`）から `write_run_meta` の `extra$seed` に実シードを渡し、乱数不使用スキルでは `null` を記録。
  - M3: `environment.platform` を `R.version$platform`（例: `aarch64-apple-darwin23`）に是正。
  - `tests/run_regression_suite.R` に `test_latest_pointer_real_path.R` を追加（計59本）。
  - 作業ツリー全体回帰: 全59本中 59 PASS / 0 FAIL（91.98秒）。
  - クリーン展開（git archive HEAD + patch）全体回帰: 全59本中 59 PASS / 0 FAIL（94.65秒）、実行後 `find evidence_runs -mindepth 2` が 0 件であることを確認。
  - 統計値不変性検証: sas-proc-freq, sas-proc-means, questionnaire, vcd-categorical の主結果が baseline と完全一致することを確認。
- [2026-10-14 02:26:00 JST] Tasks 3.1-3.4 (SAS PROC FREQ / MEANS メタ統合): `run_freq.R` および `run_means.R` から旧 `manifest.json` 出力を完全撤廃。`tests/test_sas_proc_freq_numerical_parity.R` および `tests/test_sas_proc_means_numerical_parity.R` にて `manifest.json` 非存在（`!"manifest.json" %in% files` かつ `!file.exists`）および `run_meta.json` / `results_manifest.json` / `session_info.txt` 整合性検証を新設（RED→GREEN、アサーション件数増加: FREQ +25, MEANS +26）。`SKILL.md` (FREQ, MEANS) の成果物定義を更新。単体テスト全件 PASS 確認。
- [2026-10-14 02:37:00 JST] Tasks 4.2-4.4 (VCD Categorical メタ統合): `templates/analysis.R` から run 内 `run_state.json` 出力を完全撤廃（初期 running および completed）。`record_run_failure()` を更新し、`is_root = TRUE` の時のみ出力 root 直下の早期失敗 `run_state.json` を生成、run 内は `run_meta.json`（`run_state = "failed"`）に統合。正常完了時は `write_run_meta(extra)` に `analysis_signature`, `execution_mode = "canonical"`, `provenance_status = "verified"` を移送。`dashboard.Rmd` の provenance 取得元を `run_meta.json`（存在時優先、フォールバック旧 run_state.json）に対応。`tests/test_vcd_categorical_input_boundary.R` (56 PASS), `test_vcd_categorical_run_isolation.R` (55 PASS), `test_vcd_categorical_input_validation.R` (8 PASS), `test_vcd_categorical_dashboard_v4.R` (16 PASS) のアサーション移行完了。
- [2026-10-14 02:37:30 JST] 追加作業 (a) & (b): `vcd-bayesian-evidence-analysis/templates/analysis.R` にて定数 `bayesian_sim_seed <- 20260906L` を定義し計算側・記録側のシード直書き2か所を統一。`openspec/changes/unify-run-metadata/design.md` §8 表に `sas-proc-freq` の `environment.seed` が単一値なら整数、異なる値が複数なら整数の配列となる旨を明記。
- [2026-10-14 02:37:50 JST] Tasks 5.1 & 5.2 (ドキュメント更新): `README.md`, `docs/Artifacts/README.md`, `docs/reference/skill_responsibilities.md`, `vcd-categorical-analysis/SKILL.md` の成果物一覧・説明を更新し、`run_meta.json`, `results_manifest.json`, `session_info.txt`, `runs_index.jsonl`, `latest.json` を正しく反映。`openspec/changes/unify-run-metadata/tasks.md` §5.2 に AGENTS.md 追加改定文案（3点）を「ユーザー承認待ち」として記載。tasks.md の完了タスクを `[x]` に更新。
- [2026-10-14 02:40:30 JST] Step 4 最終検証完了:
  - 作業ツリー全体回帰: `Rscript tests/run_regression_suite.R` 全59本中 59 PASS / 0 FAIL（93.14秒）。
  - クリーン展開（git archive HEAD + patch）全体回帰: 全59本中 59 PASS / 0 FAIL（92.30秒）、実行後 `find evidence_runs -mindepth 2` が 0 件であることを確認。
  - 統計値不変性検証: `/tmp/baseline_snapshot_3b2` との比較により、sas-proc-freq (MC p値), sas-proc-means (要約値), vcd-categorical (効果量・事後分布) の完全一致を確認。
  - 実スキル実行出力の目視検証: sas の run 内に `manifest.json` が未存在であること、categorical の run 内に `run_state.json` が未存在であることを確認。
  - `openspec validate unify-run-metadata --strict`: valid（終了コード 0）。
  - grep 棚卸し再確認: `git grep -nE "manifest\.json|run_state\.json"` の残存全ヒットが「出力 root 直下の早期失敗記録」「results_manifest.json との区別」「fixture」「歴史的アーカイブ」のみであることを確認。Phase 3B-2 実装完了。
- [2026-10-14 08:08:00 JST] Phase 3B-2 レビュー対応計画策定:
  - 指摘1（必須）: `validate_input_table` から `run_dir` 引数および内部 `record_failure` のファイル書き込みを撤去し、純粋な例外送出関数（`[ERROR_CODE] msg`）へ改修。`analysis.R` の呼出元で `conditionMessage(e)` からコードを抽出して `record_run_failure()`（`run_meta.json` 書込み）を呼ぶ。`tests/test_vcd_categorical_input_validation.R` のアサーションを `run_meta.json`（`run_state == "failed"`）に移行。
  - 指摘2（修正許可）: `config_file_sha256` を `write_run_meta`（完了時・失敗時）の `extra` に移送。`design.md` に対応表を追記。
  - 指摘3（情報）: `design.md` に強制終了時のメタなし空 run 残存と例外経路のみでの失敗記録を追記。
  - 指摘4（情報）: `design.md` およびコードに `dashboard.Rmd` のフォールバック挙動を注記。
- [2026-10-14 08:24:30 JST] Phase 3B-2 レビュー指摘修正完了・検証完了:
  - `validate_input.R`: `validate_input_table` から `run_dir` を削除しファイル出力のない純粋例外関数化完了。
  - `analysis.R`: 入力検証例外を捕捉して `record_run_failure(run_output_dir, code, clean_msg, config_file_sha256 = ...)` を呼出。完了時・失敗時の両方で `config_file_sha256` を `extra` に記録。
  - `tests/test_vcd_categorical_input_validation.R`: Test 8 を `analysis.R` 実実行検証へ改修。run 内 `run_state.json` 非存在、`run_meta.json` の `run_state == "failed"`、`error_code == "STRUCTURAL_ZERO_NOT_SUPPORTED"`、`config_file_sha256` 存在を検証（11 PASS / 0 FAIL）。
  - 全体回帰テスト: `Rscript tests/run_regression_suite.R` 全59本 PASS / 0 FAIL（95.58秒）。
  - 統計値不変性検証: `/tmp/baseline_snapshot_3b2/categorical_results.json` との比較で数値完全一致を確認。
  - `openspec validate unify-run-metadata --strict`: valid（終了コード 0）。Phase 3B-2 レビュー対応完了。
- [2026-10-14 08:52:00 JST] AGENTS.md 統一メタデータ規約反映（ユーザー承認完了）:
  - ユーザー明示承認に基づき、`AGENTS.md` の「3. 解析成果物をrun単位で分離する」へ統一メタデータ規約（`run_meta.json` / `results_manifest.json` 正本、出力 root 直下の `runs_index.jsonl` / `latest.json` / `.run_locks`、早期失敗 `run_state.json` 例外維持）を追記。
  - `openspec/changes/unify-run-metadata/tasks.md` のタスク 5.2 を完了済みに更新。
- [2026-10-14 09:10:00 JST] Phase 3B-2 第2次レビュー指摘対応完了:
  - 指摘A: `analysis.R` の完了時 `extra_meta` および run レベル失敗時の `record_run_failure` に `canonical_config_sha256` を追加移送。`design.md` の対応表を更新。`tests/test_vcd_categorical_input_validation.R`（失敗時）および `tests/test_vcd_categorical_run_isolation.R`（完了時）にアサーションを追加し合格確認。
  - 指摘B: `analysis.R` の未抽出時既定エラーコード `INPUT_VALIDATION_FAILED` を維持し、前回報告の誤記を訂正。`design.md`、`SKILL.md`、`references/` に `INPUT_VALIDATION_FAILED` を追記。`tests/test_vcd_categorical_input_validation.R` に非 `[CODE]` 例外時のフォールバック抽出テスト（Test 9）を追加し合格確認。
  - 指摘C: ベースコミットハッシュの実測値（`2783fe90e5eb3af28fac5ee3465ac76a813894b8`）による報告の訂正。
  - 指摘D: `analysis.R` 内の全 19 箇所の `record_run_failure` 呼出を点検。run ディレクトリ予約後の 3 箇所すべてに `config_file_sha256` および `canonical_config_sha256` の両方を渡すよう統一。run 予約前の 16 箇所は root レベル早期失敗記録（`run_state.json`）専用のため引数不要であることを確認・整理。
