---
name: vcd-pass0-consultation
description: Use when starting a new categorical data analysis to inspect data, select dimensions, and define the analysis scope before statistical computation.
---

# VCD Pass 0: Interactive Consultation（対話型事前相談）

大標本カテゴリカルデータ分析（`vcd-bayesian-evidence-analysis` 等）の最初の一手として、データの統計的性質を事前に検分し、分析の軸（次元）、目的変数、層別、およびモデル前提を確定するための対話型スキル。

> [!CAUTION]
> **IRON LAW of ANALYSIS**:
> Pass 0（事前検分と相談）を経ずに Pass 1（統計計算）を開始してはなりません。「次元の呪い」や疎セルの見落としによる破綻を防ぐため、**Step 1 は常に Pass 0 です。**

---

## 共通品質契約

本スキルは `.agents/shared/analysis_quality_contract.md` に準拠します。Pass 0 では、統計計算前の入力品質、分析スコープ、変数選択、集約・除外・層別の判断を確認し、`data_analysis_scope.md` と `analysis_config.json`（Single Source of Truth）に反映します。

---

## ワークフロー

### 1. データ物理検分 (Inspection)
まず、以下のスクリプトを実行して、データの客観的な統計情報を取得します：

```bash
Rscript .agents/shared/inspect_data.R <path_to_your_data.csv> \
  --out-dir output/<project>/run_<id>/
```

`<project>` と `<id>` は実際の識別子へ置き換え、実行ごとに新しい run directory を指定します。既存 run へ無言で上書きしてはなりません。

生成された `inspection_results.json` を確認し、以下の統計的性質を点検します：
- 各変数の水準数（多すぎないか？）
- 度数の分布（極端に少ないセルやサンプリングゼロはないか？）
- 欠測値（NA）の有無と処理方針
- 度数列（`Freq` 等）の有無（集計表か個票か）
- 観測間の独立性（同一被験者の重複測定ではないか）

### 2. インタラクティブ提案 (Consultation)
検分結果に基づき、ユーザーに対して以下の観点で対話型提案を行います：

#### A. 次元の絞り込みと変数の選定
- 4 変数以上を同時に投入すると、高次交互作用が複雑化し解釈が困難になります。
- 目的変数に対して関連が深い 3 変数（3元配置）への絞り込み、または水準数の集約（再分類）を提案します。

#### B. 層別解析の提案
- 特定の属性（性別、年齢層、施設等）によって関連構造が大きく異なる疑いがある場合、全体の一括分析ではなく層別（サブグループ）解析を提案します。

#### C. 大標本 Dual-Filter と基準モデルの選定
- 総度数 $N > 2,000$ の大標本では、微小な偏りでも P 値が飽和するため、新 4 軸セル診断における **Effect（$|\log(O/E)| \ge 0.50$）第一スクリーニング** と **Evidence（$T_i^{\rm score} \ge 3.84$）ノイズ排除** の Dual-Filter 適用を合意します。
- セル診断の比較対照となる基準モデル（既定: M1 相互独立モデル、または M7/M8 等）を確認します。

### 3. 設計図と構成の出力 (Artifacts)
合意事項に基づき、以下の 2 つの成果物を生成します：

1. **`data_analysis_scope.md`**:
   - 分析の背景、選択した変数の根拠、除外・集約した変数の理由、標本単位の前提を記録した人間可読ドキュメント。
2. **`analysis_config.json`**:
   - Pass 1 に渡すための設定ファイル（Single Source of Truth）。
   - 現行 3 次元正本（`vcd-bayesian-evidence-analysis` の `three-way-results-v1` 経路）の設定例：

```json
{
  "input": "examples/titanic.csv",
  "vars": ["Class", "Sex", "Survived"],
  "freq": "Freq",
  "response_var": "Survived",
  "base_model": "M1",
  "large_n_threshold": 2000,
  "top_k": 10,
  "dirichlet_a": 1.0,
  "output_dir": "output/titanic",
  "run_id": "titanic_v1"
}
```

設定ファイル作成後、Pass 1 の本格計算に進む前に `--validate-only` フラグで設定の整合性を事前検証します：

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R \
  --config output/titanic/run_titanic_v1/analysis_config.json \
  --validate-only
```

### 4. 次の一手へのガイド (The Guidance)
検証が成功したら、ユーザーに対して次に実行すべき Pass 1 のコマンドを案内します：

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R \
  --config output/titanic/run_titanic_v1/analysis_config.json
```

---

## 完了条件

- `inspection_results.json` を読んだ上で、データの水準数、総度数、欠測、疎セルの確認結果を報告できること。
- `data_analysis_scope.md` と `analysis_config.json` が生成され、検証（validate-only）を通過していること。
- 未解決の欠測、過剰水準、疎セル、観測の従属性がある場合は、Pass 1 へ進む前の解釈保留（ブロッカー）として明示すること。

## アンチパターン

- **全変数の一括投入**: 4 変数以上の無計画な投入は「次元の呪い」と過適合を招きます。Pass 0 で 3 次元以内に集約することが重要です。
- **検分なしの即時計算**: データの疎密やゼロセルを知らずに Pass 1 を実行すると、モデル非収束や特異行列エラーの原因となります。
