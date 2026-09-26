## 1. Input Boundary & Pass 0 Provenance Setup

- [x] 1.1 `.agents/skills/vcd-categorical-analysis/templates/analysis.R` に共有モジュール `.agents/shared/pass0_contract.R` の `validate_pass0_provenance()` を接続し、`analysis_config.json` 必須契約、入力 CSV の実測 SHA-256 と設定内ハッシュ検証、および対象スキル名 `vcd-categorical-analysis` の検証を実装する
- [x] 1.2 `analysis.R` の実行フローを是正し、`sum(..., na.rm=TRUE)` による集約やプロファイリング処理より前に `validate_input_table()` を実行する Fail-Fast パイプラインを確立し、度数データによる情報の暗黙消失を防止する
- [x] 1.3 `input_mode`（`"aggregated"` / `"individual"`）の厳格な安全契約を実装する:
  - `aggregated` モード: 頻度列（freq）の指定が必須であり、未指定・タイポ・不在時は `MISSING_FREQUENCY_COLUMN` で即時停止
  - `individual` モード: 頻度列の指定は明示的に禁止（PROHIBITED）とし、指定・検出時は誤設定検知として `FREQUENCY_COLUMN_NOT_PERMITTED` で即時停止（暗黙の無視・除外は行わない）
  - `input_mode` 欠損または未知値時は `INVALID_INPUT_MODE` で即時停止
  - `validate_input_table()` および `analysis.R` から暗黙の `Freq=1` フォールバックを完全撤廃する
- [x] 1.4 ゼロマージン表（空カテゴリ、行和または列和が 0）を検出し、`ZERO_MARGIN_DETECTED` でフェイルファスト停止する検証ロジックを実装する
- [x] 1.5 入力境界の 7 大異常系テストスイート（`tests/test_vcd_categorical_input_boundary.R`）を実装・検証する:
  1. Pass 0 設定ファイル未指定（`MISSING_REQUIRED_CONFIG`）
  2. Pass 0 入力 CSV の SHA-256 不一致（`PROVENANCE_SHA_MISMATCH`）
  3. Pass 0 対象スキル名不一致（`TARGET_SKILL_MISMATCH`）
  4. `input_mode` 未指定・欠損・未知値（`INVALID_INPUT_MODE`）
  5. `aggregated` 時の頻度列タイポ・未検出（`MISSING_FREQUENCY_COLUMN`）
  6. `individual` 時の頻度列指定禁止違反（`FREQUENCY_COLUMN_NOT_PERMITTED`）
  7. ゼロマージン分割表入力（`ZERO_MARGIN_DETECTED`）

## 2. 2-way Engine Purification & Legacy Removal

- [x] 2.1 `analysis.R` から残存する 3-way log-linear 分析、HairEyeColor 自動フォールバック、および旧フォーマット結果生成ロジックを完全除去し、Arity=2 専任の実行系に純化する
- [x] 2.2 3次元以上の入力時に `INVALID_INPUT_ARITY` を発行し、正本スキル `vcd-bayesian-evidence-analysis` を案内して即時停止することを単体テストで検証する
- [x] 2.3 構造的ゼロ指定時に `STRUCTURAL_ZERO_NOT_SUPPORTED` で即時停止することを検証する

## 3. Statistical Logic & Diagnostics Hardening

- [x] 3.1 `.agents/skills/vcd-categorical-analysis/R/effect_evidence_metrics.R` における大標本 Dual-Filter ロジックを修正し、$N < 2000$ の小標本表では常に `dual_filter_candidate = FALSE` となること、および正規セル・閾値超過時のみ候補となることを単体テストで検証する
- [x] 3.2 期待度数診断（Expected-Count Diagnostics）を実装し、全セルの $E_{ij}$、最小値、$<5$ のセル割合、および Cochran 条件充足フラグを `expected_count_diagnostics` として算出・出力する
- [x] 3.3 practical delta の既定無効化を実装し、設定で明示指定がない限り実務差確率を計算せず `practical_delta: null` として出力することを検証する
- [x] 3.4 事前分布感度分析（$\alpha = 0.5$）の比較要約を実装し、主事前（$\alpha = 1.0$）との事後中央値シフトおよび 95% ETI 区間幅を `sensitivity_analysis` に保持することを検証する
- [x] 3.5 Dirichlet 事後推論のサンプリングドロー数を既定 10,000 回に一元化し、決定論的乱数シードにより完全再現可能であることを検証する

## 4. Canonical Signature, Provenance & Schema Integrity

- [x] 4.1 単一の決定論的 SHA-256 署名（Canonical Analysis Signature）を生成する共通ヘルパーを整備し、実行ディレクトリ（`run_<first16>`）、RNG シード導出、結果 JSON、メタ情報、ダッシュボードで共通の一意な署名が使われることを検証する
- [x] 4.2 成果物 JSON（`categorical_results.json` / `evidence_profile.json`）の `provenance` ブロックに入力 SHA-256、設定 SHA-256、R バージョン、プラットフォーム、乱数シード、タイムスタンプ（JST）を完全記録する
- [x] 4.3 成果物シリアライザに Cross-Field Invariant 検証（確率総和 1.0、信用区間順序 $Q2.5 \le median \le Q97.5$、および `categorical_results.json` と `evidence_profile.json` 間の `analysis_signature`, `run_id`, 全セル識別キー整合性）を実装し、不変量違反時に `SCHEMA_INVARIANT_VIOLATION` でフェイルファスト停止することを検証する
- [x] 4.4 ライフサイクル管理として `run_state.json` を配備し、開始時（`running`）、異常終了時（`failed` + `error_code` + `message`）、正常完了時（`completed` + `run_id` + 成果物一覧）が確定記録されることを検証する

## 5. End-to-End Verification Suite

- [x] 5.1 `.agents/skills/vcd-categorical-analysis/tests/` 配下に v4.1 の全修復項目（Pass 0 接続、先行入力検証、2-way 専任化、Dual-Filter 是正、決定論的署名、統計診断、Schema 不変量、Run State 記録）を網羅するテストスイートを配備し、全テスト合格を確認する
- [x] 5.2 実データを用いた Pass 0 `inspect_data.R` $\to$ `analysis_config.json` $\to$ Pass 1 `analysis.R` $\to$ AI 考察 $\to$ `dashboard.html` レンダリングの完全な監査証跡チェーンをエンドツーエンドで検証する
