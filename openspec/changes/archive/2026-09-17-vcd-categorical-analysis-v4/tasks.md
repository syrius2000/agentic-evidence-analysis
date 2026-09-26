## 1. Contract Freeze & Architecture Setup

- [x] 1.1 `interface_version = "3.0"` および `schema = "two-way-results-v2"` のスキーマ定義を確定し、非有限値（`log_oe: null`, `log_oe_state: "NEGATIVE_INFINITY"`, `is_finite: false`）および Cramér's V 信頼区間（未補正 `cramers_v_ci` と補正後 `cramers_v_corrected_ci`）の分離をスキーマに反映する
- [x] 1.2 入力受入境界（Arity=2, $I \ge 2, J \ge 2$, $N > 0$, 有限非負整数）および構造的ゼロ入力禁止（OutOfScope / `STRUCTURAL_ZERO_NOT_SUPPORTED`）の仕様を確定する
- [x] 1.3 `.agents/skills/vcd-categorical-analysis/` 内のモジュール構成および `.agents/shared/categorical/` （共有化対象）のディレクトリ構造を定義し、依存関係を整理する

## 2. Input Validation, Poisson Independence GLM & Residual Diagnostics

- [x] 2.1 厳格な入力検証関数 `validate_input_table()` を実装し、3次元以上の入力、構造的ゼロ、1水準、総度数0、非整数重み度数をフェイルファストで拒否し、`tests/test_vcd_categorical_input_validation.R` で検証する
- [x] 2.2 2次元分割表に対する Poisson 独立 GLM 適合、期待度数、Pearson 残差 $r^P$、Deviance 残差 $r^D$、および Hat 行列対角成分 Leverage $h_{ij}$ の算出関数を実装し、`tests/test_vcd_categorical_residual_diagnostics_v4.R` で検証する
- [x] 2.3 調整残差 $r^{\rm adj}_{ij} = r^P_{ij} / \sqrt{1 - h_{ij}}$ を実装し、Haberman 型標準化残差の理論値との一致を単体テストで確認する
- [x] 2.4 セルの安定性評価（Quarantine: $O=0$, $E<5$, $h \ge 0.80$）および理由コード（`ZERO_OBSERVED`, `EXPECTED_LT_5`, `HIGH_LEVERAGE`）の付与ロジックを実装し、ゼロ観測セルの Quarantine 必須化をテストする

## 3. Effect & Evidence Metrics, Global Association & Cramér's V CI

- [x] 3.1 局所対数効果比 $\log(O/E)$ および符号付き割合差 $(O-E)/N$ の算出処理を実装し、ゼロ観測セルで `null` かつ `NEGATIVE_INFINITY` を安全に出力することをテストで確認する
- [x] 3.2 局所 Rao スコア統計量 $T^{\rm score} = (r^P)^2 / (1 - h)$、未調整 $p$ 値、および BH 調整 $p$ 値（補助情報）の算出処理を実装し、`tests/test_vcd_categorical_evidence_v4.R` で検証する
- [x] 3.3 大標本 Dual-Filter 判定（$N \ge 2000$ 時の $|\log(O/E)| \ge 0.50$ かつ $T^{\rm score} \ge 3.84$）を実装し、ゼロセルおよび Quarantine セルが自動除外されることを検証する
- [x] 3.4 非心カイ二乗累積分布の反転（`stats::uniroot`）による非心度 $\lambda$ の 95% 信頼区間導出と、Bergsma (2013) bias-corrected Cramér's $V$ への単調写像を実装し、端点順序 $0 \le \tilde{V}_L \le \tilde{V}_U \le 1$ および退化表フォールバックを `DescTools` 参照値比較（許容誤差 $10^{-4}$）で検証する

## 4. Multinomial Dirichlet Posterior Engine

- [x] 4.1 対称 Dirichlet 事前分布（既定 $\alpha=1.0$）に基づく多項共役事後分布の解析的平均・分散の算出処理を実装する
- [x] 4.2 `analysis_signature` からの決定論的シード生成と、10,000 回の事後モンテカルロサンプリング処理を実装し、`tests/test_vcd_categorical_dirichlet_v4.R` で再現性を検証する
- [x] 4.3 生ドローを JSON に永続化せず、事後平均、SD、Q2.5、Q25、Q50、Q75、Q97.5、95% ETI 区間幅、方向確率のみを抽出・保持するメモリポリシーを実装する

## 5. Posterior Generated Quantities & Prior Sensitivity

- [x] 5.1 結合セル確率 $\pi_{ij}$、行条件付き確率 $P(B|A)$、および列条件付き確率 $P(A|B)$ の事後要約算出を実装し、条件付き確率の総和が 1 になることを単体テストで検証する
- [x] 5.2 局所独立性からの事後乖離 $D_{ij} = \log(\pi_{ij} / (\pi_{i+}\pi_{+j}))$、事後方向確率 $P(D>0 \mid data)$、および指定時のみの $P(|\Delta| > \delta \mid data)$ の算出処理を実装し、`tests/test_vcd_categorical_generated_quantities_v4.R` で検証する
- [x] 5.3 代替事前分布（$\alpha=0.5$）による事後要約比較（事前感度分析）処理を実装し、主結果への影響度評価をテストする

## 6. Interface 3.0 Contract & JSON Serializer

- [x] 6.1 旧 `Evidence Score` を完全排除し、`global`, `cells`, `posterior`, `quality`, `provenance` を含む Interface 3.0 (`categorical_results.json`) のシリアライズ関数を実装し、ゼロ観測セルおよび Cramér's V CI の JSON スキーマ適合性を検証する
- [x] 6.2 `references/interface.md` を更新し、旧インターフェース 2.x の fixture に対する後方互換性エラーハンドリングを `tests/test_vcd_categorical_interface_v3.R` で検証する

## 7. Offline Scientific Dashboard & Visualizations

- [x] 7.1 外部 CDN・Google Fonts・リモート MathJax を一切使用せず、システムフォントスタック、ローカル KaTeX、完全インライン JavaScript 日本語辞書付き DataTables を用いた完全オフライン `templates/dashboard.Rmd` を作成する
- [x] 7.2 所定の 10 セクション構成（ヘッダー、エグゼクティブ要約、全体関連、Effect × Evidence 散布図、残差ヒートマップ、Bayesian Credible Box、不確実性マトリクス、独立性乖離、セルエクスプローラー、構造確認 Mosaic、品質・プロビナンス）を実装する
- [x] 7.3 生成 HTML に対する静的正規表現スキャン（`http://` または `https://` の検出でテスト失敗）を実装し、`tests/test_vcd_categorical_dashboard_v4.R` で完全オフライン受入を機械的に検証する

## 8. Documentation, AI Narrative Guidelines & Integration Verification

- [x] 8.1 AI Narrative の 7 ステップ考察順序（全体関連 $\to$ 効果量 $\to$ 証拠 $\to$ 影響度・安定性 $\to$ 事後不確実性 $\to$ 実務解釈 $\to$ 制約）と禁止事項を反映した `references/ai-narrative-workflow.md` および `SKILL.md` を改定する
- [x] 8.2 実データを用いたエンドツーエンド（Pass 1 計算 $\to$ Pass 2 AI 考察 $\to$ Pass 3 HTML レンダリング）の総合検証を実施し、`walkthrough.md` で結果を確認する
