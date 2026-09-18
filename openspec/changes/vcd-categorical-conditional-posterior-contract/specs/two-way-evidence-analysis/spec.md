## MODIFIED Requirements

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

解析結果は `interface_version = "3.0"` および `schema = "two-way-results-v2"` に準拠した構造化JSON（`categorical_results.json`）として出力されなければならない（MUST）。旧式の `Evidence Score = r² - k log(N)` は完全に廃止し出力に含めてはならない。既存readerとの互換性を保てる場合、条件付き事後のフィールドは既存の`posterior`構造への加法的拡張として提供しなければならない。

#### Scenario: 結果 JSON の妥当性検証

- **WHEN** 解析スクリプトが完了する
- **THEN** 生成されたJSONに `global`、`cells`、`posterior`、`quality`、および `provenance` の各キーが存在し、スキーマ定義に合致することを検証する

#### Scenario: 条件付き事後フィールドの機械可読な伝播

- **WHEN** 条件付き事後要約をシリアライズする
- **THEN** 結果JSONと必要なセル単位表形式出力は、行水準・列水準と一意に対応する両方向の条件付き事後要約を同じ丸め規則で保持し、JSON Schema、serializer、下流reader間でフィールド名・型・null表現が一致する

### Requirement: 成果物 Schema 不変量検証と Run State ライフサイクル管理

システムは、生成されるInterface 3.0成果物の構造および統計的一貫性を厳格に保証し、実行ライフサイクルの状態遷移を `run_state.json` に記録しなければならない（MUST）。

#### Scenario: 成果物 JSON の Cross-Field Invariant 検証

- **WHEN** 解析結果JSONをシリアライズする
- **THEN** serializerは canonical 実行専用とし（`execution_mode = "canonical"` のみ受入）、出力直前に推定結合確率の総和、結合確率の信用区間順序、条件付き事後の確率範囲・分位点順序・平均の総和、`evidence_profile.json` と `categorical_results.json` の `analysis_signature`・`run_id`・全セル識別キー集合、64桁の有効な `analysis_signature`・`input_sha256`・`config_sha256`（フォールバック代替生成の禁止。Canonical Core で再検証済みの `canonical_config_sha256` を受け取って記録すること）、および `provenance` ブロックの `execution_mode: "canonical"` を検証し、違反時は `SCHEMA_INVARIANT_VIOLATION` で停止する。Pass 0 承認ハッシュと最終成果物 `provenance.config_sha256` の一致は E2E 検証で保証する

#### Scenario: Run State ライフサイクルの確定記録

- **WHEN** 解析プロセスの各フェーズ（開始、失敗、成功）を遷移する
- **THEN** `run_state.json` を更新し、開始時は `status: "running"`、異常終了時は `status: "failed"` および確定 `error_code` とメッセージ、正常完了時は `status: "completed"`、`run_id`、および成果物ファイル一覧を記録する
