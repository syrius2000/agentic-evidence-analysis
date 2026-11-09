# 実装・検証記録

## TDD

- Pass 1 lifecycleテストは実装前に `active`、最終Dashboard未生成、handover、manifestの各条件で失敗し、実装後に全条件を通過した。
- rendererテストは実装前に要約取込・スキルID・改変検出・安全表示・封緘の条件で失敗し、実装後に全条件を通過した。空ファイル拒否は既存の共通Pass 2ガードが既に満たしていた。
- 共通finalizerの `latest.json` が `active` のまま残る問題は回帰テストで再現後に修正し、`sealed` になることを確認した。
- 空白だけの要約もPass 2で確定されていたため、失敗するテストを先に追加し、確定前に拒否するよう修正した。

## 実行結果

- `test_reporting_summary_lifecycle.R`、`test_reporting_summary_renderer.R`、`test_reporting_summary_end_to_end.R`: すべて成功。end-to-endはhandoverに記録されたCLIでPass 2とPass 3を実行した。
- `test_vcd_categorical_reporting.R`: 40 PASS / 0 FAIL。
- `test_comparative_dashboard_qa.R`: 239 PASS / 0 FAIL。
- `test_comparative_schemas.R`: 142 PASS / 0 FAIL。
- `test_dashboard_theme_contract.R`: 88 PASS / 0 FAIL。一時fixtureを正規の出力rootと一時ディレクトリへ変更して再実行。
- `test_latest_pointer_real_path.R`: 24 PASS / 0 FAIL。`test_single_pass_completed_state.R`: 3 PASS / 0 FAIL。
- `test_run_scope_index.R`: 16 PASS / 0 FAIL。`test_run_scope_run_state.R`: 8 PASS / 0 FAIL。`test_run_scope_lock.R`: 27 PASS / 0 FAIL。`test_run_scope_environment.R`: 25 PASS / 0 FAIL。`test_run_scope_timestamp_jst.R`: 15 PASS / 0 FAIL。
- `openspec validate embed-executive-summary-in-dashboard --strict`: 成功。

## 実データ確認

`examples/Drug-Safty-example.csv` の新run `evidence_runs/vcd_categorical_reporting/run_drug_safety_2026/` では、前回runと250件のcontrast JSONおよびsummary CSVが一致した。以前のAI要約を結果一致後に取り込み、PT間の独立性を誤解させる表現とモンテカルロ推定値の表記を補正した。HTML解析で要約全文の一致、スキルID、`sealed` 状態、要約・DashboardのSHA-256、外部URLなしを確認した。プレビューの未完成表示と最終Dashboardに表示が残らないことも回帰テストで確認した。

実ブラウザでの視覚QAはファイルURLに対するブラウザのセキュリティ制限により未実施。独立ブラインドQAは未実施。

## 2026-11-09 表示改善

- 一時TDDテストで従来表示の順序・Markdownタグ・開いた折りたたみが失敗することを確認し、実装後に通過。番号付きリストの開始番号も失敗を再現して修正した。
- 既存のlifecycle・renderer・end-to-endテスト、比較報告40件、Dashboard回帰239件が成功。黄色の免責事項はpreviewとfinalのHTML要素が一致した。危険なHTML、リンク、外部画像は実行・読み込みされないことを確認。
- 新run `evidence_runs/vcd_categorical_reporting/run_drug_safety_2026_2/` は前runと250 contrastおよびsummary CSVが一致し、H1→免責事項→初期展開の要約、manifest、要約・Dashboardのハッシュ、外部URLなしを確認した。
- `commonmark` 2.0.0、`xml2` 1.4.0を使用。Rパッケージの自動インストールは実施していない。一時TDDスクリプトと専用runディレクトリは削除した。
- 55,000文字の日本語・記号を含むMarkdownもHTMLへ変換できることを確認した。
- 実ブラウザ視覚QAと独立ブラインドQAは未実施。
