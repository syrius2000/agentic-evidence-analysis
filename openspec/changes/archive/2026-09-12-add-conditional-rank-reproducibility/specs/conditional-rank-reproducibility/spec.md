## Purpose

集計度数表に対して指定モデル（M1/M5）の再適合を伴う多項再標本化を実行し、元データ由来の適格セル集合（REGULAR）および有効反復に条件付けたセル順位選択頻度と監査情報を評価・出力する機能を提供します。

## ADDED Requirements

### Requirement: モデル再適合を伴う多項再標本化
システムは、観測総度数 $N$ および経験割合 $\hat{\boldsymbol{p}}$ に基づく多項再標本化において、各反復で指定された基準モデル（M1 または M5）を再適合し、反復ごとの期待度数 $\widehat{\boldsymbol{E}}^{(b)}$ を用いて評価指標 $S_i^{(b)} = |\log(\widetilde{O}_i^{(b)}/\widehat{E}_i^{(b)})|$ を算出しなければならない（SHALL）。元データの固定期待度数 $E^{(0)}$ を用いてはならない。

#### Scenario: M5モデルの反復再適合評価
- **WHEN** `analysis_config.json` で `target_baseline_model: "M5"`, `target_metric: "abs_log_oe"`, `iterations: 1000` が指定されて Pass 1 が実行されたとき
- **THEN** 各反復 $b$ において M5 モデルが再推定され、反復ごとの $\widehat{\boldsymbol{E}}^{(b)}$ に基づいて局所効果比が算出されること

#### Scenario: M1モデルの反復再適合評価
- **WHEN** `analysis_config.json` で `target_baseline_model: "M1"`, `target_metric: "abs_log_oe"` が指定されて Pass 1 が実行されたとき
- **THEN** 各反復 $b$ において M1 相互独立モデルが再推定され、反復ごとの $\widehat{\boldsymbol{E}}^{(b)}$ に基づいて局所効果比が算出されること

### Requirement: Phase 1 入力表および水準順序契約
システムは、`conditional_rank_reproducibility.enabled: true` の場合、入力が厳密に3変数（`vars` の長さが 3）であり、全水準直積の完全セル格子を一意に含み、度数が有限の非負整数かつ総度数 $N > 0$ であることを検証しなければならない（SHALL）。また、Pass 0 の `analysis_config.json` に各変数の水準順序を明示列挙した `factor_levels_order` が含まれ、入力表の全水準と完全一致することを検証しなければならない。構造的ゼロがないことは Pass 0 の確認前提とし、不完全表・重複セル・水準不整合は明確なエラーで停止しなければならない。

#### Scenario: 完全な3元表および水準順序の正常受理
- **WHEN** 3因子の全水準直積が過不足なく1回ずつ記載され、`factor_levels_order` と整合した正当な集計CSVおよび設定が入力されたとき
- **THEN** 一次検証を通過し、計算サブルーチンへ入力表が引き渡されること

#### Scenario: 不完全セル格子・重複セル・水準順序不整合の拒否
- **WHEN** 水準の欠落した不完全格子、重複行、`factor_levels_order` の欠落または水準不一致がある状態で本機能が有効化されたとき
- **THEN** 計算を開始せず、終了コード 1 と不整合理由を示す明確なエラーで停止すること

### Requirement: 元データ REGULAR セル限定の条件付き順位付けと 0.5 連続性補正
システムは、元データ診断で `REGULAR` と判定された適格セル集合 $\mathcal{C}_{\mathrm{reg}}$ を順位付けの母集合として固定しなければならない（SHALL）。反復 $b$ において適格セル $i \in \mathcal{C}_{\mathrm{reg}}$ の度数が $O_i^{(b)} = 0$ となった場合は 0.5 連続性補正 $\log(0.5 / \widehat{E}_i^{(b)})$ を適用して有限値を保ち、反復を破棄せずに $\mathcal{C}_{\mathrm{reg}}$ 内での決定論的順位付けを継続しなければならない。

#### Scenario: 反復中観測ゼロを含む適格セルの順位付け
- **WHEN** 反復 $b$ において適格セル $i \in \mathcal{C}_{\mathrm{reg}}$ の観測度数が $O_i^{(b)} = 0$ となったとき
- **THEN** $|\log(0.5 / \widehat{E}_i^{(b)})|$ により有限値として評価指標が算出され、$\mathcal{C}_{\mathrm{reg}}$ 内の他セルと降順順位付けが行われること

#### Scenario: 条件付き順位選択頻度とMCSEの出力
- **WHEN** 有効反復 $B_{\mathrm{valid}}$ の計算が完了したとき
- **THEN** 各適格セルについて Top-$K$ 選択頻度 $\widehat{\pi}_i^{(K)}$ の `estimate` と $\mathrm{MCSE} = \sqrt{\frac{\hat{\pi}(1-\hat{\pi})}{B_{\mathrm{valid}}}}$ が対で出力され、分母として `eligible_cell_count` および `quarantined_cell_count` が明記されること

### Requirement: 正準セル順序の固定と衝突のないセルID
システムは、`vars` 順および `factor_levels_order` の直積順に基づいて `canonical_cell_index`（1から始まる連番）およびキー付き構造化 `cell_id`（例: `Dept=A/Gender=Female/Admit=Admitted`）を生成し、全反復の決定論的タイブレーク（セルインデックス昇順）および結果出力順序に一貫して用いなければならない（SHALL）。入力行の並び順や表示用ソート（$|\log(O/E)|$ 降順）によって順位やタイ判定が変化してはならない。

#### Scenario: 入力行順および表示順に対するタイ順位不変性
- **WHEN** 同一の完全セル格子について入力 CSV の行順を変更し、同一シードで本機能を実行したとき
- **THEN** 各セルの `canonical_cell_index`、元順位、順位選択頻度、順位分布要約が完全に一致すること

#### Scenario: 衝突のないセルID生成
- **WHEN** 水準名に記号や空白が含まれるデータで本機能が実行されたとき
- **THEN** `Key=Value` の構造化文字列により各セルが一意かつ安全に同定されること

### Requirement: Estimand 条件付けの完全開示と無効反復監査
システムは、評価された順位選択頻度が「経験分布、元データREGULAR適格セル、およびモデル再適合が成功した有効反復」に条件付けられたものであることを明記する `estimand_conditioning` ブロックを出力しなければならない（SHALL）。また、反復標本における周辺度数ゼロや特異反復の内訳（`invalid_breakdown`）を記録し、有効反復率が運用基準値（既定 0.95）未満となった場合、個別セルの選択頻度を保留（HOLD）し、品質ゲート未達を出力しなければならない。

#### Scenario: 運用品質ゲートの正常通過と条件付けの明記
- **WHEN** 1000 回の反復のうち有効反復が 950 回以上（$\text{valid\_rate} \ge 0.95$）であったとき
- **THEN** `status: "COMPUTED"`, `quality_gate.passed: true` として各適格セルの結果が出力され、`estimand_conditioning` に `valid_replicates_only: true` が記録されること

#### Scenario: 運用品質ゲートの作動による保留
- **WHEN** 疎セル多発等により有効反復が 950 回未満（$\text{valid\_rate} < 0.95$）となったとき
- **THEN** `status: "INSUFFICIENT_VALID_REPLICATES"`, `quality_gate.passed: false`, `cells: null` となり、個別セルの再現率は出力されないこと

### Requirement: 完全な後方互換性
システムは、`conditional_rank_reproducibility` が未指定または `enabled: false` の場合、既存の `evidence_results.json` の構造および数値を完全に維持しなければならない（SHALL）。

#### Scenario: 機能無効時の既存出力不変性
- **WHEN** `analysis_config.json` に `conditional_rank_reproducibility` が設定されていない状態で Pass 1 を実行したとき
- **THEN** 出力 JSON に新オブジェクトは追加されず、既存のモデル適合・セル診断・条件付き割合出力が 1 bit の狂いもなく一致すること

### Requirement: 実行可能性の二段階判定
システムは、元データ診断完了後に適格セル数 $C_{\mathrm{reg}}$ を評価し、実行可能性を検証しなければならない（SHALL）。

#### Scenario: 適格セルがゼロの場合の保留
- **WHEN** 元データ診断において `eligible_cell_count == 0` となったとき
- **THEN** `status: "NO_ELIGIBLE_CELLS"`, `cells: null` として安全に保留（HOLD）すること

#### Scenario: 要求Kが適格セル数を超過した場合のエラー
- **WHEN** `top_k > eligible_cell_count` であったとき
- **THEN** 要求 $K$ を暗黙に縮小（`min()`）せず、設定不整合を示す明確な実行エラーで停止すること
