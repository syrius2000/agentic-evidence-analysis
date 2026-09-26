# アーカイブ済みArtifactの要約 (Batch 010)

- **created**: 2026-09-22 16:56 (JST)
- **author**: Antigravity
- **対象期間**: 2026-09-22 10:41 (JST) 〜 2026-09-22 16:55 (JST)
- **archive_batch_id**: 20260922_165600_010
- **source_count**: 2

---

## 1. 対象と結論

本ドキュメントは、`docs/Artifacts/` に配備されていた以下の実装計画書2件を精査・完了確認し、原本を [20260922_165600_010/sources/](20260922_165600_010/sources/) へ退避・集約したアーカイブです。

1. [implementation_plan_022_0922.md](20260922_165600_010/sources/implementation_plan_022_0922.md): リポジトリ内スキル出力先の `evidence_runs/` 統一・移行計画
2. [implementation_plan_023_0922.md](20260922_165600_010/sources/implementation_plan_023_0922.md): 独立検証指摘事項への是正・再検証実装計画 (`evidence-runs-output-unification`)

本期間において、本リポジトリは全統計解析スキルの出力隔離統一・監査証跡強化・衝突回避・後方互換探索に関する大規模な改修を完遂しました。第1回および第2回独立レビューで指摘されたCRITICAL全件およびWARNING全件を完全に解消し、OpenSpec delta specの同期（[openspec/specs/evidence-run-layout/spec.md](../../openspec/specs/evidence-run-layout/spec.md)）とChangeアーカイブ（`2026-09-22-evidence-runs-output-unification`）を完了しました。

---

## 2. 確定した決定と理由

| 計画・記録文書 | 確定した決定事項 | 理由・背景 | 集約先の節 |
| :--- | :--- | :--- | :--- |
| `implementation_plan_022_0922.md` | 全解析スキルの既定出力ルートを `evidence_runs/<skill_slug>/` に統一し、各Runは `run_<id>[_N]/` に完全隔離。 | 出力ルート直下への成果物漏洩を排除し、エビデンスの不変性・再現性を担保するため。 | §3.1 |
| 同上 | `questionnaire-batch-analysis` の過去生成成果物 `runs/<id>/` は移動・削除せず、読取り専用互換探索を維持。 | 既存の運用成果物や下流の集約レポート・ダッシュボードへの後方互換性を破壊しないため。 | §3.1 |
| `implementation_plan_023_0922.md` | `reserve_run_output_dir` による原子的ディレクトリ予約（`recursive=FALSE`、既存時は `_2`, `_3` サフィックス付与）を全4スキルランナー（Questionnaire, Categorical, SAS FREQ, SAS MEANS）へ完全統一。 | 同一ID指定や並行実行時の競合・上書き破壊を確実に防止するため。 | §3.2 |
| 同上 | Questionnaire の `--run-id auto` 指定時、利用者の指定値（`requested_run_id = "auto"`）と一意なJST時刻ID（`logical_run_id = "YYYYMMDD_HHMMSS"`）を明確に分離。 | 監査ログにおいて `"auto"` という曖昧な識別子が残る問題を排除するため。 | §3.2 |
| 同上 | SAS ランナー（FREQ / MEANS）において、16文字切り詰めスラッグは物理ディレクトリ命名に限定し、`logical_run_id` および `requested_run_id` には指定された論理IDそのものを完全保持。 | 16文字を超える長い論理IDがメタデータ上で切り詰められる問題を解消するため。 | §3.2 |
| 同上 | 全4スキルランナーにおいて、解析完了時に共通監査契約（`results_manifest.json` および `run_meta.json`）を必須生成し、ハッシュ（`results_manifest_sha256`）で封緘。設問失敗時は `run_state="failed"` を記録し非ゼロ終了。 | 失敗の警告握りつぶしを防止し、すべてのエビデンスに完全な監査証跡を付与するため。 | §3.2 |
| 同上 | `inspect_data.R` は事前検分スクリプトとして、未指定時はカレントディレクトリ出力を許容し、明示的 `--out-dir` 指定時は指定ディレクトリ配下に出力する後方互換シナリオをOpenSpecに明文化。 | 対話的検分ワークフローの後方互換性と、隔離出力規約の整合性を両立するため。 | §3.3 |

---

## 3. 主要成果と検証の限界

### 3.1 仕様およびアーキテクチャの統一成果

1. **新仕様の正本昇格**:
   - [openspec/specs/evidence-run-layout/spec.md](../../openspec/specs/evidence-run-layout/spec.md) を作成し、全6要件（Canonical Recommended Output Root, Run Isolation and No Root Leakage, Run Identifier Normalization and Collision Handling, Questionnaire Run Layout and Backward-Compatible Discovery, Path Safety and Symbolic Link Traversal Guard, Output Parameter Precedence and Run Meta Binding）を正本化。
2. **OpenSpec Change の完了アーカイブ**:
   - `openspec/changes/evidence-runs-output-unification` を [openspec/changes/archive/2026-09-22-evidence-runs-output-unification/](../../openspec/changes/archive/2026-09-22-evidence-runs-output-unification/) へアーカイブ。
3. **共有基盤とランナーの一体改修**:
   - `.agents/shared/run_scope.R`
   - `.agents/skills/questionnaire-batch-analysis/templates/batch_runner.R`
   - `.agents/skills/sas-proc-freq/templates/run_freq.R`
   - `.agents/skills/sas-proc-means/templates/run_means.R`
   - `.agents/skills/vcd-categorical-analysis/templates/analysis.R`

### 3.2 検証エビデンス

- **隔離・衝突回避・監査メタデータ契約テスト ([tests/test_skill_run_isolation.R](../../tests/test_skill_run_isolation.R))**: **73 / 73 PASS**
  - Bayesian, Questionnaire, SAS FREQ, SAS MEANS, Categorical 全スキルの原子的衝突回避（`_2` サフィックス）
  - 全4スキルの `run_meta.json` と `results_manifest.json` の存在・整合性
  - `results_manifest.json` 実体ファイル SHA-256 と `run_meta.json` 内 `results_manifest_sha256` の完全一致
  - `resolve_run_meta_paths` による `out_root` / `run_output_dir` / `path_schema_version`（1.0）の突合
  - 16文字超の長文論理IDの完全保持
  - Questionnaire 設問失敗時の `run_state="failed"` 記録および終了コード 1 停止
- **正規回帰テストスイート ([tests/run_regression_suite.R](../../tests/run_regression_suite.R))**: **31 / 31 PASS**
- **スキル所有権契約テスト ([tests/test_skill_ownership_contract.py](../../tests/test_skill_ownership_contract.py))**: **8 / 8 PASS**
- **OpenSpec 厳格検証 (`openspec validate --all --strict`)**: **13 / 13 Specs PASS**
- **コード書式検証 (`git diff --check`)**: **PASS**

### 3.3 検証の限界と成立条件

- **旧成果物の移行非実施**:
  過去の検証実行等で生成された旧レイアウト成果物は自動移行・削除せず、読取り専用として維持されます。新規実行のみが本出力規約に準拠します。
- **外部ファイルシステムの原子的操作**:
  ディレクトリの原子的予約は `dir.create(..., recursive = FALSE)` に依存しており、POSIX準拠ファイルシステムにおいて保証されます。

---

## 4. 未解決事項と引継ぎ

- **後続タスク**:
  - 本アーカイブ完了後、ワークツリーの変更（ランナー是正、テスト拡充、main spec同期、OpenSpecアーカイブ、Artifactsアーカイブ）を Git コミットし、最新のマイルストーンを記録する。

---

## 5. 元文書と復元情報

| 元文書パス (Artifacts) | 退避先パス (Archives) | 最終状態 | 備考 |
| :--- | :--- | :--- | :--- |
| `docs/Artifacts/implementation_plan_022_0922.md` | [20260922_165600_010/sources/implementation_plan_022_0922.md](20260922_165600_010/sources/implementation_plan_022_0922.md) | 完遂・アーカイブ | 初期統一計画書 |
| `docs/Artifacts/implementation_plan_023_0922.md` | [20260922_165600_010/sources/implementation_plan_023_0922.md](20260922_165600_010/sources/implementation_plan_023_0922.md) | 完遂・アーカイブ | 是正および再検証実装計画書 |

- **復元方法**:
  退避先ディレクトリ `docs/Archives/20260922_165600_010/sources/` から原本ファイルをコピーして復元可能です。また Git 履歴からもコミット `0711e65` 以降のツリーから復元できます。
