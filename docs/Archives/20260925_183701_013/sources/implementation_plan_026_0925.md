# 実装計画 026 — Section 13.10–13.13（Phase C 残り）

created: 2026-09-25 15:43 (JST)
update: 2026-09-25 15:50 (JST)
author: Auto (Composer)
approval: ユーザー指示「承認。実装して」を本範囲の実装承認として扱う
hold_lift: [s13_9_ledger_hold_lift_001_0925.md](s13_9_ledger_hold_lift_001_0925.md)

## 1. 目的

Section 13.9 HOLD 解除後の Phase C 残りを閉じる。

| ID | 内容 |
|---|---|
| **13.10** | 設定可能な discordance 方針（近傍 $k$ または距離半径）＋先例分布提示＋乖離を "QA Review Candidate" として助言 |
| **13.11** | 文言契約（乖離＝QA Review Candidate。system error / invalid 禁止）。string audit |
| **13.12** | study phase / data cutoff 横断の意思決定軌道追跡 |
| **13.13** | 患者行あり → patient-level bootstrap co-clustering。term summary のみ → `NOT_ASSESSED` / `CROSS_THEME_DEPENDENCE_UNAVAILABLE` |

## 2. 範囲外

- Section 14 HTML / Dashboard
- 規制判断・ラベル自動変更（13.14 維持）
- 署名 / WORM / 外部永続ストア

## 3. 契約（実装方針）

### 3.1 Discordance（13.10）+ 文言（13.11）

1. 入力は `retrieve_nearest_precedents()` 相当の近傍＋active の provisional `decision_state`。
2. 方針は排他的に 1 つ:
   - `policy = "k_neighbors"` + 正整数 `k`
   - `policy = "distance_radius"` + 有限 `[0,1]` の `radius`（Gower）
3. 近傍の `decision_state` 最頻値を `dominant_state` とする（同票は `tie=true`、discordance は出さない／または `QA Review Candidate` の tie 理由を明示。実装は **tie → advisory なし + `tie=true`**）。
4. `provisional_state != dominant_state` かつ非 tie のときだけ:
   - `advisory_flag = "QA Review Candidate"`
   - `severity = "advisory"`（error / fatal / invalid 禁止）
   - workflow は継続（stop / throw しない）
5. 禁止語監査（結果オブジェクト・文言定数）: `error`, `fatal`, `invalid`, `system defect`, `reject`, `自動却下` 等を discordance 文脈で使わない。

### 3.2 Trajectory（13.12）

1. 同一 `case_id`（または `evidence_profile` 系列キー）に対し、`study_phase` / `data_cutoff` / `decided_at_jst` 付き決定イベント列を時系列ソート。
2. 出力: `trajectory`（状態遷移列）+ `n_changes` + `phases` / `cutoffs`。
3. ledger レコードからの導出を優先（13.9 成果物との接続）。決定ラベルは特徴量に入れない。

### 3.3 Stability（13.13）

1. **患者行あり**（明示 `patient_rows` / 共有 subject ID）: 患者単位 bootstrap → 各 replicate で HAC `fixed_k` → pair-wise co-clustering 頻度行列。`stability_status = "ASSESSED"` + 要約指標（例: 平均 co-clustering / 対角平均）。
2. **term summary のみ**（現行既定）: 既存どおり `stability_status = "NOT_ASSESSED"`, `reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE"`。独立 PT bootstrap で擬似安定性を名乗らない。
3. `evidence_cluster.R` の governance フィールドを 13.13 API 経由で上書き可能にする（既定は NOT_ASSESSED 維持）。

## 4. 変更対象（予定）

| パス | 役割 |
|---|---|
| `.agents/shared/evidence_discordance.R` | 新規: 13.10/13.11 |
| `.agents/shared/evidence_trajectory.R` | 新規: 13.12 |
| `.agents/shared/evidence_cluster.R` | 13.13 API（bootstrap / NOT_ASSESSED） |
| `schemas/discordance-advisory-v1.json` | 新規 |
| `schemas/decision-trajectory-v1.json` | 新規 |
| `tests/test_evidence_discordance.R` | 13.10/11 |
| `tests/test_evidence_trajectory.R` | 13.12 |
| `tests/test_evidence_cluster.R` | 13.13 拡張 |
| `.agents/skills/evidence-decision-review/SKILL.md` | Phase C 更新 |
| `openspec/.../tasks.md` | チェック更新 |

## 5. 実装バッチ

1. **Batch A**: 13.10 + 13.11（discordance + wording）→ verify
2. **Batch B**: 13.12（trajectory）→ verify
3. **Batch C**: 13.13（stability）→ verify + full regression

各 Batch 後に `Yip:` 中間コミット可（別指示時）。

## 6. 検証

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

## 7. 承認ゲート

- 本計画の明示承認があるまでコード変更しない。
- 独立 QA・commit / push は別指示まで行わない。
