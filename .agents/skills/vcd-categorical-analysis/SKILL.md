---
name: vcd-categorical-analysis
description: "Use when performing nominal two-way or three-way categorical analysis through the profile, render, expert narrative, quality-check, and dashboard workflow."
license: MIT
metadata:
  author: vcd-categorical-analysis-skill
  version: "3.1"
---

名義カテゴリカル変数の **2-wayを主対象**とする独立性検定（Poisson GLM）および残差の可視化を行う。既存3-way出力は互換保守の範囲に限り、現行の新規3-way推論は `vcd-bayesian-evidence-analysis`へ誘導する。**エージェント3ステップ**で集計・AI考察・レポート生成までを一貫して行う。Step 1 の R エンジンは **2パス**（`--profile` → `render_config.json` → `--render`）。

## 共通品質契約

本スキルは `.agents/shared/analysis_quality_contract.md` を参照する。Step 1では入力品質と出力生成、Step 2ではAIレビュー標準構成、Step 2.5では品質確認、Step 3ではHTMLと図表の読み取り確認を契約に沿って満たす。

## スコープ

| 項目 | 内容 |
| :--- | :--- |
| **次元** | **2-wayを主対象**。既存3-wayは互換保守のみ。4-way以上は対象外（分割・集約を提案）。 |
| **出力先** | `./skill_out/vcd_categorical/run_<first16>[_N]/`（一般形: `<out>/run_<first16>[_N]/`） |
| **正本** | `.agents/skills/vcd-categorical-analysis/` です。旧ミラーは廃止済みのため参照しません。 |

## 責務境界

本スキルは名義カテゴリの2次元分析を主担当とし、プロファイル、残差、全体のCramér's V、既存の2パス・ダッシュボードを提供する。3次元の新規探索で9階層対数線形モデル、基準モデル別セル診断、明示事前の条件付き割合を計算する場合は、[vcd-bayesian-evidence-analysis](../vcd-bayesian-evidence-analysis/SKILL.md)へ移る。両スキルの結果JSONを相互に読み替えない。

3次元入力を受けた場合は、目的、分母、標本単位、欠測・ゼロ、独立性を `vcd-pass0-consultation` で確認したうえで、現行の統計的正本である `three-way-results-v1` 経路へ誘導する。旧レポートの互換保守は `vcd-categorical-reporting` の範囲であり、新規の3次元推論をこのスキルへ複製しない。

## 必須ワークフロー（実行フェーズ）

ユーザーが **「実行して」** 等で実行フェーズに入った後、**以下3ステップを連続実行**する。Step 1 完了前にチャットで要約して終了しない。

1. **Step 1（Data）**: R **2パス**を完遂し、`summary_*.json`・`categorical_results.json`・残差 CSV/HTML/PNG 等が生成されたことを確認する。
2. **Step 2（AI Review）**: JSON を読み、日本語考察を **`executive_summary.md`** として保存する（チャットへの長文出力のみで代替しない）。詳細が必要な場合は `vcd_analysis_report.md` も可。
3. **Step 2.5（Quality Check）**: 必要に応じて **`quality_check.md`** を保存し、P値偏重、残差方向、スパースセル、集約による情報損失、図表と本文の矛盾を確認する。
4. **Step 3（Report）**: **既定は `dashboard.Rmd`**。`report.Rmd` はレガシー代替。HTML 生成と読み取り確認を行ってから完了報告する。

## Step 1: R Engine（2パス）

**IRON LAW**: Pass 2（`--render`）の前に、必ず Pass 1 の `data_profile.json` を確認し、過大セル数・過剰水準に対する `render_config.json` を決める。

### Pass 1: プロファイリング

```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --profile \
  --data your_data.csv \
  --vars "var1,var2" \
  --freq "Freq" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260417
```

- **`--run-id`（任意）**: 成果物を `<out>/run_<first16>[_N]/` に隔離。同じ明示ID・入力内容・vars順序・freqの `--profile` → `--render` は、`run_meta.json` の `requested_run_id` と `analysis_signature` が完全一致し、`run_state` が `profile_complete` のrunだけを継続する。同じmodeの再実行、identity不一致、完了・中断・不明stateのrunとの衝突では `_2` 以降のsuffixを付ける。省略または `auto` ではJSTタイムスタンプIDを使う。
- **run state machine**: 新規run確保時は `allocated`、profile完了時は `profile_complete`、render開始前は `render_in_progress`、全成果物の生成成功後だけ `render_complete` とする。旧meta、state欠落、不明state、途中renderは再開しない。
- **atomic reservation**: out rootを先に作成し、候補run directoryは再帰なしのdirectory作成が成功した時だけ確保済みとする。profile runの再開時も隠しclaim directoryを原子的に取得し、identity・state・profile-only条件の再検証後に `render_in_progress` へ遷移する。同時実行、claim失敗・残置、再検証失敗、既存directoryとの衝突はsuffix付きの別runへ分離する。
- **`--data` 省略時**: 省略時だけ内蔵 `HairEyeColor` を使用する。存在しない `--data` を明示した場合は、signature計算やrun directory作成より前にエラー停止する。
- **`--freq` 列が無い場合**: 自動集計し `Freq` として扱う。

### Pass 2: 本生成

`data_profile.json` を読んだうえで `render_config.json` を用意し、本生成を実行する。

```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --render \
  --config render_config.json \
  --data your_data.csv \
  --vars "var1,var2" \
  --freq "Freq" \
  --label "mydata" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260417
```

### Step 1 確認ゲート

- 別データを連続解析する場合は **`--run-id`** で識別しやすいrun名を指定する。省略時もJST日時でrunを分離する。
- Pass 1とPass 2には同じ明示 `--run-id`、同じ入力内容、同じ順序の `--vars`、同じ `--freq` を渡す。Pass 2は `requested_run_id` と `analysis_signature` が一致し、`run_state` が `profile_complete` で、`data_profile.json` があり `categorical_results.json` がないrunだけを継続する。旧meta、identity fieldやstateがないrun、`render_in_progress`、`render_complete`、不明stateは再開しない。
- `--out` が既存でも完了runや同じmodeの成果物は上書きせず、衝突時はsuffixで分離する。
- `render_config.json` で `collapse_below_n` 等を使う場合、情報損失の許容可否を確認する。
- `data_profile.json` で過剰水準、スパースセル、4-way以上相当の複雑性が見える場合は、集約、除外、層別、解釈保留のいずれかを提案する。

## Step 2: AI 考察

主に `summary_{label}.json` および `categorical_results.json` を読み、`executive_summary.md` を生成する。

**構成（最低限）**:
- 節1: 結論ファースト（何が分かったか、実務上何を保留するか）
- 節2: Cramér's V と Cohen 基準による全体関連
- 節3: `abs_pearson_res` ≥ 1.96 のセル（観測度数が期待度数より多い/少ない方向）
- 節4: 限界、解釈保留、次アクション

**禁止**: 英語本文（変数名・数式除く）、P値のみでの結論、残差方向を確認しない「多い/少ない」表現、セル数や集約による情報損失を無視した断定。

判断ファースト3章の詳細は `vcd-categorical-reporting/references/report-template.md`（非推奨スキル・参照テンプレ）を参照可。

## Step 2.5: 品質確認

Step 2 の後、必要に応じて `quality_check.md` を同じ出力ディレクトリに保存する。

**確認項目**:
- AIレビューが結論、根拠、限界、解釈保留、次アクションを含む。
- P値だけで結論していない。
- 残差方向、効果量、セル数、スパースセル、集約による情報損失を区別している。
- 図表、残差表、`categorical_results.json` と本文が矛盾していない。
- 重大な未解決事項がある場合は完了扱いにせず、ブロッカーまたは解釈保留として報告する。

## Step 3: レポート

### 既定: dashboard.Rmd

```bash
Rscript -e "rmarkdown::render(
  '.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd',
  output_file = 'dashboard.html',
  output_dir = './skill_out/vcd_categorical/',
  params = list(output_dir = './skill_out/vcd_categorical/'),
  knit_root_dir = getwd()
)"
```

`params$output_dir` には `<out>`（out_root）または完了済みの `run_output_dir` を指定できる。上記の標準例のようにout_rootを渡すと、`run_<JST日時|slug>[_N]/` のうち `categorical_results.json` を持つ最新の完了runを解決する。特定runへ固定したい場合は、そのrun directoryを明示する。

`executive_summary.md` が無いとダッシュボードに警告が出る。Step 2 を省略しない。
`quality_check.md` がある場合は、未解決事項が残っていないか確認してから完了報告する。

### 代替: report.Rmd（レガシー）

```bash
Rscript -e "rmarkdown::render(
  '.agents/skills/vcd-categorical-analysis/templates/report.Rmd',
  output_file = 'report.html',
  output_dir = './skill_out/vcd_categorical/',
  params = list(output_dir = './skill_out/vcd_categorical/'),
  knit_root_dir = getwd()
)"
```

## 生成ファイル

| 出力 | Step / Pass | 説明 |
| :--- | :--- | :--- |
| `data_profile.json` | Pass 1 | 次元・水準・セル数プロファイル |
| `data_profile_post.json` | Pass 2 | 集約後プロファイル |
| `summary_{label}.json` | Pass 2 | モデル比較・残差統計サマリー |
| `residuals_{label}.csv` 等 | Pass 2 | 残差・gt/DT HTML・PNG |
| `categorical_results.json` | Pass 2 | ダッシュボード連携用 JSON |
| `executive_summary.md` | Step 2 | AI 日本語サマリー |
| `quality_check.md` | Step 2.5 | AIレビュー・図表・解釈保留の品質確認 |
| `dashboard.html` | Step 3（既定） | 統合ダッシュボード |

## リソース

| パス | 役割 |
| :--- | :--- |
| `templates/analysis.R` | 2パス集計パイプライン |
| `templates/dashboard.Rmd` | **既定** HTML ダッシュボード |
| `templates/report.Rmd` | 代替 Rmd |
| `references/interface.md` | JSON/CSV 契約 |
| `references/workflow.md` | 3ステップ + 2パス図 |
| `references/ai-narrative-workflow.md` | AI による考察文生成、残差・効果量・層別差の説明順序、過剰主張を避ける表現ルール |
| `.agents/shared/analysis_quality_contract.md` | 共通分析品質契約、Pass 2.5、完了条件 |
| `tests/verify_skill.sh` | 検証スクリプト |

## 関連スキル

- `vcd-pass0-consultation` … 分析前のデータ検分・次元選定
- `vcd-bayesian-evidence-analysis` … 大標本時の効果量・BIC/BF 視点
- `vcd-categorical-reporting` … **非推奨**（本スキル Step 2 に統合。参照テンプレのみ）
- `mysql-table-cardinality` … DB 探索が先の場合
