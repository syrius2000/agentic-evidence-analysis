# 実装計画書: Section 14 QA 指摘修復および完全受入（14.R1–14.R4）

- 文書番号: `docs/Artifacts/implementation_plan_017_0926.md`
- 作成日時: 2026-09-26 JST
- 対象ブランチ: `feat/comparative-evidence-reporting-v3`
- 基準コミット: `3a2643aa34c4fec21aec1fdf9a0549fdf10bbb0c` (Yip: implement Section 14 dashboard and report QA)
- 根拠QAレビュー: [`docs/Artifacts/s14_dashboard_report_qa_review1_001_0926.md`](s14_dashboard_report_qa_review1_001_0926.md)
- 目的: Section 14 の Independent QA Review 1 で指摘された 4 点（H14-01, H14-02, M14-01, M14-02）およびテスト網羅性（Test Adequacy）を完全に修復し、Section 14 を HOLD から PASS / ACCEPT に昇格させる。

---

## 1. 現状分析と課題の特定（Gap Analysis）

QA Review 1 において、以下の指摘がなされ、Section 14 の受入が保留（HOLD）となっている。

| 指摘ID | 重要度 | 課題の根本原因 | 修復方針（14.R1–14.R4） |
| :--- | :--- | :--- | :--- |
| **H14-01** | **HIGH** | `relative_risk$interval` が `NULL` の場合（IPTW 等の governed suppression 時）、`rr_low` / `rr_upp` が `NULL` となり、`%\|\|%` フォールバック内の `!is.na(rr_low)` で `logical(0)` が生じ、`if` 文で実行時エラーが発生する。また、抑制された指標を勝手に再計算しようとする。 | - `rr_est`, `rr_low`, `rr_upp` を算術／条件分岐の前に `NA_real_` へ安全に正規化。<br>- `rr_interval` が `NULL` の場合、governed suppression を尊重し、精度指標（`log_rr_interval_width`, `rr_interval_fold_range`）も再計算せず `NA_real_` を保持。<br>- IPTW partial-undefined および zero-reference override のテスト Fixture を追加。 |
| **H14-02** | **HIGH** | `theme`, `target_arm`, `reference_arm` などの入力文字列が HTML エスケープされずに `sprintf` で展開されており、悪意あるタグ（`<img src="http...">`, `<script>` 等）がアクティブなマークアップとなり Zero-External-Asset 原則に違反し得る。また静的スキャナーが可視テキストとアクティブ属性を区別していない。 | - データ由来の可視テキストに対する共通エスケープ関数 `html_escape()` を導入。<br>- enum 由来の class 名（`u_grade`, `dominant_region`）を厳格にホワイトリスト化。<br>- 敵対的ラベル（hostile-but-valid labels）Fixture を追加し、アクティブなタグ・外部読み込みが発生しないことを検証。<br>- 静的スキャナーを「アクティブな HTML 属性・タグ（`<img[^>]+src=`, `<link[^>]+href=`, `<script[^>]+src=`, `@import`, `url(...)`）」の検査にリファイン。 |
| **M14-01** | **MEDIUM** | Task 14.9 のブラウザ検証が実行できず静的 DOM 検査で代替されていた。また、実行記録内の CSS 主張（`max-width: 1200px`, `overflow-x: auto` 等）が実際のコードに未反映であった。 | - 実際に生成された成果物を 1280x800 でレンダリング検証し、viewport、横スクロール有無（scrollWidth vs innerWidth）、callout、badge、U3、実務領域セルの外観を実測記録。<br>- 実際の CSS にテーブルラッパー（`.table-container { overflow-x: auto; }`）等を整備し、実行記録の乖離を解消。 |
| **M14-02** | **MEDIUM** | `rr_bootstrap_defined_replicates` および `rr_bootstrap_undefined_replicates` の抽出パスが実際の発行元（matched-set, IPTW）と一致しておらず、実測値が `NA` となっていた。 | - matched-set: `relative_risk.rr_bootstrap_diagnostics.defined_replicates` / `undefined_replicates`<br>- IPTW: `iptw.bootstrap_diagnostics.defined_rr_replicates` / `undefined_rr_replicates`<br>上記の発行元パスから正確に値を抽出し、単なる列存在だけでなく値の完全性をテスト。 |
| **Test Adequacy** | **NOTE** | U3 テストで synthetic fixture が U3 を生成しなかった場合の無条件 PASS フォールバック（`assert_true(TRUE, ...)`）が存在した。 | - 確実に U3 となる Fixture パラメータを固定し、U3 状態に達しない場合はテスト失敗（FAIL）とする。 |

---

## 2. データ契約と Provenance 設計（Data / Provenance First）

### 2.1 相対リスク（RR）と区間抑制の正規化契約

`generate_comparative_report()` 内で、各 contrast オブジェクトから値を抽出する際の契約を以下のように確定する：

```r
# 1. Point estimate null-safety
rr_est_raw <- ev$relative_risk$estimate$value
rr_est_avail <- !is.null(rr_est_raw) && !is.na(rr_est_raw)
rr_est <- if (rr_est_avail) as.numeric(rr_est_raw) else NA_real_

# 2. Interval null-safety & governed suppression
rr_interval <- ev$relative_risk$interval
rr_int_avail <- !is.null(rr_interval) &&
                !is.null(rr_interval$lower) && !is.null(rr_interval$upper) &&
                !is.na(rr_interval$lower) && !is.na(rr_interval$upper)
rr_low <- if (rr_int_avail) as.numeric(rr_interval$lower) else NA_real_
rr_upp <- if (rr_int_avail) as.numeric(rr_interval$upper) else NA_real_

# 3. Precision metrics (preserve suppression; do not invent metrics if suppressed)
rd_width <- ev$precision_metrics$rd_interval_width %||% (rd_upp - rd_low)
log_rr_width <- if (!is.null(ev$precision_metrics$log_rr_interval_width)) {
  as.numeric(ev$precision_metrics$log_rr_interval_width)
} else if (rr_int_avail && !is.na(rr_low) && !is.na(rr_upp) && rr_low > 1e-10 && rr_upp > 1e-10) {
  log(rr_upp) - log(rr_low)
} else {
  NA_real_
}

rr_fold <- if (!is.null(ev$precision_metrics$rr_interval_fold_range)) {
  as.numeric(ev$precision_metrics$rr_interval_fold_range)
} else if (rr_int_avail && !is.na(rr_low) && !is.na(rr_upp) && rr_low > 1e-10) {
  rr_upp / rr_low
} else {
  NA_real_
}
```

### 2.2 Bootstrap Replicates Provenance 抽出パスの統一

```r
rr_boot_def <- if (!is.null(ev$relative_risk$rr_bootstrap_diagnostics$defined_replicates)) {
  as.integer(ev$relative_risk$rr_bootstrap_diagnostics$defined_replicates)
} else if (!is.null(ev$iptw$bootstrap_diagnostics$defined_rr_replicates)) {
  as.integer(ev$iptw$bootstrap_diagnostics$defined_rr_replicates)
} else if (!is.null(ev$relative_risk$bootstrap_defined_replicates)) {
  as.integer(ev$relative_risk$bootstrap_defined_replicates)
} else if (!is.null(ev$diagnostics$bootstrap_defined_replicates)) {
  as.integer(ev$diagnostics$bootstrap_defined_replicates)
} else {
  NA_integer_
}

rr_boot_undef <- if (!is.null(ev$relative_risk$rr_bootstrap_diagnostics$undefined_replicates)) {
  as.integer(ev$relative_risk$rr_bootstrap_diagnostics$undefined_replicates)
} else if (!is.null(ev$iptw$bootstrap_diagnostics$undefined_rr_replicates)) {
  as.integer(ev$iptw$bootstrap_diagnostics$undefined_rr_replicates)
} else if (!is.null(ev$relative_risk$bootstrap_undefined_replicates)) {
  as.integer(ev$relative_risk$bootstrap_undefined_replicates)
} else if (!is.null(ev$diagnostics$bootstrap_undefined_replicates)) {
  as.integer(ev$diagnostics$bootstrap_undefined_replicates)
} else {
  NA_integer_
}
```

### 2.3 HTML エスケープとホワイトリスト化契約

1. **`html_escape(text)` ヘルパー**:
   `&`, `<`, `>`, `"`, `'` を確実にエスケープする。
   対象: `theme`, `target_arm`, `reference_arm`, `support_label`, `dominant_region`, バッジ文字列。
2. **enum クラス名のホワイトリスト化**:
   - `u_grade`: `U0` -> `u0`, `U1` -> `u1`, `U2` -> `u2`, `U3` -> `u3`, その他 -> `none`
   - `dominant_region`: `target_excess` -> `target-excess`, `reference_excess` -> `reference-excess`, `practical_neutral` -> `practical-neutral`, その他 -> `none`

---

## 3. 具体的テストマトリクス（Test Matrix）

| テスト分類 | 対象 Fixture / 入力条件 | Checks / 検証内容 | 期待結果 (Expected Result) |
| :--- | :--- | :--- | :--- |
| **14.R1 (H14-01)** | IPTW override: `relative_risk.interval = NULL`, `log_rr_interval_width = NULL`, `diagnostic = "PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES"` | レポート生成実行、RD 表示、RR 区間表示、警告バナー判定 | エラーなく終了。RD は区間付で表示。RR 区間は `"N/A"`。`warning-callout` 出現。 |
| **14.R1 (H14-01)** | IPTW override: `relative_risk = NULL` (ZERO_REFERENCE_RISK, 参照群リスク 0) | レポート生成実行、点推定および区間の null-safety | エラーなく終了。RR 点推定・区間ともに `"N/A"`。警告バナー出現。 |
| **14.R2 (H14-02)** | 敵対的ラベル: `theme = '<img src="https://evil.invalid/x" onerror="alert(1)">'`, `arm = '<script>fetch("http://leak.invalid")</script>'` | HTML 生成後のタグ存在スキャンおよび表示テキスト | `<img` や `<script` タグとして解釈されず、`&lt;img ...&gt;` にエスケープされる。外部アセットスキャナーで PASS。 |
| **14.R4 (M14-02)** | Matched-set 由来の `rr_bootstrap_diagnostics` (defined=195, undefined=5) | `summary_df$rr_bootstrap_defined_replicates` および `undefined_replicates` の値 | 単なる非 NA ではなく、195L および 5L と完全一致。 |
| **14.R4 (M14-02)** | IPTW 由来の `iptw$bootstrap_diagnostics` (defined_rr=180, undefined_rr=20) | `summary_df$rr_bootstrap_defined_replicates` および `undefined_replicates` の値 | 180L および 20L と完全一致。 |
| **Test Adequacy** | U3 判定条件を満たす Fixture (RD=0 付近、小標本、primary_delta=0.01) | `summary_df$u_grade == "U3"` の検証およびスタイル検査 | U3 行が必ず存在すること（存在しない場合は FAIL）。U3 セルが `rgba(148, 163, 184, 0.12)` で描画され赤色が入らないこと。 |
| **14.R3 (M14-01)** | 生成された dashboard.html のブラウザ実測 (1280x800) | viewport, scrollWidth vs innerWidth, callout, badge, U3 外観 | 横スクロールなし (scrollWidth <= innerWidth)。callout および各要素が正常描画。 |

---

## 4. 変更対象ファイル一覧

1. **`.agents/skills/vcd-categorical-reporting/comparative_reporting.R`**:
   - `html_escape()` ヘルパーの実装
   - `relative_risk` の null-safe な取り出しと governed suppression 尊重
   - bootstrap replicates provenance の正規化（matched-set / IPTW 両対応）
   - enum クラス名のホワイトリスト化
   - レスポンシブ用コンテナ（`.table-container { overflow-x: auto; }`）および CSS 整備
2. **`tests/test_comparative_dashboard_qa.R`**:
   - 14.R1（IPTW RR 抑制 override 2種）のテスト追加
   - 14.R2（敵対的ラベルエスケープ & 外部アセット監査リファイン）のテスト追加
   - 14.R4（Bootstrap provenance 実測値一致アサート）のテスト追加
   - U3 テストの無条件 PASS フォールバック撤廃と厳格化
3. **`docs/Artifacts/s14_dashboard_report_exec_001_0925.md`**:
   - CSS 主張の整合化
   - 1280x800 での実機／ブラウザ検証結果、artifact ハッシュ、実測メトリクスを追記

---

## 5. 実行ステップ

1. 計画書の作成とレビュー（本計画書）
2. `.agents/skills/vcd-categorical-reporting/comparative_reporting.R` の実装修正
3. `tests/test_comparative_dashboard_qa.R` のテスト拡充と検証実行（Rscript）
4. 全体回帰テストスイート（`tests/run_regression_suite.R`）の実行確認
5. ブラウザ実機検証（1280x800 レンダリング、メトリクス測定）
6. 実行記録（`s14_dashboard_report_exec_001_0925.md`）の更新
7. 作業コミット（`Yip: repair Section 14 QA findings (14.R1-14.R4)`）の作成
