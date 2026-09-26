---
name: vcd-pass0-consultation
description: Use when starting a new categorical data analysis to inspect data, select dimensions, and define the analysis scope before statistical computation.
---

# VCD Pass 0: Interactive Consultation（対話型事前相談）

大標本カテゴリカルデータ分析（`vcd-bayesian-evidence-analysis` 等）の最初の一手として、データの統計的性質を事前に検分し、分析の軸（次元）、目的変数、層別、およびモデル前提を確定するための対話型スキル。

## Pass 0の適用範囲

- **必須 (Mandatory)**: `vcd-categorical-analysis` および `vcd-bayesian-evidence-analysis` の新規分析、ならびに `comparative-design-analysis` の非独立観測デザイン（マッチドペア、マッチドセット、IPTW、人年発症率、集約可能判定）。
- **推奨 (Recommended)**: `vcd-categorical-reporting`（複数テーマ一括比較・安全性スクリーニング）、`questionnaire-batch-analysis`（複数設問の入力・出力設計の事前調整）。
- **対象外 (Not Required)**: `sas-proc-freq`、`sas-proc-means`、単体集計スクリプトの直接実行、回帰・ユニットテスト、ドキュメントやコードの改修保守。

---

## 共通品質契約

本スキルは `.agents/shared/analysis_quality_contract.md` に準拠します。Pass 0では統計計算前の入力品質、分析スコープ、変数選択、集約・除外・層別を確認します。2次元canonical経路では承認済み`analysis_config.json`を正本とし、3次元新経路では設定内の`consultation.rationale`を合意理由の正本とします。

---

## ワークフロー

### 1. データ物理検分 (Inspection)
まず、以下のスクリプトを実行して、データの客観的な統計情報を取得します：

```bash
Rscript .agents/shared/inspect_data.R <path_to_your_data.csv> \
  --out-dir evidence_runs/inspections/<project>/run_<id>/
```

`<project>` と `<id>` は実際の識別子へ置き換え、実行ごとに新しい run directory を指定します。既存 run へ無言で上書きしてはなりません。
空のout-dirを指定する場合も、実行識別子を含む run directory を新規に確保してから出力します。

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

#### C. 観測デザインの検分とルーティング判定 (Design Verification & Routing)
- **独立 2 群（または対照群 vs 各群）**:
  - 各群の度数が独立であれば `vcd-categorical-reporting`（独立 Jeffreys Beta-Binomial）へルーティング。
- **マッチドペア (1:1 Matched Pairs)**:
  - 被験者ペアID（`pair_id`）に基づく 4 セル分割表であれば `comparative-design-analysis`（Dirichlet 厳密期待値）へルーティング。
- **マッチドセット (1:k Matched Sets)**:
  - 1処置対 $k$ 対照の非復元マッチングデータであれば `comparative-design-analysis`（固定条件付きクラスタブートストラップ）へルーティング。
- **IPTW (逆確率重み付け)**:
  - 個票共変量に基づく傾向スコア調整であれば `comparative-design-analysis`（PSモデル再推定患者ブートストラップ）へルーティング（非整数擬似度数を独立推論器に渡すことは禁止）。
- **人年発症率 (Person-Time Exposure)**:
  - 観察人年/人月とイベント数であれば `comparative-design-analysis`（共役 Gamma-Poisson 率モデル）へルーティング。
- **反復測定・縦断データ (Repeated Observations)**:
  - 同一被験者の複数行データについて、被験者レベルの二値状態（イベント経験有無）へ一意に集約可能か（`can_collapse_to_subject_binary`）を検分。集約可能かつ他の依存構造がないことが確認された場合のみ集約後二値推論へルーティングし、階層クラスタや GEE/GLMM が必要な場合は範囲外として明示停止。
- **決定監査 (Evidence Decision Review)**:
  - 算出された統計エビデンスプロファイルから過去の専門家判断との整合性を確認する場合は `evidence-decision-review` へルーティング。

#### D. Dual-Filter と基準モデルの選定
- 2次元では、$N \ge 2,000$、REGULAR、Effect（$|\log(O/E)| \ge 0.50$）、Evidence（$T_i^{\rm score} \ge 3.84$）を満たす探索候補を定義します。
- 3次元では、現行候補条件にNカットオフを加えず、REGULAR、Effect、Evidenceを明示します。どちらも探索的条件であり、FWER/FDR保証、実務的重要性、因果性を意味しません。
- セル診断の比較対照となる基準モデル（既定: M1 相互独立モデル、または M7/M8 等）を確認します。

### 3. 設計図と構成の出力 (Artifacts)
合意事項に基づき、以下の 2 つの成果物を生成します：

1. **`data_analysis_scope.md`または`consultation.rationale`**:
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
  "top_k": 10,
  "dirichlet_prior": {
    "primary_alpha": 0.5,
    "sensitivity_alpha": 1.0
  },
  "output_dir": "output/titanic",
  "run_id": "titanic_v1"
}
```

設定ファイル作成後、Pass 1 の本格計算に進む前に `--validate-only` フラグで設定の整合性を事前検証します：

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --config output/titanic/run_titanic_v1/analysis_config.json \
  --validate-only
```

### 4. 次の一手へのガイド (The Guidance)
検証が成功したら、ユーザーに対して次に実行すべき Pass 1 のコマンドを案内します：

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --config output/titanic/run_titanic_v1/analysis_config.json
```

---

## 完了条件

- `inspection_results.json` を読んだ上で、データの水準数、総度数、欠測、疎セルの確認結果を報告できること。
- 2次元では`analysis_config.json`、3次元新経路では`analysis_config.json`と`consultation.rationale`が整合し、検証を通過していること。
- 未解決の欠測、過剰水準、疎セル、観測の従属性がある場合は、Pass 1 へ進む前の解釈保留（ブロッカー）として明示すること。

## アンチパターン

- **全変数の一括投入**: 4 変数以上の無計画な投入は「次元の呪い」と過適合を招きます。Pass 0 で 3 次元以内に集約することが重要です。
- **検分なしの即時計算**: データの疎密やゼロセルを知らずに Pass 1 を実行すると、モデル非収束や特異行列エラーの原因となります。
