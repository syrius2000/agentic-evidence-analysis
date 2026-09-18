## 1. デザイン決定の記録と標準化

- [x] 1.1 `vcd-categorical-analysis` で実証された NEJM/Nature Medical 調デザイン決定（`THEME_TOKENS`、確定行パレット、残差正負色と隔離セルの分離、Pandoc Raw HTML 用語集構造）を仕様として確定する
- [x] 1.2 `docs/Artifacts/section12_refresh_proposal_001_0918.md` および `implementation_plan_007_0918.md` の記録整合性を検証する

## 2. 3次元ダッシュボードテンプレートの NEJM/Nature Medical 調刷新

- [x] 2.1 `.agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd` の CSS スタイルを NEJM/Nature Medical 調（1px 枠線、カード背景 `#F6F8FB`、学術ネイビー `#1F4D7A`、シャドウ排除）へ更新する
- [x] 2.2 因子群カラーパレット（Okabe-Ito 拡張）と、調整残差の正負発散色（`#0F766E` / `#B45309`）、隔離セル琥珀色（`#A16207`）の分離表示を適用する
- [x] 2.3 Pandoc Raw HTML Block（```` ```{=html} ````）を用いて、3次元対数線形モデル（M1〜M9）、明示式 BIC、Rao スコア、多項 Dirichlet 事後推論の用語集・学術リファレンスアコーディオンを設置する

## 3. テストとオフライン品質の検証

- [x] 3.1 3次元ダッシュボードのレンダリングテストを実行し、UCB 等の標準データセットで HTML が正常生成されることを検証する
- [x] 3.2 生成された 3次元 HTML に対する静的正規表現スキャンを実施し、Zero-External-Asset（外部 CDN / 通信 0 件）および用語集の pre/code エスケープ非混入を検証する
