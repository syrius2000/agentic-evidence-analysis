---
name: sas-proc-means
description: Use when calculating SAS PROC MEANS compatible descriptive summary statistics, CLASS group stratification, FREQ/WEIGHT handling, VARDEF options, and quantiles (QNTLDEF 1-5) in R with 3-pack outputs (JSON/CSV/Markdown).
license: MIT
metadata:
  version: "1.0"
---

# SAS PROC MEANS Compatible Descriptive Statistics Skill

SAS PROC MEANS の記述統計量、CLASS群化、欠損処理、FREQ/WEIGHT規則、分散定義（VARDEF）、分位数（QNTLDEF 1〜5）について、R環境（base R / stats）を用いて対象限定・参照環境明示・許容誤差付きの数値互換を提供し、Run隔離配下に3点セット成果物を出力する。

## 境界と非保証・非主張事項（Boundaries & Non-Claims）

- **ビット単位一致の非保証**: 浮動小数点演算順序やプラットフォーム・アーキテクチャ差による最下位ビットの差異を許容し、ビット単位の完全一致は保証しません。
- **全SAS構文・全ODS画面再現の対象外**: QMETHOD=P2、SAS FORMAT による群化、特殊欠損値（.A〜.Z）などは対象外とし、明示された機能のみを対象とする限定互換です。
- **規制提出適格性の非主張**: 本スキルおよびその出力は研究・探索的データ解析を目的とするものであり、規制当局への申請・バリデーション適格性を主張するものではありません。

## 実行ワークフロー

1. **設定の準備**:
   `schemas/analysis_config.schema.json`（`schema_version: "sas-summary-config-v1"`, `analysis_kind: "sas_proc_means"`）に準拠した `analysis_config.json` を用意する。
2. **計算エンジンの実行**:
   `templates/run_means.R` を `--config <path_to_config>` で実行する。
3. **成果物の確認**:
   隔離ディレクトリ `<output_dir>/run_<first16_run_id>/` 配下に以下の成果物が漏れなく生成されていることを確認する：
   - `means_results.json`: 機械可読・正本・全統計量・未定義理由コード（`status_reason`）
   - `summary.csv`: SAS ODS Summary / OUT=データセット相当の表形式データ
   - `summary_report.md`: 日本語Markdownレポート（群別要約表・設定一覧・適用制約）
   - `analysis_config.json`: 設定の完全な写し
   - `manifest.json`: 入出力SHA-256、JSTタイムスタンプ、R環境メタデータ
