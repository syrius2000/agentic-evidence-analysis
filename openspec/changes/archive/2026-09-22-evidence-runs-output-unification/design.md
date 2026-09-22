# Technical Design: evidence-runs-output-unification

## Context

全解析スキルの出力先規約を整理し、`evidence_runs/<skill_slug>/` を基点とする体系へ移行する（動機は `proposal.md` 参照）。
現在、`.agents/shared/run_scope.R` には `questionnaire-batch-analysis` に対する特例分岐（`runs/` サブディレクトリ生成）が存在し、また各スキルで既定値（`skill_out/...`）やCLI引数の受け付け方針がばらついていた。

## Goals / Non-Goals

**Goals:**

- 全スキルの推奨既定出力ルートを `evidence_runs/<skill_slug>/` に統一する。
- 物理Runディレクトリを `run_<canonical_id>[_N]/` に完全統一し、出力ルート直下への成果物書き込みを排除する。
- `run_001` 入力時に `run_run_001` となる重複を排除するID正規化を導入する。
- `questionnaire-batch-analysis` の旧出力（`runs/<id>/`）および既存の `skill_out/` 成果物を破壊せず、読取り専用探索互換を維持する。
- `run_meta.json` と実際の物理パスの整合性を保証する。

**Non-Goals:**

- 既存の成果物ディレクトリ（`skill_out/`, `output/` 等）の物理的な一括移動・改名・削除。
- 既存の `.playwright-mcp` や `figure/` 等の未関係ファイルの削除。
- `sas-proc-*` への不要なCLI出力先上書き引数の追加（設定JSON正本契約を維持）。

## Decisions

### 1. 物理ディレクトリ名の正規化ロジック

- **決定**: 論理Run IDがすでに `run_` で始まる場合（例: `run_001`）、先頭の `run_` を一度だけ除去してから `paste0("run_", slug)` を適用する。
- **代替案**: そのまま `paste0("run_", slug)` を適用すると `run_run_001` となり、パスの冗長化と識別性の低下を招くため却下。

### 2. スキル別のCLI・設定JSON契約

- **`vcd-categorical-analysis`**: 既存の `--out` を正規形とする（canonical CLI許可リストのセキュリティ境界を維持）。
- **`vcd-bayesian-evidence-analysis`**: 既存の `--output_dir` / `--output-dir` を維持し、`--out` もエイリアスとして受容可能とする。同時指定時は `--out` を優先するか競合エラーとする。
- **`questionnaire-batch-analysis`**: 既存の `--out` を維持し、`--run-id` が未指定または `run` の場合はJST時刻ベースの論理ID（`format(Sys.time(), "%Y%m%d_%H%M%S", tz="Asia/Tokyo")`）を生成する。
- **`sas-proc-freq` / `sas-proc-means`**: 設定JSON内の `output_dir` を正本とし、CLIからの上書きは提供しない（config-only契約の維持）。

### 3. Questionnaire の旧形式（`runs/<id>/`）読取り互換と信頼境界再設計

- **決定**: `.agents/shared/run_scope.R` の `resolve_pass3_run_dir`、`resolve_run_meta_paths`、および `verify_run_lock_trust_boundary` において、新形式 `out_root/run_<id>` を第一の正規形式とし、旧形式 `out_root/runs/<id>` は読取り専用のフォールバック形式として受容する。新レイアウトのRunを信頼境界違反として拒否しないよう境界判定を再設計する。新規書き込みは常に `run_<id>` とする。
- **理由**: 過去の検証・アーカイブ成果物との互換性を維持しつつ、新レイアウトの信頼境界検証を成功させるため。

### 4. `vcd-categorical-analysis` の隔離ディレクトリ統合

- **決定**: `vcd-categorical-analysis/templates/analysis.R` はすでに `run_<prefix16>`（解析署名）を生成しているが、既定ルートを `evidence_runs/vcd_categorical` に更新し、競合時のサフィックスや原子的排他ロックとの一貫性を維持する。

### 5. Git除外設定（`.gitignore`）

- **決定**: `.gitignore` に `evidence_runs/` を追加する。同時に、既存のローカル成果物が誤って追跡されないよう `skill_out/` や `skill_output/` の除外ルールも保持する。

## Risks / Trade-offs

- **[Risk] テストスクリプトでの固定パス依存**: `tests/` 内の既存テストが `skill_out/questionnaire` などを前提としている場合、テストが失敗する可能性がある。
  - **Mitigation**: 実装時に該当テストスクリプト（`test_questionnaire_batch_ucbadmissions.R` 等）の期待値を `evidence_runs/` に更新する。
- **[Risk] 二重プレフィックス正規化による意図しない改名**: `running_test` のような単語が誤って `ning_test` に削られるリスク。
  - **Mitigation**: 正規表現を `^run_` に限定（アンダースコア必須）し、`run_` で始まる場合のみ先頭を除去する。

## Migration Plan

1. **Phase 1: 共有基盤改修**: `run_scope.R` の原子的予約・ID正規化・旧探索互換を実装し、単体テストで検証。
2. **Phase 2: 各スキルおよびドキュメント更新**: 各スキルのスクリプト既定値、SKILL.md、`AGENTS.md`、`README.md`、`.gitignore` を更新。
3. **Phase 3: テスト実行と実演検証**: 回帰テストスイート全件実行および各スキルの最小実演。
