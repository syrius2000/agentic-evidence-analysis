---
name: vcd-bayesian-evidence-analysis
description: Use when exploring aggregated three-way categorical counts with hierarchical log-linear models, local cell diagnostics, explicit-prior Bayesian proportions, Japanese interpretation, and HTML reports; also maintains the legacy two-way evidence workflow.
license: MIT
metadata:
  version: "2.0"
---

# 3次元カテゴリカル探索支援

集計済み度数の3変数について、全体構造、差の大きさ、証拠量、不確実性を区別して説明する。利用者と分析設計を相談し、計算結果に追跡可能な日本語考察を作成する。ベイズなら標本サイズの問題が消えるとは扱わない。

## 統計的正本と責務境界

新規の3次元集計表では、このスキルの `three-way-results-v1` 経路を統計的正本とする。`vcd-categorical-analysis` は名義カテゴリの2次元を主とする互換・記述経路であり、9階層モデルや本スキルの結果JSONを代替しない。旧2次元経路と `Reference.md` は履歴・互換保守専用で、旧Evidence Scoreをセルの証拠、効果量、セルBF、実質的重要性の自動判定に使わない。

`ΔG²/N` は標準化された効果量ではなく、基準モデルから拡張モデルへの **1観測あたりの逸脱度改善（per-observation deviance improvement）** である。固定総度数の多項表では、観測分布とのKL乖離の差として読む。`log(O/E)`、`d/√N`、局所 `ΔG²`、leverage、BF、信用区間はそれぞれ別の問いに答えるため、合成した単一スコアや一律閾値を導入しない。セル順位の安定性は再標本化で別途評価する計画であり、現行初版のleverageや境界フラグだけから安定性を主張しない。

## 経路を選ぶ

- **3次元・整数の集計度数**: 以下の新経路を使用する。目的変数未指定でも解析でき、指定時は条件付き割合と条件群間の差を追加する。
- **2次元または旧結果の保守**: [旧経路](references/legacy_usage.md)を参照する。旧ScoreはBFでも実質的重要性の判定でもない。新経路の結果JSONを旧rendererへ渡さない。
- **割合だけ・重み・複数回答・依存観測・構造ゼロ**: 新経路の適用を保留し、分母・標本単位・モデルを再相談する。度数へ丸めて通さない。

共通の [品質契約](../../shared/analysis_quality_contract.md) と [新経路の契約](references/three_way_contract.md) に従う。コマンドはリポジトリルートから実行する。

## Pass 0：相談と設定

`vcd-pass0-consultation`で目的、3変数、目的変数の有無、集約軸、標本単位・重複・独立性、欠測・ゼロ、分母、水準順、抽出、実用上意味のある差を確認する。既に合意した事項は再質問しない。最大512セルは初期版の運用上限であり、3変数なら無条件に解釈可能とはしない。

```bash
Rscript .agents/shared/inspect_data.R examples/titanic.csv --out-dir output/my_inspection
```

検分JSONは列・水準・行数・欠測数・入力SHA-256を持つ。行数は総度数と異なる。度数集約の補足検分は次のvalidate-onlyで確認する。設定は [例](templates/three_way/config_example.json) と [schema](templates/three_way/analysis_config.schema.json) に基づいて実データに合わせて作る。入力・検分・出力の相対パスはリポジトリルート基準。`consultation.rationale`に合意した理由と限界を記載し、`input_sha256`は検分からコピーする。

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R --config analysis_config.json --validate-only
```

この操作はモデル適合をしない。検証成功・総度数・集約・ゼロ扱いを確認してからPass 1へ進む。未知抽出条件はエラーとなり、全件へのフォールバックはしない。

## Pass 1：計算

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R --config analysis_config.json
```

出力は設定の `output_dir/run_<run_id先頭16文字>/`。同じ出力先の再使用を拒否する。`evidence_results.json`のschemaは `three-way-results-v1`。計算済みは `COMPUTED`、推定保留を含む場合 `PARTIAL_HOLD`（終了2）、校正・照合失敗は `CHECK_FAILED`（終了1）。部分保留を全体成功へ言い換えない。独立参照照合を実施する検証入口は `tests/statistical_foundations/run_validation.R --config ...`。

## Pass 2：結果を読んで日本語で考察する

定型文だけを出力せず、今回の問いと結果JSONを読んで `executive_summary.md` を作る。

1. **問いと分母**: 対象、総度数、軸、合算・抽出、目的変数、標本の前提。
2. **構造**: M1〜M9の何を比較したか。全体関連と3次交互作用を区別。比較のID、ΔG²、自由度、近似状態を根拠にする。
3. **セルと差の大きさ**: 基準モデル・cell_id・水準・O/E・log(O/E)・正規化量を明示。全体BFをセルの確信度にしない。leverageは影響度・安定性そのものではない。
4. **ベイズの不確実性**: 事前総集中度、条件付き割合の分母、点ごとの95%等裾信用区間、感度を説明。セル確率の事後と対数線形モデルの事後を混同しない。
5. **限界と次の分析**: 多重性、疎なセル、独立性、因果解釈の限界、実用差の未指定を記載。100倍化は人工感度実験であり、実データの証拠を増やしていない。どの層・比較を追加確認するか具体的に述べる。

## Pass 2.5：数値と解釈の確認

`quality_check.md` に計算状態、独立参照の実施有無、校正、数値主張、保留・限界の説明を記録する。`narrative_claims.json` に結果ファイルのSHA-256、`status: "REVIEWED"`、数値主張の `pointer` と `value` を配列 `claims` として保存する。pointerはJSON Pointer（配列は0始まり）。例: `/models/M8/deviance`。参照数値を説明文から切り離さず、本文にも対象と参照箇所を記載する。

この自動照合は登録した数値の一致だけを確認する。考察全文の統計的な正しさ・未登録の数値・妥当な因果解釈まで機械的に保証しない。実際に全文を確認してからREVIEWEDとする。

## Pass 3：HTMLと図表を確認する

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/render_report.R output/my_analysis/run_my_run
```

必要なPass 2/2.5成果がない場合、数値・結果ハッシュが違う場合は生成を停止する。`dashboard.html`にはモデル比較、3番目の変数で層別したヒートマップ、全セル表、条件付き割合と区間、条件群間差、事前感度、考察と限界を表示する。列名・水準・日本語・色尺度・保留が読めることを確認する。レポート内に旧Scoreの自動判定を戻さない。
