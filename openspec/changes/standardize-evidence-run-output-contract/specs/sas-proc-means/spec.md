# Spec Delta

## MODIFIED Requirements

### Requirement: 3点セット成果物とRun隔離出力

システムは、解析完了時に `evidence_runs/sas_proc_means/` または共通仕様で許可されたその配下の `output_dir` から解決するRun固有の隔離ディレクトリ `run_<canonical_id>[_N]/` へ、①構造化JSON（`means_results.json`）、②CSV（`summary.csv`）、③日本語Markdownレポート（`summary_report.md`）の3点セットを必ず出力しなければならない（MUST）。また実行設定の写し（`analysis_config.json`）および整合性メタデータ（`manifest.json`）を同梱しなければならない（MUST）。

#### Scenario: 3点セット成果物の正常生成

- **WHEN** PROC MEANS 解析が正常に完了する
- **THEN** 解決後の出力root（`evidence_runs/sas_proc_means/` またはその配下にある明示 `output_dir`）直下に `run_<canonical_id>[_N]/` が作成され、その配下に `means_results.json`、`summary.csv`、`summary_report.md`、`analysis_config.json`、`manifest.json` が漏れなく生成される

#### Scenario: 未定義統計量の出力表現

- **WHEN** 重み指定により歪度・尖度が未計算、または DF 以外で STDERR が未定義となる
- **THEN** JSONでは値を null とし `status_reason` を記録し、CSVでは空文字またはNAとし、Markdownレポートには未定義理由を注記する

#### Scenario: Configured output directory remains within the SAS PROC MEANS namespace

- **WHEN** 設定JSONに `output_dir` が明示される
- **THEN** 解決後の出力は `evidence_runs/sas_proc_means/` 自身またはその配下に作られ、成果物はその出力root直下ではなく `run_<canonical_id>[_N]/` に隔離される。namespace外の指定は書込み前に拒否される
