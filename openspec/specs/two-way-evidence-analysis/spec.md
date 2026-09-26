# two-way-evidence-analysis Specification

## Purpose

2次元名義分割表の解析において、効果量（Effect）、統計的証拠（Evidence）、影響度（Influence）、推定安定性（Stability）、事後不確実性（Posterior Uncertainty）の5軸を分離した統計診断と、多項Dirichlet事後推論、Interface 3.0結果契約、および完全オフラインのScientific Dashboardを提供する。

## Requirements

### Requirement: 入力受入境界と構造的ゼロの禁止

システムは、完全な2次元名義分割表（Complete 2-way contingency table）のみを入力として受入・処理しなければならない（MUST）。次元数が3以上、各軸水準数が2未満、総度数が0、いずれかの行和または列和が0（ゼロマージン）、または度数が有限非負整数でない入力はフェイルファストで拒否しなければならない。また、理論的・生理学的に発生不可能な構造的ゼロ（不完全分割表）は本エンジンの対象外（OutOfScope）とし、入力禁止として扱わなければならない。Canonical実行は、Pass 0で確定した設定と入力を唯一の解析条件とし、あらゆるデータ集約・モデル適合・解析署名算出に先行してprovenance検証と入力テーブル検証を完了しなければならない。

#### Scenario: 3次元以上の入力に対するフェイルファスト拒否と正本委譲

- **WHEN** 3次元以上の分割表（arity \(\ge 3\)）が入力される
- **THEN** 解析計算を行わずに即時停止し、`run_state.json` に `status: "failed"` および `error_code: "INVALID_INPUT_ARITY"` を記録し、3次元以上の解析は正本スキル `vcd-bayesian-evidence-analysis` を使用すべき旨のエラーメッセージを出力する

#### Scenario: 構造的ゼロ指定時のフェイルファスト拒否

- **WHEN** 入力データまたは設定において構造的ゼロ（発生不能セル）が指定される
- **THEN** 即時停止し、`run_state.json` に `status: "failed"` および `error_code: "STRUCTURAL_ZERO_NOT_SUPPORTED"` を記録し、準独立モデル等専用の解析手続きを案内する

#### Scenario: ゼロマージン表のフェイルファスト拒否

- **WHEN** いずれかの行和または列和が0である分割表（空カテゴリが存在する表）が入力される
- **THEN** 即時停止し、`run_state.json` に `status: "failed"` および `error_code: "ZERO_MARGIN_DETECTED"` を記録し、空水準の除外または再定義を案内する

#### Scenario: 入力度数形式の検証

- **WHEN** 負の度数、非有限値（NA/NaN/Inf）、非整数重み度数、または総度数 \(N=0\) の表が入力される
- **THEN** 入力検証段階で即時停止し、該当するエラーコード（`NON_INTEGER_COUNTS`, `ZERO_TOTAL_COUNT` 等）を記録して終了する

#### Scenario: Pass 0 必須契約およびプロベナンス先行検証

- **WHEN** canonical実行（`vcd-categorical-analysis`）を開始する
- **THEN** `analysis_config.json` の指定を必須とし、設定未指定時は `MISSING_REQUIRED_CONFIG` で即時停止する。指定時は共有Pass 0 provenance契約により、設定で参照された入力CSVのSHA-256、設定内の `input_sha256`、Pass 0 inspectionの入力SHA-256、および対象スキル `vcd-categorical-analysis` の一致を、解析署名算出前に検証する。ハッシュ不一致時は `PROVENANCE_SHA_MISMATCH`、スキル不一致時は `TARGET_SKILL_MISMATCH` で即時停止する

#### Scenario: Pass 0 確定設定の整合性検証（運用上の信頼済み正本照合）

- **WHEN** Pass 0 確定後に `analysis_config.json` 内の解析設定（`vars`、`freq`、`input_mode`、`practical_delta` 等）が変更された状態で canonical 実行が呼び出される
- **THEN** Pass 0 検分成果物（`inspection_results.json`）を運用上の信頼済み正本とみなし、Core 内部で現在の解析パラメータから再算出した `canonical_config_sha256` が、設定ファイル内の `pass0_provenance$canonical_config_sha256` および `inspection_results.json` 内の承認値 `approved_config$canonical_config_sha256` の両方と一致することを検証する。いずれかの未束縛または不一致時は `PROVENANCE_CONFIG_MISMATCH` で即時停止し、解析署名算出および `run_<signature>` ディレクトリ作成を一切行わない

#### Scenario: Canonical CLI 上書きおよび未知引数のホワイトリスト拒否

- **WHEN** canonical実行（`analysis.R`）において、ホワイトリスト許可引数（`--config`, `--out`, `--label`, `--help`）以外の引数（`--data`, `--vars`, `--freq`, `--input-mode`, `--prior-alpha`, `--practical-delta` 等の解析変更型引数、および未知引数）が指定される
- **THEN** システムは `CANONICAL_CONFIG_OVERRIDE_FORBIDDEN` を記録して非ゼロ終了し、解析署名、`run_<signature>` ディレクトリ、集約済みデータ、結果JSON、Dashboardを一切生成してはならない。失敗状態の記録は、指定出力root直下の `run_state.json` に限定する

#### Scenario: input_mode 安全契約と誤入力の即時遮断

- **WHEN** 入力データの集約モード（`input_mode`）を判定・検証する
- **THEN** 解析署名算出および `run_<signature>` ディレクトリ作成に先行して以下の規則を厳格に適用し、暗黙のフォールバック（`Freq=1`）を一切行わずに即時停止する：
  1. `input_mode: "aggregated"` の場合：頻度列（freq列）の指定が必須。未指定、タイポ、不在時は即時停止し、出力root直下の `run_state.json` に `status: "failed"` および `error_code: "MISSING_FREQUENCY_COLUMN"` を記録する。
  2. `input_mode: "individual"` の場合：頻度列の指定は明示的に禁止（PROHIBITED）。頻度列が設定で指定された場合、または列として検出された場合は誤設定検知として即時停止し、出力root直下の `run_state.json` に `status: "failed"` および `error_code: "FREQUENCY_COLUMN_NOT_PERMITTED"` を記録する（無視や暗黙除外は行わない）。
  3. `input_mode` が未指定、欠損、または未知値の場合は即時停止し、出力root直下の `run_state.json` に `status: "failed"` および `error_code: "INVALID_INPUT_MODE"` を記録する。

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

システムは、分割表全体を多項分布モデルとし、フィッシャー情報行列に基づくパラメータ変換不変性を備えた多項Jeffreys事前分布（主事前 \(\alpha = 0.5\)）に基づく共役事後分布からパラメータ推論および生成量を算出しなければならない（MUST）。点推定値のみで不確実性を省略してはならず、生ドローは永続化せず要約統計量のみを保持しなければならない。既定のモンテカルロドロー数は10,000回とし、決定論的乱数シードにより完全再現可能でなければならない。

#### Scenario: 条件付き確率および独立性からの乖離の事後要約

- **WHEN** Dirichlet事後分布からモンテカルロドロー（既定10,000回、決定論的シード）を実行する
- **THEN** 結合確率 \(\pi_{ij}\)、行条件付き確率 \(P(B=j\mid A=i)\)、列条件付き確率 \(P(A=i\mid B=j)\)、および局所独立性からの事後乖離 \(D_{ij}=\log(\pi_{ij}/(\pi_{i+}\pi_{+j}))\) を算出し、生ドローは破棄して要約統計量のみを保持する

#### Scenario: 条件付き事後要約の完全性

- **WHEN** 行条件付き確率または列条件付き確率を成果物へ出力する
- **THEN** 各セルについて、丸め前drawから算出した平均、標準偏差、中央値、q025、q975、および `eti_width = q975 - q025` を保持し、`0 <= probability <= 1`、`q025 <= median <= q975`、`eti_width >= 0` を満たす

#### Scenario: 条件付き確率の総和不変量

- **WHEN** 条件付き事後確率の数値整合性を検証する
- **THEN** 数理エンジン内部において各モンテカルロdrawの \(\sum_j P(B=j\mid A=i)\) と \(\sum_i P(A=i\mid B=j)\)、ならびに丸め前の各条件付き事後平均の対応する総和が、浮動小数点許容差 \(10^{-12}\) 内で1となることを検証し、Serializer出力直前には丸め累積誤差を考慮した許容差 \(K \times 10^{-6}\) で検証する。違反時は `SCHEMA_INVARIANT_VIOLATION` で停止する

#### Scenario: 非線形要約を総和不変量から除外する

- **WHEN** 条件付き事後中央値または分位点を検証する
- **THEN** システムは確率範囲と分位点順序を検証するが、中央値・q025・q975の行和または列和が1であることを要求してはならない

#### Scenario: 主事前自己記述メタデータと統計的意味論

- **WHEN** 事後推論結果をシリアライズする
- **THEN** `posterior.prior_specification` に `family: "symmetric_dirichlet"`, `alpha: 0.5`, `role: "primary"`, `name: "jeffreys"` を記録し、感度分析側にも `sensitivity_alpha: 1.0` を記録する。成果物は自己記述的であり、主事前分布が異なる成果物同士を同一推定量として直接比較してはならない境界を明示する

#### Scenario: 事前分布感度分析の実行

- **WHEN** 事前分布感度分析（主事前 \(\alpha = 0.5\)、対照事前 \(\alpha = 1.0\)）を成果物へ出力する
- **THEN** 恣意的な閾値による自動二値判定（`is_sensitive` boolean 等）を排除し、数値要約（`max_absolute_mean_diff`, `max_median_shift`, `max_eti_width_diff`）のみを保持する。各セル比較 `cell_comparisons[*]` には `primary_median`, `sensitivity_median`, `median_shift`（絶対値差）, `primary_eti_width`, `sensitivity_eti_width`, `eti_width_difference`（符号付き: 感度側幅 - 主側幅）を漏れなく保持し、下流Dashboardが独自再計算を行わずに直接描画できるようにする

#### Scenario: 局所独立性対数乖離および不確実性ランキングの契約

- **WHEN** 局所独立性乖離および不確実性ランキングをシリアライズする
- **THEN** `posterior.cell_posteriors[*]` に `log_divergence_mean`, `log_divergence_median`, `log_divergence_q025`, `log_divergence_q975`, `log_divergence_eti_width`, `prob_dir_positive`, `prob_practical_delta` を数値型（未指定時はnull）として出力する。不確実性ランキングは `prob_eti_width` 降順 $\to$ `observed` 昇順 $\to$ `row_level` 昇順 $\to$ `col_level` 昇順の決定論的ソート規則を満たす

#### Scenario: practical delta の既定無効化

- **WHEN** 実務差閾値 `practical_delta` を処理する
- **THEN** 設定で未指定（null）の場合は計算を抑止して `null` を出力し、恣意的な閾値による自動重要度判定を排除する。有効値（\(0 < \delta < 1\)）の場合は絶対結合確率乖離の超過確率 \(P(|\pi_{ij} - \pi_{i+}\pi_{+j}| > \delta \mid \mathrm{data})\) を計算する。0、負値、1以上、非数値、または非有限値が指定された場合は入力境界エラーとして fail-fast で即時停止し、null への暗黙フォールバックをしてはならない

### Requirement: Interface 3.0 結果契約（JSON）

解析結果は `interface_version = "3.0"` および `schema = "two-way-results-v2"` に準拠した構造化 JSON（`categorical_results.json`）として出力されなければならない（MUST）。旧式の `Evidence Score = r² - k log(N)` は完全に廃止し出力に含めてはならない。既存readerとの互換性を保てる場合、条件付き事後のフィールドは既存の `posterior` 構造への加法的拡張として提供しなければならない。

#### Scenario: 結果 JSON の妥当性検証

- **WHEN** 解析スクリプトが完了する
- **THEN** 生成された JSON に `global`（Pearson $\chi^2$, $G^2$, `cramers_v`, `cramers_v_ci`, `cramers_v_corrected`, `cramers_v_corrected_ci`）、`cells`（効果量、残差、証拠、影響度、安定性）、`posterior`（事前分布、結合、行/列条件付き、独立性乖離）、`quality`、および `provenance` の各キーが存在し、スキーマ定義に合致することを検証する

#### Scenario: 条件付き事後フィールドの機械可読な伝播

- **WHEN** 条件付き事後要約をシリアライズする
- **THEN** 結果JSONと必要なセル単位表形式出力は、行水準・列水準と一意に対応する両方向の条件付き事後要約を同じ丸め規則で保持し、JSON Schema、serializer、下流reader間でフィールド名・型・null表現が一致する

### Requirement: 完全オフライン Scientific Dashboard の生成と機械的受入検査

システムは、外部CDN、リモートウェブフォント、外部スクリプトへの依存を一切排除した完全自己完結型HTMLとしてScientific Dashboardを生成しなければならない（MUST）。Dashboardは、Effect、頻度論的局所逸脱、条件付き事後、不確実性、独立性からの事後乖離、事前感度が異なる問いであることを明示しなければならない。生成HTMLに対しては、外部URL/CDNおよび絶対ローカルパスの混入を機械的に検出・拒否する静的検査を実施しなければならない。

#### Scenario: 11セクションの統計的責務分離

- **WHEN** 2次元名義分割表のDashboardを生成する
- **THEN** Executive Summary、Global Association & Effect Size、Effect × Evidence、Adjusted Residual Structure、Cell Explorer、Joint Posterior、Conditional Posterior、Uncertainty Ranking、Posterior Departure from Independence、Prior Sensitivity、Quality & Provenanceを表示し、各新規視座の先頭に日本語で「この図が答える統計的・科学的問い」と解釈上の限界を表示する。Section 11（Quality & Provenance）には先行Change 1/2で確定した `execution_mode: "canonical"`、三者SHA再検証状態、決定論的乱数シード、解析署名を表示する

#### Scenario: 条件付き事後を予測確率として表示する

- **WHEN** 条件付き事後要約を含む結果をDashboardへ読み込む
- **THEN** `P(B|A)` と `P(A|B)` を区別して表示し、中央値と95% ETIを主表示、平均を補助表示として、条件付き中央値・分位点の総和を1と解釈してはならない旨を明示する

#### Scenario: 局所診断・不確実性・乖離・感度の解釈を分離する

- **WHEN** Adjusted Residual、Uncertainty Ranking、Posterior Departure、Prior Sensitivityを表示する
- **THEN** adjusted residualを効果量そのものとして表示せず、ETI幅を重要性または有意性として表示せず、対数乖離の区間が0をまたぐかだけで自動二値判定をせず、alpha=1.0と0.5の差をモデル誤りの自動判定として表示しない

#### Scenario: 表サイズに応じた全件アクセス可能なフォールバック

- **WHEN** カテゴリ数またはセル数が表示閾値を超える表をDashboardに表示する
- **THEN** システムは決定論的な選定規則によるTop-N表示を用いても、選定規則・非表示セル数を表示し、フィルタ可能な全件表または全件CSVへの導線を提供する

#### Scenario: 生成 HTML に対する外部リソース混入の静的スキャン

- **WHEN** Dashboard HTMLがレンダリングされる
- **THEN** HTMLソース内の `script src`, `link href`, `<img> src`, iframe, CSS `url(...)`, `fetch()`, `XMLHttpRequest` において、外部通信プロトコル（`http:`, `https:`, ネットワークスキーム `//`）、およびOSローカル絶対パス（`/Users/`, `/home/`, `/private/var/`, Windowsドライブ形式 `^[A-Za-z]:`）が存在しないことを静的検査し、検出時は受入テストを失敗させる

#### Scenario: ダッシュボードのオフライン閲覧とコンポーネント構造

- **WHEN** インターネット非接続環境で生成されたDashboard HTMLを開く
- **THEN** CSS、JS、数式表示、日本語のデータテーブルが外部通信なしに描画され、主要図表・全件表・大規模表フォールバックが閲覧でき、数式または拡張機能が使えない場合は日本語で読める代替説明を表示する

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

システムは、単一の決定論的SHA-256署名（Canonical Analysis Signature）を生成し、実行ディレクトリ、乱数シード導出、結果成果物、およびDashboardへ同一値を供給しなければならない（MUST）。Canonical signatureは、Pass 0で承認され、実ファイルSHAを再検証済みのcanonicalized入力・設定からのみ算出し、算出後に解析条件を変更してはならない。また、完全な監査再現性を担保するため、拡張provenance情報を `run_state.json` および成果物に記録しなければならない。

#### Scenario: Canonical Signature の一意生成と伝播

- **WHEN** canonical解析実行を初期化する
- **THEN** 再検証済みの `engine_version`、実入力CSVの生ハッシュ `input_sha256`、正規化された解析設定ダイジェスト `canonical_config_sha256`（変数名、頻度列指定、入力モード、事前分布パラメータ、閾値設定を含む）、および成果物名に反映される `data_label` から `analysis_signature` を単一算出（SHA-256）し、ディレクトリ名（`run_<first16>`）、乱数シード、JSONメタデータ、Dashboardに同一値を埋め込む。label が異なる場合は異なる署名・別ディレクトリとして分離し、署名算出後にCLIまたは内部処理でこれらの値を変更してはならない

#### Scenario: 拡張 Provenance および環境情報の記録

- **WHEN** Canonical解析プロセスのライフサイクル（開始・失敗・成功）および解析結果成果物を生成する
- **THEN** `run_state.json` に実行モード（`execution_mode: "canonical"`）、Pass 0 由来の検証状態（`provenance_status: "verified"`）、実入力ファイルSHA（`input_sha256`）、ディスク上の設定ファイル生ハッシュ（`config_file_sha256`）、タイムスタンプ（JST）を記録する。成果物JSONの既存 `provenance` ブロックへの整合を維持し、次Change（条件付き事後契約）へのハンドオフ境界とする

### Requirement: 成果物 Schema 不変量検証と Run State ライフサイクル管理

システムは、生成されるInterface 3.0成果物の構造および統計的一貫性を厳格に保証し、実行ライフサイクルの状態遷移を `run_state.json` に記録しなければならない（MUST）。Canonical実行の失敗時は、失敗内容を監査可能に記録しつつ、正常完了を示すrun成果物を残してはならない。

#### Scenario: 成果物 JSON の Cross-Field Invariant 検証

- **WHEN** 解析結果JSONをシリアライズする
- **THEN** serializerは canonical 実行専用とし（`execution_mode = "canonical"` のみ受入）、出力直前に推定結合確率の総和、結合確率の信用区間順序、条件付き事後の確率範囲・分位点順序・平均の総和、`evidence_profile.json` と `categorical_results.json` の `analysis_signature`・`run_id`・全セル識別キー集合、64桁の有効な `analysis_signature`・`input_sha256`・`config_sha256`（フォールバック代替生成の禁止。Canonical Core で再検証済みの `canonical_config_sha256` を受け取って記録すること）、および `provenance` ブロックの `execution_mode: "canonical"` を検証し、違反時は `SCHEMA_INVARIANT_VIOLATION` で停止する。Pass 0 承認ハッシュと最終成果物 `provenance.config_sha256` の一致は E2E 検証で保証する

#### Scenario: Run State ライフサイクルの確定記録

- **WHEN** 解析プロセスの各フェーズ（開始、失敗、成功）を遷移する
- **THEN** `run_state.json` を更新し、署名算出前の早期失敗時は出力root直下に `status: "failed"`、確定 `error_code`、`phase: "gateway"`、および明示的な `run_id: null`、`analysis_signature: null` を記録する。同一署名・同一出力 root の並行実行開始時は原子的排他ロック（`.run_lock`）の取得を試み、先行プロセスが実行中であれば後続プロセスは `status: "failed"`、`error_code: "CONCURRENT_RUN_IN_PROGRESS"` を出力root直下に記録して即時非ゼロ終了する。ロック取得成功後の実行開始時は `status: "running"`、異常終了時は `status: "failed"` を記録する。正常完了時は `status: "completed"`、`run_id`、および成果物ファイル一覧を記録し、終了時に原子的ロックを解放する。強制終了等でロックが残存（stale lock）した場合は手動削除により復旧する

### Requirement: 実行モード分離と Development 境界

システムは、canonical 解析実行と内部テスト専用の development 実行を厳格に分離しなければならない（MUST）。development 実行モードはインメモリ専用とし、本番成果物や `run_<signature>` ディレクトリをディスク上に一切生成してはならない。また、Canonical Core は呼び出し元のフラグのみに依存せず、独立した三者 SHA 再検証を行わなければならない。

#### Scenario: Development 実行モードによる本番成果物および run ディレクトリ生成の抑止

- **WHEN** コア関数が内部開発・テスト用として `execution_mode: "development"` で呼び出される
- **THEN** ディスク上に本番成果物（`categorical_results.json`、`evidence_profile.json`、Dashboard HTML 等）および `run_<signature>` ディレクトリを一切生成せず、インメモリの計算結果リストのみを返す。本番 Canonical 成果物との混同や誤認を防止する

#### Scenario: Canonical Core における偽造フラグおよび未検証設定の拒否

- **WHEN** `execution_mode: "canonical"` でコア関数が呼び出される
- **THEN** 呼び出し元のフラグのみに依存せず、Core 内部で必ず Pass 0 inspection、設定、実入力ファイルの独立三者 SHA 再検証を実行する。検証未完了、SHA 不一致、または偽造フラグが付与された設定が渡された場合は、即座に `PROVENANCE_SHA_MISMATCH` または `CANONICAL_CONFIG_VERIFICATION_REQUIRED` でフェイルファスト停止する

### Requirement: 2次元正本経路と3次元委譲経路を明示する

利用者向けの説明、実行導線、および失敗時メッセージは、`vcd-categorical-analysis` が完全2次元専用であり、3次元以上の解析は `vcd-bayesian-evidence-analysis` を使用することを一貫して示さなければならない（MUST）。現行の正本レポート入口は `dashboard.Rmd` とし、旧 `report.Rmd` はレガシー互換資産として現行入口と区別しなければならない（MUST）。

#### Scenario: 利用者が3次元解析を選択する

- **WHEN** 利用者が3変数以上の集計表を解析しようとする
- **THEN** 2次元スキルを使用せず、`vcd-bayesian-evidence-analysis` のPass 0および3次元正本経路へ案内される

#### Scenario: レガシーテンプレートを参照する

- **WHEN** 利用者が `vcd-categorical-analysis/templates/report.Rmd` を参照する
- **THEN** 当該ファイルがv1.xのレガシー資産であり、現行canonical入口ではないこと、および3次元解析の正本ではないことを確認できる

### Requirement: 2次元の調整標準化残差を主診断表示として提供する

2次元Dashboardは、独立モデルからの局所的な統計的乖離を示す主診断表示として、Haberman型の調整標準化残差を用いたセルヒートマップまたは同等のセル表示を提供しなければならない（MUST）。調整標準化残差は、行・列周辺の推定による分散影響を調整した標準化残差として扱い、期待度数、レバレッジ、ゼロ観測、小期待度数、およびQuarantine状態と併記しなければならない（MUST）。残差の閾値は探索的な目安であり、実務的重要性、有意性、因果性、またはセルの採否を単独で自動判定してはならない（MUST）。

#### Scenario: 2次元Dashboardの主診断を生成する

- **WHEN** 有効な2次元分割表からDashboardを生成する
- **THEN** 調整標準化残差のセル表示と、効果量・不確実性・期待度数・安定性を確認できる表示または表が提供され、残差単独の結論を促す説明は表示されない

#### Scenario: 残差の解釈境界を表示する

- **WHEN** 調整標準化残差の色または数値をDashboardに表示する
- **THEN** 独立モデルからの統計的乖離を示す探索指標であり、効果量や臨床的重要性ではないこと、小期待度数・高レバレッジ・多重性の影響を受けること、およびQuarantineセルの解釈を保留することが確認できる

#### Scenario: モザイク図を現行主経路から外す

- **WHEN** 現行canonical Dashboardの主要図を選択する
- **THEN** モザイク図を必須成果物または主診断図として要求せず、残差・estimand・不確実性・効果量を主表示とする
