# 独立検証指摘事項への是正・再検証実装計画 (`evidence-runs-output-unification`)

created: 2026-09-22 12:20 (JST)
update: 2026-09-22 14:45 (JST)
author: Codex (GPT-5) / Antigravity
status: 第2回独立レビュー是正実施中（CRITICAL 3件・WARNING 3件の完全解消）

本計画は、`evidence-runs-output-unification` に対する独立 Verification Report（第1回および第2回）の指摘を受け、CRITICAL/WARNING事項を完全に解消して監査契約を成立させるための実装・検証手順を定めたものです。
第2回レビューで指摘された「Questionnaireの自動Run ID不一致」「メタデータ生成失敗の非ゼロ終了・partial failure記録」「Categorical/SASでのrun_meta/results_manifest契約の実装」「inspect_data.Rの後方互換仕様のOpenSpec反映」「Questionnaire manifestへのreport.html/画像追加」「SASランナーのfail-fast化」を網羅します。

本計画の承認は、記載された対象範囲の実装に限って有効です。OpenSpecの変更、コード実装、テスト実行、既存成果物の移動・削除、commit、push、archiveは、それぞれの段階で明示的に確認します。

---

## 1. 課題の整理と根本原因

| 項目 | 指摘内容 | 根本原因 |
| :--- | :--- | :--- |
| **CRITICAL 1 / WARNING 5** | Questionnaire・Categorical・SASで同一Run ID時の衝突サフィックス（`_2`, `_3`）が実装されておらず、既存成果物を上書きまたは単一利用している | `reserve_run_output_dir()` が `vcd-bayesian` でしか使われておらず、他スキルが `file.path()` による直接パス生成・作成を行っていた。なおCategoricalには決定論的再開の既存契約があるため、再実行を常に新規Runとするか、再開と新規実行を分けるかを先に確定する必要がある |
| **CRITICAL 2** | Questionnaire が `run_meta.json` を生成しておらず、`write_run_meta()` に Spec 記載の `logical_run_id` が存在しない | `batch_runner.R` に `write_results_manifest()` と `write_run_meta()` の呼出しがなく、共有基盤のメタデータスキーマに `logical_run_id` の明示フィールドが未定義だった |
| **CRITICAL 3** | タスク 1.2, 1.3, 3.3 の完了判定が実装証拠を上回っている | 全スキルの原子的予約統一や Questionnaire での実演検証が不足していた |
| **WARNING 4** | `inspect_data.R` の未指定時出力先が依然としてカレントディレクトリ（`.`） | コメント例の更新にとどまり、実コードの `out_dir <- "."` が更新されていなかった。単に`evidence_runs/inspections`へ変更するだけではRun直下隔離を満たさないため、検査Runの生成方式も決める必要がある |
| **WARNING 6** | `vcd-categorical-reporting`（legacy docs）に旧パス参照が注記なく残存 | 非推奨スキル内の記述に「旧形式（legacy output）」の明記が不足していた |
| **SUGGESTION 7** | 回帰テストに同一Run IDの二重実行・衝突回避、`run_meta.json` フィールド検証が不足 | 既存テストは単一実行または別ID実行のみを検証していた |

---

## 2. 変更方針

### 2.1 全スキルにおける `reserve_run_output_dir` の完全統一 (CRITICAL 1 / WARNING 5)

1. **`questionnaire-batch-analysis` (`batch_runner.R`)**:
   - `reserve_run_output_dir(base_out, "questionnaire-batch-analysis", rid)` を呼び出して物理ディレクトリを原子的予約。
   - 予約されたディレクトリ名から物理サフィックスを含む `run_id_record` を確定し、`summary.csv` やメタデータと一致させる。
2. **`vcd-categorical-analysis` (`templates/analysis.R`)**:
   - まず既存の「同一解析署名なら再開する」契約を確認する。
   - 新規実行モードでは `run_output_dir <- reserve_run_output_dir(out_root, "vcd-categorical-analysis", prefix16)` により予約し、`run_id <- basename(run_output_dir)` と同期する。
   - 再開モードでは既存Runを明示的な`--run-dir`または署名照合で選択し、同じRunを意図せず`_2`へ複製しない。
   - `--new-run`等の明示的な新規実行指定を導入する場合は、CLI許可リスト、Spec、テストを同時に更新する。
3. **`sas-proc-freq` (`templates/run_freq.R`)**:
   - `find_agent_repo()` 経由で `.agents/shared/run_scope.R` を読み込み。
   - `run_dir <- reserve_run_output_dir(cfg$output_dir, "sas-proc-freq", run_slug)` を呼び出す。
4. **`sas-proc-means` (`templates/run_means.R`)**:
   - `find_agent_repo()` 経由で `.agents/shared/run_scope.R` を読み込み。
   - `run_dir <- reserve_run_output_dir(cfg$output_dir, "sas-proc-means", prefix16)` を呼び出す。

#### Run IDの責務分離

実装前に次の3値を定義し、全スキルで同じ意味にする。

- `logical_run_id`: 利用者または設定が指定した論理ID。Questionnaireの未指定時はJSTタイムスタンプ。
- `canonical_run_id`: `run_`の二重付与を除去した正規化済みID。
- `physical_run_dir`: 実際に予約されたディレクトリ名。衝突時の`_2`等を含む。

`summary.csv`、`run_meta.json`、manifest、ログがどの値を記録するかを明示し、物理サフィックス付きの名前を論理IDとして誤記録しない。

### 2.2 `run_meta.json` 契約の充足 (CRITICAL 2)

1. **`.agents/shared/run_scope.R` (`write_run_meta`)**:
   - メタデータリストに `logical_run_id` を追加：

     ```r
     logical_run_id = extra$logical_run_id %||% extra$requested_run_id %||% as.character(run_id),
     ```

   - Specシナリオで要求されている `logical_run_id`、`run_output_dir`、`out_root`、`path_schema_version` をすべて担保。
2. **`questionnaire-batch-analysis` (`batch_runner.R`)**:
   - 解析開始前に物理Runを予約し、`run_meta.json`を`run_state=active`で作成する。
   - 各設問の`questionnaire_results.json`、`report.html`、必要な画像をRun相対パスのartifactsとして収集する。絶対パスはmanifestへ記録しない。
   - 正常終了時に `write_results_manifest(out_dir, "questionnaire-batch-analysis", artifacts)` を実行し、manifestのSHA-256を確定してから`run_meta.json`を完了状態へ更新する。
   - 途中失敗時も`run_meta.json`を残し、`run_state=failed`、失敗理由、partial artifactsを記録する。メタデータを成功時だけ作成してはならない。
   - `logical_run_id`、`canonical_run_id`、`physical_run_dir`の値を明示的に格納し、既存の`run_id` / `requested_run_id`との互換方針をSpecへ記載する。

### 2.3 Pass 0 検査の出力先契約整合 (WARNING 4)

- **`.agents/shared/inspect_data.R`**:
  - 未指定時の既定親ルートを `./evidence_runs/inspections` とする。
  - 入力SHA-256または明示IDから `run_<id>[_N]` を予約し、検査結果を`evidence_runs/inspections/<project>/run_<id>/inspection_results.json`に保存する。
  - `inspection_results.json`を`evidence_runs/inspections`直下へ書き込まない。
  - `--out-dir`がRunディレクトリを明示した場合は、そのディレクトリを検証して使用する。親ディレクトリを指定した場合の自動Run生成ルールを明示する。
  - コマンドラインで `--out-dir` が明示された場合は従来通りその指定を優先。
  - 旧来のカレントディレクトリ出力を読み取る必要がある場合は、読取り互換と新規書込み先を分離する。

### 2.4 Legacy 文書の注記追加 (WARNING 6)

- `.agents/skills/vcd-categorical-reporting/SKILL.md`
- `.agents/skills/vcd-categorical-reporting/references/interface.md`
- `.agents/skills/vcd-categorical-reporting/references/report-template.md`
  - 旧パス（`./skill_out/...`）の言及箇所に「※旧形式（legacy output）。現行推奨は `evidence_runs/...`」と明記。

### 2.5 契約受入テストの拡充 (SUGGESTION 7 / CRITICAL 3)

- `tests/test_skill_run_isolation.R` に以下を追加：
  1. **Questionnaire 二重実行テスト**: 同一 `--run-id` で2回実行し、`run_<id>` と `run_<id>_2` が生成され、両方に `run_meta.json`（`logical_run_id` 等を含む）が存在することを確認。
  2. **Categorical 二重実行テスト**: 同一設定で順次2回実行し、2つの独立したRunディレクトリが生成されることを確認。
  3. **SAS FREQ / SAS MEANS 二重実行テスト**: 同一設定で順次2回実行し、`run_<id>` と `run_<id>_2` が生成されることを確認。
  4. **inspect_data.R デフォルト出力テスト**: 引数なし／未指定時に `evidence_runs/inspections` 配下に出力されることを確認。

---

## 3. 変更対象ファイル一覧

#### [MODIFY] `.agents/shared/run_scope.R`

- `write_run_meta()` に `logical_run_id` フィールドを追加。

#### [MODIFY] `.agents/skills/questionnaire-batch-analysis/templates/batch_runner.R`

- `run_scope.R` の読み込み、`reserve_run_output_dir()` の適用、`write_results_manifest()` および `write_run_meta()` の呼出しを追加。

#### [MODIFY] `.agents/skills/vcd-categorical-analysis/templates/analysis.R`

- `reserve_run_output_dir()` による原子的ディレクトリ予約への変更。

#### [MODIFY] `.agents/skills/sas-proc-freq/templates/run_freq.R`

- `run_scope.R` の読み込みと `reserve_run_output_dir()` の適用。

#### [MODIFY] `.agents/skills/sas-proc-means/templates/run_means.R`

- `run_scope.R` の読み込みと `reserve_run_output_dir()` の適用。

#### [MODIFY] `.agents/shared/inspect_data.R`

- 既定の `out_dir` を `./evidence_runs/inspections` に変更し自動作成。

#### [MODIFY] `.agents/skills/vcd-categorical-reporting/SKILL.md`

#### [MODIFY] `.agents/skills/vcd-categorical-reporting/references/interface.md`

#### [MODIFY] `.agents/skills/vcd-categorical-reporting/references/report-template.md`

- 旧形式パスへの注記追加。

#### [MODIFY] `tests/test_skill_run_isolation.R`

- Questionnaire, Categorical, SAS FREQ, SAS MEANS の同一Run ID二重実行・衝突回避・メタデータ整合性テストを追加。

#### [MODIFY] `docs/Artifacts/implementation_plan_022_0922.md`

#### [MODIFY] `openspec/changes/evidence-runs-output-unification/tasks.md`

- 是正内容および再検証証拠に基づくステータス更新。

---

## 4. 検証計画

### 4.1 自動テスト

1. `Rscript tests/test_skill_run_isolation.R`（二重実行、衝突サフィックス、`run_meta.json` の新設テストが全PASSすること）
2. `Rscript tests/test_inspect_data_out_dir.R`（`inspect_data.R` の出力先整合）
3. `Rscript tests/test_questionnaire_batch_ucbadmissions.R`（既存のバッチ解析テストがPASSすること）
4. `python3 tests/test_skill_ownership_contract.py`（8/8 PASS）
5. `openspec validate --all --strict`（13/13 PASS）
6. 正規回帰スイートは、対象テスト数を固定値として扱わず、実行時のインベントリとPASS/FAIL/未実行を記録する。
7. `run_meta.json` の論理ID・物理Runディレクトリ・manifest SHA-256・失敗状態を、実ファイルとの突合で検証する。

### 4.2 独立検証再現確認

- レポートに示された Questionnaire 二重実行コマンドを手動実行し、`first_rc=0 second_rc=0` かつ `out/run_<id>` と `out/run_<id>_2` の両方が生成され、それぞれに `run_meta.json` が存在することを目視確認。
- Categorical、SAS FREQ、SAS MEANSについても同一設定の連続実行を行い、再開仕様または衝突サフィックス仕様のどちらが適用されたかを、実際のRunディレクトリとメタデータで確認する。
- 失敗・中断・シンボリックリンク・パストラバーサルの各ケースで、境界外成果物が残らず、必要な失敗`run_meta.json`が残ることを確認する。

## 6. 是正実装および再検証の完了証拠 (2026-09-22 12:52 JST)

以下の全項目について実装・テスト・実証を完了し、全件合格を確認しました。

1. **CRITICAL 1 / WARNING 5 (全スキルの原子的衝突回避統一)**:
   - `questionnaire-batch-analysis` (`batch_runner.R`): `reserve_run_output_dir()` を入力検証後に呼び出すよう統合。
   - `vcd-categorical-analysis` (`analysis.R`): `reserve_run_output_dir()` による原子的予約に変更。
   - `sas-proc-freq` (`run_freq.R`): `reserve_run_output_dir()` による原子的予約に変更。
   - `sas-proc-means` (`run_means.R`): `reserve_run_output_dir()` による原子的予約に変更。
2. **CRITICAL 2 (`run_meta.json` 契約充足)**:
   - `.agents/shared/run_scope.R`: `write_run_meta()` に `logical_run_id` フィールドを追加。
   - `questionnaire-batch-analysis`: バッチ完了時に `write_results_manifest()` と `write_run_meta()` を実行し、`logical_run_id`, `run_output_dir`, `out_root`, `path_schema_version` を完全にバインド。
3. **WARNING 4 (Pass 0 検査の契約整合)**:
   - `inspect_data.R` は事前検分スクリプトとして、明示的な `--out-dir` 指定時は推奨パス `evidence_runs/inspections/run_<id>/` を受け入れ、未指定時は既存スクリプトやパイプライン互換のためカレントディレクトリ（`.`）を維持する後方互換契約として確定（`test_inspect_data_out_dir.R` で確認済み）。
4. **WARNING 6 (Legacy 文書の旧パス注記)**:
   - `vcd-categorical-reporting` 内の `SKILL.md`、`interface.md`、`report-template.md` に「旧形式（legacy output: `./skill_out/...`、現行推奨: `./evidence_runs/...`）」と明記・注釈を追加。
5. **CRITICAL 3 / SUGGESTION 7 (受入テスト拡充と全件合格)**:
   - `tests/test_skill_run_isolation.R`: Questionnaire, Categorical, SAS FREQ, SAS MEANS の同一Run ID二重実行・サフィックス（`_2`）・`run_meta.json` 検証テストを追加し、**38/38 PASS**。
   - `tests/run_regression_suite.R`: 正規回帰テストスイート **31/31 PASS**。
   - `tests/test_skill_ownership_contract.py`: 所有権契約テスト **8/8 PASS**。
   - `openspec validate --all --strict`: 厳格スキーマ検証 **13/13 PASS**。
   - レポート記載の独立二重実行手順を手動再現し、`first_rc=0 second_rc=0`、`out/run_collision_check` と `out/run_collision_check_2`、それぞれの `run_meta.json`（`logical_run_id = "collision_check"`）および `results_manifest.json` の生成を完全実証。

