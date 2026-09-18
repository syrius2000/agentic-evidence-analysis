## Why

現在、2次元カテゴリカル分析（`vcd-categorical-analysis`）と3次元エビデンス分析（`vcd-bayesian-evidence-analysis`）において、NEJM / Nature Medical 調の CSS スタイル定義、DataTables 完全インライン日本語辞書、および 4大数理用語集（4軸セル診断、対数線形モデル、ベイズDirichlet推論、一次文献）が、それぞれの `dashboard.Rmd` 内に個別に重複して記述されています。
この重複は、フォントサイズやデザイン改定の際に二重修正を強いられ、バージョン間の不整合や保守コスト増大を招きます。
本変更では、これらの共通プレゼンテーション資産を `.agents/shared/` に集約・一元化し、DRY（Don't Repeat Yourself）原則を達成します。

## What Changes

- **共通テーマ CSS の新設**: `.agents/shared/dashboard_theme.css` を作成し、NEJM / Nature Medical 調デザイントークン、px 絶対指定タイポグラフィ、フラットカード、DataTables ラッパー、用語集アコーディオンのスタイルを集約。
- **DataTables 日本語辞書の一元化**: `.agents/shared/dashboard_dt_ja.R` を作成し、外部 CDN 参照ゼロ（Zero-External-Asset）のインライン辞書オブジェクトを共通化。
- **共通用語集モジュールの抽出**: `.agents/shared/dashboard_glossary.R` で共通定義と2次元・3次元固有項目を組み立てる。基準モデル、実際の事前分布、ゼロセルの表示規約、条件付き割合の分母、図への導線は利用側コンテキストとして渡す。M1〜M9/BICを2次元へ無条件に掲載しない。
- **テンプレートの軽量化と参照切り替え**: 2次元および 3次元の `dashboard.Rmd` から重複コードを削除し、共有アセットをインライン注入（`readLines()` / `cat()`）する構造へリファクタリング。
- **完全オフライン静的契約の維持**: 外部 CDN やローカル絶対パスを一切混入させず、既存テスト（`test_three_way_dashboard_html.R`, `test_vcd_categorical_dashboard_v4.R`）の 100% 合格を維持。

## Capabilities

### New Capabilities

- `shared-dashboard-presentation`: 2次元および3次元ダッシュボード全体で共有される NEJM / Nature Medical テーマ CSS、DataTables 辞書、および数理用語集の共通基盤。

### Modified Capabilities

- 表示共通化工程では計算値を維持する。その後、利用者指定により3次元の多項Dirichlet主事前をα=1.0からα=0.5へ移行する工程を同じChangeに含める。事後要約と成果物の統計的意味は変わるため、完全互換のリファクタリングとは扱わない。α=1.0は感度分析として比較する。計画の詳細は `docs/Artifacts/implementation_plan_008_0919.md` を参照する。

## Impact

- `.agents/shared/`: 共有 CSS、辞書、用語集フラグメントの新設
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd`: スタイルおよび用語集の共有読み込み化
- `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd`: スタイルおよび用語集の共有読み込み化
- 既存のダッシュボード出力結果およびテストスイート（回帰テストの通過を保証）

## 数学的検証による補足（2026-09-19）

現行実装では2次元の主事前はα=0.5、3次元の条件付き割合はα=1.0である。利用者の追加指定により、3次元計算をα=0.5へ移行する方針に更新した。旧成果物のα=1.0を表示だけJeffreysへ変更してはならない。レバレッジ、BIC、事後確率要約等の訂正基準は `design.md` の決定4と追加仕様に定める。実装は現時点で未完了である。

- 追加影響範囲: 3次元 `templates/pass1_compute.R`、`templates/analysis.R`、関連設定・結果契約・由来情報・テスト・fixture。主事前と感度事前、支持集合を成果物から識別できるようにする。Poissonモデル選択や局所診断の計算変更は含めない。
