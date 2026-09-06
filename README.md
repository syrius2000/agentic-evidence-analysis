# agentic-evidence-analysis

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![R >= 4.0](https://img.shields.io/badge/R-%3E%3D%204.0-276DC3?logo=r)](https://www.r-project.org/)

**AIエージェントおよびRユーザーのための、エビデンス駆動型カテゴリカルデータ分析スキルセット**  
*Evidence-Driven Categorical Data Analysis Skills for AI Agents & R Users.*

大標本データ（RWD、臨床・疫学データ、アンケート等）で、構造、効果の大きさ、証拠量、不確実性を分けて読む分析パイプラインを提供します。P値、BIC近似、明示事前によるBF、セル診断を同じ意味の指標として扱いません。

---

## 背景：なぜエビデンス駆動なのか？

サンプルサイズが大きい場合、微小な偏りでもP値が小さくなることがあります。ただし、普遍的なNの境界で自動判定せず、効果量、分母、意思決定上の許容差、モデルの前提を併記します。

2016年のアメリカ統計学会（ASA）「P値に関する声明」に基づき、本ツールキットは以下の原則を実装しています：

1. **P値は仮説とデータの矛盾度を示すにすぎない**: 効果の大きさや研究の重要性を証明しない。
2. **$p < 0.05$ の二択評価を廃止する**: 思考停止の有意・非有意判定を行わない。
3. **効果量・信頼区間・モデル尤度を併用する**: 「差の大きさ」と「証拠の強さ」を峻別する。

---

## 4-Pass 分析パイプライン

本ツールキットは、AIエージェントと統計スクリプトが協調する 4 ステップ（Pass）で分析を実行します。

```mermaid
graph TD
  Data[Raw Data CSV] --> P0["<b>Pass 0: Interactive Consultation</b><br/>AIがデータを検分し分析設計を提案"]
  P0 --> CFG[analysis_config.json]
  CFG --> P1["<b>Pass 1: R Engine</b><br/>統計計算と異常検知の実行"]
  P1 --> JSON[Analysis Results JSON]
  JSON --> P2["<b>Pass 2: AI Review</b><br/>専門家による日本語考察の執筆"]
  P2 --> MD[executive_summary.md]
  JSON & MD --> P3["<b>Pass 3: Report Integration</b><br/>インタラクティブなHTMLダッシュボード生成"]
  P3 --> HTML[dashboard.html]

  style P0 fill:#fff3e0,stroke:#e65100
  style CFG fill:#fff3e0,stroke:#e65100,stroke-dasharray: 5 5
  style P1 fill:#e1f5fe,stroke:#01579b
  style P2 fill:#f3e5f5,stroke:#4a148c
  style P3 fill:#e8f5e9,stroke:#1b5e20
  style HTML font-weight:bold,fill:#fff9c4
```

1. **Pass 0 (Interactive Consultation)**: AIがデータの水準数や度数を事前に検分し、次元削減（変数の絞り込み）や層別解析をユーザーに提案。Pass 1 の入力を固定する **`analysis_config.json`** を作成します。
2. **Pass 1 (R Engine Computation)**: Rスクリプトがベイズ因子、エビデンススコア、標準化残差を計算。`--config` 引数で Pass 0 の設定を読み込み、中間成果物（JSON）を出力します。
3. **Pass 2 (AI Review & Narrative)**: AIが専門コンサルタントとして中間成果物を読み解き、背景知識を交えた日本語のエグゼクティブ・サマリー (`executive_summary.md`) を執筆します。必要に応じて `quality_check.md` で解釈保留や図表整合を確認します。
4. **Pass 3 (Report Integration)**: RMarkdownが統計数値とAI考察を統合し、インタラクティブ・ダッシュボード (`dashboard.html`) を生成します。

---

## スキル一覧 (AI Agent Skills)

本リポジトリで提供されるスキル一覧です（`.agents/skills/` に配置）：

| スキル名 | 種別 | 主な役割 |
|---|---|---|
| **vcd-pass0-consultation** | 事前相談 | データ検分、次元削減、層別解析の提案。分析の「次の一手」をガイド。 |
| **vcd-bayesian-evidence-analysis** | 主力解析 | 3次元の階層対数線形モデル、局所セル診断、明示事前のベイズ推定、日本語レポート。旧2次元経路も保守。 |
| **vcd-categorical-analysis** | 名義解析 | 名義カテゴリ分析。R 2パス・executive_summary・quality_check・ダッシュボード生成。 |
| **questionnaire-batch-analysis** | バッチ処理 | アンケート集計。複数設問の設定に基づき、ダッシュボードを自動量産。 |
| **vcd-categorical-reporting** | 参照用 | （レガシー参照用テンプレート。新規は `vcd-categorical-analysis` を推奨） |

---

## 指標の読み分け

現行の3次元経路では、一律の閾値による合否判定を行いません。

| 問い | 主な指標 | 読み方 |
|---|---|---|
| 全体の構造は何か | 9階層モデル、逸脱度、固定Nの多項BIC | どの交互作用を許したモデルが問いに合うか |
| セルはどれだけずれるか | `log(O/E)`、`d/√N`、`ΔG²/N` | 基準モデル、分母、方向を付けて読む |
| 追加セル効果の証拠はあるか | 局所`ΔG²`、leverage補正score、近似P値 | 正則な近似条件を満たす場合だけ補助的に使う |
| 確率や割合はどれだけ不確かか | Dirichlet事後、条件付き割合、信用区間、事前感度 | 点ごとの区間であり、多重性調整済みではない |

旧 `r² − k log N` は監査用です。セルBF、実質的重要性、真の信号の自動判定には用いません。Cramér's VとFeiは補助的な背景知識であり、現行3次元経路の合否指標ではありません。数式と参考文献は [docs/reference/](docs/reference/) にまとめています。

---

## クイックスタート

### 動作環境要件
- **R**: >= 4.0。3次元経路は標準の`stats`に加え、既存の`jsonlite`、検分用の`dplyr`・`readr`、HTML用の`htmltools`・`commonmark`を使用。
- **Pandoc**: HTMLダッシュボード生成に必要

### 1. AIエージェントで使う（推奨）
Agent Skills 対応のCLIやエディタ（Antigravity, Cursor, Gemini CLI等）からスキルをインストールします：

```bash
npx skills add syrius2000/agentic-evidence-analysis
```

導入後、エージェントに対話形式で依頼します：

> 「`data.csv` を分析したい。まずは `vcd-pass0-consultation` スキルでデータの性質を調べて、分析の軸を提案して。」

### 2. Rスクリプトとして手動実行する

```bash
# Pass 0: データの検分
Rscript .agents/shared/inspect_data.R examples/titanic.csv \
  --out-dir output/<project>/run_<id>/

# Pass 1: 3次元統計計算（Pass 0で作成した設定を指定）
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R \
  --config output/titanic/run_v1/analysis_config.json
```

`--out-dir=`、`--out-dir ""`、空の第2位置引数など、空のout-dirは拒否され、ファイルシステムのrootへは書き込みません。

**出力ディレクトリ規則**:
- `vcd-bayesian-evidence-analysis`: `--output_dir` 直下に `run_<run_idの先頭16文字>/` を作成。
- `vcd-categorical-analysis`: 常に `<out>/run_<first16>[_N]/` へ出力（run ID未指定時はJST日時、衝突時はサフィックス付与）。
- `questionnaire-batch-analysis`: `--run-id` 利用時に `runs/<id>/` 配下へ出力。

---

## リポジトリ管理方針 & アーキテクチャ

- **統計分析の正本リポジトリ**: この `agentic-evidence-analysis` リポジトリを、同名5スキル、統計schema、統計品質契約、Rテンプレート、統計回帰テストの唯一の正本とします。
- **他リポジトリとの責務分離**:
  - `Productivity-Skill`: 一般コード・SQLコード理解を担当します。
  - `rwd-mysql-skill-toolkit`: RWD/DB実行・統合ハブを担当します。
  - DB/SQL/Python実行補助をこのリポジトリへ複製せず、統計仕様・実装の変更はこの正本へ反映します。
- **スキルツリー**: `.agents/skills` を公式管理対象とし、旧 `.cursor/skills` は管理しません。

---

## おすすめの読み方

1. `vcd-pass0-consultation` でデータの水準数、欠損、セルの疎密、層別の必要性を確認する。
2. [docs/reference/stats_categorical.md](docs/reference/stats_categorical.md) で期待度数、残差、2元表効果量、P値を確認する。
3. 3変数なら [docs/reference/three_way_models.md](docs/reference/three_way_models.md) で9モデル、固定Nの多項BIC、セル診断を確認する。
4. [docs/reference/stats_bayesian.md](docs/reference/stats_bayesian.md) でBIC近似、厳密BF、Dirichlet事後、条件付き割合を確認する。
5. 統計的有意性、効果の大きさ、不確実性、実務判断を分けた日本語サマリーを作成する。

---

## ライセンス

[MIT](LICENSE)


## 3次元探索支援（2026-09-06）

集計済みの3元表には、[vcd-bayesian-evidence-analysisの新経路](.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md)を追加した。9つの階層対数線形モデル、基準モデル別のセル診断、明示した事前分布による条件付き割合・層間差、日本語考察、層別ヒートマップ付きHTMLを扱う。

[統計契約と再現手順](.agents/skills/vcd-bayesian-evidence-analysis/references/three_way_contract.md)を確認し、Pass 0から開始する。旧Scoreの正負は真の関連・ノイズの判定に使わない。ベイズでも標本サイズへの感度は残る。FREQ・MEANS互換、階層モデル・再標本化安定性は後続予定。
