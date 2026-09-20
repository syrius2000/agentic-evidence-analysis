---
name: vcd-categorical-analysis
description: "Use when performing nominal two-way categorical analysis through the profile, render, expert narrative, quality-check, and dashboard workflow."
license: MIT
metadata:
  author: vcd-categorical-analysis-skill
  version: "4.1"
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
| **出力先** | `<out>/run_<first16>[_N]/` | 衝突時は自動サフィックス分離 |

---

## 2. 必須ワークフロー（Pass 0 + エージェント3ステップ）

1. **Pass 0（Consultation）**: `vcd-pass0-consultation`で入力品質、変数、度数列、構造的ゼロ、標本単位、実務上の問いを確認し、承認済みの`analysis_config.json`を確定する。
2. **Step 1（Canonical R）**: 確定設定から`categorical_results.json`（Interface 3.0）、`residuals_table.csv`、`quarantine_cells.csv`を生成する。
3. **Step 2（AI Review）**: JSONを読み、7ステップ考察契約に従って日本語の`executive_summary.md`を作成する。
4. **Step 3（Report）**: 完全オフライン`dashboard.Rmd`をレンダリングし、調整標準化残差、条件付きestimand、効果量、不確実性を中心とした外部リソースゼロの`dashboard.html`を生成・確認する。モザイク図は現行canonicalの主表示・必須成果物ではない。

---

## 3. R エンジンの実行方法

### Canonical実行

```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --config path/to/analysis_config.json \
  --out ./skill_out/vcd_categorical/ \
  --label datasetA
```

`--config`、`--out`、`--label`、`--help`以外の引数はcanonical経路では使いません。`--data`、`--vars`、`--freq`、`--input-mode`、`--prior-alpha`、`--practical-delta`などで解析条件を上書きすると、`CANONICAL_CONFIG_OVERRIDE_FORBIDDEN`で停止します。

開発・テスト用の非canonical経路は成果物を生成せず、運用上のcanonical実行例として使用しません。

### 実行同一性と再開

canonical実行は `requested_run_id`、`analysis_signature`、`run_state` を記録し、出力先を `<out>/run_<first16>[_N]/` として予約します。予約は atomic reservation で行い、状態は順に `allocated`、`profile_complete`、`render_in_progress`、`render_complete` と遷移します。再開時にも設定と署名を再照合します。存在しない `--data` を含む個別上書き引数はcanonical経路で受け付けません。

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

### Pass 2.5: 品質確認

Pass 2の後、同じrun出力に`quality_check.md`を作成し、P値偏重、効果量とEvidenceの混同、隔離セルの過大解釈、図表と本文の不整合、未解決の解釈保留を確認します。重大な未解決事項があれば、完成扱いにせず理由を明記します。
