## Why

製薬・RWD解析の実務において、SASで作成された要約帳票（PROC FREQ）と同一基準での集計・推測検証が求められる場面が多い。既存のカテゴリカル分析パイプライン（3元表対数線形モデル・多項Dirichlet推論）とは独立に、SAS PROC FREQ の明示された集計規則・統計定義・欠損処理をR環境上で再現し、対象限定・許容誤差付き数値互換を提供する独立スキル `.agents/skills/sas-proc-freq` を導入する。

## What Changes

- **独立スキルの創設**: `.agents/skills/sas-proc-freq` を新設し、専用の `SKILL.md`、設定スキーマ、Rエンジンテンプレートを配置。
- **入力・集計契約の実装**:
  - 非負整数の `count_variable` を持つ集計表（SASの `WEIGHT count;` 相当）を入力契約とする。
  - 明示水準順序（`levels_order`）、イベント水準、比較方向を固定。
  - SAS既定動作に従い、度数0行（count=0）は集計セル生成時に除外（SAS `ZEROS` オプションは初回非サポート）。
  - ゼロ周辺・退化表・0/0割合の未定義理由コード（`INDETERMINATE_FRACTION_ZERO_DENOMINATOR` 等）および構造的ゼロ拒否の実装。
  - 1元表、2元表、層ごとの2元表における度数、全体割合、行/列割合、累積度数・割合を計算。
  - 3つの欠損モード（`exclude` [SAS既定]、`missprint`、`include` [MISSINGオプション]）の厳密な分母・表示制御（table request ごとの独立適用）。
- **推測統計量・区間推定**:
  - Pearson カイ二乗検定（連続性補正なし）。
  - 尤度比カイ二乗検定（$G^2 = 2\sum O \log(O/E)$、$O=0$寄与は厳密に0）。
  - 2×2表の連続性補正カイ二乗検定（$Q_C = \sum [\max(0, |O-E|-0.5)]^2 / E$、SAS定義直接計算）。
  - 2×2表のオッズ比（OR）、相対リスク（RR列1/列2）およびそれぞれの対数変換Wald信頼区間（ゼロセル時は `null` / `ZERO_CELL_UNDEFINED`、無断の0.5加算禁止）。
  - 二項割合の信頼区間（Wald、Clopper-Pearson、Wilson）。
- **Fisher正確検定、子プロセス資源保護、およびMonte Carlo推定**:
  - 2×2表（超幾何分布和）と一般 $R \times C$ 表（ネットワーク法）で両側P値計算法を分離。
  - 子プロセス監視による資源保護（`timeout_sec`, `max_memory_mb`）、強制停止（SIGTERM/SIGKILL）、状態コード記録（`TIMEOUT`, `OUT_OF_MEMORY` 等）、部分成果物（集計・カイ二乗）の保護保存。
  - 資源超過時の Monte Carlo フォールバック（事前承認時のみ）。
  - SAS仕様準拠の Monte Carlo 推定・要約（点推定 $\hat{p} = M/B$、標準誤差 $\sqrt{\hat{p}(1-\hat{p})/(B-1)}$、正規近似区間、境界 $M=0, B$ 端点式）。R補正値（$(M+1)/(B+1)$）は監査列へ隔離。
- **3点セットの出力成果物とRun隔離**:
  - Run単位の隔離ディレクトリ配下に、①構造化JSON（`freq_results.json`: 全統計量・表の向き・未定義理由コード・`sas_parity` メタデータを含む正本）、②CSV（`summary.csv`: 安定複合キー `strata_key` を持つ表形式データ）、③日本語Markdownレポート（`summary_report.md`: 分割表・検定結果・注意点を記載した監査用文書）を出力。
  - 実行設定の写し（`analysis_config.json`）および整合性メタデータ（`manifest.json`）を同梱。
- **2段階受入ゲートと検証**:
  - Stage 1: 数理定義・手計算・境界値に基づく基礎受入（SAS fixture未提供環境でも `sas_parity: "unverified"` として完了可能）。
  - Stage 2: SAS実機fixture提供時のParity受入（許容誤差基準による検証）。
  - 一括検証コマンド `Rscript tests/test_sas_proc_freq_numerical_parity.R --stage=foundation` による自動検証。

## Capabilities

### New Capabilities
- `sas-proc-freq`: SAS PROC FREQ 対象限定互換スキルの入力契約、欠損処理、集計、カイ二乗検定、Fisher正確検定、2×2効果量・信頼区間、Monte Carlo推定、および3点セット（JSON/CSV/Markdownレポート）の出力仕様を規定する。

### Modified Capabilities
<!-- なし。既存パイプラインの仕様変更はない。 -->

## Impact

- **新規ファイル**:
  - `openspec/specs/sas-proc-freq/spec.md`
  - `.agents/skills/sas-proc-freq/SKILL.md`
  - `.agents/skills/sas-proc-freq/schemas/analysis_config.schema.json`
  - `.agents/skills/sas-proc-freq/templates/run_freq.R`
  - `tests/test_sas_proc_freq_numerical_parity.R`
- **既存システムへの影響**:
  - 既存の 3-way 分析コード（`analysis.R`, `render_report.R` 等）や既存 specs への破壊的変更はなく、完全な独立拡張として動作する。
