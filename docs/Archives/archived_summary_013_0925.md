# アーカイブ済みArtifactの要約 (Batch 013)

- **created**: 2026-09-25 18:37 (JST)
- **author**: Auto (Composer)
- **対象期間**: 2026-09-24 14:12 (JST) 〜 2026-09-25 18:28 (JST)
- **archive_batch_id**: 20260925_183701_013
- **source_count**: 42

---

## 1. 対象と結論

本ドキュメントは、`docs/Artifacts/` にあった OpenSpec `comparative-evidence-reporting-v3` **Section 13（Evidence-Decision Review Engine）** の完了文書 42 件を精査し、原本を [20260925_183701_013/sources/](20260925_183701_013/sources/) へ退避・集約したアーカイブです。

### アーカイブ対象文書一覧

1. 実装計画 `implementation_plan_016_0924.md` 〜 `implementation_plan_028_0925.md`（13 件）
2. Section 13 実行・QA・修復証跡 `s13_*`（29 件）

### 結論

Section 13 は Phase A（特徴量）→ Phase B（Gower / HAC / K-means / 先例）→ Phase C（ledger / discordance / trajectory / stability）を完了した。最終独立 Re-QA Review3（`s13_10_13_phase_c_qa_review3_001_0925.md`、reviewed `7b51fd1`、QA commit `c00a1af`）で **Section 13.10–13.13: PASS / ACCEPT**（Blocker/High/Medium = 0）。**Section 14 へ進行可能**。本バッチ文書は安全にアーカイブできる。

---

## 2. 確定した決定と理由

| 元文書群 | 確定した決定事項 | 理由・背景 | 集約先 |
| :--- | :--- | :--- | :--- |
| plan016–017 / phaseA QA | 決定ラベル無し `evidence-feature-v1`、run lifecycle、delta 原子性 | 規制ラベルをクラスタ特徴に混入させない | §3.1 |
| plan018–019 / Gower+HAC | 凍結範囲寄与クリップ、HAC average + fixed_k、exploratory only | Gower 幾何と自動 K 推論を禁止 | §3.2 |
| plan020–023 / K-means+先例 | 連続特徴のみ K-means、canonical nested feature、distance_scorable 分離 | 部分 feature の距離誤用を防ぐ | §3.2 |
| plan024–025 / ledger | append-only SHA 連鎖、exact field set、JST 正規形式 | tamper-evident 監査 | §3.3 |
| plan026–028 / Phase C | Discordance=QA Review Candidate、trajectory+ledger verify、patient refit + canonical assert | 助言のみ／偽 bootstrap 排除／schema 強制 | §3.3 |

---

## 3. 主要成果と検証の限界

### 3.1 Phase A（13.1–13.3 / 13.A.R*）

1. `.agents/skills/evidence-decision-review/` と `evidence_feature_extract.R`。
2. 禁止キー Fail-Fast、core / delta_dependent 分割、run_meta lifecycle。

### 3.2 Phase B（13.4–13.8 / 13.14）

1. `evidence_gower.R` / `evidence_cluster.R` / `evidence_precedent.R`。
2. frozen range overflow、HAC fixed_k、K-means distinct-case gate、先例版バインドと最近傍。

### 3.3 Phase C（13.9–13.13）

1. `evidence_ledger.R` / `evidence_discordance.R` / `evidence_trajectory.R`、stability API。
2. wording 監査は system 文言のみ。ASSESSED は `patient_rows`+`refit_features`+`frozen_range`+canonical feature 必須。
3. 最終検証（実装者記録）: 回帰 49/49、OpenSpec strict valid。独立 QA は各 review 文書の判定を正とする。

### 3.4 検証の限界

- 独立 QA ランタイムに R が無い場合、PASS 数は実装者 claim 扱い（判定本文はコードレビュー）。
- Section 14 HTML / Dashboard は未実装。
- HTML Zero-External-Asset は Section 14 のゲート対象。

---

## 4. 未解決事項と引継ぎ

1. **Section 14（Dashboard / Self-Contained Report QA）** へ進行可。
2. **後続バックログ（非ブロッカー / Section 13 ACCEPT 後）**:
   - precedent `decided_at_jst` を ledger/trajectory と同 JST 正規化
   - `attach_cluster_stability` の NOT_ASSESSED 付け替え時 stale フィールド掃除
   - discordance を truncated neighborhood に掛ける API 注記
3. **Artifacts 残置（当時）**: `implementation_plan_013`〜`015`、`s11_*`、`s12_*`（Section 11/12）。→ **Batch 014（`20260925_185527_014`）でアーカイブ済み**。計画番号は再採番しない。

---

## 5. 元文書と復元情報

退避先: [20260925_183701_013/sources/](20260925_183701_013/sources/)
移動時点の作業ツリー HEAD: `c00a1afaf0d50ea881dbd70d5f42e673be784a9a`
復元: `git checkout <commit> -- docs/Artifacts/<filename>` または sources 配下のコピーを戻す。

| 元ファイル名 | 退避先相対パス |
| :--- | :--- |
| `implementation_plan_016_0924.md` | [sources/implementation_plan_016_0924.md](20260925_183701_013/sources/implementation_plan_016_0924.md) |
| `implementation_plan_017_0924.md` | [sources/implementation_plan_017_0924.md](20260925_183701_013/sources/implementation_plan_017_0924.md) |
| `implementation_plan_018_0924.md` | [sources/implementation_plan_018_0924.md](20260925_183701_013/sources/implementation_plan_018_0924.md) |
| `implementation_plan_019_0924.md` | [sources/implementation_plan_019_0924.md](20260925_183701_013/sources/implementation_plan_019_0924.md) |
| `implementation_plan_020_0925.md` | [sources/implementation_plan_020_0925.md](20260925_183701_013/sources/implementation_plan_020_0925.md) |
| `implementation_plan_021_0925.md` | [sources/implementation_plan_021_0925.md](20260925_183701_013/sources/implementation_plan_021_0925.md) |
| `implementation_plan_022_0925.md` | [sources/implementation_plan_022_0925.md](20260925_183701_013/sources/implementation_plan_022_0925.md) |
| `implementation_plan_023_0925.md` | [sources/implementation_plan_023_0925.md](20260925_183701_013/sources/implementation_plan_023_0925.md) |
| `implementation_plan_024_0925.md` | [sources/implementation_plan_024_0925.md](20260925_183701_013/sources/implementation_plan_024_0925.md) |
| `implementation_plan_025_0925.md` | [sources/implementation_plan_025_0925.md](20260925_183701_013/sources/implementation_plan_025_0925.md) |
| `implementation_plan_026_0925.md` | [sources/implementation_plan_026_0925.md](20260925_183701_013/sources/implementation_plan_026_0925.md) |
| `implementation_plan_027_0925.md` | [sources/implementation_plan_027_0925.md](20260925_183701_013/sources/implementation_plan_027_0925.md) |
| `implementation_plan_028_0925.md` | [sources/implementation_plan_028_0925.md](20260925_183701_013/sources/implementation_plan_028_0925.md) |
| `s13_10_13_phase_c_exec_001_0925.md` | [sources/s13_10_13_phase_c_exec_001_0925.md](20260925_183701_013/sources/s13_10_13_phase_c_exec_001_0925.md) |
| `s13_10_13_phase_c_qa_review1_001_0925.md` | [sources/s13_10_13_phase_c_qa_review1_001_0925.md](20260925_183701_013/sources/s13_10_13_phase_c_qa_review1_001_0925.md) |
| `s13_10_13_phase_c_qa_review2_001_0925.md` | [sources/s13_10_13_phase_c_qa_review2_001_0925.md](20260925_183701_013/sources/s13_10_13_phase_c_qa_review2_001_0925.md) |
| `s13_10_13_phase_c_qa_review3_001_0925.md` | [sources/s13_10_13_phase_c_qa_review3_001_0925.md](20260925_183701_013/sources/s13_10_13_phase_c_qa_review3_001_0925.md) |
| `s13_10_13_phase_c_repair_exec_001_0925.md` | [sources/s13_10_13_phase_c_repair_exec_001_0925.md](20260925_183701_013/sources/s13_10_13_phase_c_repair_exec_001_0925.md) |
| `s13_13_r3_repair_exec_001_0925.md` | [sources/s13_13_r3_repair_exec_001_0925.md](20260925_183701_013/sources/s13_13_r3_repair_exec_001_0925.md) |
| `s13_4_gower_exec_001_0924.md` | [sources/s13_4_gower_exec_001_0924.md](20260925_183701_013/sources/s13_4_gower_exec_001_0924.md) |
| `s13_4_gower_qa_repair_001_0924.md` | [sources/s13_4_gower_qa_repair_001_0924.md](20260925_183701_013/sources/s13_4_gower_qa_repair_001_0924.md) |
| `s13_4_gower_repair_exec_001_0924.md` | [sources/s13_4_gower_repair_exec_001_0924.md](20260925_183701_013/sources/s13_4_gower_repair_exec_001_0924.md) |
| `s13_5_hac_exec_001_0924.md` | [sources/s13_5_hac_exec_001_0924.md](20260925_183701_013/sources/s13_5_hac_exec_001_0924.md) |
| `s13_5_hac_qa_review1_001_0924.md` | [sources/s13_5_hac_qa_review1_001_0924.md](20260925_183701_013/sources/s13_5_hac_qa_review1_001_0924.md) |
| `s13_5_hac_qa_review2_001_0925.md` | [sources/s13_5_hac_qa_review2_001_0925.md](20260925_183701_013/sources/s13_5_hac_qa_review2_001_0925.md) |
| `s13_5_hac_repair_exec_001_0925.md` | [sources/s13_5_hac_repair_exec_001_0925.md](20260925_183701_013/sources/s13_5_hac_repair_exec_001_0925.md) |
| `s13_6_kmeans_exec_001_0925.md` | [sources/s13_6_kmeans_exec_001_0925.md](20260925_183701_013/sources/s13_6_kmeans_exec_001_0925.md) |
| `s13_6_kmeans_qa_review1_001_0925.md` | [sources/s13_6_kmeans_qa_review1_001_0925.md](20260925_183701_013/sources/s13_6_kmeans_qa_review1_001_0925.md) |
| `s13_7_8_precedent_exec_001_0925.md` | [sources/s13_7_8_precedent_exec_001_0925.md](20260925_183701_013/sources/s13_7_8_precedent_exec_001_0925.md) |
| `s13_7_8_precedent_qa_review1_001_0925.md` | [sources/s13_7_8_precedent_qa_review1_001_0925.md](20260925_183701_013/sources/s13_7_8_precedent_qa_review1_001_0925.md) |
| `s13_7_8_precedent_qa_review2_001_0925.md` | [sources/s13_7_8_precedent_qa_review2_001_0925.md](20260925_183701_013/sources/s13_7_8_precedent_qa_review2_001_0925.md) |
| `s13_7_8_precedent_r1b_repair_exec_001_0925.md` | [sources/s13_7_8_precedent_r1b_repair_exec_001_0925.md](20260925_183701_013/sources/s13_7_8_precedent_r1b_repair_exec_001_0925.md) |
| `s13_7_8_precedent_repair_exec_001_0925.md` | [sources/s13_7_8_precedent_repair_exec_001_0925.md](20260925_183701_013/sources/s13_7_8_precedent_repair_exec_001_0925.md) |
| `s13_9_ledger_exec_001_0925.md` | [sources/s13_9_ledger_exec_001_0925.md](20260925_183701_013/sources/s13_9_ledger_exec_001_0925.md) |
| `s13_9_ledger_hold_lift_001_0925.md` | [sources/s13_9_ledger_hold_lift_001_0925.md](20260925_183701_013/sources/s13_9_ledger_hold_lift_001_0925.md) |
| `s13_9_ledger_qa_review1_001_0925.md` | [sources/s13_9_ledger_qa_review1_001_0925.md](20260925_183701_013/sources/s13_9_ledger_qa_review1_001_0925.md) |
| `s13_9_ledger_repair_exec_001_0925.md` | [sources/s13_9_ledger_repair_exec_001_0925.md](20260925_183701_013/sources/s13_9_ledger_repair_exec_001_0925.md) |
| `s13_phaseA_exec_001_0924.md` | [sources/s13_phaseA_exec_001_0924.md](20260925_183701_013/sources/s13_phaseA_exec_001_0924.md) |
| `s13_phaseA_qa_repair_001_0924.md` | [sources/s13_phaseA_qa_repair_001_0924.md](20260925_183701_013/sources/s13_phaseA_qa_repair_001_0924.md) |
| `s13_phaseA_qa_review2_001_0924.md` | [sources/s13_phaseA_qa_review2_001_0924.md](20260925_183701_013/sources/s13_phaseA_qa_review2_001_0924.md) |
| `s13_phaseA_r5_exec_001_0924.md` | [sources/s13_phaseA_r5_exec_001_0924.md](20260925_183701_013/sources/s13_phaseA_r5_exec_001_0924.md) |
| `s13_phaseA_repair_exec_001_0924.md` | [sources/s13_phaseA_repair_exec_001_0924.md](20260925_183701_013/sources/s13_phaseA_repair_exec_001_0924.md) |

### 残置したアクティブ文書（再採番なし）

- `implementation_plan_013_0924.md` 〜 `implementation_plan_015_0924.md`
- `s11_*` / `s12_*` 証跡一式
