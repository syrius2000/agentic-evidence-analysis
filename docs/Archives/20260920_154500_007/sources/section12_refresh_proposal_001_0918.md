# Section 12 指標の読み方・数理モデル・学術リファレンス刷新計画（改定確定版）

- **作成日時**: 2026-09-18 23:45 (JST)
- **ステータス**: FIX（改定完了・実装承認待ち）
- **対象スキル**: `vcd-categorical-analysis`
- **対象ファイル**:
  - `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd`
  - `tests/test_vcd_categorical_dashboard_v4.R`

---

## 1. 目的と結論

本改定は、Section 12（旧「統計用語集・方法論解説・学術リファレンス」）において発生した **Pandoc による HTML 構文のコードブロック化（`pre > code` によるエスケープ崩れ）を根絶**し、Sections 1–11 のダッシュボード出力を臨床・統計の専門家が正確かつ直感的に読み解くための **「指標の読み方・数理モデル・学術リファレンス」ナビゲータ** へと刷新することを目的とする。

NEJM / Nature Medical 調の洗練された視覚美（無駄な装飾の排除、1px 細枠線、学術ネイビー `#1F4D7A` アクセント）を保持しつつ、フィッシャー情報行列や局所ハール不変性に根ざした数理的厳密性と、非専門家にも誤読を生じさせない「3行解説テンプレート（何か／どこを見るか／誤解しないこと）」を両立させる。

---

## 2. 現状のレンダリング障害と根本原因

### 観測された現象

生成成果物（`skill_out/vcd_categorical/run_otc_q05_design_test/dashboard.html`）において：

- 冒頭の問いかけブロック内の `<strong>` 等が `<pre><code>&lt;strong&gt;...</code></pre>` とエスケープ出力。
- アコーディオン `<details>` 内部の定義リスト `<dl><dt><dd>` や参考文献リスト `<ol><li>` が全て `<pre><code>` 内に文字列として埋め込まれ、HTML 要素としての階層構造とスタイルが消失。

### 根本原因

Pandoc Markdown パーサの仕様上、HTML ブロック要素（`<div>`, `<details>` 等）の内部に **4 空白以上のインデント** が存在すると、Markdown の「インデントコードブロック」規則が優先適用され、内部 HTML がコード断片として解釈・エスケープされる。

### 解決策（構文契約）

1. **行頭インデントの完全排除（Zero-Leading-Space）**:
   Section 12 の HTML 要素（`<details>`, `<summary>`, `<div>`, `<dl>`, `<dt>`, `<dd>`, `<ol>`, `<li>`, `<p>`）は、行頭 0 カラムから開始し、Markdown コードブロック判定を完全に無効化する。
2. **プレーンな HTML5 ネイティブ構造**:
   ブラウザ標準の開閉アコーディオン `<details class="glossary-accordion">` を使用し、外部 JS / 外部 CSS は一切使用しない（鉄則 6: Zero-External-Asset 遵守）。
3. **テストによる静的検出**:
   `tests/test_vcd_categorical_dashboard_v4.R` において、`#section-glossary` 内に `pre` または `code` が存在しないこと（`!grepl("<pre>", glossary_html)`）をアサーションとして追加し、再発を恒久防止する。

---

## 3. 情報設計とセクション構造

初期状態はすべて折りたたまれた状態（閉）とする。読者が着目した図表（Sections 1〜10）からスムーズに数理的背景へたどり着けるよう、4 つのアコーディオンで構造化する。

```text
Section 12: 指標の読み方・数理モデル・学術リファレンス
│
├─ 冒頭カード: 統計的・科学的問いと利用原則
│  └─ 「P値単独判定の排除」「相関と因果の分離」「統計的証拠強度と効果量の分離」
│
├─ 1. 全体連関構造と効果量 (Global Association & Effect Size) ── [対応: Sec 1, 2]
│  ├─ Pearson X² 独立性検定統計量（大標本でのP値飽和特性、帰無仮説からの乖離）
│  ├─ Cramér's V（標準化された全体連関強度 [0, 1]）
│  └─ Bergsma (2013) バイアス補正 Cramér's Ṽ（有限標本上振れバイアスの低減、95% CI）
│
├─ 2. 局所セル診断と 4 軸フレームワーク (Four-Axis Local Cell Diagnostics) ── [対応: Sec 3, 4, 5]
│  ├─ 【第1軸】Effect: 局所対数効果比 λ_ij = log(O/E)（乗法乖離倍率、標本数不変）
│  ├─ 【第2軸】Evidence: Rao スコア検定統計量 T_score（局所証拠強度、標本数比例）
│  ├─ 【第3軸】Influence: レバレッジ h_ii（幾何学的影響度、GLM ハット行列対角成分）
│  ├─ 【第4軸】Stability: 隔離条件 QUARANTINED（数値的不安定セル、探索候補からの除外）
│  └─ Haberman (1973) 調整標準化残差 z_ij（漸近 N(0, 1) 残差、正負の統計発散色）
│
├─ 3. 多項 Dirichlet 事後推論と不確実性 (Multinomial Dirichlet Posterior) ── [対応: Sec 6–10]
│  ├─ 主事前分布: 多項 Jeffreys 事前分布 α = 0.5（情報幾何学・局所不変性に基づく無情報事前）
│  ├─ 感度分析: Laplace 一様事前分布 α = 1.0（事前分布への頑健性検証）
│  ├─ 95% 等裾信用区間 (ETI) と不確実性幅 prob_eti_width（推定精度の評価）
│  ├─ 条件付き事後予測確率 P(B|A) および P(A|B)（条件向きの厳格分離、中央値と平均の視覚分離）
│  └─ 独立モデルからの対数事後乖離 log divergence（事後分布スケールでの独立予測からの逸脱）
│
└─ 4. 学術参考文献と正本リファレンス (Scientific References)
   ├─ 一次学術文献（Agresti, Haberman, Rao, Bergsma, Pregibon, Gelman, ASA Statement）
   └─ リポジトリ内正本ドキュメントへの相対パスリンク
```

---

## 4. 各項目の解説テンプレートと数理的厳密性の契約

各用語は、**「① 定義と数理モデル」「② どの図で見るか」「③ 誤解しないこと（批判的視点）」** の 3 段構成で統一する。

### 4.1 表記・文言の厳格ルール（禁止表現の排除）

| 対象概念 | 正しい表現（採用） | 禁止・過剰表現（不採用） | 数理的根拠 |
| :--- | :--- | :--- | :--- |
| **Cramér's Ṽ** | 有限標本バイアス低減量 | 不偏推定量 | Bergsma (2013) は漸近展開に基づくバイアス補正であり、厳密な意味での最小分散不偏推定量（UMVUE）ではない。 |
| **Evidence / $T_i^{\rm score}$** | 統計的証拠強度 | 臨床的重要性、確信度、再現性の保証 | $T_i^{\rm score}$ は標本サイズ $N$ に依存する検定統計量であり、実質的効果の大きさとは独立である。 |
| **Effect / $\lambda_{ij}$** | 局所的乗法乖離（対数効果比） | 因果効果、真の関連度 | 観測度数と期待度数の比 $\log(O/E)$ であり、交絡因子の存在下では直接の因果効果を意味しない。 |
| **QUARANTINED** | 数値的不安定セル（解釈保留） | 異常値、除外データ、第3の臨床群 | サンプリングゼロや低期待度数による漸近崩壊を防ぐための安全弁であり、データ自体の誤りではない。 |
| **95% ETI** | 事後等裾信用区間（パラメータの不確実性） | 95% 信頼区間、有意差の検定 | ベイズ事後分布におけるパラメータ存在確率区間であり、頻度論の反復試行被覆率とは哲学的に異なる。 |
| **Jeffreys 事前 $\alpha=0.5$** | 局所ハール不変事前分布 | 最良の事前分布、主観的信念 | 多項分布のフィッシャー情報行列 $\det(\mathcal{I}(\boldsymbol{\pi}))^{1/2}$ に基づく客観的・幾何学的一貫性による。 |

---

## 5. CSS デザイン仕様（NEJM / Nature Medical 調）

Section 12 専用 CSS クラス（`glossary-accordion`, `glossary-body`, `glossary-item` 等）を `dashboard.Rmd` の `<style>` に定義する：

```css
/* Section 12: NEJM / Nature Medical 調アコーディオン */
.glossary-accordion {
  border: 1px solid #E2E8F0;
  border-radius: 4px;
  margin-bottom: 10px;
  background: #FFFFFF;
  transition: border-color 0.2s ease;
}
.glossary-accordion:hover {
  border-color: #1F4D7A;
}
.glossary-accordion summary {
  padding: 12px 16px;
  font-weight: 600;
  color: #152238;
  cursor: pointer;
  background: #F8FAFC;
  border-radius: 4px;
  list-style-position: inside;
  font-size: 0.95rem;
  outline: none;
}
.glossary-accordion[open] summary {
  border-bottom: 1px solid #E2E8F0;
  border-radius: 4px 4px 0 0;
  background: #F1F5F9;
  color: #1F4D7A;
}
.glossary-body {
  padding: 16px 20px;
  font-size: 0.88rem;
  line-height: 1.65;
  color: #334155;
}
.glossary-item {
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px dashed #E2E8F0;
}
.glossary-item:last-child {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}
.glossary-item-title {
  font-weight: 700;
  color: #1F4D7A;
  font-size: 0.92rem;
  margin-bottom: 4px;
}
.glossary-meta {
  display: block;
  font-size: 0.82rem;
  color: #64748B;
  margin-top: 3px;
}
.glossary-caution {
  display: block;
  font-size: 0.82rem;
  color: #9B2945;
  margin-top: 2px;
}
```

---

## 6. 受入条件（Acceptance Criteria）

| 検査区分 | 受入条件 | 検証手法 |
| :--- | :--- | :--- |
| **構文・レンダリング** | Section 12 の HTML 内に `<pre>` および `<code>` が一切出現しないこと。 | 静的正規表現スキャン（自動テスト） |
| **デザイン・階層** | 各項目がタイトル・定義・対応セクション・注意点（赤茶 `#9B2945`）の視覚的階層を持つこと。 | 生成 HTML ソースおよびブラウザ確認 |
| **数学的厳密性** | Pearson $X^2$, Cramér's $\tilde{V}$, Rao $T_i^{\rm score}$, Leverage $h_{ii}$, Jeffreys $\alpha=0.5$, ETI, 隔離条件が正確に定義され、禁止表現を含まないこと。 | コードレビューおよびテキスト一致確認 |
| **Zero-External-Asset** | 外部 CDN、外部 JS、外部 Web フォント、OS ローカル絶対パスを含まないこと（0 件）。 | `tests/test_vcd_categorical_dashboard_v4.R` |
| **既存動作の不変性** | 統計計算結果、JSON インターフェース、隔離セル数、実行時間（~4.4秒）に影響を与えないこと。 | `run_otc_design_test.R` 回帰検証 |

---

## 7. 実装手順（Execution Steps）

1. **`dashboard.Rmd` の Section 12 を左詰め HTML 構造へ改修**:
   - 行頭インデントを除去し、定義リスト・アコーディオンを洗練された CSS クラス構造で再実装。
2. **`test_vcd_categorical_dashboard_v4.R` に Section 12 の pre/code 排除アサーションを追加**:
   - `!grepl("<pre>", section12_html)` 等の検証を追加。
3. **OTC_Q05 によるレンダリング再実行と検証**:
   - `Rscript scratch/run_otc_design_test.R` を実行し、HTML 出力の `<pre><code>` エスケープが解消されたことを実証確認。
4. **結果報告とコミット可否の確認**:
   - ユーザーへ改定完了を報告。
