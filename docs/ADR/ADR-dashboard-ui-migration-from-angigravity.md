# ADR: Angigravity からのダッシュボード UI 移植

## 決定

`Angigravity` ブランチを統合せず、`main` の `three-way-results-v1` を唯一の統計的正本として、表示パターンだけを移植する。レポート経路を検証、表示用 view model、オフライン HTML 描画に分離する。

## 理由

ブランチ全体の統合は、分析ライフサイクル、schema、モデル計算、Pass 2 の契約まで巻き戻す危険がある。一方、バナー、カード、因子凡例、モデル詳細、レスポンシブ配置、フォーカス移動は統計値を変更せず独立に導入できる。

## 統計フィールドの表示対応

| UI | `three-way-results-v1` の入力 | 表示規則 | HOLD 時 |
|---|---|---|---|
| 概要カード | `input_summary.total_n`, `n_cells`, `models` | 値の整形のみ | 件数を明示 |
| 因子凡例 | `input_summary.variables`, `levels` | 配列順を A/B/C に対応 | 欠落を推測しない |
| モデル比較・詳細 | `models.*` | 構造、式、状態、逸脱度、df、BIC、log P | オレンジの HOLD badge と理由 |
| 入れ子比較 | `comparisons` | ΔG²、Δdf、ΔG²/N、近似 log BF、状態 | 近似状態を残す |
| セル診断 | `cells.*.cells` | 現行 `log(O/E)` 色尺度と4軸診断を維持 | 灰色・状態列を維持 |
| ベイズ | `posterior` | 厳密 BF、事後平均、点ごとの区間、感度を分離 | 未算出を明示 |
| 由来・QA | `provenance`, Pass 2/2.5 artifacts | SHA、日時、R、成果物リンク | 非表示にしない |

## 移植しないもの

旧 Evidence Score、自動的な「勝者」、BIC 近似値の厳密 BF 扱い、preview narrative の代用、CDN 依存、DataTables の全面導入、Angigravity の分析・schema・run lifecycle は移植しない。

## 結果

`report_validation.R` が schema、状態、Pass 2/2.5、結果 SHA、登録数値を検査する。`report_view_model.R` は表示整形だけを担う。基本表と `<details>` は JavaScript や MathJax がなくても読め、JavaScript はモデルリンクの展開とフォーカス移動だけを強化する。
