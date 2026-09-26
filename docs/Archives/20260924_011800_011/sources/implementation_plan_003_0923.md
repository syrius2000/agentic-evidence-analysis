# Phase 2 Section 8 マッチドペア OR 意味論修正計画

created: 2026-09-23 14:26 (JST)
update: 2026-09-23 14:28 (JST)
author: Codex (GPT-6)

## 1. 対象と承認境界

対象 Change は `comparative-evidence-reporting-v3` の Section 8（1:1 マッチドペア Dirichlet 推論）である。独立レビューで、既存の `matched_pair.odds_ratio` がペア内連関 OR を治療効果 OR と読める名称で返していることが判明した。Owner は 2026-09-23 に、条件付き治療効果 OR を主 OR とし、ペア内連関 OR を別フィールドで保持する案Aを承認した。

本計画の対象はこの意味論修正だけである。commit、push、アーカイブ、および Section 9 以降の実装は対象外とする。

## 2. 実装契約

- `matched_pair.odds_ratio` は条件付き治療効果 OR の事後ドロー `p10 / p01` を要約する。
- 既存の `p11 * p00 / (p10 * p01)` は `matched_pair.intra_pair_association_or` として明示的に返す。
- 条件付き OR の理論平均は `n01 = 0` のときだけ非有限として `mean = null`、`mean_is_finite = false` とする。
- 連関 OR の理論平均は `n10 = 0` または `n01 = 0` のとき非有限として同じ表現にする。
- OpenSpec の Requirement、design、tasks を同じ定義に更新し、固定シードの数値テストで主 OR と連関 OR を区別する。

## 3. 検証

```text
Rscript tests/test_matched_pair_dirichlet.R
Rscript tests/test_comparative_schemas.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

各実行結果は、実装検証として記録し、独立 QA・Owner 裁定・commit・push と区別する。

## 4. 実施結果

2026-09-23 14:28（JST）に、主 OR を `p10/p01`、ペア内連関 OR を `intra_pair_association_or` に変更した。固定シードのテストで両式を別々に再計算して出力値との一致を確認し、分母ゼロ時の理論平均の有限性もそれぞれ検証した。`Rscript tests/test_matched_pair_dirichlet.R` は 20/20、`Rscript tests/test_comparative_schemas.R` は 37/37 成功した。完全回帰は 39/39 成功した。OpenSpec strict validation は valid、`git diff --check` は成功した。
