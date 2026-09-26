# Third-Party Notices & Dependency Specifications

本リポジトリ（`agentic-evidence-analysis`）のダッシュボード生成およびオフライン閲覧で使用される第三者ライブラリのライセンスおよび再生成仕様です。

---

## 1. KaTeX (R package `katex` & bundled CSS)

- **パッケージ名**: `katex` (CRAN v1.5.0) & `katex.min.css` (v0.16.9)
- **使用バージョン**: `katex` 1.5.0 / KaTeX CSS 0.16.9
- **ライセンス**: MIT License (Copyright (c) 2013-2023 Khan Academy and other contributors)
- **用途**: R Markdown レンダリング時（静的ビルド時）における LaTeX 数式の HTML/CSS 変換。ブラウザ閲覧時の外部 CDN（MathJax/jsdelivr 等）へのネットワーク通信を一切排除し、完全オフライン閲覧を保証するために使用。
- **再生成・同梱手順**:
  - Rパッケージ導入:

    ```r
    install.packages("katex", repos = "https://cloud.r-project.org")
    ```

  - 同梱 CSS: `.agents/skills/vcd-bayesian-evidence-analysis/templates/assets/katex.min.css` をテンプレートビルド時にインライン `<style>` 埋め込み。
- **注意**: MacTeX 等の TeX Live ローカル組版環境は HTML 閲覧には不要です。本パッケージおよびインライン CSS により、生成時に数式が完全自己完結型 HTML にインライン変換されます。

---

## 2. DataTables (via R package `DT` / `htmlwidgets`)

- **ライブラリ名**: DataTables / DT
- **ライセンス**: MIT License
- **用途**: 対数線形モデル比較表および局所セル診断表の対話的ソート、検索、ページネーション。
- **オフライン化・ローカライゼーション方針**:
  - `self_contained: true` により、DataTables 本体の JavaScript および CSS は単一 HTML 内にインライン埋め込みされます。
  - 日本語ロケール（検索ボックス、件数表示、ページ送り等）は、外部 CDN の `ja.json` を参照せず、テンプレート内の `language` オプションに直接インライン記述されています。閲覧時の Ajax 外部通信はゼロです。

---

## 3. Bootstrap & Flatly Theme (via R package `rmarkdown`)

- **ライセンス**: MIT License
- **用途**: レポーティング UI のベース CSS フレームワーク。
- **オフライン方針**: R Markdown の HTML 自立出力エンジン（Pandoc）により、すべてのスタイルシートおよびフォント定義が単一 HTML 内に自己完結化されます。
