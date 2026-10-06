# agentic-evidence-analysis

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![R >= 4.0](https://img.shields.io/badge/R-%3E%3D%204.0-276DC3?logo=r)](https://www.r-project.org/)

**AIエージェントおよび統計エンジニアのための、エビデンス駆動型カテゴリカルデータ分析スキルセット**
*Evidence-Driven Categorical Data Analysis Skills for AI Agents & Statistical Engineers.*

リアルワールドデータ（RWD）、臨床・疫学調査、アンケート集計などの大規模カテゴリカルデータにおいて、「統計的有意性と実用的有意性の乖離（P値の呪い）」を克服し、**全体構造、効果量、証拠強度、数値安定性、統計的不確実性** を明確に切り分ける高信頼な分析パイプラインを提供します。

---

## 背景：なぜエビデンス駆動なのか？

サンプルサイズ $N$ が大規模（数万〜数十万件）になると、実務的に無意味な微小な偏りであっても検定統計量は巨大化し、$p < 0.0001$ のように P 値は容易に極小化（飽和）します。

2016年のアメリカ統計学会（ASA）「P値に関する声明」に基づき、本ツールキットは以下の原則を徹底しています：

1. **P 値は仮説とデータの矛盾度を示す指標に過ぎない**: 効果の大きさや研究・実務上の重要性を直接証明しない。
2. **$p < 0.05$ の二択判定（有意・非有意）を廃止する**: 思考停止の機械的足切りを行わない。
3. **「効果の大きさ（Effect）」と「証拠の強さ（Evidence）」を峻別する**: 標本サイズ $N$ に依存しない効果量と、標本サイズに比例する統計的確信度を分離する。

---

## 分析の進み方

Pass 0（事前相談）の適用はスキルごとに異なります。`vcd-bayesian-evidence-analysis` と `vcd-categorical-analysis` の新規分析、および `comparative-design-analysis` で非独立デザインを扱う場合は必須です。複数テーマ・複数設問の一括分析では、設計を揃えるためPass 0を推奨します。SAS互換の集計や保守作業では要求しません。条件の詳細は [`vcd-pass0-consultation`](.agents/skills/vcd-pass0-consultation/SKILL.md) を参照してください。

```mermaid
flowchart LR
  A[入力と目的の確認] --> B{Pass 0の対象か}
  B -->|必須・推奨| C[入力検分と分析設計]
  B -->|対象外| D[スキル固有の設定・実行]
  C --> E[スキル固有の計算]
  D --> E
  E --> F[結果の確認・解釈]
  F --> G[必要に応じてレポート生成]
```

3次元集計表の `vcd-bayesian-evidence-analysis` では、Pass 0の相談、R計算、AIによる結果レビュー、HTMLレポート生成という4段階を代表的な流れとして使います。他スキルは固有の手順・成果物を持つため、各スキルの説明に従ってください。

統計手法の概要は、全体構造、効果、証拠、不確実性、数値安定性を区別して扱うことです。数式、モデル、推論条件と限界は [統計リファレンスポータル](docs/reference/README.md) を参照してください。P値だけで実務的重要性を決めたり、探索結果を自動的な規制判断に使ったりしません。

---

## 提供スキル一覧 (Agent Skills)

本リポジトリで提供されるスキル一覧です（`.agents/skills/` 配下）：

| スキル名 | 種別 | 主な役割と守備範囲 |
| :--- | :--- | :--- |
| **vcd-pass0-consultation** | 事前相談 | データ検分、次元削減・層別解析の提案、観察デザインの検証・ルーティング（`analysis_config.json` / `routing_decision.json` 作成） |
| **vcd-bayesian-evidence-analysis** | 3次元正本 | 3次元集計表の 9 階層対数線形モデル、新 4 軸セル診断、明示式 BIC、Dirichlet 事後推論、HTML レポート生成 |
| **vcd-categorical-analysis** | 2次元正本 | 名義 2 変数の全体効果量（Cramér's V、Bergsma 補正）、調整標準化残差ヒートマップ、新 4 軸セル診断、多項 Jeffreys 事前推論、条件付き事後分布、11 セクション完全オフライン Scientific Dashboard 生成。3次元以上は `vcd-bayesian-evidence-analysis` へ委譲 |
| **vcd-categorical-reporting** | 比較報告 | 独立 2 群（または対照群 vs 各群）の比較エビデンス（RD/RR/E100/reciprocal・方向支持/実務領域/U-Grade）、12 列提示階層、ゼロセル確定挙動、完全自己完結型 HTML/Markdown、安全性（SOC/PT 重複排除）および処方スクリーニング。数理正本: [`docs/reference/comparative_evidence_math.md`](docs/reference/comparative_evidence_math.md) |
| **comparative-design-analysis** | デザイン推論 | マッチドペア（Dirichlet 厳密期待値）、マッチドセット（固定条件付きクラスタブートストラップ）、IPTW（PS 再適合患者ブートストラップ）、人年発症率（共役 Gamma-Poisson 率推論）。数理正本: [`docs/reference/design_aware_inference_math.md`](docs/reference/design_aware_inference_math.md) |
| **evidence-decision-review** | 決定監査 | 決定ラベル非含有特徴量、Gower・HAC、先例検索（QA Review Candidate、自動決定排除）。数理解説は P1 計画中（[ギャップ監査](docs/reference/math_coverage_gap_inventory_001_0927.md)） |
| **questionnaire-batch-analysis** | バッチ処理 | アンケート複数設問の設定ファイルに基づく自動一括集計とサマリー量産 |
| **sas-proc-freq** | SAS 互換集計 | PROC FREQ 互換の度数・分割表、独立性検定、2×2効果量、Fisher 正確検定、Monte Carlo 推定 |
| **sas-proc-means** | SAS 互換記述統計 | PROC MEANS 互換の記述統計、CLASS 群化、FREQ/WEIGHT、VARDEF、QNTLDEF 1〜5 |

エージェントへの依頼時は、結論・次の行動・未検証事項が分かるように、[`docs/reference/output_style_adhd.md`](docs/reference/output_style_adhd.md) の出力方針を適用します。この方針は独立したSkillではありません。

### 解析成果物の出力先

解析結果をディスクへ保存するSkillは、安定slugに対応する正規rootと、その配下のrun directoryを使います。slug台帳・境界の規範は [`evidence-run-layout`](openspec/specs/evidence-run-layout/spec.md) です。

| Skill | 正規root |
| :--- | :--- |
| `vcd-bayesian-evidence-analysis` | `evidence_runs/vcd_bayesian/` |
| `vcd-categorical-analysis` | `evidence_runs/vcd_categorical/` |
| `vcd-categorical-reporting` | `evidence_runs/vcd_categorical_reporting/` |
| `comparative-design-analysis` | `evidence_runs/comparative_design/`（推論APIは現在in-memoryで、直接ファイルを保存しません） |
| `evidence-decision-review` | `evidence_runs/evidence_decision_review/` |
| `questionnaire-batch-analysis` | `evidence_runs/questionnaire/` |
| `sas-proc-freq` | `evidence_runs/sas_proc_freq/` |
| `sas-proc-means` | `evidence_runs/sas_proc_means/` |

run成果物は各rootまたは許可されたroot内 `output_dir` の直下ではなく、`run_<canonical_id>[_N]/` 配下へ隔離されます。明示rootも当該Skillの正規root内に限り、namespace外のパス、`..`、symlink逸脱は拒否されます。旧runは移動・上書きしません。

Pass 0の `inspect_data.R` は分析root台帳の対象外です。未指定時は互換のため `.` を使用し、明示する場合は実行ごとに新しい `evidence_runs/inspections/<project>/run_<id>/` を指定します。

---

## クイックスタート

### 動作環境要件

- **R**: >= 4.0
- **Pandoc**: HTML ダッシュボードおよび R Markdown レポートのレンダリングに必要

> [!IMPORTANT]
> **実行時パッケージ自動インストールの廃止**:
> 本リポジトリのスクリプトおよびエージェントスキルは、実行時に `install.packages()` や `pacman::p_load()` によるパッケージ自動インストールを行いません（オフライン環境および決定論的実行の保証）。
> 初回利用時または不足時は、以下の表に従って必要な R パッケージを事前に導入してください。

| カテゴリ | 対象パッケージ | 主な用途・実行経路 |
| :--- | :--- | :--- |
| **コア計算・データ検分**<br>(Pass 0 / Pass 1) | `jsonlite`, `digest`, `dplyr`, `readr`, `tidyr`, `effectsize`, `vcd`, `optparse` | `inspect_data.R`、`run_scope.R`、`vcd-bayesian-evidence-analysis` 計算、`vcd-categorical-analysis --profile`、`questionnaire-batch-analysis` バッチ実行 |
| **レポート・描画**<br>(Pass 2 / Pass 3) | `rmarkdown`, `knitr`, `DT`, `htmltools`, `htmlwidgets`, `ggplot2`, `gt`, `katex` | `render_dashboard.R`、各スキルの HTML ダッシュボードおよび個別レポート生成 |

#### 事前一括インストール用 R コマンド

R コンソールまたは `Rscript -e` で以下を実行してください：

```r
# 全機能向けパッケージの一括導入（全エントリポイントの完全な和集合）
install.packages(c(
  "jsonlite", "digest", "dplyr", "readr", "tidyr", "effectsize", "vcd", "optparse",
  "rmarkdown", "knitr", "DT", "htmltools", "htmlwidgets", "ggplot2", "gt", "katex"
), repos = "https://cloud.r-project.org")
```

### 1. AI エージェントで使う（推奨）

Agent Skills 対応ツール（Antigravity, Cursor, Gemini CLI 等）から本スキルを呼び出します：

```bash
npx skills add syrius2000/agentic-evidence-analysis
```

このリポジトリは、統計スキル・schema・統計品質契約・Rテンプレート・統計回帰テストの正本です。一般コード・SQLコード理解は `Productivity-Skill`、RWD/DB実行・統合ハブは `rwd-mysql-skill-toolkit` が担当します。エージェントが本リポジトリで作業する際の契約は [AGENTS.md](AGENTS.md) を参照してください。

> 「`examples/titanic.csv` を Class × Sex × Survived で分析したい。まずは `vcd-pass0-consultation` スキルでデータの性質を検分して、分析設定を作って。」

### 2. R コマンドラインから実行する

各スキルは成果物をrun単位で分離します。以下はPass 0を経て3次元 `vcd-bayesian-evidence-analysis` を実行する例です。スキル別の出力名や設定形式は各 `SKILL.md` を確認してください。

```bash
# Pass 0: データの事前検分
Rscript .agents/shared/inspect_data.R examples/titanic.csv \
  --out-dir evidence_runs/inspections/<project>/run_<id>/

# Pass 0 の検分後、合意した設定を run ディレクトリ内に保存して計算
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --config evidence_runs/vcd_bayesian/run_01/analysis_config.json

# ダッシュボード生成
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R \
  evidence_runs/vcd_bayesian/run_01/
```

出力先には実行ごとに新しいrunディレクトリを使い、既存成果物を無言で上書きしないでください。

---

## 参考文献・一次情報ポータル

本ツールキットの統計数理手法は、国際的に認知された学術論文および標準教科書（一次情報）に厳密に依拠しています。

- **ポータル（読解順・OpenSpec 17 対応・スキル別リンク）**: [docs/reference/README.md](docs/reference/README.md)
- **カバレッジ監査（不足と記載すべき情報）**: [docs/reference/math_coverage_gap_inventory_001_0927.md](docs/reference/math_coverage_gap_inventory_001_0927.md)

> [!NOTE]
> 3 次元／2 次元探索、比較エビデンス（独立 Jeffreys / U-Grade / 12列提示: [`comparative_evidence_math.md`](docs/reference/comparative_evidence_math.md)）、デザイン考慮推論（マッチドペア / セット / IPTW / 人年発症率: [`design_aware_inference_math.md`](docs/reference/design_aware_inference_math.md)）は**専用数理正本を充足**しています。Gower／HAC 決定監査の数理文書は上記ギャップ監査の P1 計画文書として策定予定です。現行の規範挙動は `openspec/specs/` と [skill_responsibilities.md](docs/reference/skill_responsibilities.md) を参照してください。

代表的一次文献（詳細一覧はポータル §5）:

- **局所スコア検定理論**: Rao, C. R. (1948). *Proc. Camb. Phil. Soc.* [DOI:10.1017/S0305004100024038](https://doi.org/10.1017/S0305004100024038)
- **GLM 診断とレバレッジ**: Pregibon, D. (1981). *Ann. Statist.* [DOI:10.1214/aos/1176345513](https://doi.org/10.1214/aos/1176345513)
- **モデル選択基準 (BIC)**: Schwarz, G. (1978). *Ann. Statist.* [DOI:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)
- **対数線形モデル**: Agresti, A. (2013). *Categorical Data Analysis* (3rd ed.). Wiley.
- **多項 Dirichlet 事後推論**: Good, I. J. (1965). *The Estimation of Probabilities*. MIT Press.
- **ベイズデータ解析**: Gelman, A. et al. (2013). *Bayesian Data Analysis* (3rd ed.). CRC Press.
- **効果量基準**: Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). LEA.
- **P 値声明**: Wasserstein, R. L., & Lazar, N. A. (2016). *Amer. Statist.* [DOI:10.1080/00031305.2016.1154108](https://doi.org/10.1080/00031305.2016.1154108)

---

## ライセンス

[MIT License](LICENSE)
