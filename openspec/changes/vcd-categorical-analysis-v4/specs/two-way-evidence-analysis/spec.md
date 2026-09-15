## Purpose

2次元名義分割表の解析において、効果量（Effect）、統計的証拠（Evidence）、影響度（Influence）、推定安定性（Stability）、事後不確実性（Posterior Uncertainty）の5軸を分離した統計診断と、多項Dirichlet事後推論、Interface 3.0結果契約、および完全オフラインのScientific Dashboardを提供する。

## ADDED Requirements

### Requirement: 入力受入境界と構造的ゼロの禁止
システムは、完全な2次元名義分割表（Complete 2-way contingency table）のみを入力として受入・処理しなければならない（MUST）。次元数が3以上、各軸水準数が2未満、総度数が0、または度数が有限非負整数でない入力はフェイルファストで拒否しなければならない。また、理論的・生理学的に発生不可能な構造的ゼロ（不完全分割表）は本エンジンの対象外（OutOfScope）とし、入力禁止として扱わなければならない。

#### Scenario: 3次元以上の入力に対するフェイルファスト拒否と正本委譲
- **WHEN** 3次元以上の分割表（arity $\ge 3$）が入力される
- **THEN** 解析計算を行わずに即時停止し、`run_state.json` に `status: "failed"` および `error_code: "INVALID_INPUT_ARITY"` を記録し、3次元以上の解析は正本スキル `vcd-bayesian-evidence-analysis` を使用すべき旨のエラーメッセージを出力する

#### Scenario: 構造的ゼロ指定時のフェイルファスト拒否
- **WHEN** 入力データまたは設定において構造的ゼロ（発生不能セル）が指定される
- **THEN** 即時停止し、`run_state.json` に `status: "failed"` および `error_code: "STRUCTURAL_ZERO_NOT_SUPPORTED"` を記録し、準独立モデル等専用の解析手続きを案内する

#### Scenario: 入力度数形式の検証
- **WHEN** 負の度数、非有限値（NA/NaN/Inf）、非整数重み度数、または総度数 $N=0$ の表が入力される
- **THEN** 入力検証段階で即時停止し、該当するエラーコード（`NON_INTEGER_COUNTS`, `ZERO_TOTAL_COUNT` 等）を記録して終了する

### Requirement: 5軸セル診断の分離と非有限値の安全な表現
システムは、名義2次元分割表のPoisson独立GLMに基づき、各セルに対して効果量（Effect）、統計的証拠（Evidence）、影響度（Influence）、および推定安定性（Stability）の各指標を明確に分離して算出しなければならない（MUST）。残差単独を有意性の根拠としてはならず、観測度数0のセルにおける対数効果比 $-\infty$ は標準JSONに適合した安全な形式で出力しなければならない。

#### Scenario: 局所調整残差とスコア統計量の算出
- **WHEN** 2次元分割表に対して独立モデルGLMを適合する
- **THEN** 各セルにおいて Pearson残差 $r^P$、Deviance残差 $r^D$、Leverage $h_{ij}$、調整残差 $r^{\rm adj} = r^P / \sqrt{1 - h}$、および局所スコア統計量 $T^{\rm score} = (r^P)^2 / (1 - h)$ が算出され、それぞれの数学的定義に従って保持される

#### Scenario: ゼロ観測セルにおける対数効果比の非有限値表現
- **WHEN** セルの観測度数が0 ($O_{ij}=0$) である
- **THEN** JSON出力において `log_oe` を `null` とし、`log_oe_state: "NEGATIVE_INFINITY"` および `is_finite: false` を付与して出力し、標準JSONパーサーとの互換性を保証する

### Requirement: セルの推定安定性評価と隔離（Quarantine）
システムは、サンプリング偶然によるゼロ度数、小期待度数、または高レバレッジにより近似・推定の信頼性が損なわれるセルを自動判定し、安定性状態を `QUARANTINED` としてフラグ付けし、理由コードを配列として保存しなければならない（MUST）。

#### Scenario: ゼロ度数、小期待度数、または高レバレッジのセルを検出する
- **WHEN** セルの観測度数が0 ($O=0$)、期待度数が5未満 ($E<5$)、またはレバレッジが0.80以上 ($h \ge 0.80$) である
- **THEN** 当該セルの stability status を `QUARANTINED` に設定し、該当する理由コード（`ZERO_OBSERVED`, `EXPECTED_LT_5`, `HIGH_LEVERAGE` 等）を配列として保存し、通常セルと明確に区別して表示する

### Requirement: 大標本 Dual-Filter による探索的候補抽出
システムは、大標本時の過剰検出を抑制するため、効果の大きさと証拠の強さの双方を同時に満たすセルを探索的候補（Exploratory dual-filter candidate）として抽出しなければならない（MUST）。ゼロ観測セルおよび隔離セルは候補判定から除外しなければならない。

#### Scenario: 大標本閾値に基づく候補抽出と隔離セルの除外
- **WHEN** 標本サイズ $N \ge 2000$ かつセルが非隔離（regular）である
- **THEN** $|\log(O/E)| \ge 0.50$ かつ $T^{\rm score} \ge 3.84$ の両方を満たすセルのみを dual-filter candidate として識別し、$O=0$ または Quarantine 状態のセルは候補から除外する

### Requirement: グローバル関連度と Cramér's V 信頼区間の厳密算定
システムは、全体関連の統計量（Pearson $\chi^2$, $G^2$, Cramér's V）を算出するとともに、非心カイ二乗分布の反転による解析的 95% 信頼区間を算出しなければならない（MUST）。未補正推定量に対する区間と Bergsma (2013) bias-corrected 推定量に対する区間を明確に分離して出力しなければならない。

#### Scenario: 非心カイ二乗反転による信頼区間導出と単調写像
- **WHEN** 観測カイ二乗統計量 $X^2$ から母集団非心パラメータ $\lambda$ の 95% 信頼区間 $[\lambda_L, \lambda_U]$ を導出する
- **THEN** 累積分布関数の求根により $0 \le \lambda_L \le \lambda_U$ を得た上で、未補正区間 $V_* = \sqrt{(\lambda_*/N)/(k-1)}$ および bias-corrected 区間 $\tilde{V}_* = \min(1, \sqrt{\max(0, \lambda_*/N)/(\tilde{k}-1)})$ を単調写像により算出し、区間端点 $0 \le \tilde{V}_L \le \tilde{V}_U \le 1$ を保証する

#### Scenario: 退化表・小標本時のフォールバック
- **WHEN** 有効次元 $\tilde{k} \le 1$、標本サイズ極小（$N \le df + 1$）、または数値求根が不収束となる
- **THEN** `cramers_v_corrected_ci` を `null` とし、`quality_warnings` に理由コードを記録する

### Requirement: 多項 Dirichlet 事後推論と不確実性の定量化
システムは、分割表全体を多項分布モデルとし、対称 Dirichlet 事前分布（既定 $\alpha = 1.0$）に基づく共役事後分布からパラメータ推論および生成量を算出しなければならない（MUST）。点推定値のみで不確実性を省略してはならず、生ドローは永続化せず要約統計量のみを保持しなければならない。

#### Scenario: 条件付き確率および独立性からの乖離の事後要約
- **WHEN** Dirichlet 事後分布からモンテカルロドロー（既定 10,000 回、決定論的シード）を実行する
- **THEN** 結合確率 $\pi_{ij}$、行条件付き確率 $P(B|A)$、列条件付き確率 $P(A|B)$、および局所独立性からの事後乖離 $D_{ij} = \log(\pi_{ij} / (\pi_{i+}\pi_{+j}))$ の事後平均、事後中央値、95% 等裾信用区間（ETI: [Q2.5, Q97.5]）、区間幅、および方向確率 $P(D>0 \mid data)$ を算出し、生ドローは破棄して要約統計量のみを保持する

#### Scenario: 事前分布感度分析の実行
- **WHEN** 事前分布感度分析が有効化されている
- **THEN** 代替事前分布（$\alpha = 0.5$）における 95% 信用区間および中央値を比較用に算出し、主結果（$\alpha = 1.0$）の結論安定性を評価可能にする

### Requirement: Interface 3.0 結果契約（JSON）
解析結果は `interface_version = "3.0"` および `schema = "two-way-results-v2"` に準拠した構造化 JSON（`categorical_results.json`）として出力されなければならない（MUST）。旧式の `Evidence Score = r² - k log(N)` は完全に廃止し出力に含めてはならない。

#### Scenario: 結果 JSON の妥当性検証
- **WHEN** 解析スクリプトが完了する
- **THEN** 生成された JSON に `global`（Pearson $\chi^2$, $G^2$, `cramers_v`, `cramers_v_ci`, `cramers_v_corrected`, `cramers_v_corrected_ci`）、`cells`（効果量、残差、証拠、影響度、安定性）、`posterior`（事前分布、結合、行/列条件付き、独立性乖離）、`quality`、および `provenance` の各キーが存在し、スキーマ定義に合致することを検証する

### Requirement: 完全オフライン Scientific Dashboard の生成と機械的受入検査
システムは、外部 CDN、リモートウェブフォント、外部スクリプトへの依存を一切排除した完全自己完結型 HTML として Scientific Dashboard を生成しなければならない（MUST）。生成された HTML に対しては、外部 URL / CDN の混入を機械的に検出・拒否する静的検査を実施しなければならない。

#### Scenario: 生成 HTML に対する外部リソース混入の静的スキャン
- **WHEN** Dashboard HTML がレンダリングされる
- **THEN** HTML ソース内に `http://` または `https://` で始まる外部 URL（DataTables 日本語辞書 CDN 等）が存在しないことを静的検査し、外部通信依存が検出された場合はテストを失敗させる

#### Scenario: ダッシュボードのオフライン閲覧とコンポーネント構造
- **WHEN** インターネット非接続環境で生成された Dashboard HTML を開く
- **THEN** すべての CSS、JS、数式フォント（KaTeX）、インライン日本語辞書付きデータテーブルがローカルリソースで正常に描画され、Effect × Evidence 散布図、残差ヒートマップ、Bayesian Credible Box、信用区間幅ランキング、セルエクスプローラー、および構造確認用 Mosaic プロットが正しく対話操作可能である

### Requirement: AI Narrative とレポートの品質契約
AI 考察およびレポート生成は、所定の評価順序（全体関連 $\to$ 効果量 $\to$ 証拠 $\to$ 影響度・安定性 $\to$ 事後不確実性 $\to$ 実務解釈 $\to$ 制約）を遵守し、$p$ 値単独判定や無条件の因果主張を行ってはならない（MUST）。

#### Scenario: 隔離セルの解釈
- **WHEN** 分析結果に `QUARANTINED` 状態のセルが含まれる
- **THEN** AI 考察およびレポートは当該セルの推定が小度数や高レバレッジにより不安定であることを明示し、確定的な効果量や証拠として解釈しない
