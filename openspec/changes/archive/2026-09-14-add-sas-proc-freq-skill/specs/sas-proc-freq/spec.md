## Purpose

SAS PROC FREQ の明示された集計規則、欠損処理、カイ二乗検定、Fisher正確検定、2×2効果量・信頼区間、Monte Carlo推定、および3点セット成果物（JSON/CSV/Markdownレポート）について、対象限定・参照環境明示・許容誤差付きの数値互換を提供する。

## ADDED Requirements

### Requirement: 入力契約、水準順序、およびゼロ度数・構造的ゼロの制御
システムは、非負整数の度数列（SASの `WEIGHT count;` 相当）を持つ集計表を正規入力として受理しなければならない（MUST）。度数列に負値、小数、欠損値、非有限値が含まれる場合は処理を直ちに拒否しなければならない（MUST）。
また、表の水準順序、ゼロ度数行、構造的ゼロ、および退化表について厳密な契約を適用しなければならない（MUST）。

#### Scenario: 負値または小数の度数が入力された場合
- **WHEN** 入力データの度数列に負数または小数が含まれる
- **THEN** 計算を開始せずに直ちに処理を停止し、明示的な入力検証エラー（`INVALID_COUNT_DATA`）を返す

#### Scenario: 水準順序の明示指定
- **WHEN** 入力設定の `tables` 内で `levels_order` が明示される
- **THEN** データの出現順や暗黙の辞書順置換を行わず、指定された水準順（行水準・列水準）で表および限界度数を構成する

#### Scenario: ゼロ度数行（count = 0）の入力とSAS ZEROS非サポート
- **WHEN** 入力データに度数0のレコードが存在する
- **THEN** SAS既定動作（`WEIGHT` 文で `ZEROS` オプション未指定時の挙動）に準拠し、度数0の行は集計セル生成時に除外する。未観測組み合わせを自動補完する `ZEROS` オプションは初回非サポート（Non-Goal）とする

#### Scenario: ゼロ周辺・退化表・0/0割合の処理
- **WHEN** 有効な分割表の行合計または列合計に0が存在するか、あるいは推測表が2行2列未満に退化する
- **THEN** 独立性検定および推測統計量の計算を停止し、値を `null` とし、理由コード（`DEGENERATE_TABLE_ZERO_MARGINAL` 等）を記録する。また 0/0 割合は 0 に置換せず `null`（理由: `INDETERMINATE_FRACTION_ZERO_DENOMINATOR`）を記録する

#### Scenario: 構造的ゼロの検出
- **WHEN** 入力設定で構造的ゼロ（`structural_zeros`）が定義されたセルが推測表に含まれる
- **THEN** 通常の独立性検定への投入を拒否し、`STRUCTURAL_ZERO_PRESENT` エラーまたは理由コードを返す

### Requirement: 欠損値モードと分母の独立制御
システムは、`exclude`（SAS既定）、`missprint`、`include`（MISSING指定）の3つの欠損処理モードをサポートしなければならない（MUST）。欠損除外判定は表要求（table request）ごとに独立して適用し、全要求の一括完全ケース除外（complete-case）を行ってはならない（MUST）。

#### Scenario: excludeモードでの集計
- **WHEN** `missing_mode` が `exclude` に指定される
- **THEN** 欠損セルを表から除外して有効度数を分母とし、除外された欠損度数を `excluded_missing_count` に保存する

#### Scenario: missprintモードでの集計
- **WHEN** `missing_mode` が `missprint` に指定される
- **THEN** 欠損水準を表に表示するが、割合計算および推測検定統計量の分母からは除外する

#### Scenario: includeモードでの集計
- **WHEN** `missing_mode` が `include` に指定される
- **THEN** 欠損水準を有効なカテゴリ水準として表および検定の分母に算入する

### Requirement: 分割表の独立性検定
システムは、Pearsonカイ二乗検定、尤度比カイ二乗検定（$G^2 = 2\sum O \log(O/E)$）、および2×2表の連続性補正カイ二乗検定（$Q_C = \sum [\max(0, |O-E|-0.5)]^2/E$）を提供しなければならない（MUST）。

#### Scenario: 2×2表の連続性補正計算
- **WHEN** 2×2表に対してカイ二乗検定（CHISQ）を要求する
- **THEN** Pearson統計量とは別に、SAS定義に準拠した連続性補正統計量およびP値を算出して出力する。標本サイズ $N$ や期待度数 $E$ による出力切替は行わない

#### Scenario: 尤度比カイ二乗における観測ゼロの扱い
- **WHEN** 分割表内に観測度数 $O_{ij} = 0$ のセルが存在する
- **THEN** 当該セルの $O \log(O/E)$ 寄与を厳密に0として扱い、数値エラーを回避して $G^2$ を算出する

### Requirement: 2×2表の効果量、比較方向、および区間推定
システムは、2×2表におけるオッズ比（OR）、相対リスク（RR列1および列2）と各対数Wald信頼区間、ならびに二項割合の信頼区間（Wald、Clopper-Pearson、Wilson）を算出しなければならない（MUST）。計算方向・イベント水準は設定で固定され、結果メタデータに明示されなければならない（MUST）。

#### Scenario: 2×2表の効果量と比較方向の明示
- **WHEN** 2×2表に対して効果量（MEASURES / RELRISK）を要求する
- **THEN** 設定キー `event_level`（列水準）および `comparison_direction`（例: 行1 vs 行2）に基づき、OR、RR列1、RR列2をそれぞれの標準誤差式（RRへのOR式流用厳禁）により算出する。出力結果には適用された行水準・列水準・イベント水準・比較方向を完全記録する

#### Scenario: 効果量におけるゼロセルの扱い
- **WHEN** 2×2表のいずれかのセルが0で、ORまたはRRの分母が0となる
- **THEN** 無断の 0.5 加算を行わず、値を `null` とし、理由コード `ZERO_CELL_UNDEFINED` を記録する

#### Scenario: 二項割合の区間推定
- **WHEN** 二項信頼区間の算出（BINOMIAL）を要求する
- **THEN** 指定された方式（Wald, Clopper-Pearson, Wilson）に基づき、対象水準（`binomial_level`、未指定時は表の先頭水準）について区間下限および上限を算出して出力する

### Requirement: Fisher正確検定（2×2 vs 一般表）と両側定義の分離
システムは、周辺度数固定の帰無分布に基づく正確検定（exact）を提供しなければならない（MUST）。表の次元（2×2か一般 $R \times C$ 表か）に応じて明確に分離された両側P値計算法を適用しなければならない（MUST）。

#### Scenario: 2×2表のFisher正確検定
- **WHEN** 2×2表に対して `fisher.method: "exact"` が要求される
- **THEN** 超幾何分布に基づき、観測表の確率 $P_{obs}$ 以下となる全可能表の確率の和（$\sum_{P(t) \le P_{obs}} P(t)$）として両側P値を算出する（片側2倍方式や mid-p を用いてはならない）

#### Scenario: 一般 $R \times C$ 表のFisher正確検定
- **WHEN** $R \times C$ 表に対して `fisher.method: "exact"` が要求される
- **THEN** 同一周辺度数を持つ全可能表の中で、観測表の多変量超幾何確率 $P_{obs}$ 以下の確率を持つ表の確率総和（Mehta & Patel ネットワーク法）として両側P値を算出する

### Requirement: 子プロセス監視による資源保護と状態コード
システムは、Unix プラットフォーム（macOS / Linux）環境において、正確検定の実行時に子プロセス監視を行い、設定された時間上限（`timeout_sec`）、メモリ上限（`max_memory_mb`）、およびワークスペース制限（`workspace_bytes`）を超過した場合は安全に子プロセスを強制停止（SIGTERM/SIGKILL）し、プロセスハングやメインセッションのクラッシュを防止しなければならない（MUST）。Windows 環境における資源監視は対象外（Non-Goal）とする。
また、`workspace` 引数は 2×2 表（超幾何直接計算）では不使用であり、一般 $R \times C$ 表（$R > 2$ または $C > 2$）の Exact 計算時にのみ、R の公式仕様である 4 バイト単位（$\min(\lfloor \mathrm{workspace\_bytes}/4 \rfloor, 2147483647)$）に正確に換算して適用しなければならない（MUST）。R/FEXACT 固有の作業領域不足（`WORKSPACE_EXCEEDED`、例: `"FEXACT error 40. Out of workspace."`）とプロセス全体のメモリ割当失敗（`OUT_OF_MEMORY`）は厳密に区別して記録しなければならない（MUST）。プロセス監視ポーリング外での OS OOM Killer による瞬時終了は、終了ステータス（137 / 9）等により `OUT_OF_MEMORY` と推定するが、ミリ秒未満の物理メモリ追従は保証外とする。

#### Scenario: 資源制限超過時の安全停止と状態コードの厳密区別
- **WHEN** 正確検定が設定された実行時間上限（`timeout_sec`）を超過するか、プロセス物理メモリが `max_memory_mb` を超過するか、OS OOM Killer によりプロセスが強制終了されるか、あるいは R/FEXACT からワークスペース不足エラーが返される
- **THEN** 子プロセスを安全に強制終了（またはエラー捕捉）し、Fisher検定結果を `null` とし、正確な状態コード（`TIMEOUT`, `OUT_OF_MEMORY`, `WORKSPACE_EXCEEDED`）を記録する。すでに完了している基本集計やカイ二乗検定の結果は保持して3点セット成果物を正常出力する

#### Scenario: 資源制限時のMonte Carloフォールバック
- **WHEN** 正確検定で資源制限超過が発生し、かつ設定で `fallback_to_mc: true` が事前承認されている
- **THEN** 直ちに Monte Carlo 推定へフォールバックして計算を完了し、結果メタデータに `requested_method: "exact"`, `executed_method: "monte_carlo"`, `fallback_reason: "RESOURCE_LIMIT_EXCEEDED"` を記録する

### Requirement: SAS準拠Monte Carlo推定と要約契約
システムは、必須設定項目 `mc_sampling_algorithm`（`"patefield"` または `"awb"`、既定: `"patefield"`）、設定された反復回数 $B$ および乱数Seedに基づき、周辺固定ランダム表生成による Monte Carlo 推定を提供しなければならない（MUST）。極端表の判定は $P(t) \le P(t_{obs})$ とし、適用されたアルゴリズム・Seed・反復回数を結果JSONおよび `manifest.json` に完全記録して固定Seedにおける完全再現性を保証しなければならない（MUST）。要約統計量はSAS仕様式に準拠しなければならない（MUST）。

#### Scenario: SAS仕様Monte Carlo要約の算出とアルゴリズム記録
- **WHEN** `fisher.method` が `monte_carlo`（またはフォールバック）で実行される
- **THEN** 反復回数 $B$ と極端表数 $M$ から、点推定値 $\hat{p} = M/B$、標準誤差 $\mathrm{SE} = \sqrt{\hat{p}(1-\hat{p})/(B-1)}$、正規近似区間（$0 < M < B$）、および境界端点式（$M=0$: $(0, 1-\alpha_{MC}^{1/B})$、$M=B$: $(\alpha_{MC}^{1/B}, 1)$）を算出して出力する。R既定の $(M+1)/(B+1)$ は主値とせず、必要に応じて監査用別名列 `p_mc_plus_one` にのみ記録する。また結果JSONおよび `manifest.json` に使用アルゴリズム（`mc_sampling_algorithm: "patefield"` 等）を明示記録する

### Requirement: 成果物3点セット、安定CSVキー、およびRun隔離出力
システムは、解析完了時に Run 固有の隔離ディレクトリ（`<output_dir>/run_<first16_run_id>/`）へ、①構造化JSON（`freq_results.json`）、②CSV（`summary.csv`）、③日本語Markdownレポート（`summary_report.md`）の3点セットを必ず出力しなければならない（MUST）。また `summary.csv` は RFC 3986 percent-encoding（UTF-8）により真に可逆・衝突なしの複合キー列 `strata_key` を持つとともに、各層別変数の生値を保持する個別列を併記しなければならない（MUST）。

#### Scenario: 3点セット成果物、可逆CSVキー、および個別層別変数列の正常出力
- **WHEN** 解析が完了する
- **THEN** 隔離ディレクトリ配下に3点セット成果物、設定写し（`analysis_config.json`）、および `manifest.json` が生成される。`summary.csv` には `table_id, strata_key, <strata_var1>, ..., row_level, col_level, frequency, percent, row_percent, col_percent` 列が含まれる。`strata_key` は変数名昇順にソートされた RFC 3986 percent-encoded `var=val` 文字列を `|` で結合した可逆・一意形式（例: `"REGION=East|STAGE=II"`、層別なし時は `"ALL"`）で出力され、デコードにより元の層別変数名および水準値が一意復元できることを保証する

### Requirement: 数値検証受入ゲート（基礎受入 vs SAS Parity受入）
システムは、受入基準を「Stage 1: 数式・手計算・独立実装に基づく基礎受入」と「Stage 2: SAS実機fixtureに基づくParity受入」の2段階ゲートとして管理しなければならない（MUST）。SAS実機参照出力が未提供の間は成果物メタデータに `sas_parity: "unverified"` を維持し、基礎受入完了をもって当面の開発完了条件を満たすものとする。

#### Scenario: SAS実機fixture未提供環境での基礎受入
- **WHEN** SAS実機環境やfixtureが未提供で、Stage 1 の数式・手計算・境界値単体テストが全件合格する
- **THEN** `sas_parity: "unverified"`, `parity_basis: "formula_and_hand_calculation"` を記録して正常終了し、基礎受入合格とする

#### Scenario: SAS実機fixture照合によるParity受入
- **WHEN** バージョン・実行ログ・丸め前出力を伴うSAS実機fixtureが提供され、許容誤差（決定論的統計量 $|R-SAS| \le 10^{-12} + 10^{-10}|SAS|$、MC要約一致等）を満たす
- **THEN** `sas_parity: "verified"` へ昇格させる
