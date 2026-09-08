---
name: vcd-pass0-consultation
description: Use when starting a new categorical data analysis to inspect data, select dimensions, and define the analysis scope before statistical computation.
---

# VCD Pass 0: Interactive Consultation

大標本カテゴリカルデータ分析（`vcd-bayesian-evidence-analysis`）の最初の一手として、データの統計的性質を検分し、分析の軸（次元）や層別の要否を決定するための対話型スキル。

## 共通品質契約

本スキルは `.agents/shared/analysis_quality_contract.md` を参照する。Pass 0では、統計計算前の入力品質、分析スコープ、変数選択、集約・除外・層別の判断を契約に沿って確認し、`data_analysis_scope.md` と `analysis_config.json` に反映する。

## 共通 4-Pass 正式対応表

| 共通 4-Pass | Pass 0 の役割と各スキルの対応 |
| :--- | :--- |
| **Pass 0** (Consultation) | `inspect_data.R` によるデータ検分、対話型次元選定、`analysis_config.json` 単一正本策定（**正式 run は作成しない**）。Categorical では必要に応じて `analysis.R --profile` を実行 |
| **Pass 1** (Statistical Compute) | 各スキルの計算エンジン（Bayesian: `analysis.R`, Categorical: `analysis.R --render`, Questionnaire: `batch_runner.R`）が正式 run を原子的に予約・隔離作成し、`results_manifest.json` と `run_handover.json` を出力 |
| **Pass 2** (Expert Narrative) | AI 専門家による考察執筆。staging 領域から `finalize_run_stage.R` による本番確定 |
| **Pass 3** (Dashboard / Report) | 各スキルの `render_dashboard.R --run-dir <path>` による単一ファイル完結型ダッシュボード生成と `run_state = "sealed"` 封印 |

## Pass 0 ワークフロー（正式 run 非作成の原則）

**重要原則**: Pass 0 は分析の設計図を策定するフェーズであり、**成果物用の正式 run ディレクトリ（`run_<id>` 等）は作成しません**。検分結果は作業用ディレクトリに出力し、確定した設定を `analysis_config.json` として出力します。正式 run ディレクトリは、後続の Pass 1 が唯一の作成主体として原子的に予約・確保します。

### 1. データ物理検分 (Inspection)

以下のスクリプトを実行して、データの客観的な統計情報を取得します。

```bash
Rscript .agents/shared/inspect_data.R <path_to_your_data.csv> \
  --out-dir output/<project>/run_<id>/
```

`<project>` と `<id>` は実際の識別子へ置き換えます。空のout-dir（`--out-dir=""` 等）は拒否されます。
※ Pass 0 の検分出力先はコンサルテーション作業領域であり、分析成果物の本番正式 run ディレクトリは後続の Pass 1 が唯一の主体として原子予約・作成します。

実行後、生成された `inspection_results.json` を読み取り、以下の点を確認します：
- 各変数の水準数（多すぎないか？）
- 度数の分布（極端に少ないセルはないか？）
- 欠損値の有無
- 度数列（`Freq` 等）の有無
- 過剰次元、スパースセル、集約による情報損失の可能性

### 2. インタラクティブ提案 (Consultation)

検分した統計量に基づき、ユーザーに対して以下の2点を主軸に提案を行います。

#### A. 次元削減の提案
- 変数が多い（4次元以上）場合、交互作用が複雑になりすぎて解釈が困難になります。
- 目的変数に対して寄与が低いと思われる変数や、水準数が多すぎる変数の除外・集約を提案します。

#### B. 層別解析の提案
- 特定の属性（例：性別、地域）によって構造が全く異なると予想される場合、全体分析ではなく層別（分割）して分析することを提案します。

### 3. 設計図と構成の出力 (Artifacts)

ユーザーの合意が得られたら、以下の2つのファイルを生成します。保存先はプロジェクトの作業領域（例: `output/<project_name>/`）です。

1. **`data_analysis_scope.md`**:
   - 分析の背景、選択した変数の根拠、除外した変数の理由を記録した人間用ドキュメント。
   - 集約、除外、層別、解釈保留が必要な場合は、その理由と影響を記録する。
2. **`analysis_config.json`**:
   - Pass 1 に渡すための単一正本設定ファイル。
   - `vcd-bayesian-evidence-analysis/references/analysis_config.schema.json` に準拠:
     - `input`: 入力CSVのパス（外部元データは Pass 1 でコピーせず `hash_only` で安全に参照）
     - `vars`: 分析対象の変数リスト (`["var1", "var2"]`)
     - `freq`: 度数列の名前 (例: `"Freq"`)
     - `response_var`: 応答変数（任意）
     - `output_dir`: 出力の親ディレクトリ（out_root）
     - `run_id`: 実行識別子（任意）

### 4. 後続 Pass 1 実行へのハンドオーバー

成果物生成後、ユーザーに対して次に実行すべき Pass 1 コマンドを案内します。

#### A. Bayesian Evidence Analysis の場合
```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --config output/<project>/analysis_config.json
```

#### B. Categorical Analysis の場合
```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --render \
  --config output/<project>/analysis_config.json \
  --out ./skill_out/vcd_categorical/
```

#### C. Questionnaire Batch Analysis の場合
```bash
Rscript .agents/skills/questionnaire-batch-analysis/templates/batch_runner.R \
  --config output/<project>/analysis_config.json \
  --question-config question_config.csv \
  --out ./skill_out/questionnaire/
```

### パス・リンク表現基準と AI 報告要件
- リポジトリ内ファイルは必ず相対パス（`[analysis_config.json](output/analysis_config.json)`）で記述する。
- Pass 0 完了報告では、(1) 検分結果の要約、(2) 策定した `data_analysis_scope.md` と `analysis_config.json` への相対リンク、(3) 次に実行すべき Pass 1 コマンドを提示する。

## 確定・回復時の共通契約

- 本番確定とpreview公開は、共通 `run.lock` の下で状態を再読して実行する。既に封印されたrunや完了済み工程は再確定しない。
- Pass 2はmanifestの期待ハッシュを引き継ぐ。Pass 3は確定済み考察の記録ハッシュと由来manifestを描画前後に照合する。改定は新runで実施する。
- promotion中断時は、元の `--source-artifact` と期待ハッシュで確定CLIを再実行する。sourceが消失していても、run外の `transaction_<stage>.json` と公開先が一致するときに回復する。ロックが残った場合のみ `--recover-stale-lock` を明示する。証跡を削除・捏造しない。
- legacy previewは `--allow-legacy-run-meta --preview --preview-output-dir <元run外の出力先>` を指定する。元runは読み取り専用とし、同名previewは上書きしない。
- Questionnaireのpartial/failedは非ゼロ終了し、停止理由付きhandoverの本番next_actionsは空となる。診断成果物を確認して新しいrunへ進む。
- `run_handover.json` の `cwd` へ移動し、提示された `argv` を実行する。存在しないstubコマンドを推測して追加しない。
