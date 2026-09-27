## 1. 共有テーマの正本

- [x] 1.1 `.agents/shared/dashboard_theme_tokens.R` に categorical の `THEME_TOKENS` と行パレット関数を抽出し、既存の色値と行順の一致を確認する。
- [x] 1.2 categorical / bayesian の Dashboard テンプレートから共有トークンを読み込み、欠落時の明示エラーと既存の共有 CSS インライン埋め込みを確認する。

## 2. 対象スキルの HTML 表示

- [x] 2.1 reporting の HTML 生成で共有 CSS をインライン埋め込み、ページ背景・見出し・CTA・表頭の旧色を学術パレットへ置換し、生成 HTML の12列と操作機能が維持されることを確認する。
- [x] 2.2 reporting の `practical_bg` の T/N/R/U3 色値を計画書の写像先へ変更し、強度・分岐・実務領域セル限定の着色が維持されることを確認する。
- [x] 2.3 questionnaire の `dashboard.Rmd` と `report.Rmd` から `flatly` を外し、共有 CSS をインライン埋め込み、旧グラデーションと禁止アクセントが生成 HTML に残らないことを確認する。
- [x] 2.4 `docs/reference/skill_responsibilities.md` に、将来 HTML を生成するスキルへ共有テーマを適用する方針を1行追加し、対象スキル名と既存責務の記載との整合を確認する。

## 3. 契約確認と成果物

- [x] 3.1 `tests/test_dashboard_theme_contract.R` 等に4スキルの共有 CSS 参照と製品ツリーの禁止色・`flatly` 残留を検出する静的契約を追加し、正常・違反 fixture で期待どおり成功・失敗することを確認する（計画 T1/T2）。
- [x] 3.2 `Rscript tests/test_path_sanitization.R` を実行し、既存のパス・オフライン契約が回帰していないことを確認する（計画 T3）。
- [x] 3.3 categorical、reporting、questionnaire の代表 fixture HTML を再生成し、インライン共有 CSS、構造、12列、実務領域セル限定着色、外部資産ゼロを確認する。再生成物をレビュー可能な差分として残す（計画 T4/T5）。証跡: `tests/fixtures/dashboard_theme/{categorical,reporting,questionnaire}_demo/dashboard.html`（`tests/test_dashboard_theme_contract.R` が live render 後に更新）。
