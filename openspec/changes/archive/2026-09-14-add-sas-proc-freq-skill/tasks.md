## 1. ディレクトリとスキーマ整備

- [x] 1.1 `.agents/skills/sas-proc-freq` ディレクトリ構造（`SKILL.md`、`schemas/`、`templates/`）を作成し、初期ファイルが存在することを確認する
- [x] 1.2 `schemas/analysis_config.schema.json` を定義し、`schema_version: "sas-summary-config-v1"`、`analysis_kind: "sas_proc_freq"`、水準順（`levels_order`）、イベント水準（`event_level`）、比較方向（`comparison_direction`）、資源上限（`timeout_sec`, `max_memory_mb`, `workspace_bytes`）、サンプリングアルゴリズム（`mc_sampling_algorithm: ["patefield", "awb"]`）、およびフォールバック設定（`fallback_to_mc`）のバリデーションを実装する

## 2. 入力検証、水準順序、およびゼロ契約の実装

- [x] 2.1 入力集計表のバリデーション関数を実装し、非負整数度数列の受理、負数・小数・欠損値の即時拒否（`INVALID_COUNT_DATA`）、および構造的ゼロ指定の検出・拒否（`STRUCTURAL_ZERO_PRESENT`）を検証する
- [x] 2.2 水準順序解決モジュールを実装し、`levels_order` による固定順序、SAS既定動作に準拠した度数0レコード（count=0）の集計セル除外（SAS `ZEROS` オプション非サポート）、ゼロ周辺・退化表の検出、および0/0割合の `null`（理由コード `INDETERMINATE_FRACTION_ZERO_DENOMINATOR`）処理を実装・検証する
- [x] 2.3 1元表、2元表、層別2元表における度数・割合集計および3つの欠損モード（`exclude`, `missprint`, `include`）の計算ロジックを実装し、table request ごとの独立適用と分母制御をテストで検証する

## 3. 独立性検定と2×2効果量・区間推定

- [x] 3.1 Pearsonカイ二乗、尤度比カイ二乗（$G^2$、ゼロセル寄与厳密0）、2×2連続性補正カイ二乗（$Q_C$、SAS定義直接計算）を実装し、数理公式および手計算参照値と一致することを確認する
- [x] 3.2 2×2表のオッズ比（OR）、相対リスク（RR列1/列2）および各Wald信頼区間（RRへのOR式流用厳禁）、二項割合信頼区間（Wald, Clopper-Pearson, Wilson）を実装し、指定水準順・比較方向に基づく計算、およびゼロセル時の `null` / `ZERO_CELL_UNDEFINED` 記録を検証する

## 4. Fisher正確検定、子プロセス資源保護、およびMonte Carlo要約

- [x] 4.1 Fisher正確検定モジュールを実装し、2×2表（超幾何分布和）と一般 $R \times C$ 表（ネットワーク法）で両側P値計算法を分離する
- [x] 4.2 子プロセス監視による資源保護ラッパーを実装し、一般 $R \times C$ 表 Exact 検定において `workspace_bytes` を R の `fisher.test(workspace = ...)` の 4 バイト単位（$\min(\lfloor \mathrm{bytes}/4 \rfloor, 2147483647)$）に換算して適用する（2×2表では不使用）。制限時間（`timeout_sec`）超過、メモリ超過、またはワークスペース超過（`"FEXACT error 40"` 等）時に子プロセスを強制停止/エラー捕捉し、状態コード（`TIMEOUT`, `OUT_OF_MEMORY`, `WORKSPACE_EXCEEDED`）の厳密区別と記録、部分成果物（度数・カイ二乗等）の保護保存、および `fallback_to_mc: true` 時のMC移行動作を検証する
- [x] 4.3 SAS仕様準拠の Monte Carlo 要約関数 `sas_mc_summary`（点推定 $\hat{p}=M/B$、SE、正規近似区間、境界 $M=0, B$ 端点式）を実装し、標本化アルゴリズムを `mc_sampling_algorithm`（既定 `"patefield"`）に固定して実行メタデータに記録する。極端表判定 $P(t) \le P(t_{obs})$、およびR補正値（$(M+1)/(B+1)$）の監査列隔離を単体テストで検証する

## 5. 3点セット成果物出力と2段階受入テスト

- [x] 5.1 構造化JSON（`freq_results.json`）出力モジュールを実装し、全統計量、表の向き、`status_reason`、使用アルゴリズム（`mc_sampling_algorithm`）、および `sas_parity` メタデータ（初期値 `"unverified"`）の出力を確認する
- [x] 5.2 表形式CSV（`summary.csv`）出力モジュールを実装し、RFC 3986 percent-encoding（UTF-8）による可逆・衝突なしの安定複合キー列 `strata_key`（非層別時は `"ALL"`）および個別層別変数列（生値）の併記出力を確認し、デコードによる一意復元性をテストする
- [x] 5.3 日本語Markdownレポート（`summary_report.md`）生成モジュールを実装し、分割表、検定結果一覧、効果量区間、資源停止注記、および統計的注意点テーブルの描画を確認する
- [x] 5.4 Run隔離ディレクトリ配下への成果物（3点セット + `analysis_config.json` + `manifest.json`）の配置とSHA-256ハッシュ整合性を検証する
- [x] 5.5 **Stage 1 基礎受入テスト**: `Rscript tests/test_sas_proc_freq_numerical_parity.R --stage=foundation` を実行し、JSON Schema検証、入力境界値、数式単体試験、ゼロセル・退化表、`workspace_bytes` の4バイト換算（4未満・端数切捨て・`.Machine$integer.max` クリップを含む）、子プロセス資源停止（TIMEOUT/OOM/WORKSPACE_EXCEEDEDの区別）、MCアルゴリズム再現性、`strata_key` 可逆性、および3点セット出力整合性が全件合格することを確認する（未提供fixture環境下で `sas_parity: "unverified"` をもって基礎受入完了判定とする）
- [x] 5.6 **Stage 2 [条件付き] SAS Parity検証テスト**: 将来SAS実機fixtureが提供された場合に `Rscript tests/test_sas_proc_freq_numerical_parity.R --stage=parity` を実行し、決定論的統計量の許容誤差（$|R-SAS| \le 10^{-12} + 10^{-10}|SAS|$）およびMC要約の完全一致を検証して `sas_parity: "verified"` へ昇格可能であることを確認する
