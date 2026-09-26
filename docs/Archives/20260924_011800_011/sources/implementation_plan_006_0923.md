# 実装計画書: Phase 2 Section 9 (1:k Matched Sets) 完全修復計画 (Review #6 確定版)

- **計画書番号**: `implementation_plan_006_0923`
- **作成・改訂日時**: 2026-09-23 17:05 (JST)
- **対象ブランチ**: `feat/comparative-evidence-reporting-v3`
- **基準コミット（HEAD）**: `51f846b8ea8db7604156fc1b1a65b3a15310773b`
- **準拠レビュー文書**:
  - [`docs/Artifacts/Phase2_Section9_matched_sets_review_1_20260923.md`](Phase2_Section9_matched_sets_review_1_20260923.md) (Code Review #6)
  - [`docs/Artifacts/Phase2_Section9_repair_plan_review_1_20260923.md`](Phase2_Section9_repair_plan_review_1_20260923.md) (Plan Review Gate)
- **対象 OpenSpec**: `openspec/changes/comparative-evidence-reporting-v3/` (Section 9)

---

## 1. 概要と修復目標

独立計画レビュー（Plan Review Gate）の要求事項（H-01〜H-04, M-01〜M-04）に完全準拠し、以下の統計数理・出力契約・ガバナンスの未確定事項を確定の上で実装する。

1. **H-01 (部分ゼロ参照群 RR の統治ポリシー)**:
   - `rr_bootstrap_diagnostics`（`defined_replicates`, `undefined_replicates`, `defined_fraction`）をメタデータとして記録。
   - 保守的ポリシー（Conservative Option）を採用：ブートストラップ反復内で未定義ドローが 1 件でも発生した場合（`undefined_replicates > 0`）、`RR percentile interval = null` とし、不安定な比率の代わりに安定な RD を主対比として提示する。
2. **H-02 (ATT 加重対照群分散の確定式)**:
   - 処置群重み $w_{Tj} = 1$、対照群重み $w_{Rj\ell} = 1/k_j$（両群ともに総重み $J$）。
   - 加重平均：$\bar{X}_T = \frac{1}{J}\sum_j X_{Tj}$、$\bar{X}_R = \frac{1}{J}\sum_j \bar{X}_{Rj}$。
   - 加重2次中心モーメント（SMD 分散）：
     $$s_T^2 = \frac{1}{J}\sum_{j=1}^J (X_{Tj} - \bar{X}_T)^2, \quad s_R^2 = \frac{1}{J}\sum_{j=1}^J \sum_{\ell=1}^{k_j} \frac{1}{k_j}(X_{Rj\ell} - \bar{X}_R)^2$$
     $$s_{pooled} = \sqrt{\frac{s_T^2 + s_R^2}{2}}, \quad SMD = \frac{\bar{X}_T - \bar{X}_R}{s_{pooled}}$$
3. **H-03 (生カウント vs ATT 加重リスクのスキーマ分離)**:
   - `matched_set.raw_target_counts`（`events`, `total`）および `matched_set.raw_reference_counts`（`events`, `total`）を定義。
   - `reference_cohort.estimate_semantics = "att_set_weighted_risk"` を明記し、`reference_cohort.events = null`, `reference_cohort.total = null` とすることで生比率の単純除算による誤解を遮断。
4. **H-04 (OpenSpec 正本仕様の改訂)**:
   - `specs/comparative-design-inference/spec.md`, `design.md`, `tasks.md` を修復対象として更新（Task 9.7〜9.12 の追加）。
5. **M-01 (被験者 ID 必須化と非復元検証)**:
   - `subject_id_col` を必須引数（mandatory）とし、全被験者 ID の一意性を検証（重複は Fail-Fast 拒絶）。
6. **M-02 (draws 側のブートストラップスコープ保持)**:
   - `draws.matched_set_metadata` にも `estimand = "ATT"`, `bootstrap_scope` を保持。
7. **M-03 (SMD スキーマの null/status 定義)**:
   - `smd`（`["number", "null"]`）、`status`（`["OK", "ZERO_VARIANCE_ZERO_DIFFERENCE", "ZERO_VARIANCE_NONZERO_DIFFERENCE"]`）。
8. **M-04 (実行時引数バリデーション)**:
   - `caliper`, `discarded_*`, `seed=NULL` などの境界検証を完備。

---

## 2. 変更対象ファイル一覧

| 操作 | ファイルパス | 変更概要 |
| :--- | :--- | :--- |
| **[MODIFY]** | `openspec/changes/comparative-evidence-reporting-v3/specs/comparative-design-inference/spec.md` | ATT加重SMD式、ゼロ除算RRポリシー、被験者ID契約、スコープメタデータの規範化 |
| **[MODIFY]** | `openspec/changes/comparative-evidence-reporting-v3/design.md` | Section 9 数理仕様（分散定義、生カウント分離）の更新 |
| **[MODIFY]** | `openspec/changes/comparative-evidence-reporting-v3/tasks.md` | 修復タスク 9.7〜9.12 の追加と追跡 |
| **[MODIFY]** | `schemas/comparative-evidence-v1.json` | `raw_target/reference_counts`, `estimate_semantics`, `bootstrap_scope`, `smd status` の定義 |
| **[MODIFY]** | `schemas/comparative-draws-v1.json` | `matched_set_metadata` への `estimand`, `bootstrap_scope`, `rr_bootstrap_diagnostics` 追加 |
| **[MODIFY]** | `.agents/shared/matched_set_inference.R` | 全修復ロジックの実装（必須 subject_id、加重分散、ゼロ参照RRポリシー、生カウント分離） |
| **[MODIFY]** | `.agents/skills/comparative-design-analysis/SKILL.md` | Abadie & Imbens (2008) 境界および ATT 加重 SMD の仕様追記 |
| **[MODIFY]** | `tests/test_matched_set_inference.R` | T1〜T8 の全追加テストケース完備 |
| **[MODIFY]** | `tests/test_comparative_schemas.R` | 更新後スキーマに対する Draft-7 純R検証テストの更新 |

---

## 3. 段階的実装手順

### ステップ 1: OpenSpec 正本仕様およびタスク更新
- `specs/comparative-design-inference/spec.md`, `design.md` を改訂。
- `tasks.md` に修復タスク（9.7〜9.12）を追加。

### ステップ 2: JSON スキーマ更新（Contract First）
- `comparative-evidence-v1.json` および `comparative-draws-v1.json` を更新。

### ステップ 3: コア推論器実装修復（`matched_set_inference.R`）
- `subject_id_col` の必須検証。
- ATT 加重分散による $s_{pooled}$ および SMD `status` の計算。
- 観測標本ゼロ参照群および部分ゼロ反復時の RR 抑制ポリシー実装。
- `reference_cohort` の生カウント分離（`raw_*_counts`）と `estimate_semantics` 付与。

### ステップ 4: スキル文書およびテストスイート拡充
- `SKILL.md` の更新。
- `test_matched_set_inference.R` に T1（完全一致定数）、T2（完全分離ゼロ分散）、T3（可変比率ATT加重分散）、T4（部分ゼロ反復RR抑制）、T5（重複ID拒絶）、T6（生カウント分離）、T7（引数型バリデーション）、T8（スコープメタデータ）を追加。
- `test_comparative_schemas.R` 更新。

### ステップ 5: 全件回帰テストと検証
- `tests/run_regression_suite.R`（全40本）の実行（100% PASS）。
- `openspec validate`、`git diff --check`。
- レビュー用中間コミット（`Yip:` コミット）作成。

---

## 4. 検証コマンド

```bash
Rscript tests/test_matched_set_inference.R
Rscript tests/test_comparative_schemas.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```
