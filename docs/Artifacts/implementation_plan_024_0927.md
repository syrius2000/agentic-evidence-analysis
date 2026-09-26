# 実装計画書 024: 比較エビデンス・ダッシュボード指標階層と列順序の再設計

- **作成日時**: 2026-09-27 (JST)
- **ステータス**: READY FOR OPENSPEC IMPLEMENTATION
- **対象ブランチ**: `codex/Gower-PCoA`
- **計画策定ベースライン**: `7c5468dbd8ab45ecc2a3f73f797ee5e196902d9a`
- **推奨 OpenSpec Change ID**: `comparative-dashboard-metric-hierarchy-v1`
- **対象機能**: `vcd-categorical-reporting` の比較エビデンス要約表（HTML / Markdown）
- **実装境界**: 本計画ではコード実装を行わない。OpenSpec Change として別途実装・検証する。

---

## 1. 結論

現在のダッシュボード指標を置換・削除するのではなく、**既存の統計概念を維持したまま表示階層と列順序を整理する**。

特に以下を確定する。

1. `RD`, `RR`, Direction Support, Practical Region, **U-Grade**, Precision, Diagnostics は維持する。
2. 現在 1 列に結合されている **「100人あたり差 / NNT・NNH-like」** を 2 列に分離する。
3. `E100 = 100 × RD` を **絶対効果の自然単位表現**として前段に置く。
4. `1/|RD|` は **二次的な NNT/NNH-like 解釈値**として E100 の直後に置く。
5. U-Grade は削除せず、Practical Region と組み合わせた独立列として主表に残す。
6. JSON / CSV の canonical data contract は変更しない。
7. Gower / PCoA / HAC の特徴量契約は変更しない。E100 と reciprocal RD は引き続き幾何特徴量から除外する。

---

## 2. 現状確認（Zero-Guesswork）

### 2.1 現行 HTML 表の列順

`.agents/skills/vcd-categorical-reporting/comparative_reporting.R` の現行表は 11 列である。

1. `テーマ`
2. `比較`
3. `記述N (T / R)`
4. `記述イベント数 (T / R)`
5. `RD 推定値 [区間]`
6. `100人あたり差 / NNT・NNH-like`
7. `RR 推定値 [区間]`
8. `方向支持指標`
9. `実務領域・U-Grade`
10. `精度指標 (ESS / 区間幅)`
11. `診断バッジ`

### 2.2 既存 canonical fields

現行 `summary_df` および `comparative-evidence-v1` には、今回必要な値がすでに存在する。

- `rd_estimate`
- `rd_interval_lower`
- `rd_interval_upper`
- `excess_per_100`
- `reciprocal_absolute_rd`
- `reciprocal_status`
- `reciprocal_direction`
- `rr_estimate`
- `rr_interval_lower`
- `rr_interval_upper`
- `direction_support`
- `u_grade`
- `dominant_region`
- `rd_interval_width`
- `target_ess`
- `reference_ess`
- `badges`

したがって今回の変更は **新しい統計推定量の追加ではなく presentation contract の再編**である。

---

## 3. 新しい主表の列順序

HTML / Markdown の主表は以下の 12 列を正本とする。

| 順序 | 表示列 | canonical source | 概念 |
|---:|:---|:---|:---|
| 1 | テーマ | `theme` | 識別 |
| 2 | 比較 | `target_arm`, `reference_arm` | 識別 |
| 3 | 記述N (T / R) | `target_total`, `reference_total` | 生データ記述 |
| 4 | 記述イベント数 (T / R) | `target_events`, `reference_events` | 生データ記述 |
| 5 | **RD 推定値 [区間]** | `rd_estimate`, interval | 絶対効果・一次対比 |
| 6 | **100人あたり差 (E100)** | `excess_per_100` | 絶対効果の自然単位換算 |
| 7 | **NNT・NNH-like** | `reciprocal_absolute_rd`, status, direction | 二次的な逆数 RD 解釈 |
| 8 | **RR 推定値 [区間]** | RR fields | 相対効果 |
| 9 | **方向支持指標** | `direction_support`, `support_label` | 方向支持 |
| 10 | **実務領域・U-Grade** | `dominant_region`, `u_grade` | 実務領域解像度 |
| 11 | **精度指標 (ESS / 区間幅)** | ESS, `rd_interval_width` | 連続精度 |
| 12 | **診断バッジ** | `badges` | 数値・設計診断 |

### 3.1 読み順の統計的意図

```text
識別
  → 生データ
  → 絶対効果 RD
  → 自然単位 E100
  → 二次的 reciprocal RD
  → 相対効果 RR
  → 方向支持
  → 実務領域解像度 U-Grade
  → 精度
  → 診断
```

この順序により、

```
Effect size
≠ Natural-unit translation
≠ Reciprocal translation
≠ Direction support
≠ Practical-region resolution
≠ Precision
≠ Diagnostics
```

の概念分離を UI 上でも保持する。

---

## 4. E100 表示契約

### 4.1 定義

[
E100 = 100 	imes RD
]

### 4.2 表示

例:

- `+3.20 / 100人`
- `-1.40 / 100人`
- 利用不能時: `N/A`

### 4.3 位置づけ

- RD の線形な自然単位変換である。
- 一次 estimand を置換しない。
- RD と同じ情報を人間向け単位へ翻訳する。
- Gower / PCoA / HAC の入力特徴量には追加しない。

### 4.4 ソート

既存の `excess_per_100` を machine-readable `data-sort-value` として利用する。
表示文字列を再解釈して数値化してはならない。

---

## 5. NNT / NNH-like 表示契約

### 5.1 canonical definition

[
R_{RD} = rac{1}{|RD|}
]

canonical field は引き続き `reciprocal_absolute_rd` とする。
データ構造上の名称を `NNT` / `NNH` へ変更しない。

### 5.2 Safety domain

`reciprocal_status == "STABLE_DIRECTION"` かつ有限値の場合のみ方向ラベルを表示する。

- `reciprocal_direction == "target_excess"`
  - `NNH-like ≈ xx.x人`
- `reciprocal_direction == "reference_excess"`
  - `NNT-like ≈ xx.x人`

### 5.3 非 Safety domain

安定方向かつ有限値の場合:

- `1/|RD| ≈ xx.x人`

因果的 NNT / NNH と断定しない。

### 5.4 抑制契約

以下の場合は方向付き NNT / NNH-like を表示しない。

- `SIGN_AMBIGUOUS`
- `RD_NEAR_ZERO`
- `NOT_INTERPRETABLE`

表示例:

- `— (SIGN_AMBIGUOUS)`
- `— (RD_NEAR_ZERO)`
- `— (NOT_INTERPRETABLE)`

RD 区間が 0 を跨ぐ場合、単純逆数による連続区間を生成してはならない。

### 5.5 ソート

新規 `reciprocal_sort_val` を presentation layer で構築する。

- 安定方向かつ有限値: `reciprocal_absolute_rd` の数値
- 抑制状態: 空 sort key

既存の「有限値を missing/NA より前に置く」表ソート契約に従う。
status の恣意的な数値順位は導入しない。

---

## 6. U-Grade / Practical Region 契約

### 6.1 U-Grade は維持する

U-Grade は今回の変更で削除・置換しない。

[
C = max(q_T, q_N, q_R)
]

- U0: (C ge 0.95)
- U1: (0.80 le C < 0.95)
- U2: (0.60 le C < 0.80)
- U3: (C < 0.60)

### 6.2 表示

現行の 1 セル内 2 段表示を維持する。

例:

```text
U0
target_excess
```

### 6.3 色の責務

Practical Region / U-Grade セルだけが実務領域カラーを持つ。
RD、E100、NNT/NNH-like、RR、Direction Support、Precision のセルや行全体へ同色を伝播させない。

### 6.4 解釈

U-Grade は以下を意味しない。

- 効果量の大きさ
- 標本サイズ
- 臨床的重症度
- P 値
- 規制判断

U-Grade は active uncertainty distribution が practical regions のどこへ集中しているかの **resolution** を表す。

---

## 7. データ契約・Provenance

### 7.1 新規 canonical field は追加しない

今回の変更で以下は変更しない。

- `schemas/comparative-evidence-v1.json`
- `schemas/comparative-evidence-batch-v1.json`
- `summary_df` の canonical 40 fields
- `comparative_summary.csv` の列集合
- `comparative_evidence.json` の統計構造

### 7.2 表示層の再計算禁止

主表は必ず canonical `summary_df` の以下を使用する。

- E100: `summary_df$excess_per_100`
- reciprocal: `summary_df$reciprocal_absolute_rd`
- status: `summary_df$reciprocal_status`
- direction: `summary_df$reciprocal_direction`

HTML JavaScript で RD から E100 / reciprocal RD を再計算してはならない。

### 7.3 CSV export

現在の canonical export 契約を維持する。

- 全 40 canonical fields
- presentation-only `row_key` を除外
- UTF-8 BOM
- CRLF
- RFC 4180
- 表示列が 11 → 12 列になっても export schema は不変

---

## 8. Markdown レポート同期

`comparative_report.md` の要約表も HTML と同じ意味順に変更する。

現行:

```text
RD
→ 100人あたり差 / NNT・NNH-like
→ RR
→ Direction
→ U-Grade
```

変更後:

```text
RD
→ 100人あたり差 (E100)
→ NNT・NNH-like
→ RR
→ Direction
→ U-Grade / Region
```

HTML と Markdown で指標順序・名称・抑制規則を一致させる。

---

## 9. Metric Guide の変更

既存 10 accordion 構造は維持する。

Risk Difference セクションで以下を明確に分離する。

1. RD = primary absolute contrast
2. E100 = preferred natural-unit translation
3. reciprocal RD = secondary interpretation metric
4. NNT/NNH-like は Safety domain における direction-aware label
5. reciprocal RD は primary estimand ではない
6. zero-crossing interval では direction label と reciprocal interval を抑制

U-Grade セクションは維持し、主表に残ることと semantic alignment を取る。

---

## 10. Gower / PCoA との境界

今回の変更はダッシュボード presentation hierarchy の変更であり、Evidence Map の統計幾何を変更しない。

以下を Gower feature keys へ追加してはならない。

- `excess_per_100`
- `reciprocal_absolute_rd`
- `reciprocal_status`
- `reciprocal_direction`

理由:

- E100 は RD の線形再表現であり重複情報。
- reciprocal RD は (RD 	o 0) で発散する非線形・特異変換。
- status / direction は表示補助メタデータ。

---

## 11. 想定変更ファイル

### 必須

1. `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
   - HTML header を 12 列化
   - HTML row を 12 cell 化
   - E100 と reciprocal RD を分離
   - reciprocal sort key を追加
   - Markdown 表を同期
   - Metric Guide の文言を階層化

2. `tests/test_comparative_dashboard_qa.R`
   - 列順序
   - E100 / reciprocal 分離
   - NNT / NNH direction-aware 表示
   - suppression
   - U-Grade 維持
   - sort / export / accessibility 不変性

3. `openspec/specs/comparative-evidence-reporting/spec.md`
   - Dashboard presentation hierarchy requirement
   - E100 / reciprocal RD separation
   - U-Grade retention
   - HTML / Markdown synchronization

### OpenSpec Change 内で作成

- `openspec/changes/<change-id>/.openspec.yaml`
- `openspec/changes/<change-id>/proposal.md`
- `openspec/changes/<change-id>/design.md`
- `openspec/changes/<change-id>/tasks.md`
- `openspec/changes/<change-id>/specs/comparative-evidence-reporting/spec.md`

### 原則変更不要

- `schemas/comparative-evidence-v1.json`
- `.agents/shared/comparative_contrasts.R`
- `.agents/shared/evidence_gower.R`
- `.agents/shared/evidence_feature_extract.R`

canonical contract に不足が発見された場合のみ、計画差分を更新して再レビューする。

---

## 12. OpenSpec 実装タスク順序

### Task 1: Spec delta

- 12列の canonical presentation order を SHALL として定義。
- E100 と reciprocal RD の列分離を定義。
- U-Grade retention を定義。
- HTML / Markdown synchronization を定義。
- export schema non-change を明示。

### Task 2: HTML renderer

- header を 12列化。
- `absolute_translation_html` を E100 / reciprocal の 2 cell に分割。
- `e100_sort_val` と `reciprocal_sort_val` を別管理。
- 行セル数 = header 列数を保証。

### Task 3: Markdown renderer

- 結合列を 2 列へ分割。
- Safety / non-Safety / suppression contract を HTML と一致させる。

### Task 4: Guide

- E100 = preferred natural-unit translation。
- reciprocal = secondary translation。
- U-Grade = practical-region resolution。
- 因果的 NNT の誤用を禁止。

### Task 5: QA

以下のテストマトリクスを満たす。

---

## 13. Concrete QA Test Matrix

| ID | Fixture / 状態 | Check | Expected |
|:---|:---|:---|:---|
| Q1 | 標準 Safety fixture | HTML header 順序 | 12 列が本計画の順序と完全一致 |
| Q2 | 標準 Safety fixture | HTML row cell count | 全行 12 cell |
| Q3 | 標準 Safety fixture | Markdown header | HTML と同じ意味順 |
| Q4 | (RD > 0), stable interval | NNT/NNH column | `NNH-like ≈ ...人` |
| Q5 | (RD < 0), stable interval | NNT/NNH column | `NNT-like ≈ ...人` |
| Q6 | interval crosses 0 | reciprocal suppression | `SIGN_AMBIGUOUS`、direction label 非表示 |
| Q7 | RD near 0 | reciprocal suppression | reciprocal null / `RD_NEAR_ZERO` |
| Q8 | non-Safety domain | reciprocal label | `1/|RD| ≈ ...人`、NNT/NNH と断定しない |
| Q9 | E100 | value provenance | `summary_df$excess_per_100` と表示値が一致 |
| Q10 | reciprocal | value provenance | `summary_df$reciprocal_absolute_rd` と表示値が一致 |
| Q11 | U0–U3 | retention | `実務領域・U-Grade` 列が存在し表示維持 |
| Q12 | U3 | color semantics | U3 は muted/achromatic contract を維持 |
| Q13 | primary_delta = null | U contract | NONE / none、実務領域色無効 |
| Q14 | E100 sort | machine sort | 数値昇降順、表示文字列再解析なし |
| Q15 | reciprocal sort | machine sort | stable finite 値が数値ソート、suppressed は missing 扱い |
| Q16 | existing sorting | keyboard | click / Enter / Space と `aria-sort` が維持 |
| Q17 | CSV export | schema | canonical 40 fields が完全不変 |
| Q18 | filtered export | order | 表示中 sort order と一致 |
| Q19 | Zero-External-Asset | static scan | http/https/CDN/OS絶対パスなし |
| Q20 | RR zero-reference fixture | regression | RR instability warning と RD/E100 利用可能性を維持 |
| Q21 | Bayesian-only | guide semantics | posterior median / ETI を維持 |
| Q22 | Bootstrap-only | guide semantics | observed estimate / percentile interval を維持 |
| Q23 | mixed semantics | guide semantics | 両推論方式を明示 |
| Q24 | Gower feature contract | static assertion | E100 / reciprocal fields が clustering keys に入らない |

---

## 14. Acceptance Criteria

OpenSpec 実装完了の受入条件は以下。

1. 主表が 12 列で、順序が本計画と一致する。
2. E100 と NNT/NNH-like が別セルで表示される。
3. U-Grade / Practical Region が削除されていない。
4. U-Grade の色は Practical cell のみに限定される。
5. reciprocal RD の direction-aware / suppression contract が維持される。
6. HTML と Markdown が同一意味順になる。
7. canonical JSON / CSV schema が変更されていない。
8. export 40 fields contract が維持される。
9. keyboard sorting / aria-sort / filters が退行しない。
10. Zero-External-Asset contract を満たす。
11. Gower / PCoA の feature set が変更されていない。
12. 既存 regression tests + 本計画 QA matrix が PASS する。

---

## 15. 非目標（Non-Goals）

本 Change では以下を実施しない。

- 新しい NNT estimand の導入
- causal NNT の自動主張
- reciprocal RD の posterior median の新規推定
- zero-crossing reciprocal interval の生成
- U-Grade 閾値の変更
- primary_delta の変更
- RR / RD 推論方法の変更
- schema version bump
- CSV field addition / deletion
- PCoA / HAC の再設計
- Gower feature weighting の変更

---

## 16. リスクと批判的観点

### 16.1 横幅増加

11 列から 12 列へ増えるため横スクロール量が増える。

**対応**:
- `table-container { overflow-x: auto; }` を維持。
- E100 / NNT 列は compact typography とする。
- 精度・診断を削除して帳尻を合わせない。

### 16.2 NNT/NNH の過剰解釈

NNT/NNH は一般に因果的な名称として受け取られやすい。

**対応**:
- canonical 名は `reciprocal_absolute_rd` のまま。
- Safety の安定方向のみ `NNT-like` / `NNH-like`。
- 非 Safety は `1/|RD|`。
- guide に secondary interpretation と明記。

### 16.3 U-Grade の独自性

U-Grade は一般的標準統計量ではないため初見で誤解され得る。

**対応**:
- 主表には残す。
- Guide で practical-region resolution と明示。
- 効果量・精度・重症度とは別概念であることを維持。

---

## 17. 推奨実装判断

本変更では **削除ではなく階層化**を採用する。

最終的な主表の読み順は以下を正本とする。

> **RD → E100 → NNT/NNH-like → RR → Direction Support → Practical Region / U-Grade → Precision → Diagnostics**

この順序により、統計量を増やしながらも「何のための指標か」を視覚的に分離できる。
