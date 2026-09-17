## Why

現行の `vcd-categorical-analysis` は 2 次元分割表に対する VCD 可視化と Pearson 残差の分析にとどまり、効果量（Effect）、統計的証拠（Evidence）、影響度（Influence）、推定安定性（Stability）、事後不確実性（Posterior Uncertainty）が混同・未分離のままである。また、構造的ゼロの境界や非有限値の JSON 契約、Cramér's V 信頼区間の算定法が未固定であった。
本改修では 2 次元名義分割表の解析エンジンを完全分割表専用の v4.0（インターフェース v3.0）へと刷新し、5 軸の次元分離原則に基づく診断と完全オフライン・自己完結型の Scientific Dashboard を提供する。

## What Changes

- **入力受入境界と構造的ゼロの禁止（BREAKING）**:
  - 完全 2 変数名義分割表（Complete 2-way table, Arity = 2, $I, J \ge 2$, $N > 0$, 有限非負整数）専用エンジンに固定
  - 構造的ゼロ（不完全分割表）は準独立モデルという別 estimand を要するため入力禁止（`STRUCTURAL_ZERO_NOT_SUPPORTED` で即時停止）
  - 3 次元以上の入力は即時フェイルファスト停止（`INVALID_INPUT_ARITY`）し、正本スキル `vcd-bayesian-evidence-analysis` への委譲を案内
- **5 軸セル診断の導入と非有限値の安全な表現**:
  - **Effect**: 局所対数効果比 $\log(O/E)$、符号付き割合差 $(O-E)/N$。$O=0$ のときは `log_oe: null`, `log_oe_state: "NEGATIVE_INFINITY"`, `is_finite: false` として標準 JSON に適合
  - **Evidence**: Rao スコア統計量 $T^{\rm score} = (r^P)^2 / (1-h)$、未調整 $p$ 値、BH 調整 $p$ 値
  - **Influence**: Poisson 独立 GLM の Leverage $h_{ij}$
  - **Stability**: $O=0$、$E<5$、$h \ge 0.80$ に基づく Quarantine 状態管理（$O=0$ はサンプリング偶然のゼロとして一貫処理）
  - **Large-N Dual Filter**: 大標本時の $|\log(O/E)| \ge 0.50$ かつ $T^{\rm score} \ge 3.84$ による探索的候補抽出（ゼロセル・Quarantine セルは自動除外）
- **グローバル関連度と Cramér's V 信頼区間の厳密算定**:
  - 非心カイ二乗累積分布の数値反転（`stats::uniroot`）による非心度 $\lambda$ の 95% 信頼区間導出
  - 未補正 Cramér's $V$ および Bergsma (2013) bias-corrected $\tilde{V}$（$\tilde{k} - 1$ 分母）への単調写像と端点順序（$0 \le \tilde{V}_L \le \tilde{V}_U \le 1$）保証
  - JSON 契約での未補正 `cramers_v_ci` と補正後 `cramers_v_corrected_ci` の分離
- **多項 Dirichlet 事後不確実性の導入**:
  - 対称 Dirichlet 事前分布（既定 $\alpha = 1.0$）と共役事後分布
  - 95% 等裾信用区間（Bayesian ETI）
  - 生成量: 結合セル確率 $\pi_{ij}$、行条件付き確率 $P(B|A)$、列条件付き確率 $P(A|B)$
  - 局所独立性からの事後乖離 $D_{ij} = \log(\pi_{ij} / (\pi_{i+}\pi_{+j}))$、事後方向確率 $P(D>0 \mid data)$
  - 決定論的乱数シード、10,000 回ドロー（raw draws は永続化せず要約統計量のみ保持）
  - 任意感度分析（$\alpha = 0.5$）の比較フレームワーク
- **結果契約・JSON スキーマ刷新（BREAKING）**:
  - `interface_version = "3.0"`, `schema = "two-way-results-v2"`
  - 旧 `Evidence Score = r² - k log(N)` の完全排除
  - セル単位・事後分布単位の構造化オブジェクト出力
- **Scientific Dashboard（HTML）の刷新と静的オフライン受入検査**:
  - 完全オフライン（外部 CDN・リモートフォント・CDN JS 不使用、DataTables 日本語辞書完全インライン化）
  - 生成 HTML に対する静的正規表現スキャンによる外部 URL 混入の機械的遮断
  - Effect × Evidence マップ、残差ヒートマップ、Bayesian Credible Box、不確実性マトリクス、セルエクスプローラー、構造用 Mosaic プロット
- **AI Narrative / レポートの品質契約**:
  - 確定した 7 ステップ順序（全体関連 $\to$ 効果量 $\to$ 証拠 $\to$ 安定性 $\to$ 不確実性 $\to$ 実務解釈 $\to$ 制約）
  - 単独 $p$ 値判定や確証的結論の禁止

## Capabilities

### New Capabilities

- `two-way-evidence-analysis`: 完全な名義 2 次元分割表に対する 5 軸診断（Effect, Evidence, Influence, Stability, Posterior Uncertainty）、多項 Dirichlet 事後推論、Interface 3.0 結果契約、および完全オフライン Scientific Dashboard。

### Modified Capabilities
<!-- None -->

## Impact

- **対象コード**: `.agents/skills/vcd-categorical-analysis/` 配下の全スクリプト、テンプレート（`analysis.R`, `dashboard.Rmd`, `report.Rmd`）、リファレンスドキュメント。
- **共有コア（任意導入/将来抽出）**: `.agents/shared/categorical/`
- **データ契約（BREAKING）**: `categorical_results.json` の構造が interface 2.x から 3.0 (`two-way-results-v2`) へ移行。3 次元入力や構造的ゼロ指定時はフェイルファストで拒否。
- **テスト**: ユニットテスト・再現性テスト群の新規追加（`tests/test_vcd_categorical_*`）。
