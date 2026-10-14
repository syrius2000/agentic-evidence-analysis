# Spec Delta: sas-proc-freq

## MODIFIED Requirements

### Requirement: SAS準拠Monte Carlo推定と要約契約

システムは、必須設定項目 `mc_sampling_algorithm`（`"patefield"` または `"awb"`、既定: `"patefield"`）、設定された反復回数 $B$ および乱数Seedに基づき、周辺固定ランダム表生成による Monte Carlo 推定を提供しなければならない（MUST）。極端表の判定は $P(t) \le P(t_{obs})$ とし、適用されたアルゴリズム・Seed・反復回数を結果JSON（`freq_results.json` 内の各層別 `fisher` ブロック）および設定写し（`analysis_config.json`）に完全記録して固定Seedにおける完全再現性を保証しなければならない（MUST）。要約統計量はSAS仕様式に準拠しなければならない（MUST）。

#### Scenario: SAS仕様Monte Carlo要約の算出とアルゴリズム記録

- **WHEN** `fisher.method` が `monte_carlo`（またはフォールバック）で実行される
- **THEN** 反復回数 $B$ と極端表数 $M$ から、点推定値 $\hat{p} = M/B$、標準誤差 $\mathrm{SE} = \sqrt{\hat{p}(1-\hat{p})/(B-1)}$、正規近似区間（$0 < M < B$）、および境界端点式（$M=0$: $(0, 1-\alpha_{MC}^{1/B})$、$M=B$: $(\alpha_{MC}^{1/B}, 1)$）を算出して出力する。R既定の $(M+1)/(B+1)$ は主値とせず、必要に応じて監査用別名列 `p_mc_plus_one` にのみ記録する。また結果JSON（`freq_results.json` 内の該当層別 `fisher` オブジェクト）に使用アルゴリズム（`mc_sampling_algorithm: "patefield"` 等）、乱数Seed、反復回数を明示記録する

### Requirement: 成果物3点セット、安定CSVキー、およびRun隔離出力

システムは、解析完了時に `evidence_runs/sas_proc_freq/` 自身またはその配下で解決された `output_dir` をrootとするRun隔離ディレクトリ `run_<canonical_id>[_N]/` へ、①構造化JSON（`freq_results.json`）、②CSV（`summary.csv`）、③日本語Markdownレポート（`summary_report.md`）の3点セットを必ず出力しなければならない（MUST）。namespace外の `output_dir` は書込み前に拒否しなければならない（MUST）。また `summary.csv` は RFC 3986 percent-encoding（UTF-8）により真に可逆・衝突なしの複合キー列 `strata_key` を持つとともに、各層別変数の生値を保持する個別列を併記しなければならない（MUST）。Runディレクトリには整合性メタデータとして `run_meta.json`、`results_manifest.json`、および環境情報 `session_info.txt` を出力し、旧個別の `manifest.json` は出力してはならない（MUST NOT）。

#### Scenario: 3点セット成果物、可逆CSVキー、および個別層別変数列の正常出力

- **WHEN** 解析が完了する
- **THEN** 解決後の出力root（正規namespaceまたはnamespace内の明示 `output_dir`）直下に `run_<canonical_id>[_N]/` が作成され、その配下に3点セット成果物、設定写し（`analysis_config.json`）、`run_meta.json`、`results_manifest.json`、および `session_info.txt` が生成される。`summary.csv` には `table_id, strata_key, <strata_var1>, ..., row_level, col_level, frequency, percent, row_percent, col_percent` 列が含まれる。`strata_key` は変数名昇順にソートされた RFC 3986 percent-encoded `var=val` 文字列を `|` で結合した可逆・一意形式（例: `"REGION=East|STAGE=II"`、層別なし時は `"ALL"`）で出力され、デコードにより元の層別変数名および水準値が一意復元できることを保証する

#### Scenario: Configured output directory remains within the SAS PROC FREQ namespace

- **WHEN** 設定JSONに `output_dir` が明示される
- **THEN** 解決後rootは `evidence_runs/sas_proc_freq/` 自身またはその配下となり、成果物はそのroot直下ではなく `run_<canonical_id>[_N]/` に隔離される。namespace外の指定は書込み前に拒否される
