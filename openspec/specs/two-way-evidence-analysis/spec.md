# two-way-evidence-analysis Specification

## Purpose

2次元名義分割表の解析において、効果量（Effect）、統計的証拠（Evidence）、影響度（Influence）、推定安定性（Stability）、事後不確実性（Posterior Uncertainty）の5軸を分離した統計診断と、多項Dirichlet事後推論、Interface 3.0結果契約、および完全オフラインのScientific Dashboardを提供する。

## Requirements

### Requirement: 入力受入境界と構造的ゼロの禁止

システムは、完全な2次元名義分割表（Complete 2-way contingency table）のみを入力として受入・処理しなければならない（MUST）。次元数が3以上、各軸水準数が2未満、総度数が0、いずれかの行和または列和が0（ゼロマージン）、または度数が有限非負整数でない入力はフェイルファストで拒否しなければならない。また、理論的・生理学的に発生不可能な構造的ゼロ（不完全分割表）は本エンジンの対象外（OutOfScope）とし、入力禁止として扱わなければならない。解析実行前には共有Pass 0プロベナンス検証を実行し、さらにあらゆるデータ集約・モデル適合処理に先行して入力テーブル検証を完了しなければならない。

#### Scenario: 3次元以上の入力に対するフェイルファスト拒否と正本委譲

- **WHEN** 3次元以上の分割表（arity $\ge 3$）が入力される
- **THEN** 解析計算を行わずに即時停止し、`run_state.json` に `status: "failed"` および `error_code: "INVALID_INPUT_ARITY"` を記録し、3次元以上の解析は正本スキル `vcd-bayesian-evidence-analysis` を使用すべき旨のエラーメッセージを出力する

#### Scenario: 構造的ゼロ指定時のフェイルファスト拒否

- **WHEN** 入力データまたは設定において構造的ゼロ（発生不能セル）が指定される
- **THEN** 即時停止し、`run_state.json` に `status: "failed"` および `error_code: "STRUCTURAL_ZERO_NOT_SUPPORTED"` を記録し、準独立モデル等専用の解析手続きを案内する

#### Scenario: ゼロマージン表のフェイルファスト拒否

- **WHEN** いずれかの行和または列和が 0 である分割表（空カテゴリが存在する表）が入力される
- **THEN** 即時停止し、`run_state.json` に `status: "failed"` および `error_code: "ZERO_MARGIN_DETECTED"` を記録し、空水準の除外または再定義を案内する

#### Scenario: 入力度数形式の検証

- **WHEN** 負の度数、非有限値（NA/NaN/Inf）、非整数重み度数、または総度数 $N=0$ の表が入力される
- **THEN** 入力検証段階で即時停止し、該当するエラーコード（`NON_INTEGER_COUNTS`, `ZERO_TOTAL_COUNT` 等）を記録して終了する

#### Scenario: Pass 0 必須契約およびプロベナンス先行検証

- **WHEN** canonical 実行（`vcd-categorical-analysis`）を開始する
- **THEN** `analysis_config.json` の指定を必須とし、設定未指定時は `MISSING_REQUIRED_CONFIG` で即時停止する。指定時は共有モジュール `pass0_contract.R` の `validate_pass0_provenance()` を呼び出し、入力CSVのSHA-256、設定内の `input_sha256`、および対象スキル `vcd-categorical-analysis` の一致を検証し、ハッシュ不一致時は `PROVENANCE_SHA_MISMATCH`、スキル不一致時は `TARGET_SKILL_MISMATCH` で即時停止する

#### Scenario: input_mode 安全契約と誤入力の即時遮断

- **WHEN** 入力データの集約モード（`input_mode`）を判定・検証する
- **THEN** 以下の規則を厳格に適用し、暗黙のフォールバック（`Freq=1`）を一切行わずに即時停止する：
  1. `input_mode: "aggregated"` の場合：頻度列（freq 列）の指定が必須。未指定、タイポ、不在時は即時停止し、`run_state.json` に `status: "failed"` および `error_code: "MISSING_FREQUENCY_COLUMN"` を記録する。
  2. `input_mode: "individual"` の場合：頻度列の指定は明示的に禁止（PROHIBITED）。頻度列が引数や設定で指定された場合、または列として検出された場合は誤設定検知として即時停止し、`run_state.json` に `status: "failed"` および `error_code: "FREQUENCY_COLUMN_NOT_PERMITTED"` を記録する（無視や暗黙除外は行わない）。
  3. `input_mode` が未指定、欠損、または未知値の場合は即時停止し、`run_state.json` に `status: "failed"` および `error_code: "INVALID_INPUT_MODE"` を記録する。

#### Scenario: データ集約処理に先行する入力検証

- **WHEN** `--render` パスで解析を実行する
- **THEN** `sum(..., na.rm=TRUE)` 等による集約やプロファイリングを行う前に `validate_input_table()` を実行し、不正な度数データによる情報の暗黙喪失を防止する

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

システムは、大標本時の過剰検出を抑制するため、効果の大きさと証拠の強さの双方を同時に満たすセルを探索的候補（Exploratory dual-filter candidate）として抽出しなければならない（MUST）。標本サイズ $N < 2000$ の場合は Dual-Filter による candidate は付与してはならず、ゼロ観測セルおよび隔離セルは候補判定から除外しなければならない。

#### Scenario: 大標本閾値に基づく候補抽出と隔離セルの除外

- **WHEN** 標本サイズ $N \ge 2000$ かつセルが非隔離（regular）である
- **THEN** $|\log(O/E)| \ge 0.50$ かつ $T^{\rm score} \ge 3.84$ の両方を満たすセルのみを dual-filter candidate として識別し、$O=0$ または Quarantine 状態のセルは候補から除外する

#### Scenario: 小標本時における Dual-Filter 候補付与の抑止

- **WHEN** 標本サイズ $N < 2000$ である
- **THEN** セルの効果量やスコア統計量に関わらず、すべてのセルで `dual_filter_candidate` を `FALSE` とする

### Requirement: グローバル関連度と Cramér's V 信頼区間の厳密算定

システムは、全体関連の統計量（Pearson $\chi^2$, $G^2$, Cramér's V）を算出するとともに、非心カイ二乗分布の反転による解析的 95% 信頼区間を算出しなければならない（MUST）。未補正推定量に対する区間と Bergsma (2013) bias-corrected 推定量に対する区間を明確に分離して出力しなければならない。

#### Scenario: 非心カイ二乗反転による信頼区間導出と単調写像

- **WHEN** 観測カイ二乗統計量 $X^2$ から母集団非心パラメータ $\lambda$ の 95% 信頼区間 $[\lambda_L, \lambda_U]$ を導出する
- **THEN** 累積分布関数の求根により $0 \le \lambda_L \le \lambda_U$ を得た上で、未補正区間 $V_* = \sqrt{(\lambda_*/N)/(k-1)}$ および bias-corrected 区間 $\tilde{V}_* = \min(1, \sqrt{\max(0, \lambda_*/N)/(\tilde{k}-1)})$ を単調写像により算出し、区間端点 $0 \le \tilde{V}_L \le \tilde{V}_U \le 1$ を保証する

#### Scenario: 退化表・小標本時のフォールバック

- **WHEN** 有効次元 $\tilde{k} \le 1$、標本サイズ極小（$N \le df + 1$）、または数値求根が不収束となる
- **THEN** `cramers_v_corrected_ci` を `null` とし、`quality_warnings` に理由コードを記録する

### Requirement: 多項 Dirichlet 事後推論と不確実性の定量化

システムは、分割表全体を多項分布モデルとし、対称 Dirichlet 事前分布（主事前 $\alpha = 1.0$）に基づく共役事後分布からパラメータ推論および生成量を算出しなければならない（MUST）。点推定値のみで不確実性を省略してはならず、生ドローは永続化せず要約統計量のみを保持しなければならない。既定のモンテカルロドロー数は 10,000 回とし、決定論的乱数シードにより完全再現可能でなければならない。

#### Scenario: 条件付き確率および独立性からの乖離の事後要約

- **WHEN** Dirichlet 事後分布からモンテカルロドロー（既定 10,000 回、決定論的シード）を実行する
- **THEN** 結合確率 $\pi_{ij}$、行条件付き確率 $P(B|A)$、列条件付き確率 $P(A|B)$、および局所独立性からの事後乖離 $D_{ij} = \log(\pi_{ij} / (\pi_{i+}\pi_{+j}))$ の事後平均、事後中央値、95% 等裾信用区間（ETI: [Q2.5, Q97.5]）、区間幅、および方向確率 $P(D>0 \mid data)$ を算出し、生ドローは破棄して要約統計量のみを保持する

#### Scenario: 事前分布感度分析の実行

- **WHEN** 事前分布感度分析が有効化されている
- **THEN** 代替事前分布（$\alpha = 0.5$）における事後中央値および 95% ETI を算出し、主事前（$\alpha = 1.0$）との区間幅および中央値シフトの比較要約を `sensitivity_analysis` に保持し、結論の頑健性を評価可能にする

#### Scenario: practical delta の既定無効化

- **WHEN** 設定で `practical_delta` が明示的に指定されていない場合
- **THEN** 実務差確率 $P(|D| > \delta)$ の計算を抑止し、`practical_delta` および関連フィールドを `null` として出力し、恣意的な閾値による自動重要度判定を排除する

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

### Requirement: 期待度数診断（Expected-Count Diagnostics）

システムは、分割表モデルの統計的妥当性を担保するため、行和・列和から算出される期待度数 $E_{ij} = (n_{i+} n_{+j}) / N$ の分布を診断し、Cochran 条件に基づく妥当性指標を結果成果物に出力しなければならない（MUST）。

#### Scenario: Cochran 条件の診断と要約

- **WHEN** 独立モデル適合時の期待度数を計算する
- **THEN** 全セルの期待度数を算出し、(1) 最小期待度数 $\min(E_{ij})$、(2) $E_{ij} < 5$ であるセルの割合、(3) Cochran 条件充足フラグ（$E_{ij} < 1$ のセルが 0 かつ $E_{ij} < 5$ のセルが 20% 以下）を診断して `expected_count_diagnostics` として記録する

### Requirement: 決定論的解析署名と拡張 Provenance

システムは、単一の決定論的 SHA-256 署名（Canonical Analysis Signature）を生成し、実行ディレクトリ、乱数シード導出、結果成果物、およびダッシュボードへ同一値を供給しなければならない（MUST）。また、完全な監査再現性を担保するため、拡張 provenance 情報を成果物に記録しなければならない。

#### Scenario: Canonical Signature の一意生成と伝播

- **WHEN** 解析実行が初期化される
- **THEN** `engine_version`、入力 CSV の SHA-256、設定ファイルの SHA-256、変数名、頻度列指定、事前分布パラメータ、閾値設定から `analysis_signature` を単一算出（SHA-256）し、ディレクトリ名、乱数シード、JSON メタデータ、ダッシュボードに同一値を埋め込む

#### Scenario: 拡張 Provenance および環境情報の記録

- **WHEN** 解析結果成果物（`categorical_results.json` / `evidence_profile.json`）を生成する
- **THEN** `provenance` ブロックに入力ファイルの SHA-256、設定ファイルの SHA-256、R バージョン、プラットフォーム、乱数シード、タイムスタンプ（JST）を漏れなく記録する

### Requirement: 成果物 Schema 不変量検証と Run State ライフサイクル管理

システムは、生成される Interface 3.0 成果物の構造および統計的一貫性を厳格に保証し、実行ライフサイクルの状態遷移を `run_state.json` に記録しなければならない（MUST）。

#### Scenario: 成果物 JSON の Cross-Field Invariant 検証

- **WHEN** 解析結果 JSON をシリアライズする
- **THEN** シリアライザは出力直前に以下の不変量を検証し、違反時はフェイルファストで停止する：
  1. 推定結合確率の総和が $1.0 \pm 10^{-6}$ であること。
  2. 事後信用区間において $\text{Q2.5} \le \text{median} \le \text{Q97.5}$ が全セルで成立すること。
  3. `evidence_profile.json` と `categorical_results.json` のキー整合性（`analysis_signature`, `run_id`, 全セル識別キー集合の一致）が保たれていること。違反時はエラーコード `SCHEMA_INVARIANT_VIOLATION` でフェイルファスト停止する。

#### Scenario: Run State ライフサイクルの確定記録

- **WHEN** 解析プロセスの各フェーズ（開始、失敗、成功）を遷移する
- **THEN** `run_state.json` を更新し、開始時は `status: "running"`、異常終了時は `status: "failed"` および確定 `error_code` とメッセージ、正常完了時は `status: "completed"`、`run_id`、および成果物ファイル一覧を記録する
