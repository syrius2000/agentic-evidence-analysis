# 実装計画 027 — Section 13.10–13.13 QA修復

created: 2026-09-25 17:00 (JST)
update: 2026-09-25 17:10 (JST)
author: Auto (Composer)
approval: ユーザー指示「計画承認。実装して」を本範囲の実装承認として扱う
review: [s13_10_13_phase_c_qa_review1_001_0925.md](s13_10_13_phase_c_qa_review1_001_0925.md)

## 1. 目的

Independent QA Review1 HOLD（High 2 / Medium 2）を閉じる。Section 14 は High クローズまで着手禁止。

| ID | 指摘 | 修復 |
|---|---|---|
| **13.10.R1 / 13.11.R1** | H13.10-01: wording audit が `REJECT`/`REJECTED` 状態で Fail-Fast | 監査対象を system 文言に限定 |
| **13.13.R1** | H13.13-01: 固定距離行列の行 bootstrap を patient-level と誤称 | 真の患者 bootstrap refit、さもなくば NOT_ASSESSED のみ |
| **13.12.R1** | M13.12-01: `trajectory_from_ledger` が verify しない | `verify_decision_ledger()` 必須化 |
| **13.13.R2** | M13.13-02: 非互換 stability を attach 可能 | n/k/linkage/labels 互換性検証 |
| **13.x.R3** | 回帰ゲート | discordance / trajectory / cluster / regression / OpenSpec |

## 2. 範囲外

- Section 14 HTML
- 13.9 ledger 本体変更（verify 呼び出しのみ）
- 署名 / WORM

## 3. 契約

### 3.1 Wording audit（13.10.R1 / 13.11.R1）

1. 禁止語スキャン対象は **system 制御フィールドのみ**: `wording` / `severity` / `advisory_flag`（＋将来の system reason）。
2. **スキャンしない**: `provisional_decision_state` / `dominant_state` / decision counts のキー / case_id / 歴史ラベル。
3. 維持: `halts_workflow=FALSE`、candidate 時 flag/severity、non-candidate 時 flag/severity 禁止。
4. テスト: `REJECT` vs `ACCEPT`、`ACCEPT` vs `REJECTED` → Candidate・例外なし。system wording に `fatal` → Violation。

### 3.2 Patient-level stability（13.13.R1）— Preferred path

1. **削除**: 固定 `distance_matrix` 行/列の `sample.int` + `unique(idx)` による擬似 ASSESSED。
2. **ASSESSED 条件（すべて必須）**:
   - `patient_rows`: `subject_id` + `unit_id`（クラスタ単位。同一 subject の複数 unit 行を許可）
   - `refit_features`: `function(sampled_subject_ids) -> named list of evidence-feature-v1`（unit_id キー）
   - `frozen_range` / `k` / `linkage`
3. 各 replicate:
   - 一意 subject を with-replacement 抽出（多重度保持）
   - 抽出 subject に属する **全 patient rows** を保持（cross-theme 依存）
   - `refit_features(sampled_ids)` → Gower → HAC `fixed_k`
   - 元 unit 集合への co-clustering 蓄積（欠落 unit は当該 pair をスキップ）
4. `n_bootstrap_requested` / `n_bootstrap_usable` / `n_bootstrap_failed` を記録。
5. `refit_features` 欠落 or `patient_rows` 不足 → **のみ** `NOT_ASSESSED` / `CROSS_THEME_DEPENDENCE_UNAVAILABLE`。偽 `patient_bootstrap_co_clustering` を出さない。
6. テスト: 同一 subject が複数 unit に出現する fixture。replicate が subject 抽出＋refit 駆動であることを証明（固定距離行列の行選択ではない）。

### 3.3 Ledger verify（13.12.R1）

`trajectory_from_ledger()` 先頭で `verify_decision_ledger(ledger)`。改ざん / 連鎖断裂 / 重複 ID は Fail-Fast。

### 3.4 Attach provenance（13.13.R2）

`attach_cluster_stability()` で検証:

```text
n_cases == n_units
k == k
linkage == linkage（HAC）
labels / pair_co dimnames 一致
method 互換（HAC 結果のみ ASSESSED を許可、または method 明示一致）
```

不一致は Fail-Fast。互換時は provenance を cluster result に残す。

## 4. 変更対象

- `.agents/shared/evidence_discordance.R`
- `.agents/shared/evidence_trajectory.R`（ledger source）
- `.agents/shared/evidence_cluster.R`
- `tests/test_evidence_discordance.R`
- `tests/test_evidence_trajectory.R`
- `tests/test_evidence_cluster.R`
- `.agents/skills/evidence-decision-review/SKILL.md`
- `openspec/.../tasks.md`（R タスク追記）
- 実行証跡

## 5. 検証

```bash
Rscript tests/test_evidence_discordance.R
Rscript tests/test_evidence_trajectory.R
Rscript tests/test_evidence_cluster.R
Rscript tests/test_evidence_precedent.R
Rscript tests/test_evidence_ledger.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict
git diff --check
```

## 6. 承認ゲート

- 本計画の明示承認があるまでコード変更しない。
- 独立再 QA・commit / push は別指示まで行わない。
