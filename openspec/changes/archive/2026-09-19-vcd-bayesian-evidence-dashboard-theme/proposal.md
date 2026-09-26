## Why

2次元カテゴリカル分析スキル（`vcd-categorical-analysis`）において、NEJM / Nature Medical 調の臨床・学術標準テーマ（カード背景 `#F6F8FB`、枠線 1px `#E2E8F0`、シャドウ排除、学術ネイビー `#1F4D7A`、バーガンディ `#9B2945` 等の確定行群パレット、および Pandoc Raw HTML Block ````{=html}```` によるコードブロック化エスケープを根絶したネイティブアコーディオン用語集）が確立され、視覚的・数理的に高い評価を得た。

本変更は、この確立されたデザイン体系および数理的・構造的ノウハウを記録・標準化するとともに、3次元カテゴリカル分析の正本スキルである `vcd-bayesian-evidence-analysis` のダッシュボードテンプレート（`templates/report_template.Rmd`）へ移植・適用し、リポジトリ全体でエビデンス可視化の審美性と解釈性を最高水準に統一することを目的とする。

## What Changes

- **デザイン決定の記録と体系化**:
  - `vcd-categorical-analysis` で実証された NEJM / Nature Medical テーマのカラートークン、確定行パレット（Okabe-Ito 拡張）、統計状態発散色（正残差 `#0F766E` / 負残差 `#B45309`）、隔離セル琥珀色（`#A16207`）の分離原則をデザイン仕様として確定記録する。
  - Pandoc Markdown パーサによる HTML インデントコードブロック誤認（`pre > code` 化）を根絶する構文契約（```` ```{=html} ```` の適用）を標準プラクティスとして明記する。
- **`vcd-bayesian-evidence-analysis` テンプレートの刷新**:
  - 3次元ダッシュボードテンプレートを NEJM / Nature Medical 調の洗練されたレイアウトへ刷新。
  - 因子 A・B・C および層別（Dept等）における一貫したカラーマッピングと、正負残差・隔離セルの視覚的独立性を確保。
  - 末尾に 3 次元対数線形モデル（M1〜M9）、明示式 BIC、Rao スコア、多項 Jeffreys 事前分布、一次文献（Agresti, Haberman, Rao, etc.）を網羅した折りたたみ式用語集・学術リファレンスを新設。
  - 鉄則 6（Zero-External-Asset 原則）を完全遵守（CDN・外部フォント・外部 JS 参照 0 件）。
- **回帰テスト・検証スイートの拡充**:
  - 3次元ダッシュボードのレンダリング検査および静的 URL / pre・code エスケープ排除検査を追加。

## Capabilities

### Modified Capabilities
- `three-way-dashboard-reporting`: 3次元ダッシュボードの表示仕様に NEJM / Nature Medical 調の臨床・学術標準デザイン、統一パレット規則、および Pandoc raw HTML による用語集アコーディオンを追加し、ゼロ外部アセット契約のもとで審美性と解釈性を強化する。

## Impact

- **影響対象コード**:
  - `.agents/skills/vcd-bayesian-evidence-analysis/templates/report_template.Rmd`（または関連 Rmd テンプレート）
  - `tests/test_three_way_dashboard.R`（または該当テストファイル）
- **非機能要件**:
  - Zero-External-Asset 原則（完全オフライン）の維持
  - 既存の数値計算ロジック、Poisson GLM、BIC 算出、Interface 3.0/JSON 仕様への非破壊性
