# Spec Delta

## MODIFIED Requirements

### Requirement: 成果物3点セット、安定CSVキー、およびRun隔離出力

システムは、解析完了時に正規root `evidence_runs/sas_proc_freq/` または共通仕様で許可されたその配下の `output_dir` から解決するRun隔離ディレクトリ `run_<canonical_id>[_N]/` へ、①構造化JSON（`freq_results.json`）、②CSV（`summary.csv`）、③日本語Markdownレポート（`summary_report.md`）の3点セットを必ず出力しなければならない（MUST）。また `summary.csv` は RFC 3986 percent-encoding（UTF-8）により真に可逆・衝突なしの複合キー列 `strata_key` を持つとともに、各層別変数の生値を保持する個別列を併記しなければならない（MUST）。

#### Scenario: 3点セット成果物、可逆CSVキー、および個別層別変数列の正常出力

- **WHEN** 解析が完了する
- **THEN** 解決後の出力root（`evidence_runs/sas_proc_freq/` またはその配下にある明示 `output_dir`）直下に `run_<canonical_id>[_N]/` が作成され、その配下に3点セット成果物、設定写し（`analysis_config.json`）、および `manifest.json` が生成される。`summary.csv` には `table_id, strata_key, <strata_var1>, ..., row_level, col_level, frequency, percent, row_percent, col_percent` 列が含まれる。`strata_key` は変数名昇順にソートされた RFC 3986 percent-encoded `var=val` 文字列を `|` で結合した可逆・一意形式（例: `REGION=East|STAGE=II`、層別なし時は `ALL`）で出力され、デコードにより元の層別変数名および水準値が一意復元できることを保証する

#### Scenario: Configured output directory remains within the SAS PROC FREQ namespace

- **WHEN** 設定JSONに `output_dir` が明示される
- **THEN** 解決後の出力は `evidence_runs/sas_proc_freq/` 自身またはその配下に作られ、成果物はその出力root直下ではなく `run_<canonical_id>[_N]/` に隔離される。namespace外の指定は書込み前に拒否される
