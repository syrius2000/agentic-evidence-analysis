---
name: sas-proc-freq
description: Use when calculating SAS PROC FREQ compatible frequency and crosstabulation tables, missing value handling (exclude, missprint, include), independence tests (Pearson, Likelihood Ratio, Continuity-Adjusted Chi-Square), 2x2 effect sizes (Odds Ratio, Relative Risk, Binomial CIs), Fisher Exact test (2x2 hypergeometric and R x C network method with child-process resource protection), and Monte Carlo estimation (Patefield algorithm) in R with 3-pack outputs (JSON/CSV/Markdown).
license: MIT
metadata:
  version: "1.0"
---

# SAS PROC FREQ Compatible Categorical Analysis Skill

SAS PROC FREQ の度数・分割表集計、欠損処理規則（exclude, missprint, include）、独立性検定（Pearsonカイ二乗、尤度比カイ二乗、2×2連続性補正カイ二乗）、2×2効果量・区間推定（オッズ比、相対リスク、二項割合信頼区間）、Fisher正確検定（2×2超幾何和 vs 一般表ネットワーク法、子プロセス資源保護）、およびSAS仕様Monte Carlo推定（Patefieldアルゴリズム固定）について、R環境（base R / stats）を用いて対象限定・参照環境明示・許容誤差付きの数値互換を提供し、Run隔離配下に3点セット成果物を出力する。

## 境界と非保証・非主張事項（Boundaries & Non-Claims）

- **Unix系OS専用（macOS / Linux）**: 子プロセスのリソース監視（PID RSS 監視ループ等）は Unix プラットフォームを前提としており、Windows 環境での資源監視は v1 の対象外（Non-Goal）です。
- **サンドボックス・実行権限の運用前提**: 子プロセスの常時 RSS 監視には `/bin/ps` によるプロセス情報参照権限が必要です。IDE サンドボックス環境や厳格なコンテナ等でプロセス間参照が遮断されている場合、監視が機能しないため適切な権限（`BypassSandbox: true` 等）での運用を前提とします。
- **ビット単位一致の非保証**: 浮動小数点演算順序やプラットフォーム・アーキテクチャ差による最下位ビットの差異を許容し、ビット単位の完全一致は保証しません。
- **全SAS構文・全ODS画面再現の対象外**: SAS `WEIGHT` 文における `ZEROS` オプション（度数0セルの自動補完）、CMH統計量、特殊欠損値（.A〜.Z）などは対象外とし、明示された機能のみを対象とする限定互換です。
- **規制提出適格性の非主張**: 本スキルおよびその出力は研究・探索的データ解析を目的とするものであり、規制当局への申請・バリデーション適格性を主張するものではありません。

## 実行ワークフロー

1. **設定の準備**:
   `schemas/analysis_config.schema.json`（`schema_version: "sas-summary-config-v1"`, `analysis_kind: "sas_proc_freq"`）に準拠した `analysis_config.json` を用意する。
2. **計算エンジンの実行**:
   `templates/run_freq.R` を `--config <path_to_config>` で実行する。
3. **成果物の確認**:
   隔離ディレクトリ `<output_dir>/run_<first16_run_id>/` 配下に以下の成果物が漏れなく生成されていることを確認する：
   - `freq_results.json`: 機械可読・正本・全統計量・表の向き・未定義理由コード（`status_reason`）
   - `summary.csv`: 可逆な複合キー `strata_key` および個別層別変数列を含む表形式データ
   - `summary_report.md`: 日本語Markdownレポート（分割表・検定結果・効果量・資源停止注記・統計的注意点）
   - `analysis_config.json`: 設定の完全な写し
   - `manifest.json`: 入出力SHA-256、JSTタイムスタンプ、R環境メタデータ
