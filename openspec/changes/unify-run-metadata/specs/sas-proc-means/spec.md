# Spec Delta: sas-proc-means

## MODIFIED Requirements

### Requirement: 3点セット成果物とRun隔離出力

システムは、解析完了時に `evidence_runs/sas_proc_means/` 自身またはその配下で解決された `output_dir` をrootとするRun隔離ディレクトリ `run_<canonical_id>[_N]/` へ、①構造化JSON（`means_results.json`）、②CSV（`summary.csv`）、③日本語Markdownレポート（`summary_report.md`）の3点セットを必ず出力しなければならない（MUST）。また実行設定の写し（`analysis_config.json`）、統制メタデータ（`run_meta.json`）、成果物整合性マニフェスト（`results_manifest.json`）、および環境情報（`session_info.txt`）を同梱しなければならず（MUST）、旧個別の `manifest.json` は出力してはならない（MUST NOT）。namespace外の `output_dir` は書込み前に拒否しなければならない（MUST）。

#### Scenario: 3点セット成果物の正常生成

- **WHEN** PROC MEANS 解析が正常に完了する
- **THEN** 解決後の出力root（正規namespaceまたはnamespace内の明示 `output_dir`）直下に `run_<canonical_id>[_N]/` が作成され、その配下に `means_results.json`、`summary.csv`、`summary_report.md`、`analysis_config.json`、`run_meta.json`、`results_manifest.json`、および `session_info.txt` が漏れなく生成される

#### Scenario: Configured output directory remains within the SAS PROC MEANS namespace

- **WHEN** 設定JSONに `output_dir` が明示される
- **THEN** 解決後rootは `evidence_runs/sas_proc_means/` 自身またはその配下となり、成果物はそのroot直下ではなく `run_<canonical_id>[_N]/` に隔離される。namespace外の指定は書込み前に拒否される

#### Scenario: 未定義統計量の出力表現

- **WHEN** 重み指定により歪度・尖度が未計算、または DF 以外で STDERR が未定義となる
- **THEN** JSONでは値を null とし `status_reason` を記録し、CSVでは空文字またはNAとし、Markdownレポートには未定義理由を注記する
