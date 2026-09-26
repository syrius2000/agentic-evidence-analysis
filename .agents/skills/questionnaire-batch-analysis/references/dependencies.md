# 依存パッケージ (questionnaire-batch-analysis)

本スキルを実行するためには以下の R パッケージが必要です。
実行時の自動インストール（`pacman::p_load` 等）は行われません。事前にインストールされていることが前提となります。不足時は `check_r_dependencies()` によりエラー案内とともに即座に停止します。

## 依存パッケージ一覧

### 1. バッチ集計・計算実行（`batch_runner.R`）

| パッケージ | 用途 |
| :--- | :--- |
| `optparse` | コマンドライン引数の解析 |
| `jsonlite` | 設定および結果の JSON 入出力 |
| `ggplot2` | 設問ごとの残差プロット生成（`residual_plot.png`） |

### 2. ダッシュボード・個別レポート生成（`dashboard.Rmd` / `report.Rmd`）

| パッケージ | 用途 |
| :--- | :--- |
| `rmarkdown` | HTML ダッシュボードおよび個別レポートのレンダリング（Pandoc 必須） |
| `knitr` | R Markdown チャンク実行 |
| `ggplot2` | レポート内プロット描画 |
| `jsonlite` | ダッシュボード内集計データの読み込み |
| `digest` | Run 隔離・パス解決（`dashboard.Rmd` / `run_scope.R` 経由） |

## インストール方法

R コンソールで以下を実行して事前導入してください：

```r
# 本スキル向け一括インストール
install.packages(c(
  "optparse", "jsonlite", "ggplot2", "rmarkdown", "knitr", "digest"
), repos = "https://cloud.r-project.org")
```

全体の一括導入についてはリポジトリルートの [README.md](../../../README.md) を参照してください。
