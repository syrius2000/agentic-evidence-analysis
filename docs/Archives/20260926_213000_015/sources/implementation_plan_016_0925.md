# 実装計画 016 — Section 14: 自己完結型ダッシュボードおよびレポートQA

created: 2026-09-25 19:25 (JST)  
revised: 2026-09-25 JST, Independent plan review  
author: Antigravity (Advanced Agentic Coding)  
plan_review: GPT-5.6 Sol  
approval_required: 本計画書へのユーザー承認後に実装に着手する（承認前のコード変更禁止）

---

## 0. Plan Review 修正点

実装前レビューで以下を修正した。

1. **14.2 / 14.3 の U3 表現を明確化**
   - U0–U2 は practical-region hue × U-grade intensity を使用する。
   - U3 は Hue × Intensity の通常系列から外し、**muted desaturated override** とする。
   - U3 の `rgba(148, 163, 184, 0.12)` は U0–U2 の alpha 系列とは別契約とし、`U3 = 0.04` との二重定義を廃止する。

2. **14.4 の診断 badge 名を canonical 実装へ整合**
   - canonical badge は `ZERO_REFERENCE`, `ZERO_BOTH`, `SPARSE_EVENTS`, `UNSTABLE_RR_INTERVAL`。
   - 実装に存在しない `ZERO_EVENTS` は受入条件から除外する。

3. **14.1 / 14.5 の Precision / RR instability provenance を明示**
   - HTML を表示時推測で組み立てず、`summary_df` に必要な canonical evidence provenance を明示的に搬送する。
   - 少なくとも `rd_interval_width`, `log_rr_interval_width`, `rr_interval_fold_range`, `rr_mean_is_finite`, `rr_diagnostic` と RR interval / bootstrap diagnostics を扱える構造とする。

4. **14.2 の色付け範囲を Practical Difference 列に限定**
   - practical-region hue / U-grade intensity は原則として `Practical Difference` セルへ適用し、行全体を着色しない。
   - Effect Size / Direction / Precision の概念分離を視覚上も維持する。

5. **14.9 のブラウザ手段を実装環境非依存に修正**
   - `browser_subagent` が利用可能なら使用する。
   - 利用不可なら同等のローカルブラウザ / manual render による確認を許可する。
   - viewport、確認項目、結果を実行証跡へ記録する。

6. **14.7 の local absolute path scan を拡張**
   - macOS/Linux の `/Users/`, `/home/` に加え、Windows drive path、UNC、`file://` 等も対象にする。

---

## 1. 目的と承認範囲

OpenSpec `comparative-evidence-reporting-v3` における **Section 14: Dashboard and Self-Contained Report QA**（タスク 14.1 〜 14.9）の実装および受入テスト・静的監査ハーネスを構築する。

### 承認対象

- `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
  - HTML ダッシュボード生成ロジック拡張
  - summary provenance 拡張
  - DOM ID / accessibility attributes
  - 列グループ構造
  - 数値的不安定性 warning callout
- `tests/test_comparative_dashboard_qa.R`
  - Section 14 専用の self-contained / palette / DOM / accessibility / instability QA
- `tests/run_regression_suite.R`
  - 新規 test 登録
- 実ブラウザでの desktop viewport 視覚検証
- `openspec/changes/comparative-evidence-reporting-v3/tasks.md`
  - 14.1–14.9 の進捗更新
- `docs/Artifacts/s14_dashboard_report_exec_001_0925.md`
  - 実施記録

### 対象外（境界防衛）

- Section 13 以前の CLOSED 項目を再オープンしない。
- Section 15 / 16 へ先行着手しない。
- Section 14 のために統計推定ロジック、schema semantics、decision-review semantics を変更しない。
- `dashboard.html` の命名変更や run-layout 再設計は本 Section では行わない。
- 本計画承認前のコード変更、データ変更、git commit / push は行わない。

---

## 2. 開始時 Baseline

- **実装 baseline commit**: `6b7bb40be788fe62fc260e0ded6026eee422d88b`
- **計画書追加 commit**: `de6f1a13b64b8c73321deaa8ecfd99f4a8994535`
- **branch**: `feat/comparative-evidence-reporting-v3`
- plan / documentation-only commit は実装差分判定から分離する。
- Section 13.10–13.13 は独立 QA により PASS / ACCEPT 済みであり、本計画から再オープンしない。

---

## 3. Section 14 実装契約

| ID | タスク | 実装契約 | Pass criteria |
|---|---|---|---|
| **14.1** | レイアウト分離 | HTML table を **Effect Size / Direction / Practical Difference / Precision / Diagnostics** の概念グループへ分離する。Theme / Contrast / raw descriptive counts は identification/context として別列に置く。Effect Size は RD/RR、Direction は support、Practical Difference は U-grade + dominant region、Precision は RD interval width / log-RR interval width / ESS 等を表示する。 | 概念が別列・別 heading で識別可能。Practical Difference と Precision を混同しない。必要 provenance が `summary_df` に明示搬送される。 |
| **14.2** | Hue × Intensity | `primary_delta != null` のときだけ Practical Difference セルを region hue で描画する。U0/U1/U2 は既存 hue（target: `239,68,68`; neutral: `100,116,139`; reference: `59,130,246`）と alpha `0.20 / 0.14 / 0.08` を使用。 | `primary_delta=null` では practical cell は transparent。Effect/Direction/Precision セルへ region hue を波及させない。 |
| **14.3** | U3 muted override | U3 は dominant region に依存せず `rgba(148, 163, 184, 0.12)` の muted slate とする。これは U0–U2 の Hue × Intensity 系列とは別 override。 | U3 practical cell に coral/red/blue region hue が残らない。alarm state に見えない。 |
| **14.4** | 診断 badge 分離 | `ZERO_REFERENCE`, `ZERO_BOTH`, `SPARSE_EVENTS`, `UNSTABLE_RR_INTERVAL` 等を estimation cell から分離し `Diagnostics` 専用セルへ表示する。複数 badge は個別 `span.badge` として描画する。 | RD/RR text と badge が同一 semantic cell に混在しない。canonical badge 名を保持する。 |
| **14.5** | RR instability callout | canonical evidence 由来の RR instability を summary provenance に保持し、1件でも存在すれば table 上部に `#numerical-instability-warning` を表示する。判定対象は RR point/interval unavailable、`mean_is_finite=false`, `ZERO_REFERENCE`, `UNSTABLE_RR_INTERVAL`, `relative_risk.diagnostic`, bootstrap undefined replicate diagnostics 等。 | unstable fixture で warning 表示、stable fixture で非表示。raw `x_R==0` だけへ依存しない。 |
| **14.6** | Zero External Asset | 生成 HTML に external HTTP/HTTPS/CDN/Web font/external script/style/image URL がないことを静的監査する。 | external URL 0件。既存 self-contained contract を維持。 |
| **14.7** | Zero Local Absolute Path | HTML に macOS/Linux/Windows/UNC/`file://` の local absolute path を残さない。 | `/Users/`, `/home/`, drive-letter path, UNC, `file://` 等の検出 0件。 |
| **14.8** | DOM / Accessibility | 主要 ID を一意化: `#dashboard-title`, `#guidance-callout`, `#comparative-evidence-table`, conditional `#numerical-instability-warning`。table に `aria-describedby`、`caption`、column header に `scope="col"` を付与する。 | 必須 ID の存在・一意性、header scope、table association、warning ID の条件付出現を自動 test で確認。 |
| **14.9** | Browser visual verification | 1280×800 を基準に実ブラウザで rendering を確認する。利用可能なら browser subagent、不可なら local/manual render。 | header/columns/badges/callout が読めること。不要な page-level horizontal overflow がないこと。方法・viewport・結果を execution record に保存。 |

---

## 4. Data / Provenance 拡張契約

Section 14 は presentation QA だが、表示判定を raw counts から再推論しないため、`summary_df` に canonical evidence 由来の表示用 provenance を追加する。

最低限、各 contrast 行について以下を搬送する。

```text
rd_interval_width
log_rr_interval_width
rr_interval_fold_range
rr_mean_is_finite
rr_diagnostic
rr_estimate_available
rr_interval_available
rr_bootstrap_defined_replicates
rr_bootstrap_undefined_replicates
badges
```

### Null / unavailable contract

- canonical `NULL` は table assembly 時に明示的 `NA` / `N/A` へ正規化する。
- `NULL` を `sprintf()` 等へ直接渡さない。
- bootstrap / posterior の terminology は既存 semantics を維持する。
- Section 14 のために statistical result を再計算しない。

---

## 5. HTML 構造契約

推奨構造:

```html
<h1 id="dashboard-title">...</h1>

<div id="guidance-callout" class="callout">...</div>

<div id="numerical-instability-warning"
     class="callout warning"
     role="alert">
  ...
</div>

<table id="comparative-evidence-table"
       aria-describedby="guidance-callout">
  <caption>...</caption>
  <thead>...</thead>
  <tbody>
    <tr>
      ...
      <td class="col-effect">...</td>
      <td class="col-direction">...</td>
      <td class="col-practical practical-u1 practical-target-excess">...</td>
      <td class="col-precision">...</td>
      <td class="col-diagnostics">...</td>
    </tr>
  </tbody>
</table>
```

### Visual separation rule

- practical-region color は **Practical Difference cell only**。
- row-wide `background-color` は使用しない。
- diagnostic warning color は diagnostic/callout semantics に限定する。
- `primary_delta=null` では practical-region hue を完全に無効化する。
- U-grade を sampling precision や clinical severity と表現しない。

---

## 6. 変更対象ファイル

1. **実装**
   - `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
     - `summary_df` provenance 拡張
     - HTML rendering block 改修
     - conditional RR instability callout
     - practical-cell-only palette
     - DOM / ARIA
2. **新規 QA test**
   - `tests/test_comparative_dashboard_qa.R`
3. **既存 regression**
   - `tests/test_vcd_categorical_reporting.R`
     - 既存 Section 4 behavior を保持。必要最小限の fixture 調整のみ。
   - `tests/run_regression_suite.R`
4. **OpenSpec tracking**
   - `openspec/changes/comparative-evidence-reporting-v3/tasks.md`
5. **execution evidence**
   - `docs/Artifacts/s14_dashboard_report_exec_001_0925.md`

行番号固定で変更箇所を指定しない。関数 / rendering block の semantic location で変更する。

---

## 7. Section 14 QA test matrix

### 14.1 structure

- Effect / Direction / Practical / Precision / Diagnostics の header/class が存在。
- RD/RR は Effect に存在。
- direction support は Direction に存在。
- U-grade/region は Practical に存在。
- interval width / ESS は Precision に存在。
- badge は Diagnostics のみに存在。

### 14.2 / 14.3 palette

Fixtures:

```text
target_excess + U0
target_excess + U1
practical_neutral + U2
reference_excess + U1
U3 with each dominant region
primary_delta = null
```

Checks:

- U0/U1/U2 は指定 hue + alpha。
- U3 は常に muted slate override。
- delta null は transparent。
- Practical cell 以外に region hue が出ない。

### 14.4 diagnostics

Canonical badge fixtures:

```text
ZERO_REFERENCE
ZERO_BOTH
SPARSE_EVENTS
UNSTABLE_RR_INTERVAL
multiple badges
no badge
```

### 14.5 RR instability

最低 fixture:

```text
posterior ZERO_REFERENCE
posterior UNSTABLE_RR_INTERVAL
bootstrap RR interval suppressed / diagnostic present
stable RR
```

warning message は RR が不安定 / unavailable であることを説明し、RD まで無効であるような表現をしない。

### 14.6 external asset scan

拒否 pattern 例:

```text
http://
https://
protocol-relative external URLs
<link ... href=external>
<script ... src=external>
<img ... src=external>
@import external
url(external)
```

### 14.7 local path scan

拒否 pattern 例:

```text
/Users/
/home/
/tmp/
file://
C:\...
D:/...
\\server\share
```

### 14.8 accessibility / DOM

- required IDs: exactly once
- table `aria-describedby` references existing ID
- `scope="col"`
- `caption`
- conditional warning: unstable only
- DOM ID duplicate 0

### 14.9 visual

1280×800 で最低確認:

- table header readable
- group boundaries identifiable
- warning callout visually separate
- badges do not overlap estimate cells
- practical hue does not tint Effect/Direction/Precision
- U3 is visually muted
- page-level horizontal overflow absent

---

## 8. Verification Gate

### Automated

```bash
Rscript tests/test_comparative_dashboard_qa.R
Rscript tests/test_vcd_categorical_reporting.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

### Static HTML evidence

execution record に最低限記録:

```text
external_url_hits = 0
local_absolute_path_hits = 0
duplicate_required_id_hits = 0
required_dom_contract = PASS
palette_contract = PASS
instability_warning_contract = PASS
```

### Browser evidence

```text
render_method
viewport = 1280x800
artifact path / run id
horizontal overflow result
callout visibility
badge placement
U3 muted rendering
practical-cell-only hue
```

---

## 9. 実装終了条件

Section 14 を完了扱いにできるのは以下すべてを満たした場合のみ。

1. 14.1–14.9 の executable/static/visual evidence が存在する。
2. Section 14 専用 QA test が PASS。
3. 既存 `test_vcd_categorical_reporting.R` が regression なし。
4. full regression suite が 100% PASS。
5. OpenSpec strict validation が PASS。
6. `git diff --check` clean。
7. external URL / local absolute path hit = 0。
8. browser render evidence が記録済み。
9. Section 13 closed contracts を変更していない。
10. 実施記録 `s14_dashboard_report_exec_001_0925.md` が作成済み。

---

## 10. 実装後の独立 QA handoff

実装者は completion を自己認定しない。実装後に以下を独立 QA へ渡す。

```text
Repository: syrius2000/agentic-evidence-analysis
Branch: feat/comparative-evidence-reporting-v3
Baseline: <Section 14 implementation parent SHA>
Reviewed commit: <Section 14 implementation SHA>
Scope: Section 14 only (14.1–14.9)
Out of scope: Section 15–17
Plan: docs/Artifacts/implementation_plan_016_0925.md
Exec: docs/Artifacts/s14_dashboard_report_exec_001_0925.md
Review mode: blind-first independent QA
Decision required: PASS/ACCEPT or HOLD with Blocker/High/Medium counts
```

---

## 11. Approval Gate

- 本 revised plan への明示承認後に実装開始。
- 実装と QA report を同一 authority として扱わない。
- ユーザーの明示指示がない限り、実装者は独立 QA 判定を作成しない。
- commit / push の可否はユーザーの実装指示に従う。
