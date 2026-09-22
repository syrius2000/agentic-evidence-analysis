# Change Proposal: evidence-runs-output-unification

## Why

本リポジトリ内の各解析スキル（`vcd-bayesian-evidence-analysis`、`vcd-categorical-analysis`、`questionnaire-batch-analysis`、`sas-proc-freq`、`sas-proc-means`）において、推奨出力ルートが `skill_out/` や `output/` など不統一に分散し、さらに `questionnaire-batch-analysis` のみ `runs/<id>/` や未隔離出力（ルート直下書き込み）という特例構造を持っていました。
エビデンス駆動型統計解析の正本リポジトリとして、再現性・監査証跡・Run隔離を担保するため、全スキルの推奨出力ルートを `evidence_runs/<skill_slug>/` に統一し、物理ディレクトリ `run_<canonical_id>[_N]/` による完全隔離と後方互換探索を標準化します。

## What Changes

- **推奨出力ルートの統一**: 全スキルの既定出力先を `evidence_runs/<skill_slug>/` に整理（`vcd_bayesian`, `vcd_categorical`, `questionnaire`, `sas_proc_freq`, `sas_proc_means`, `inspections`）。
- **Run隔離の標準化**: すべての新規解析実行を `run_<canonical_id>[_N]/` 物理ディレクトリに隔離し、出力ルート直下への成果物書き込みを厳格に禁止。
- **Run ID正規化**: `run_001` 等の入力時に `run_run_001` と二重化しないよう、先頭 `run_` を一度だけ正規化。
- **Questionnaire特例の解消と互換境界**:
  - 新規解析出力は他スキルと同様に `run_<id>[_N]/` に統一し、未指定時はJST時刻ベースの論理IDを生成（`run_default` 廃止）。
  - 既存の `runs/<id>/` 成果物は移動・改名・削除せず、読み取り専用の探索対象として維持。
- **CLIと設定JSONの契約明示**: 各スキルの既存CLI許可リスト境界（`vcd-categorical` の `--out`）や設定JSON（`sas-proc-*` の `output_dir`）を尊重し、同時指定時の優先順位を仕様化。
- **規約ドキュメントとテストの整合**: `AGENTS.md`（鉄則3）、`README.md`、`.gitignore`、回帰テストスイートを新レイアウトに同期。

## Capabilities

### New Capabilities

- `evidence-run-layout`: 全解析スキルおよび事前検分に共通する、推奨出力ルート `evidence_runs/`、Run物理隔離 `run_<canonical_id>[_N]/`、ID正規化、原子的衝突回避、および旧形式（`questionnaire/runs/<id>/`）の読取り専用後方互換探索に関する標準仕様。

### Modified Capabilities

（既存の `two-way-evidence-analysis`、`sas-proc-freq`、`sas-proc-means` の要求仕様は抽象プレースホルダー `<output_dir>/run_<first16_run_id>/` に準拠しており、新能力 `evidence-run-layout` の具体化によって満たされるため、既存要件の破壊的変更はなし）

## Impact

- **共有基盤**: `.agents/shared/run_scope.R`（`reserve_run_output_dir`、`resolve_run_meta_paths`、ID正規化、新旧探索）。
- **スキル本体**: `.agents/skills/*` 内のランナー、テンプレート（`analysis.R`, `batch_runner.R`, `dashboard.Rmd`, `report.Rmd`）、設定スキーマ、SKILL.md。
- **事前検分**: `.agents/shared/inspect_data.R`, `.agents/shared/finalize_pass0_config.R`。
- **ドキュメント**: `AGENTS.md`（鉄則3）、`README.md`、`.gitignore`。
- **テスト**: `tests/` 内の公式回帰テストスイート（実行時インベントリ管理）および所有権テスト。
