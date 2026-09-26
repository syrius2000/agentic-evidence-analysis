## Context

See `proposal.md` - Why.
現行の `.agents/skills/vcd-categorical-analysis/templates/analysis.R` は、v4.0 の 5 軸分離モジュール群（`residual_diagnostics.R`, `effect_evidence_metrics.R`, `dirichlet_posterior.R`, `serializer_v3.R`）を呼び出す一方で、引数省略時の 3-way HairEyeColor フォールバックや旧フォーマット結果生成ロジックが混在しており、入力検証より先に `sum(..., na.rm=TRUE)` による集約が行われていました。また、頻度列不在時の無条件 `Freq=1` フォールバックによる誤集計リスク、Pass 0 プロベナンス検証関数 `validate_pass0_provenance()` の未接続、および計画書 §10–16 で合意された統計・成果物不変量の未充足が存在していました。

## Goals / Non-Goals

**Goals:**

- `analysis.R` から 3-way 実行分岐および旧版フォールバックを完全に排除し、完全名義 2-way 分割表専用エンジンとして純化する。
- 共有 `pass0_contract.R` を 2-way 解析入口に接続し、`analysis_config.json` 必須契約および SHA-256 検証を fail-closed で担保する。
- データの集約やモデリングに先行して `validate_input_table()` を実行し、暗黙の `Freq=1` フォールバックを完全撤廃する。
- `input_mode`（`"aggregated"` または `"individual"`）の厳密な安全境界を確立し、誤設定・タイポを即時遮断する。
- 大標本 Dual-Filter ロジックにおいて $N < 2000$ の場合に誤って candidate を付与していた挙動を是正する。
- 期待度数診断（Expected-Count Diagnostics / Cochran 条件）を導入し、成果物に記録する。
- `practical_delta` を既定無効化（`null`）とし、事前感度分析（$\alpha = 0.5$）の比較要約を保持する。
- ゼロマージン表（空カテゴリ）をフェイルファストで拒否する。
- 成果物 JSON の Cross-Field Invariant 検証および確定 `run_state.json` ライフサイクルを配備する。
- `analysis_signature` を単一の決定論的 SHA-256 署名として一元化し、ディレクトリ名、乱数シード、JSON、ダッシュボードで共通化する。
- Dirichlet 事後推論ドロー数を既定 10,000 回に一元化する。

**Non-Goals:**

- 3-way 以上の多次元対数線形モデルのサポート（正本スキル `vcd-bayesian-evidence-analysis` へ委譲）。
- 構造的ゼロ（不完全分割表）や準独立モデルのサポート。
- Interface 3.0 の破壊的スキーマ変更（後方互換を保ちつつフィールド整合性を強化）。
- 恣意的な P 値・閾値による自動重要度判定の追加。

## Decisions

### Decision 1: 3-way legacy コードの完全排除と 2-way 専任化

- **選択**: `analysis.R` から 3-way log-linear 分析、HairEyeColor デフォルト、旧 JSON 出力フォールバックを完全除去し、引数不足や 3-way 入力時は即座にエラーコード `INVALID_INPUT_ARITY` 等で停止する。
- **代替案**: 3-way 検出時に旧スクリプトを実行する互換モードを維持する。
- **理由**: 仕様上「Arity=2 のみを受け入れ、3-way は `vcd-bayesian-evidence-analysis` へ委譲する」という契約と真っ向から矛盾し、不具合の温床となっていたため。

### Decision 2: 共有 `pass0_contract.R` の再利用と設定必須契約

- **選択**: `.agents/shared/pass0_contract.R` の `validate_pass0_provenance()` を `analysis.R` の入口で呼び出す。canonical 実行において `analysis_config.json` は必須とし、未指定時は `MISSING_REQUIRED_CONFIG`、SHA-256 不一致時は `PROVENANCE_SHA_MISMATCH`、対象スキル不一致時は `TARGET_SKILL_MISMATCH` で即時停止する。
- **代替案**: `vcd-categorical-analysis` 内に SHA-256 検証ロジックを再実装する、または設定なし実行を許容する。
- **理由**: リポジトリ全体の Pass 0 契約の唯一の正本（Single Source of Truth）を維持し、監査証跡のない計算を防止するため。

### Decision 3: 入力モード（`input_mode`）の厳格な安全境界と暗黙フォールバックの完全撤廃

- **選択**:
  1. `input_mode: "aggregated"`: 頻度列指定が必須。未指定・タイポ・不在時は `MISSING_FREQUENCY_COLUMN` で即時停止。
  2. `input_mode: "individual"`: 頻度列指定は明示的に禁止（PROHIBITED）。指定・検出時は `FREQUENCY_COLUMN_NOT_PERMITTED` で即時停止（「無視」や「暗黙除外」は不可）。
  3. 未指定・欠損・未知値は `INVALID_INPUT_MODE` で即時停止。
  4. `validate_input_table()` および `analysis.R` から `Freq=1` への暗黙フォールバックを完全撤廃する。
- **代替案**: 頻度列の有無から暗黙的に推測する、または `individual` 時に freq 列を静かに無視する。
- **理由**: `--freq Freqency` のようなタイポや設定ミスを静かに通さず、解析誤りを確実に防ぐため。

### Decision 4: ゼロマージン表のフェイルファスト拒否

- **選択**: 行和または列和が 0 のカテゴリ（空水準）が存在する場合、`ZERO_MARGIN_DETECTED` で即時停止する。
- **代替案**: ラプラススムージングや事前分布のみに頼ってそのまま計算する。
- **理由**: 周辺度数ゼロのカテゴリは分割表分析の推定前提を崩し、自由度やオッズ比の不定性を招くため。

### Decision 5: 統計的契約の厳格化（期待度数、practical delta、事前感度）

- **選択**:
  1. **期待度数診断**: 全セルの $E_{ij}$ を算出し、最小値、$<5$ の割合、Cochran 条件充足フラグを `expected_count_diagnostics` として記録する。
  2. **practical delta**: 既定では `NULL` とし、明示指定がない限り実務差確率を計算せず `null` 出力とする。
  3. **事前感度分析**: 代替事前 $\alpha = 0.5$ の事後中央値および 95% ETI を算出し、主事前 $\alpha = 1.0$ との比較要約を `sensitivity_analysis` に保持する。
- **理由**: 計画書 §10–13 の統計的完成条件を忠実に満たし、恣意的な閾値判断を排除しつつ頑健性を可視化するため。

### Decision 6: Canonical Analysis Signature の一元化と拡張 Provenance

- **選択**: `analysis_signature = sha256(engine_version, input_sha256, config_sha256, vars, freq, prior_alpha, thresholds)` を一度だけ算出し、実行識別子、RNG シード、JSON、メタ情報、ダッシュボードへ同一値を供給する。provenance には R version, platform, sessionInfo ハッシュ, seed, タイムスタンプ（JST）を完全記録する。
- **代替案**: 実行ディレクトリ、RNG シード、JSON シリアライザでそれぞれ異なる文字列をハッシュ化する。
- **理由**: 再現性と監査証跡において「解析署名」という同一の語が異なるハッシュを指す混乱を解消するため。

### Decision 7: Dual-Filter の小標本判定修正

- **選択**: `N >= 2000 && is_finite && quarantine_status == "ACTIVE" && abs(log_oe) >= 0.50 && score >= 3.84` のみ `dual_filter_candidate = TRUE` とする。$N < 2000$ では常に `FALSE`。
- **理由**: Dual-Filter は「大標本（Large-N）における過剰検出」を制御するための探索的フィルターであり、小標本で同じフラグを付与すると概念の混同が生じるため。

### Decision 8: 成果物 Schema 不変量検証と Run State ライフサイクル管理

- **選択**:
  1. シリアライズ直前に確率総和 1.0、信用区間順序整合性（Q2.5 $\le$ median $\le$ Q97.5）、および成果物間（`categorical_results.json` と `evidence_profile.json`）のキー整合性（`analysis_signature`, `run_id`, 全セル識別キー集合）を検証し、違反時は `SCHEMA_INVARIANT_VIOLATION` でフェイルファスト。
  2. 実行ライフサイクル（開始: `running`, 失敗: `failed` + `error_code`, 完了: `completed`）を `run_state.json` に確定記録する。
- **理由**: 成果物完全性とライフサイクル追跡性を担保するため。

## Error Code Registry

本エンジンが発行する確定フェイルファスト・エラーコード一覧：

- `MISSING_REQUIRED_CONFIG`: `analysis_config.json` が未指定
- `PROVENANCE_SHA_MISMATCH`: 入力 CSV の実測 SHA-256 と設定内 SHA-256 が不一致
- `TARGET_SKILL_MISMATCH`: 設定内の対象スキル名が `vcd-categorical-analysis` と不一致
- `INVALID_INPUT_MODE`: `input_mode` が未指定、欠損、または未知値
- `MISSING_FREQUENCY_COLUMN`: `aggregated` モードで freq 列が未指定、タイポ、不在
- `FREQUENCY_COLUMN_NOT_PERMITTED`: `individual` モードで freq 列が指定・検出された
- `ZERO_MARGIN_DETECTED`: 行和または列和が 0 のカテゴリを検出
- `INVALID_INPUT_ARITY`: 入力分割表の次元数が 2 以外（3 次元以上）
- `STRUCTURAL_ZERO_NOT_SUPPORTED`: 構造的ゼロが指定された
- `NON_INTEGER_COUNTS`: 度数が非整数または負数
- `ZERO_TOTAL_COUNT`: 総度数 $N = 0$
- `SCHEMA_INVARIANT_VIOLATION`: 確率和・信用区間順序、または成果物間キー・セル不変量の破綻を検出

## Risks / Trade-offs

- [Risk: 引数なしの実行（`Rscript analysis.R` で HairEyeColor を自動分析する挙動）がエラーになる] → `validate_input_table()` による明確なエラーメッセージとヘルプ表示（使い方案内）を出力し、利用者を誘導する。
- [Risk: `pass0_contract.R` へのパス解決が実行カレントディレクトリに依存する] → `run_scope.R` またはスクリプト位置基準の安全なパス解決ヘルパーを用いてリポジトリルートを確定する。
- [Risk: individual モードで偶然既存列に freq 指定があった場合のエラー停止] → ユーザーの指定意図の曖昧さを排除するための fail-closed 仕様として許容し、エラーメッセージで列指定の解除を案内する。
