# 依存パッケージ (vcd-categorical-analysis)

本スキルを実行するためには以下の R パッケージが必要です。
実行時の自動インストール（`pacman::p_load` 等）は行われません。事前にインストールされていることが前提となります。不足時は `check_r_dependencies()` によりエラー案内とともに即座に停止します。

## 依存パッケージ一覧

### 1. Pass 1 プロファイル生成（`analysis.R --profile`）

Pass 1 プロファイル作成は、UI・描画パッケージ（gt、DT 等）が未導入の環境でも完結して動作します。

| パッケージ | 用途 |
| :--- | :--- |
| `jsonlite` | JSON 入出力（`data_profile.json` 等） |
| `digest` | Run 隔離・ハッシュ計算（`run_scope.R` 経由） |

### 2. Pass 2 レンダリング・ダッシュボード生成（`analysis.R --render` / `dashboard.Rmd`）

| パッケージ | 用途 |
| :--- | :--- |
| `vcd` | カテゴリカルデータの可視化（Mosaic, Association プロット）、Cramer's V |
| `gt` | 残差マトリックス表の作成（HTML） |
| `DT` | ソート可能インタラクティブ残差テーブル（`DT::datatable`） |
| `htmlwidgets` | DT の self-contained HTML 出力（`htmlwidgets::saveWidget`） |
| `ggplot2` | 補助的なプロット作成 |
| `rmarkdown` | ダッシュボードおよびレポートのレンダリング（Pandoc 必須） |
| `knitr` | コードチャンク実行 |
| `htmltools` | HTML タグ生成 |
| `kableExtra` | （オプショナル）`report.Rmd` で `residual_table_pkg: "kableExtra"` 指定時に使用 |

## インストール方法

R コンソールで以下を実行して事前導入してください：

```r
# 本スキル向け一括インストール
install.packages(c(
  "jsonlite", "digest", "vcd", "gt", "DT", "htmlwidgets",
  "ggplot2", "rmarkdown", "knitr", "htmltools"
), repos = "https://cloud.r-project.org")
```

全体の一括導入についてはリポジトリルートの [README.md](../../../README.md) を参照してください。
