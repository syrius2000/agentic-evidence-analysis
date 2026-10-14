# Tasks

## 0. 横断検索の棚卸しと対象ファイルインベントリ

- [x] **0.1 キーワード横断検索の棚卸し**
  - 対象検索語: `manifest.json`, `run_state.json`, `.run_lock`, `run_meta`, `results_manifest`
  - 検索対象外（履歴）: `docs/Archives/`, `openspec/changes/archive/`, 各テスト用fixtureディレクトリ（`tests/fixtures/` 等）
  - 全ヒット箇所の改定タスクまたは変更不要根拠の対応付け:
    - `manifest.json`:
      - `.agents/skills/sas-proc-freq/SKILL.md` (L33): 成果物一覧から削除し `run_meta.json` / `results_manifest.json` に置換（改定タスク: 3.1）
      - `.agents/skills/sas-proc-freq/templates/run_freq.R` (L1240-1273): 出力処理を廃止し `run_meta.json` / `results_manifest.json` に移送（改定タスク: 3.2）
      - `.agents/skills/sas-proc-means/SKILL.md` (L31): 成果物一覧から削除し置換（改定タスク: 3.1）
      - `.agents/skills/sas-proc-means/templates/run_means.R` (L626-658): 出力処理を廃止し `run_meta.json` / `results_manifest.json` に移送（改定タスク: 3.3）
      - `tests/test_sas_proc_freq_numerical_parity.R` (L680, 697): `run_meta.json` / `results_manifest.json` のアサーションへ移行（改定タスク: 3.4）
      - `tests/test_sas_proc_means_numerical_parity.R` (L282, 298): `run_meta.json` / `results_manifest.json` のアサーションへ移行（改定タスク: 3.4）
      - `tests/test_dashboard_fixture_invariance.R` (L18, 31): fixture読み込み。fixture内の歴史的生成例のため変更不要（根拠: fixture資産の不変性保持）
    - `run_state.json`:
      - `.agents/skills/vcd-categorical-analysis/templates/analysis.R` (L404-416): run内の出力廃止、`run_meta.json` の `run_state` へ一本化（改定タスク: 4.1）
      - `analysis.R` (L57, 82) および `validate_input.R` (L15): 出力root直下の早期失敗記録は維持（変更不要: 決定事項 §2.1/§2.7）
      - `tests/test_vcd_categorical_pass0_boundary.R`: run内検証アサーションを `run_meta.json` に移行、root直下の早期失敗アサーションは維持（改定タスク: 4.2）
    - `.run_lock` / `.run_locks`:
      - `.agents/shared/run_scope.R` (L801, 871): `acquire_signature_lock` / `release_signature_lock` で実装済み。run列挙処理の `^run_` フィルタリングを強化（改定タスク: 2.3）
      - `.agents/skills/vcd-categorical-analysis/SKILL.md` (L55, 63): 仕様記述として最新の `.run_locks` 規約を維持・明確化（改定タスク: 4.3）
      - `tests/test_vcd_categorical_run_isolation.R`, `test_run_scope_lock.R`: 署名ロック検証として維持（変更不要: Phase 2R/2Bで改修済み）
    - `run_meta.json` / `results_manifest.json`:
      - `.agents/shared/run_scope.R`: `collect_run_environment()` を追加し `write_run_meta()` で埋め込み（改定タスク: 1.1, 1.2）
  - **確認方法**: `git grep -E "manifest\.json|run_state\.json" .agents/` を実行し、未対応の記述が存在しないことを確認する。

- [x] **0.2 対象スキルの棚卸しと適用境界 (M4)**
  - `environment` ブロックおよび `runs_index.jsonl` の適用対象スキル一覧:
    - **適用対象（`write_run_meta()` を直接呼び出すスキル）**:
      1. `vcd-bayesian-evidence-analysis` (`analysis.R`)
      2. `vcd-categorical-analysis` (`analysis.R`)
      3. `vcd-categorical-reporting` (`comparative_reporting.R`)
      4. `questionnaire-batch-analysis` (`batch_runner.R`)
      5. `sas-proc-freq` (`run_freq.R`)
      6. `sas-proc-means` (`run_means.R`)
      7. `evidence-decision-review` (`evidence_feature_extract.R`)
    - **適用対象外**:
      - `comparative-design-analysis`: in-memory推論器であり、ファイル永続化を伴わないため直接の `write_run_meta` 呼出は存在しない（将来callerが永続化を担う際に共通基盤から適用される）。
  - **確認方法**: `write_run_meta` 呼出箇所のgrep結果と上記一覧の完全一致を確認。

## 1. 共通環境情報ブロック（`environment`）、`session_info.txt`、および JST タイムスタンプ固定 (M4, 決定3)

- [x] **1.1 [TDD] `collect_run_environment()` および `manifest_roles` のユニットテスト追加**
  - `tests/test_run_scope_environment.R` を新規作成する。
  - テスト項目:
    - 必須キー `r_version`, `platform`, `packages`, `seed`, `session_info_path` が存在すること。
    - `packages` にロード済みパッケージの名前とバージョンが含まれること。
    - `manifest_roles()` に新ロール `"environment_info"`（または既存許容ロール）が追加され、全スキルで `session_info.txt` のマニフェスト登録が受容されること。
    - `write_results_manifest` が上書きを拒否するため、`session_info.txt` がマニフェスト書込前に実ファイルとして存在すること（書込順の保証）。
  - **確認方法**: `Rscript tests/test_run_scope_environment.R` を実行して RED になることを確認する。
- [x] **1.2 `collect_run_environment()` の実装、`manifest_roles` 拡張、および書込順の統合**
  - `.agents/shared/run_scope.R` の `manifest_roles()` に `"environment_info"` ロール（または全スキル共通許可ロール）を追加する。
  - `session_info.txt` の生成処理を、`write_results_manifest()` 呼び出しより**前**に実行するよう各ランナーおよび `run_scope.R` に配置する。
  - `write_run_meta()` でメタデータに `environment` を追加し、`results_manifest.json` と整合させる。
  - **確認方法**: `Rscript tests/test_run_scope_environment.R` を実行して GREEN になることを確認する。
- [x] **1.3 [TDD] JST タイムスタンプ固定のテストと実装 (決定3)**
  - `tests/test_run_scope_timestamp_jst.R` を新規作成する。
  - テスト項目:
    - 実行環境のタイムゾーン（`TZ` 環境変数）を `UTC` や `America/New_York` 等に偽装した場合でも、`run_scope.R` が `run_meta.json` の `timestamps` に書き込む全キー（`write_run_meta()` による `created`, `pass1_completed`、および `finalize_stage()` による `pass2_completed`, `pass3_completed`, `sealed`）が必ず `+0900`（JST / Asia/Tokyo）のオフセットで記録されること。なお排他ロックの `acquired_at` は対象外（変更しない）。
    - 既存の run_meta を読むテストや fixture の期待値に破壊的影響がないこと。
    - 統計推定値および計算結果に一切影響を与えないこと。
  - 実装: `run_scope.R` 内の `timestamps` を書き込む2箇所（`write_run_meta` 内の L1452 付近、および `finalize_stage` 内の L1087-1088 付近）の `format(Sys.time(), ...)` を `format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "Asia/Tokyo")` に統一固定する。
  - **確認方法**: `Rscript tests/test_run_scope_timestamp_jst.R` で RED→GREEN を確認する。

## 2. 横断索引（`runs_index.jsonl`）と最新実行ポインタ（`latest.json`）(決定2)

- [x] **2.1 [TDD] `runs_index` と `latest` のユニットテスト追加**
  - `tests/test_run_scope_index.R` を新規作成する。
  - テスト項目:
    - 複数回の確定事象において、出力 root 直下の `runs_index.jsonl` に確定事象ごとに1行（JSONL）が追記されること。
    - 同一 `run_id` に対する複数事象（例: bayesian の Pass 1 確定時と Pass 3 封緘時）が複数行として追記され、インデックス読み取り関数が `run_id` ごとの最終行を最新状態として採用すること（決定2）。
    - `latest.json` が最新の正常完了/確定 run ディレクトリを指すこと（原子的更新、非symlink）。
    - 異常終了 run（`failed`）では `latest.json` が更新されないこと。
    - 出力 root 直下の子走査時に `.run_locks` を除外して `run_*` のみがインデックス対象となること。
  - **確認方法**: `Rscript tests/test_run_scope_index.R` を実行して RED になることを確認する。
- [x] **2.2 `append_run_index()` および `write_latest()` の実装**
  - `.agents/shared/run_scope.R`（または `.agents/shared/run_index.R`）に関数を実装する。
  - 各スキルの `write_run_meta()` 確定時および `finalize_stage()` 確定時に追記・更新を呼ぶ。
  - **確認方法**: `Rscript tests/test_run_scope_index.R` を実行して GREEN になることを確認する。
- [x] **2.3 run列挙処理のフィルタリング規約の徹底**
  - `.agents/` および `tests/` 内で出力 root 直下を走査している処理を確認し、`list.files(pattern = "^run_")` または `grepl("^run_", basename(...))` が徹底されていることを確認する。
  - **確認方法**: 静的コード監査および既存の run isolation テスト群の全件通過を確認する。
- [x] **2.4 [TDD] `latest.json` の `path` 実在性および `runs_index.jsonl` の `run_dir` 実在性の修正と統合テスト (H1)**
  - `write_latest()` および `append_run_index()` において、`path` および `run_dir` に最新 run の物理ディレクトリ名（出力 root からの相対パス。`basename(run_output_dir)`）を記録するよう修正。
  - 実スキル実行（最低 questionnaire, sas-proc-freq、および bayesian/reporting/categorical）を伴う統合テスト `tests/test_latest_pointer_real_path.R` を新規作成。
  - テスト項目:
    - 出力 root の `latest.json` の `path` が `dir.exists(file.path(out_root, path))` で実在すること。
    - 出力 root の `runs_index.jsonl` の最終行の `run_dir` が `dir.exists(file.path(out_root, run_dir))` で実在すること。
  - **確認方法**: `Rscript tests/test_latest_pointer_real_path.R` で RED→GREEN を確認する。
- [x] **1.4 [TDD] `session_info.txt` の環境依存絶対パス置換 (M1)**
  - `write_run_environment_session_info()` で BLAS, LAPACK 等の絶対パストークンをファイル名のみに置換する処理を追加。
  - テスト: `tests/test_run_scope_environment.R` を拡張し、生成された `session_info.txt` に絶対パストークンが存在しないこと、かつ `"R version"` を保持していることを検証。
  - **確認方法**: `Rscript tests/test_run_scope_environment.R` で RED→GREEN を確認する。
- [x] **1.5 [TDD] スキル別 `environment.seed` の配線と `platform` 定義適正化 (M2, M3)**
  - `collect_run_environment()` の `platform` を `R.version$platform` に修正（M3）。
  - 乱数を使用するスキル（`vcd-categorical-analysis`, `vcd-categorical-reporting`, `vcd-bayesian-evidence-analysis`, 条件付き `sas-proc-freq`）から `write_run_meta` の `extra$seed` に実シードを渡し、乱数不使用スキルでは `null` を記録（M2）。
  - テスト: シード使用スキルで `environment.seed` が非 null で期待値と一致し、不使用スキルで null であることを検証。
  - **確認方法**: ユニットテストおよび統合テストで検証する。

## 3. SAS PROC FREQ / MEANS メタ統合

- [x] **3.1 ドキュメント・スキーマ更新**
  - `.agents/skills/sas-proc-freq/SKILL.md` および `sas-proc-means/SKILL.md` の成果物説明から `manifest.json` を削除し、`run_meta.json` / `results_manifest.json` / `session_info.txt` を記載する。
  - **確認方法**: Markdown 差分確認。
- [x] **3.2 SAS PROC FREQ の `manifest.json` 廃止と `run_meta.json` 統合**
  - `run_freq.R` の `manifest.json` 出力ブロック（L1240-1273）を削除する。
  - `session_info.txt` を `write_results_manifest` 前に生成し、`environment` ブロックとともに `run_meta.json` へ統合する。
  - **確認方法**: `Rscript tests/test_sas_proc_freq_numerical_parity.R` を実行し、`run_meta.json` が出力され `manifest.json` が生成されないことを確認する。
- [x] **3.3 SAS PROC MEANS の `manifest.json` 廃止と `run_meta.json` 統合**
  - `run_means.R` の `manifest.json` 出力ブロック（L626-658）を削除する。
  - `session_info.txt` を `write_results_manifest` 前に生成し、`environment` ブロックとともに `run_meta.json` へ統合する。
  - **確認方法**: `Rscript tests/test_sas_proc_means_numerical_parity.R` を実行し、`run_meta.json` が出力され `manifest.json` が生成されないことを確認する。
- [x] **3.4 テスト追随改修**
  - `tests/test_sas_proc_freq_numerical_parity.R` および `tests/test_sas_proc_means_numerical_parity.R` の `manifest.json` アサーションを `run_meta.json` と `results_manifest.json` のアサーションに更新する。
  - **確認方法**: 両テストが PASS することを確認する。

## 4. VCD Categorical / Reporting / Decision Review メタ統合と completed 記録 (決定1)

- [x] **4.1 [TDD] `vcd-categorical-reporting` および `evidence-decision-review` の `completed` 記録 (決定1)**
  - `tests/test_single_pass_completed_state.R` を新規作成する。
  - テスト項目:
    - `vcd-categorical-reporting` 正常完了時に生成される `run_meta.json` の `run_state` が `"completed"` であること（RED→GREEN）。
    - `evidence-decision-review` 正常完了時に生成される `run_meta.json` の `run_state` が `"completed"` であること（RED→GREEN）。
    - 統計値および成果物内容に一切影響がないこと。
  - 実装:
    - `comparative_reporting.R` の `write_run_meta()` 呼出で `extra = list(run_state = "completed", ...)` を指定する。
    - `evidence_feature_extract.R` の `write_run_meta()` 呼出で `extra = list(run_state = "completed", ...)` を指定する。
  - **確認方法**: `Rscript tests/test_single_pass_completed_state.R` が PASS することを確認する。
- [x] **4.2 run内 `run_state.json` の廃止と `run_meta.json` 一本化 (M4)**
  - `vcd-categorical-analysis/templates/analysis.R` の run 内 `run_state.json` 出力を完全削除（初期 running、正常完了時、および入力検証失敗時）。
  - `validate_input_table`（`R/validate_input.R`）から `run_dir` 引数およびファイル書き込みを撤去し、純粋な入力検証・例外送出関数（`[ERROR_CODE] msg`）へ改修。
  - `analysis.R` の `validate_input_table` 呼出元で例外を捕捉し、`record_run_failure()` 経由で `run_meta.json`（`run_state="failed"`, `error_code`, `failure_reason`）を記録。
  - `config_file_sha256` を `write_run_meta`（完了時・失敗時）の `extra` に移送。
  - 出力 root 直下の早期失敗用 `run_state.json` はそのまま維持する。
  - **確認方法**: `Rscript tests/test_vcd_categorical_input_validation.R` および `tests/test_vcd_categorical_smoke.R` を実行し、run 内に `run_state.json` がなく `run_meta.json` に状態が記録されることを確認する。
- [x] **4.3 テスト追随改修**
  - `tests/test_vcd_categorical_pass0_boundary.R` および `tests/test_vcd_categorical_input_validation.R` の run 内 `run_state.json` アサーションを `run_meta.json` に更新する。
  - **確認方法**: `Rscript tests/test_vcd_categorical_input_validation.R` が PASS することを確認する。
- [x] **4.4 スキルドキュメント確認**
  - `vcd-categorical-analysis/SKILL.md` の成果物一覧およびロック説明を照合する。
  - **確認方法**: Markdown 差分確認。

## 5. ドキュメント・規約更新（ユーザー承認待ち事項を含む）

- [x] **5.1 共通リファレンス・ガイド更新**
  - `README.md`
  - `docs/Artifacts/README.md`
  - `docs/reference/skill_responsibilities.md`
  - **確認方法**: `git diff` による差分確認。
- [x] **5.2 [ユーザー承認完了] AGENTS.md の変更**
  - **実施内容**: ユーザー明示承認に基づき、「3. 解析成果物をrun単位で分離する」へ統一メタデータ規約（`run_meta.json` / `results_manifest.json` 正本、出力 root 直下の `runs_index.jsonl` / `latest.json` / `.run_locks`、早期失敗 `run_state.json` 例外維持）を反映。
  - **確認方法**: `AGENTS.md` の git diff 確認。

## 6. 全体回帰検証と完了判定

- [x] **6.1 全体回帰スイート実行**
  - `Rscript tests/run_regression_suite.R`
  - **確認方法**: 54 本以上すべてのテストが PASS すること。
- [x] **6.2 クリーン展開検証**
  - `git archive HEAD` からのクリーン展開で全体回帰を実行し、`find evidence_runs -mindepth 2` が 0 件であることを確認する。
  - **確認方法**: 終了コード 0、残骸 0 件。
- [x] **6.3 OpenSpec Change 検証**
  - `openspec validate unify-run-metadata --strict`
  - **確認方法**: 終了コード 0 でエラーがないこと。
