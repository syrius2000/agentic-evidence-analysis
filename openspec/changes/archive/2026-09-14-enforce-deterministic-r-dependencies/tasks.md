## 1. 共有依存性検査モジュールの新設と共有基盤の改修

- [x] 1.1 `.agents/shared/dependency_check.R` を新設し、`check_r_dependencies(required, context)` 関数（`requireNamespace()` による事前検証と不足時の日本語案内＋Fail-Fast 停止）を実装する。単体動作を R コマンドで検証する
- [x] 1.2 `.agents/shared/run_scope.R` から `install.packages("digest")` および `install.packages("jsonlite")` の自動インストール処理を削除し、`check_r_dependencies()` による事前チェックに置き換える。テストスイートで Run 隔離機能が動作することを検証する
- [x] 1.3 `.agents/shared/inspect_data.R` の依存読み込み部を `check_r_dependencies()` に改修し、不足時のメッセージを改善する。`tests/test_inspect_data_out_dir.R` で動作を検証する

## 2. スキルテンプレート（R / Rmd）からの実行時自動インストール排除と依存分離

- [x] 2.1 `vcd-bayesian-evidence-analysis` の `templates/analysis.R` から `pacman::p_load` および UI 表示依存（`DT`, `htmlwidgets`, `htmltools`）の計算時強制ロードを削除し、計算用依存（`jsonlite`, `digest`, `dplyr`, `tidyr`, `effectsize`）を `check_r_dependencies()` で検査・Fail-Fast 化する
- [x] 2.2 `vcd-bayesian-evidence-analysis` の `templates/render_dashboard.R` および `templates/dashboard.Rmd` から `pacman` 自動インストールと `p_load` を削除し、レポート・HTML 描画用依存（`rmarkdown`, `DT`, `htmlwidgets`, `ggplot2` 等）を `check_r_dependencies()` で検査するよう改修する
- [x] 2.3 `vcd-categorical-analysis` の `templates/analysis.R`, `templates/dashboard.Rmd`, `templates/report.Rmd`, `tests/test_logic.R` から `pacman` 自動インストールと `p_load` を削除し、`check_r_dependencies()` に置換する
- [x] 2.4 `questionnaire-batch-analysis` の `templates/batch_runner.R`, `templates/dashboard.Rmd`, `templates/report.Rmd` から `pacman` 自動インストールと `p_load` を削除し、`check_r_dependencies()` に置換する

## 3. テストコードの安全化とオフライン検証

- [x] 3.1 `tests/` 配下のテストスクリプト（`test_questionnaire_batch_smoke.R`, `test_questionnaire_batch_ucbadmissions.R`, `test_summary_csv_new_columns.R`, `test_vcd_categorical_smoke.R` 等）に残存する `install.packages` / `pacman` 処理を削除し、外部取得を行わない構成に改修する
- [x] 3.2 共有依存検査モジュールの回帰テスト（不足時に期待通りのエラーメッセージと終了ステータスで Fail-Fast すること、揃っている場合に正常通過すること）を新設する
- [x] 3.3 全 R / Rmd スクリプトおよびテストコードに対する静的走査（grep）を実施し、実行時自動インストール（`install.packages`, `p_load`）が 0 件であることを検証する
- [x] 3.4 定義された正規回帰テストスイート（`tests/run_regression_suite.R` の23本）および Pass 1 隔離テスト（`test_dependency_isolation_pass1.R`）を実行し、外部ネットワーク接続なしで決定論的に通過することを検証する（全59件のテスト台帳 `tests/test_inventory_manifest.csv` に基づき、除外36本の分類・理由・追跡先を計画書に明記）

## 4. ドキュメントおよび事前セットアップ手順の整備

- [x] 4.1 ルート `README.md` の「動作環境要件」を更新し、用途別の必要 R パッケージ一覧と一括事前導入コマンド（ワンライナー）を明記する
- [x] 4.2 `AGENTS.md` に「R 依存関係・実行時インストール禁止原則」を追加し、AI エージェント向けの行動規範と `README.md` 参照規則を定義する
- [x] 4.3 各スキルの `references/dependencies.md` を手動セットアップ前提に改訂する
