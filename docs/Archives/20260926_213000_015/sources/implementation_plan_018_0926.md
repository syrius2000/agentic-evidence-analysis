# 実装計画書: Section 14 Re-QA 指摘修復および完全受入（14.R3b & 14.R5）

- 文書番号: `docs/Artifacts/implementation_plan_018_0926.md`
- 作成日時: 2026-09-26 JST
- 対象ブランチ: `feat/comparative-evidence-reporting-v3`
- 基準コミット: `0da9e264b7e18f2feb76add7f5f2b9a6598ee88e` (QA: add Section 14 repair Re-QA review2)
- 根拠QAレビュー: [`docs/Artifacts/s14_dashboard_report_qa_review2_001_0926.md`](s14_dashboard_report_qa_review2_001_0926.md)
- 目的: Section 14 の Re-QA Review 2 で指摘された Medium 2件（M14-01 / 14.R3b および M14-03 / 14.R5）を完全修復し、Section 14 を HOLD から PASS / ACCEPT に昇格させる。

---

## 1. 現状分析と課題の特定（Gap Analysis）

Re-QA Review 2 において、前回の High 2件（H14-01, H14-02）および Medium 1件（M14-02）、Test Adequacy はすべて CLOSED と認定された。
残存する指摘は以下の Medium 2件である：

| 指摘ID | 重要度 | 課題の根本原因 | 修復方針（14.R3b, 14.R5） |
| :--- | :--- | :--- | :--- |
| **M14-03** | **MEDIUM** | HTML 側は `1.33 [N/A]` に修復されたが、`comparative_report.md` 生成側で `rr_interval` 抑制時の分岐が未導入であり、Markdown レポートに `1.33 [NA, NA]` が出力される。 | - `comparative_reporting.R` の Markdown 生成ループ内でも HTML 側と同一の判定契約（`is.na(rr_lower) \|\| is.na(rr_upper)` の場合は `sprintf("%.2f [N/A]", rr_est)`）を適用。<br>- `tests/test_comparative_dashboard_qa.R` にて、Markdown 出力に対する `1.33 [N/A]`、`N/A`、および `[NA, NA]` 非存在のアサーションを追加。 |
| **M14-01** | **MEDIUM** | Task 14.9 のブラウザ検証について、生成成果物（`evidence_runs/visual_qa_s14/.../dashboard.html`）が `.gitignore` によりコミットに含まれておらず GitHub 上から監査不能であった。また実機ブラウザでのレンダリング実測値の記録が求められている。 | - `.gitignore` に `!evidence_runs/visual_qa_s14/**` を追加し、Visual QA 成果物（`dashboard.html` および実機 Chrome で撮影した 1280x800 スクリーンショット `screenshot_1280x800.png`）をコミットに含める。<br>- 実機 Google Chrome（Headless 1280x800）を用いて、`window.innerWidth`, `document.documentElement.scrollWidth`, `tableWidth`, 各要素の視認性および背景色スタイルを実測・記録。 |

---

## 2. データ契約とレンダリング契約（Data / Provenance First）

### 2.1 Markdown レポートの相対リスク（RR）表示契約（14.R5）

`generate_comparative_report()` 内の Markdown 生成部（`comparative_report.md`）において、HTML 生成部と完全に整合する以下の契約を適用する：

```r
rd_str_md <- if (is.na(row$rd_estimate)) {
  "N/A"
} else {
  sprintf("%.3f [%.3f, %.3f]", row$rd_estimate, row$rd_interval_lower, row$rd_interval_upper)
}

rr_str_md <- if (is.na(row$rr_estimate)) {
  "N/A"
} else if (is.na(row$rr_interval_lower) || is.na(row$rr_interval_upper)) {
  sprintf("%.2f [N/A]", row$rr_estimate)
} else {
  sprintf("%.2f [%.2f, %.2f]", row$rr_estimate, row$rr_interval_lower, row$rr_interval_upper)
}
```

### 2.2 実機ブラウザ視覚測定契約（14.R3b）

- **対象アーティファクト**: `evidence_runs/visual_qa_s14/run_20260926_034007/dashboard.html`
- **SHA-256**: `1cc08d9fa5ff2446c5b185c4e02ec25e22fb037b63d9277a4f1e7be20c6b0533`
- **測定手段**: Google Chrome (macOS arm64 headless) `--window-size=1280,800`
- **実測メトリクス契約**:
  - `window.innerWidth`: 1280
  - `document.documentElement.scrollWidth`: 1265 (<= 1280, ページレベル横スクロールなし)
  - `table.getBoundingClientRect().width`: 1217
  - `#guidance-callout` visibility: `true`
  - `#numerical-instability-warning` visibility: `true`
  - 実務領域セル背景色（Practical-cell-only）:
    - target_excess: `rgba(239, 68, 68, 0.2)`
    - reference_excess: `rgba(59, 130, 246, 0.2)`
    - practical_neutral: `rgba(100, 116, 139, 0.08)`
    - U3: `rgba(148, 163, 184, 0.12)`
  - スクリーンショット: `evidence_runs/visual_qa_s14/run_20260926_034007/screenshot_1280x800.png`

---

## 3. 具体的テストマトリクス（Test Matrix）

| テスト分類 | 対象 Fixture / 入力条件 | Checks / 検証内容 | 期待結果 (Expected Result) |
| :--- | :--- | :--- | :--- |
| **14.R5 (Markdown RR)** | IPTW partial-undefined: `relative_risk$interval = NULL` | `comparative_report.md` の RR 列文字列 | `1.33 [N/A]` が含まれ、`[NA, NA]` は含まれない。 |
| **14.R5 (Markdown RR)** | IPTW zero-reference: `relative_risk$estimate = NULL`, `interval = NULL` | `comparative_report.md` の RR 列文字列 | `N/A` が含まれ、`[NA, NA]` は含まれない。 |
| **14.R3b (Artifact Git Tracking)** | `.gitignore` および `git status` | `evidence_runs/visual_qa_s14/` 配下の追跡状態 | `dashboard.html` および `screenshot_1280x800.png` が Git 管理対象となりコミットに含まれる。 |
| **14.R3b (Visual Metrics)** | Headless Chrome 1280x800 実測値 | `scrollWidth <= innerWidth`、コールアウト視認性、セル色 | 横スクロール 0、コールアウト表示、Practical セルのみ着色。 |

---

## 4. 変更対象ファイル一覧

1. **`.agents/skills/vcd-categorical-reporting/comparative_reporting.R`**:
   - `comparative_report.md` 生成ループ内の `rr_str_md` フォーマットを HTML 側と同一の null-safe 契約に修正
2. **`tests/test_comparative_dashboard_qa.R`**:
   - `res_iptw_partial` および `res_iptw_zero` の Markdown 出力に対するアサーション追加（`1.33 [N/A]` 検査、`[NA, NA]` 排除検査）
3. **`.gitignore`**:
   - `!evidence_runs/visual_qa_s14/**` を追加し、Visual QA 成果物を Git 追跡可能にする
4. **`evidence_runs/visual_qa_s14/run_20260926_034007/`**:
   - `dashboard.html` および `screenshot_1280x800.png` を Git 追加
5. **`docs/Artifacts/s14_dashboard_report_exec_003_0926.md`**:
   - Re-QA Review 2 指摘修復の完全な実行記録を作成

---

## 5. 実行ステップ

1. 計画書の作成と確定（本計画書）
2. `.agents/skills/vcd-categorical-reporting/comparative_reporting.R` の Markdown 生成部修正
3. `tests/test_comparative_dashboard_qa.R` のテスト追加と実行（Rscript）
4. `.gitignore` の更新と Visual QA アーティファクトのステージング
5. 実施記録 `s14_dashboard_report_exec_003_0926.md` の作成
6. 作業コミット（`Yip: resolve Section 14 Re-QA review2 findings (14.R3b, 14.R5)`）の作成
