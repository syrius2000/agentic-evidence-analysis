# 依存パッケージ (vcd-bayesian-evidence-analysis)

本スキルを実行するためには以下の R パッケージが必要です。
実行時の自動インストール（`pacman::p_load` 等）は行われません。事前にインストールされていることが前提となります。不足時は `check_r_dependencies()` によりエラー案内とともに即座に停止します。

## 依存パッケージ一覧

### 1. Pass 1 統計計算（`analysis.R`）
Pass 1 計算は、HTML レポート描画パッケージ（DT、htmlwidgets 等）が未導入の環境でも完結して動作します。

| パッケージ | 用途 |
| :--- | :--- |
| `dplyr` | データ前処理（集約・整形） |
| `tidyr` | データ整形 |
| `jsonlite` | JSON 入出力（`analysis_config.json`, `evidence_results.json` 等） |
| `digest` | Run 隔離・ハッシュ計算（`run_scope.R` 経由） |
| `effectsize` | Cramér's V / Fei（効果量）の算出と信頼区間 |

### 2. Pass 3 レポート・ダッシュボード描画（`render_dashboard.R` / `dashboard.Rmd`）

| パッケージ | 用途 |
| :--- | :--- |
| `rmarkdown` | R Markdown の HTML レンダリング（Pandoc 必須） |
| `knitr` | ドキュメントチャンク実行 |
| `DT` | 残差・エビデンス表のインタラクティブ表示 |
| `htmltools` | HTML タグ・コンポーネント生成 |
| `htmlwidgets` | DT の self-contained ウィジェット出力 |
| `digest` | Run 隔離・ハッシュ計算（`render_dashboard.R` / `run_scope.R` 経由） |
| `katex` | 数式描画 |
| `ggplot2` | 補助可視化 |

## インストール方法

R コンソールで以下を実行して事前導入してください：

```r
# 本スキル向け一括インストール
install.packages(c(
  "dplyr", "tidyr", "jsonlite", "digest", "effectsize",
  "rmarkdown", "knitr", "DT", "htmltools", "htmlwidgets",
  "katex", "ggplot2"
), repos = "https://cloud.r-project.org")
```

全体の一括導入についてはリポジトリルートの [README.md](../../../README.md) を参照してください。
