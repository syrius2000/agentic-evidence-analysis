# Implementation Plan 022: Dashboard Export, Filtering, and Mathematical Guide

## 1. Positioning

- Change: `comparative-evidence-reporting-v3`
- Layer: Section 14 dashboard/reporting usability extension
- Proposed OpenSpec tasks: 14.11–14.14
- Preconditions: Task 14.10 sortable table remediation is merged; Section 17 remains gated until this plan is implemented and Section 16 regression/QA is rerun.
- Non-goal: no change to statistical estimators, priors, uncertainty intervals, U-Grade thresholds, diagnostics, or decision-governance contracts.

この計画は、現在の比較エビデンス解析ダッシュボードを「見るための表」から「探索し、絞り込み、Excelへ持ち出し、指標をその場で理解できる報告ツール」へ拡張する。

対象機能は次の3群に限定する。

1. Excel-compatible CSV export
2. Theme / Practical Region + U-Grade / Diagnostic Badges の選択フィルタ
3. 指標の数学的解説と利用ガイドを格納する accordion

---

## 2. Architectural principles

### 2.1 Canonical data remains unchanged

`comparative_summary.csv` は引き続き R 側で生成する canonical summary artifact とする。

- 既存列名・意味を変更しない。
- manifest-bound canonical artifact と dashboard convenience export を区別する。
- browser export は canonical summary data から派生する convenience artifact であり、統計計算を再実行しない。

### 2.2 Self-contained dashboard

- 外部 CDN / DataTables / MathJax / third-party JavaScript を使用しない。
- filter / CSV generation / accordion は inline vanilla JavaScript + HTML/CSS で実装する。
- 数式は native MathML を primary rendering とし、アクセシブルなテキスト説明を必ず併記する。
- zero external HTTP/HTTPS asset contract と zero local absolute path contract を維持する。

### 2.3 No DOM-text statistical reconstruction

表示済み文字列から RD/RR 等を再 parse して CSV や filter 判定を作らない。

dashboard 内に canonical `summary_df` を安全に JSON 埋め込みし、各 table row と stable row key で対応させる。

推奨構造:

```html
<script id="comparative-summary-data" type="application/json">...</script>
<tr data-row-key="row_000001" ...>
```

埋め込み JSON では user-derived text に対して `<`, `>`, `&`, `</script`, U+2028, U+2029 を安全に escape し、hostile-label regression を維持する。

---

## 3. Task 14.11 — CSV export

### 3.1 User-facing controls

table toolbar に次の2操作を追加する。

- `全件CSV`
- `現在表示中CSV`

`全件CSV` は全 canonical summary rows を出力する。

`現在表示中CSV` は次をすべて反映する。

1. 現在の filter 状態
2. 現在の sort 順
3. hidden rows の除外

### 3.2 Excel compatibility

browser-generated CSV は次の契約とする。

- UTF-8 BOM 付き
- MIME: `text/csv;charset=utf-8`
- RFC 4180 相当の quoting
- comma / quote / CR / LF を含む文字列を正しく quote
- 改行は CRLF
- null / NA は空欄
- header row を必須とする

推奨 filename:

- `comparative_summary_all.csv`
- `comparative_summary_filtered.csv`

### 3.3 Export column contract

dashboard 表示中の10列だけではなく、`comparative_summary.csv` の canonical columns をすべて出力する。

これにより Excel 側で以下を含む再解析・報告表作成が可能になる。

- target/reference events and totals
- target/reference proportions and ESS
- inferential semantics
- interval/support labels
- RD/RR estimates and intervals
- direction support
- U-Grade and dominant region
- precision metrics
- RR availability / bootstrap diagnostics
- badges

### 3.4 Provenance

CSV convenience export に次の provenance metadata を追加する場合は、data columns を変更せず comment line も使用しない。

必要なら dashboard 上に run ID / source artifact を表示し、CSV本体は rectangular data のみとする。

---

## 4. Task 14.12 — Selection filters

### 4.1 Filter groups

table toolbar に3つの filter group を置く。

1. Theme
2. Practical Region / U-Grade
3. Diagnostic Badges

### 4.2 Theme filter

- unique theme values を決定論的に sort して提示する。
- search box + checkbox multi-select とする。
- Japanese labels をそのまま安全に表示する。
- 0件選択は `ALL` と解釈する。
- 同一 Theme group 内は OR。

250行程度の safety table を想定し、native select の長大リストではなく searchable checkbox panel を採用する。

### 4.3 Practical Region / U-Grade filter

同一 panel 内に2 subgroups を明示的に分離する。

Practical Region:

- `target_excess`
- `practical_neutral`
- `reference_excess`
- `none`

U-Grade:

- `U0`
- `U1`
- `U2`
- `U3`
- `NONE`

各 subgroup 内は OR、Region と U-Grade の間は AND。

例:

`Region = target_excess` AND (`U0` OR `U1`)

### 4.4 Diagnostic Badges filter

canonical badge valuesを unique multi-select とする。

最低限:

- `ZERO_REFERENCE`
- `ZERO_BOTH`
- `SPARSE_EVENTS`
- `UNSTABLE_RR_INTERVAL`
- `診断なし`

複数 badge 選択は v1 では `ANY` semantics とする。

例:

`ZERO_REFERENCE` OR `SPARSE_EVENTS`

`ALL selected badges` mode は将来拡張とし、今回 scope には入れない。

### 4.5 Cross-filter semantics

異なる filter group 間は AND とする。

```text
Theme condition
AND Region condition
AND U-Grade condition
AND Diagnostics condition
```

### 4.6 UX state

toolbar に常時次を表示する。

- `表示 n / N 件`
- `フィルタ解除`
- active filter count

件数更新は `aria-live="polite"` で screen reader に通知する。

filter 操作は現在の sort 状態を破壊しない。

sort 操作は現在の filter 状態を破壊しない。

### 4.7 Row metadata

filtering は表示文字列の曖昧 parse を避け、row data attributes または embedded canonical JSON を用いる。

推奨 row attributes:

```html
<tr
  data-row-key="row_000001"
  data-theme="..."
  data-region="target_excess"
  data-ugrade="U1"
  data-badges="ZERO_REFERENCE;UNSTABLE_RR_INTERVAL">
```

すべて attribute-context escape を行う。

---

## 5. Task 14.13 — Accordion mathematical guide

### 5.1 Placement

table の後に次を追加する。

`<section id="metric-guide">`

各項目は native `<details>` / `<summary>` を使用し、default collapsed とする。

JavaScript が無効でも展開・閲覧できる progressive enhancement とする。

### 5.2 Guide items

最低限以下を独立 accordion とする。

1. Risk / incidence proportion
2. Risk Difference (RD)
3. Relative Risk (RR)
4. Uncertainty interval: posterior ETI vs bootstrap percentile
5. Direction support
6. Practical difference regions and `primary_delta`
7. U-Grade
8. Precision metrics / ESS
9. Diagnostic badges
10. Multiplicity and exploratory-use guidance

### 5.3 Mathematical definitions

#### Risk

```math
p_T = x_T / n_T,    p_R = x_R / n_R
```

posterior independent count model では Jeffreys prior を使用し、

```math
p_g | x_g,n_g ~ Beta(x_g + 1/2, n_g - x_g + 1/2)
```

を明示する。

#### Risk Difference

```math
RD = p_T - p_R
```

`RD = 0.03` は 3 percentage points の絶対差であることを例示する。

#### Relative Risk

```math
RR = p_T / p_R
```

`RR = 1` が同率、`RR > 1` が target 側高率、`RR < 1` が reference 側高率であることを説明する。

`x_R = 0` では posterior median/interval と theoretical mean の存在性を区別し、`ZERO_REFERENCE` 警告の意味を説明する。

#### Direction support

posterior:

```math
P(RD > 0 | data)
```

bootstrap:

```math
(1/B) * sum_b I(RD_b^* > 0)
```

方向支持は effect magnitude や causal superiority を意味しないと明記する。

#### Practical regions

active `primary_delta = delta > 0` に対し、

```math
q_T = P(RD > delta)
q_N = P(-delta <= RD <= delta)
q_R = P(RD < -delta)
q_T + q_N + q_R = 1
```

#### U-Grade

```math
C = max(q_T, q_N, q_R)
```

canonical thresholds:

- U0: `C >= 0.95`
- U1: `0.80 <= C < 0.95`
- U2: `0.60 <= C < 0.80`
- U3: `C < 0.60`
- NONE: `primary_delta = null`

U-Grade は sampling precision でも clinical severity でもないことを強調する。

#### Precision

最低限次を説明する。

```math
RD interval width = upper_RD - lower_RD
log-RR width = log(upper_RR) - log(lower_RR)
RR fold range = upper_RR / lower_RR
```

design-aware evidence では ESS が raw N と異なることを説明する。

### 5.4 Rendering

- native MathML を primary とする。
- 各式に plain-language description を併記する。
- external MathJax/KaTeX CDN は禁止。
- Markdown report 側は LaTeX math を使用してよい。
- HTML guide と Markdown guide の意味を同期させる。

### 5.5 Guidance language

各 accordion は `定義 / どう読むか / 注意点 / いつ使うか` の4ブロック構成を基本とする。

特に次を禁止表現として維持する。

- interval crossing zero => equivalence と断定しない
- high direction support => large effect と断定しない
- U0/U1 => clinically important と断定しない
- cluster/filter result => regulatory decision としない

---

## 6. Task 14.14 — Integrated browser and regression QA

### 6.1 Automated tests

`tests/test_comparative_dashboard_qa.R` を拡張して次を静的検証する。

- embedded canonical JSON row count / keys
- hostile label safe JSON embedding
- all / filtered CSV controls
- BOM / CSV escaping helper contract
- filter controls and deterministic option sets
- filter AND/OR semantics implementation
- row count `aria-live`
- reset behavior
- accordion IDs and default-collapsed `<details>`
- MathML presence
- no external assets
- no absolute local paths
- existing sort contract remains intact

### 6.2 Browser interaction QA

新しい run ID で browser artifact set を生成し、少なくとも以下を実操作する。

1. Theme filter selection
2. Region + U-Grade cross-filter
3. Diagnostic badge filter
4. filter reset
5. filter + RD sort composition
6. filtered CSV download
7. downloaded CSV row count and order verification
8. accordion open/close
9. keyboard access
10. no horizontal-overflow regression

### 6.3 Excel acceptance

生成 CSV を最低限次で確認する。

- Japanese theme labels preserved
- header names preserved
- numeric columns remain numeric-looking values rather than formatted interval strings
- quoted commas/quotes/newlines survive
- filtered row count equals dashboard visible count

### 6.4 Regression gate

実装後に少なくとも次を再実行する。

- `Rscript tests/test_comparative_dashboard_qa.R`
- `Rscript tests/test_vcd_categorical_reporting.R`
- `Rscript tests/run_regression_suite.R`
- `python3 tests/test_skill_ownership_contract.py`
- `python3 tests/test_archive_manifest_integrity.py`
- `openspec validate comparative-evidence-reporting-v3 --strict --json`
- `git diff --check`
- browser visual/interaction QA

Section 16 execution record を更新し、独立 Re-QA PASS 後にのみ Section 17 へ進む。

---

## 7. Implementation order

```text
14.11 embedded canonical data + CSV export
   ↓
14.12 filters + visible-count/reset state
   ↓
14.13 mathematical accordion guide
   ↓
14.14 integrated browser/CSV/accessibility QA
   ↓
Section 16 regression + independent Re-QA
   ↓
Section 17 archive readiness
```

---

## 8. Definition of Done

以下をすべて満たした時点で Plan 022 を完了とする。

- canonical `comparative_summary.csv` を変更せず利用できる
- dashboard から full/filtered Excel-compatible CSV を取得できる
- Theme / Region+U-Grade / Diagnostics を選択 filter できる
- filter と sort が合成可能
- visible count と reset が正しく機能する
- mathematical guide が default collapsed accordion で利用できる
- U-Grade 等の数理定義が runtime contract と一致する
- zero-external-asset / escaping / accessibility contracts を維持する
- new coherent browser QA run が manifest/hash/screenshot と整合する
- Section 16 independent QA が PASS / ACCEPT
