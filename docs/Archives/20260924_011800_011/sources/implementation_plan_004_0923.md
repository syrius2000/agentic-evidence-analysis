# Phase 2 Section 8 Review #5 指摘事項修復計画（H-01, H-02, M-01〜M-04）

created: 2026-09-23 15:32 (JST)  
author: Antigravity  
review_reference: docs/Artifacts/Phase1_implementation_review5_20260923.md  

## 1. 背景と目的

独立レビュー Review #5（`b80d7e983502178808bf95d065d15b87c7605d72`）において、Section 8 の数理的修正（主 OR = 不一致ペア比 $p_{10}/p_{01}$、連関 OR = $p_{11}p_{00}/(p_{10}p_{01})$）は PASS と判定された。
一方、セマンティック契約およびスキーマ保護に関する 2 件の High 指摘（H-01, H-02）および 4 件の Medium 推奨（M-01〜M-04）が提起された。
本計画は、Section 8 の完了基準を満たし、Section 9（1:k Matched Sets）へ安全に進むための契約強化とコード修復を目的とする。

## 2. 修復方針と対象スコープ

### H-01 (High): 因果的表現（`treatment-effect`）の脱色と中立化

- **対象**: `design.md`, `spec.md`, `tasks.md`, `matched_pair_dirichlet.R`
- **内容**: 観察研究マッチドペアにおいて「因果的治療効果」と誤認されるのを防ぐため、`conditional treatment-effect OR` を中立的な `discordant-pair matched odds ratio`（不一致ペアマッチドオッズ比）または `conditional_matched_pair_or` に統一。

### H-02 (High): スキーマによる `matched_pair` 拡張の厳密な定義と保護

- **対象**: `schemas/comparative-evidence-v1.json`, `schemas/comparative-draws-v1.json`
- **内容**:
  - `comparative-evidence-v1.json` の `properties` に `matched_pair` オブジェクトを明示定義：
    - `pair_count` (integer, min 1)
    - `concordant_pair_count` (integer, min 0)
    - `discordant_pair_count` (integer, min 0)
    - `cell_counts` (object: n11, n10, n01, n00)
    - `odds_ratio_definition` (string, enum: `["discordant_pair_p10_over_p01"]`)
    - `odds_ratio` (estimate + interval + mean + mean_is_finite)
    - `intra_pair_association_or` (estimate + interval + mean + mean_is_finite)
  - `comparative-draws-v1.json` の `properties` に `matched_pair_counts` および `cell_probability_draws` を明示定義。
  - スキーマテスト（`tests/test_comparative_schemas.R`）でこれらがDraft-7バリデータで確実に検証されることを担保。

### M-01 (Medium): Dirichlet 事後分布の解析的厳密期待値の採用

- **対象**: `.agents/shared/matched_pair_dirichlet.R`
- **内容**: モンテカルロ平均 `mean(or_draws)` を廃止し、Jeffreys 事前分布 $\text{Dir}(n_{ij} + 0.5)$ に基づく解析的厳密期待値を計算：
  $$E(OR_{\rm cond}) = \frac{\alpha_{10}}{\alpha_{01} - 1} = \frac{n_{10} + 0.5}{n_{01} - 0.5} \quad (n_{01} \ge 1)$$
  $$E(OR_{\rm assoc}) = \frac{\alpha_{11}\alpha_{00}}{(\alpha_{10} - 1)(\alpha_{01} - 1)} = \frac{(n_{11} + 0.5)(n_{00} + 0.5)}{(n_{10} - 0.5)(n_{01} - 0.5)} \quad (n_{10} \ge 1 \land n_{01} \ge 1)$$
  これによりモンテカルロ誤差と極端ドローによる平均不安定性を完全に排除。

### M-02 (Medium): 対数スケールによるオッズ比分位数の安定計算

- **対象**: `.agents/shared/matched_pair_dirichlet.R`
- **内容**: `pmax(..., 1e-15)` による人工的打ち切りを排除し、対数差分：
  $$\log OR_{\rm cond} = \log p_{10} - \log p_{01}$$
  $$\log OR_{\rm assoc} = \log p_{11} + \log p_{00} - \log p_{10} - \log p_{01}$$
  から分位数を求め、$\exp(\cdot)$ で ETI および中央値を算出。

### M-03 (Medium): 対称なゼロセル境界テストと解析的平均の一致検証

- **対象**: `tests/test_matched_pair_dirichlet.R`
- **内容**:
  - $n_{10} > 0, n_{01} = 0$: 条件付き OR 平均非有限、連関 OR 平均非有限
  - $n_{10} = 0, n_{01} > 0$: 条件付き OR 平均有限（= 0）、連関 OR 平均非有限
  - $n_{10} = 0, n_{01} = 0$: 両方非有限
  - 有現ケース（$n=(3,2,1,4)$）での解析平均値（$OR_{\rm cond} = 5.0$, $OR_{\rm assoc} = 21.0$）の一致検証。

### M-04 (Medium): SKILL ドキュメントの明確化

- **対象**: `.agents/skills/comparative-design-analysis/SKILL.md`
- **内容**: 主たる不一致ペア比（$p_{10}/p_{01}$）とペア内連関比（$p_{11}p_{00}/(p_{10}p_{01})$）の定義と解釈の違いを明記。

## 3. 変更対象ファイル一覧

1. `[MODIFY] schemas/comparative-evidence-v1.json`
2. `[MODIFY] schemas/comparative-draws-v1.json`
3. `[MODIFY] .agents/shared/matched_pair_dirichlet.R`
4. `[MODIFY] .agents/skills/comparative-design-analysis/SKILL.md`
5. `[MODIFY] openspec/changes/comparative-evidence-reporting-v3/design.md`
6. `[MODIFY] openspec/changes/comparative-evidence-reporting-v3/specs/comparative-design-inference/spec.md`
7. `[MODIFY] openspec/changes/comparative-evidence-reporting-v3/tasks.md`
8. `[MODIFY] tests/test_matched_pair_dirichlet.R`
9. `[MODIFY] tests/test_comparative_schemas.R`

## 4. 検証手順

```bash
Rscript tests/test_matched_pair_dirichlet.R
Rscript tests/test_comparative_schemas.R
git diff --check
```

## 5. 承認ゲート

本計画書の内容（H-01, H-02, M-01〜M-04 の修復方針）についてユーザーの承認を得た後、実装フェーズへ移行する（2026-09-23 15:40 JST 承認済）。

## 6. 実施結果

2026-09-23 15:43 (JST) に以下の全項目を実装・検証完了：

1. **H-01**: `conditional treatment-effect OR` を `discordant-pair matched odds ratio`（不一致ペアオッズ比）へ中立化（`design.md`, `spec.md`, `tasks.md`, `SKILL.md`, `matched_pair_dirichlet.R`）。
2. **H-02**: `schemas/comparative-evidence-v1.json` に `matched_pair` オブジェクト定義（`odds_ratio_definition = "discordant_pair_p10_over_p01"` 等）および `schemas/comparative-draws-v1.json` に `matched_pair_counts`, `cell_probability_draws` を追加。Draft-7 スキーマ検証テストで無効な定義の拒絶を確認。
3. **M-01**: モンテカルロ平均を廃止し、Dirichlet 事後分布の厳密な理論期待値（$E[OR_{\rm cond}] = \frac{n_{10}+0.5}{n_{01}-0.5}$ 等）を解析的に算出。テストケースで $OR_{\rm cond}=5.0, OR_{\rm assoc}=21.0$ の完全一致を検証。
4. **M-02**: $\log$ 差分からの分位数算出と $\exp$ 変換により、`pmax` 人工的打ち切りを排除。
5. **M-03**: 対称なゼロセル境界テスト（$n_{10}>0, n_{01}=0$、$n_{10}=0, n_{01}>0$、$n_{10}=0, n_{01}=0$）を追加（26/26 PASS）。
6. **M-04**: `SKILL.md` に主オッズ比（不一致ペア比）とペア内連関比の明確な役割・解釈の違いを追記。
7. **検証**:
   - `test_matched_pair_dirichlet.R`: 26/26 PASS
   - `test_comparative_schemas.R`: 38/38 PASS
   - `git diff --check`: クリーン（エラーなし）
