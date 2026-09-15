---
name: vcd-categorical-analysis
description: "Use when performing nominal two-way categorical analysis through the profile, render, expert narrative, quality-check, and dashboard workflow."
license: MIT
metadata:
  author: vcd-categorical-analysis-skill
  version: "4.0"
---

名義カテゴリカル変数の **完全2次元分割表（Arity=2）専用**の独立性検定（Poisson GLM）、局所診断（Haberman 調整残差・Rao スコア）、大標本 Dual-Filter、多項 Dirichlet 事後推論、および完全オフライン Scientific Dashboard の生成を行う。

3次元以上の多次元探索や階層対数線形モデル（M1〜M9）は、正本スキル `vcd-bayesian-evidence-analysis` へ委譲する。

---

## 1. 共通品質契約と入力境界

本スキルは `.agents/shared/analysis_quality_contract.md` を厳格に遵守する。

| 項目 | 契約仕様 | 違反時の挙動 |
| :--- | :--- | :--- |
| **次元数（Arity）** | 厳密に2（$I \ge 2, J \ge 2$） | `INVALID_INPUT_ARITY` でフェイルファスト停止し、3-way正本スキルへ委譲案内 |
| **度数** | 有限非負整数（$N > 0$） | 欠測・負値・非整数重みは即時停止（`NON_INTEGER_COUNTS` 等） |
| **構造的ゼロ** | **入力禁止**（サンプリングゼロのみ許容） | `STRUCTURAL_ZERO_NOT_SUPPORTED` で即時停止し準独立モデル案内 |
| **出力先** | `./skill_out/vcd_categorical/run_<first16>[_N]/` | 衝突時は自動サフィックス分離 |

---

## 2. 必須ワークフロー（エージェント3ステップ + R 2パス）

1. **Step 1（Data）**: R **2パス**を実行し、`data_profile.json`、`categorical_results.json`（Interface 3.0）、`residuals_table.csv`、`quarantine_cells.csv` を生成する。
2. **Step 2（AI Review）**: JSON を読み、7ステップ考察契約に従って日本語の **`executive_summary.md`** を作成する。
3. **Step 3（Report）**: **完全オフライン `dashboard.Rmd`** をレンダリングし、外部リソースゼロの `dashboard.html` を生成・確認する。

---

## 3. R エンジンの実行方法

### Pass 1: 入力検証とプロファイリング

```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --profile \
  --data your_data.csv \
  --vars "Treatment,Outcome" \
  --freq "Freq" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260915
```

### Pass 2: 本生成（GLM・Dirichlet推論・Interface 3.0）

```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --render \
  --data your_data.csv \
  --vars "Treatment,Outcome" \
  --freq "Freq" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260915
```

---

## 4. Step 2 AI Narrative の 7ステップ考察契約

`references/ai-narrative-workflow.md` に従い、以下の順序で記述する：
1. **全体関連構造**: $\chi^2, G^2$、自由度、$p$ 値
2. **効果の大きさ**: 未補正 Cramér's $V$ と bias-corrected $\tilde{V}$（95% CI）
3. **統計的証拠強度**: $\log(O/E)$、Rao スコア $T^{\rm score}$、大標本 Dual-Filter 候補
4. **局所診断と安定性**: Quarantine 判定（ゼロセル、低期待度数、高レバレッジ）
5. **ベイズ事後不確実性**: 多項 Dirichlet 95% ETI 信用区間
6. **条件付き割合と実務解釈**: $P(B|A), P(A|B)$
7. **制約事項と次アクション**: 限界、交絡、3次元以上への移行案内

**禁止事項**:
- P値単独判定
- 観測ゼロセルの対数比0扱い（$-\infty$ 隔離セルとして扱うこと）
- 英語本文（数式・記号除く）
- 残差符号の未確認解釈
