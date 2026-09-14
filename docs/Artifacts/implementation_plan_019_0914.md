# 回帰テスト成果物の完全自己隔離・クリーンアップ計画 (改訂第2版)

created: 2026-09-15 00:05 (JST)
update: 2026-09-15 00:15 (JST)
author: Antigravity

## 概要 (Goal & Background)

回帰テストスイート（`tests/run_regression_suite.R`）実行時に、作業ツリー内の `skill_out/` および `tests/skill_out_smoke/` にテスト成果物が残留する問題について、全23テストの動作調査を実施しました。
先行レビュー（Codex/QMS review）での指摘を踏まえ、`analysis.R` の `source_only` ガードの適用範囲（スキップする全副作用の明示、描画系依存検査の抑制、明示的オプション制御）の具体化、および `test_questionnaire_batch_ucbadmissions.R` における既存成果物の退避・復元メカニズムの定義を反映した改訂計画を策定します。

---

## 調査結果と根本原因 (Investigation Findings & Root Causes)

| # | テストスクリプト | 該当ファイル | 根本原因 |
|---|---|---|---|
| 4 | `.agents/skills/vcd-categorical-analysis/tests/test_logic.R` | `.agents/skills/vcd-categorical-analysis/templates/analysis.R` | `source(analysis_path)` 時にトップレベルの初期化部および `Main dispatcher`（Line 872〜905）が直接実行され、既定パス `skill_out/vcd_categorical/run_*` にレンダリング結果が出力される。`args <- commandArgs()` でローカル環境の `args` が上書きされるため、実行抑制が効いていない。また描画系依存パッケージの検査も走る。 |
| 6 | `tests/test_questionnaire_batch_smoke.R` | 同テストスクリプト | 固定パス `tests/skill_out_smoke/` に出力しており、終了時のクリーンアップ処理（`unlink()`）が存在しない。 |
| 7 | `tests/test_questionnaire_batch_ucbadmissions.R` | 同テストスクリプト | **`--out` 省略時に `skill_out/questionnaire/` に出力される仕様を正当に検証**している。しかし、テスト冒頭で既存ディレクトリを無条件削除（Line 47-49）しており、かつ終了時のクリーンアップがないためファイルがそのまま残留する。 |
| 他20本 | その他の全テスト | 各テストスクリプト | すでに `tempfile()` / `tempdir()` かつ `on.exit(unlink(td))` により完全に自己隔離されている。 |

---

## 提案する改修内容 (Proposed Changes)

### 1. `analysis.R` の `source_only` 明示的ガード導入と副作用スキップ範囲の具体化

`test_logic.R` からの `source()` 時に純粋に関数定義のみをロードし、一切の副作用を発生させないガードを実装します。

- **ガード制御方式**:
  - `sys.nframe() > 0L` による自動判定は**使用しない**（将来別スクリプトからの `source()` 時に予期せず実行部が抑制されるリスクを回避）。
  - 明示的な `isTRUE(getOption("vcd_categorical.source_only", FALSE))` **のみ**で制御する。
- **`source_only = TRUE` 時にスキップする副作用の範囲**:
  1. **描画系依存パッケージ検査**（Line 26〜34）:
     `source_only` 時は描画系依存（`vcd`, `gt`, `DT`, `htmlwidgets`, `ggplot2`）の検査をスキップする。ロジック単体ロードに必要な基本ライブラリ（`jsonlite`, `digest`）のみ、または純粋な関数定義に必要な依存のみを確認する。
  2. **CLI引数・設定ファイル読み込み・デフォルト値初期化**（Line 23〜25, Line 47〜115）:
     `commandArgs()` のパース、`--config` の読み込み、入力ファイル存在確認（`data_path` 存在チェック）、`run_id` 生成等のトップレベル変数の評価をスキップする。
  3. **入力データ署名計算**（Line 115〜130 付近）:
     SHA-256 ファイル署名計算をスキップする。
  4. **出力ディレクトリ予約・メタデータ書き込み**（Line 321〜367）:
     `reserve_run_output_dir()` によるディレクトリ作成、および `write_run_meta()` による `run_meta.json` 出力を完全にスキップする。
  5. **メインディスパッチャ**（Line 869〜905）:
     `load_input_data()`、`generate_profile()`、`generate_data()`、`generate_plots()`、`update_run_state()` 等のパイプライン実行をスキップする。
- **ロード対象**:
  - 純粋な関数定義のみ（`validate_config`, `apply_aggregation`, `generate_profile`, `generate_data`, `generate_gt_matrix`, `generate_dt_table`, `generate_plots`, `generate_categorical_results_json` など）。
- **通常のCLI実行時の挙動**:
  - オプション `vcd_categorical.source_only` が未設定または `FALSE` の場合は、従来どおりすべての引数処理、ディレクトリ予約、依存性検査、メインディスパッチが実行される（完全な後方互換性を保証）。
- **`test_logic.R` での呼び出し側実装**:
  - `options(vcd_categorical.source_only = TRUE)` を設定した上で `source(analysis_path, local = local_env)` を実行。
  - テスト終了時または `on.exit()` で `options(vcd_categorical.source_only = NULL)` を確実に復元する。

### 2. `tests/test_questionnaire_batch_smoke.R` の一時ディレクトリ化
- **改修内容**:
  `out_dir <- file.path(root, "tests", "skill_out_smoke")` を `tempfile("skill_out_smoke_")` に変更し、テスト冒頭に `on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)` を設定。テスト完了後に自動削除する。

### 3. `tests/test_questionnaire_batch_ucbadmissions.R` の既存成果物保護（安全な退避・復元メカニズム）
- **改修内容**:
  「`--out` 省略時の既定パス（`skill_out/questionnaire/`）動作検証」というテスト仕様は100%維持しつつ、**既存成果物の保護**と**テスト後残留ゼロ**を両立させます。
  1. **実行前無条件削除の撤廃**:
     Line 47〜49 の `if (dir.exists(default_out_dir)) { unlink(...) }` を削除。
  2. **安全な退避関数 (`safe_backup_dir`) の導入**:
     - テスト開始時に `default_out_dir`（`skill_out/questionnaire/`）が存在する場合、同一親ディレクトリ内に独立した一時ホルダーを作成し、その配下へ退避。
     - 第1選択として `file.rename` を試行し、失敗時は親ホルダーへの `file.copy(recursive = TRUE)` を実行。
     - **元データ保護契約**: コピー成功およびファイル数一致を完全に確認するまで元ディレクトリを**絶対に削除しない**。
     - 退避に失敗した場合は、元データを保護するため `stop()` により**テストを開始せず即時中止**する。
  3. **安全な復元関数 (`safe_restore_dir`) の導入**:
     - テスト終了時（`on.exit()`）：
       - テストが生成した `default_out_dir` を `unlink(recursive = TRUE, force = TRUE)` で削除。
       - 退避先から `file.rename`（失敗時は `file.copy`）で元の `default_out_dir` へ復元。
       - 復元成功を確認できた場合のみ、一時ホルダーを削除。
       - **データ喪失防止契約**: 復元に失敗した場合は、バックアップを**絶対に削除せず安全に保持**し、手動復元用のパス警告を出力する。

### 4. 既存成果物の保護と削除承認方針
既存の `skill_out/vcd_categorical/`、`skill_out/questionnaire/`、`tests/skill_out_smoke/` は、ユーザー成果物の可能性があるため自動削除しない。テスト前後の状態を比較し、削除が必要な残留物は対象と根拠を確認したうえで、別途明示承認を得る。

---

## 受入基準と検証計画 (Acceptance Criteria & Verification Plan)

### 受入基準 (Acceptance Criteria)
1. **既存差分との整合**: テストスイート実行前後で、Git の tracked / untracked ファイル差分が一切増加していないこと（開始時点のスナップショットと終了時点の `git status -s` が完全一致）。`git diff --check`（末尾空白・空行）が完全 PASS すること。
2. **新規テスト成果物の残留ゼロ**: テスト実行によって新規成果物が残留しないこと（既存成果物は保護・維持され、テストによって生成された成果物は `on.exit()` 等により完全にクリーンアップされる）。
3. **回帰テスト品質**: `tests/run_regression_suite.R` の全23テストが引き続き **100% PASS (23/23)** すること。

### 追加検証ケース (Verification Steps)
- [x] **Case 1 (単体実行残留検証)**:
  - `Rscript .agents/skills/vcd-categorical-analysis/tests/test_logic.R` 単体実行後に `skill_out/vcd_categorical/` が生成されないこと。(確認済み: 28/28 PASS, 新規ラン生成ゼロ)
  - `Rscript tests/test_questionnaire_batch_smoke.R` 単体実行後に `tests/skill_out_smoke/` が残らないこと。(確認済み: 22/22 PASS, 一時ディレクトリ自動削除確認)
  - `Rscript tests/test_questionnaire_batch_ucbadmissions.R` 単体実行後に `skill_out/questionnaire/` が新規残留しないこと。(確認済み: 19/19 PASS, 既存成果物完全復元・新規残留ゼロ)
- [x] **Case 2 (異常終了時クリーンアップ・失敗注入検証)**:
  - `run_test()` 内でテスト実行中に意図的に `stop("Failure Injection")` を発生させた場合でも、`on.exit()` により元ファイルが完全復元されることを実証済み。
  - 実証結果: 事前7ファイルと事後7ファイルの SHA-256 ハッシュが完全一致（`identical = TRUE`）、テストが生成した中間不正ファイルは消去（`FALSE`）、一時バックアップホルダーの残留ゼロ（`count = 0`）を確認。
  - ※注意: OS による `SIGKILL` やプロセス強制終了の場合は言語ランタイムの制約上 `on.exit()` は評価されません。
- [x] **Case 3 (連続実行再現性)**:
  - `tests/run_regression_suite.R` を2回連続実行し、いずれの実行後も残留ゼロ・差分増分ゼロであることを確認。(確認済み: 1回目 23/23 PASS 41.97s, 2回目 23/23 PASS 42.58s, git status 増分ゼロ)
- [x] **Case 4 (既存成果物および非対象成果物の保護検証)**:
  - `output/` や他の作業成果物が誤って削除されていないこと。(確認済み)
  - **対象3ディレクトリの個別ハッシュ検証**: テストスイート実行前後の全ファイル SHA-256 ハッシュを比較し、完全一致を確認済み。
    - `skill_out/vcd_categorical/`: 全48ファイルのハッシュ完全一致 (`identical = TRUE`)
    - `skill_out/questionnaire/`: 全7ファイルのハッシュ完全一致 (`identical = TRUE`)
    - `tests/skill_out_smoke/`: 全10ファイルのハッシュ完全一致 (`identical = TRUE`)
