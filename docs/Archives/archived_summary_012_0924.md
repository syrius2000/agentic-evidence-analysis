# アーカイブ済みArtifactの要約 (Batch 012)

- **created**: 2026-09-24 14:11 (JST)
- **author**: Auto (Composer)
- **対象期間**: 2026-09-24 00:21 (JST) 〜 2026-09-24 01:48 (JST)
- **archive_batch_id**: 20260924_141100_012
- **source_count**: 11

---

## 1. 対象と結論

本ドキュメントは、`docs/Artifacts/` にあった Phase 2 Section 10（IPTW）完了文書および Section 11（人年発生率）初回実装文書 11 件を精査し、原本を [20260924_141100_012/sources/](20260924_141100_012/sources/) へ退避・集約したアーカイブです。

### アーカイブ対象文書一覧

1. `Phase2_Section10_IPTW_QA_Repair_Report1_20260924.md` 〜 `Report3_20260924.md`（3件）
2. `implementation_plan_009_0924.md` 〜 `implementation_plan_012_0924.md`（4件）
3. `iptw_qa_repair_execution_001_0924.md` 〜 `003_0924.md`（3件）
4. `person_time_section11_execution_001_0924.md`

### 結論

Section 10 は独立 QA Report3 で `PASS / ACCEPT`（reviewed: `4829cb0`）とし、10.R1〜10.R22 の修復・受入後硬化を完了・凍結した。Section 11 は計画012に基づき Gamma–Poisson 人年率エンジン（11.1〜11.6）を実装し、独立 QA で `PASS / ACCEPT`（reviewed: `1d42f4a`）とした。現行作業は Section 12 / QA-0001（計画013以降）へ移行済みのため、本バッチ文書は安全にアーカイブできる。

---

## 2. 確定した決定と理由

| 元文書 | 確定した決定事項 | 理由・背景 | 集約先の節 |
| :--- | :--- | :--- | :--- |
| Report1 / plan009 / exec001 | IPTW レポートを bootstrap 推論セマンティクスに分岐。PS 境界を公開 API 化し raw/effective PS・clipping を機械可読化。raw counts と weighted risk を分離。 | Bayesian の posterior/ETI と IPTW の bootstrap percentile を混同しないため。 | §3.1 |
| Report2 / plan010 / exec002 | evidence override 時は evidence 内 raw counts を真値源とし不一致で Fail-Fast。ESS と descriptive N を分離。PS provenance を schema 必須化。小セル抑制（N&lt;10）は Owner 未決のため未実装。 | 表示・schema・runtime の provenance を一致させ、未承認の表示マスキングを入れないため。 | §3.1 |
| Report3 / plan011 / exec003 | Section 10 を `PASS / ACCEPT`。PS 境界 `upper` を `exclusiveMaximum: 1`。共有 PS 要約 schema を新設。Batch 011 要約の Section 9 方式名・パス誤記を訂正。 | 受入後 hardening（非ブロッカー）として schema 厳密化と監査文書修正を完了するため。 | §3.1 |
| plan012 / person_time exec001 | Jeffreys 由来 `Gamma(shape=x+0.5, rate=T)`、IRD/IRR 率専用変換、率専用 evidence schema、参照群0件時 IRR 平均の発散抑止を実装。 | 二値リスク schema に率を混入させず、人年率の不確実性を明示するため。 | §3.2 |

---

## 3. 主要成果と検証の限界

### 3.1 Section 10（IPTW）

1. `.agents/shared/iptw_inference.R` と reporting の推論セマンティクス分離・診断拡張。
2. `schemas/comparative-evidence-v1.json` / `comparative-draws-v1.json` / `comparative-ps-summary-v1.json` の provenance・境界契約強化。
3. 検証（実施記録時点）: IPTW・schema・reporting・正規回帰・OpenSpec strict が PASS。

### 3.2 Section 11（Person-Time 初回）

1. `.agents/shared/person_time_rate.R` 新設、`comparative_contrasts.R` へ率専用変換追加。
2. `schemas/comparative-rate-evidence-v1.json` 新設。
3. 検証（実施記録時点）: `test_person_time_rate.R` 30 PASS、`test_comparative_schemas.R` 96 PASS、正規回帰 42/42、OpenSpec strict valid。

### 3.3 検証の限界

- 本バッチの実施記録は実装者実行証拠であり、独立 QA / Owner 裁定そのものではない（判定は各 QA 報告に記載）。
- 人年率のレポート画面表示、患者内反復イベント相関、時間変化ハザードは対象外。
- 小セル表示抑制（N&lt;10）は Owner 要件未確定のまま保留。

---

## 4. 未解決事項と引継ぎ

1. **Section 11 受入後硬化〜Section 12 / QA-0001**:
   - 当時は Artifacts に残置。**Batch 014（`docs/Archives/20260925_185527_014/` / `archived_summary_014_0925.md`）でアーカイブ済み**。
2. **小セル抑制**:
   - Owner が要件確定した場合のみ別計画で扱う。
3. **Batch 011 要約 §4**:
   - 本アーカイブ完了により、旧「009/010 進行中」記述は過去形へ更新済み（下記リンク修復）。

---

## 5. 元文書と復元情報

退避先: [20260924_141100_012/sources/](20260924_141100_012/sources/)
移動時点の作業ツリー HEAD: `7cd4b11c6e0ad74d46b359e2a283c564c1338f65`
復元: `git checkout <commit> -- docs/Artifacts/<filename>` または sources 配下のコピーを戻す。

| 元ファイル名 | 退避先相対パス |
| :--- | :--- |
| `Phase2_Section10_IPTW_QA_Repair_Report1_20260924.md` | [sources/...](20260924_141100_012/sources/Phase2_Section10_IPTW_QA_Repair_Report1_20260924.md) |
| `Phase2_Section10_IPTW_QA_Repair_Report2_20260924.md` | [sources/...](20260924_141100_012/sources/Phase2_Section10_IPTW_QA_Repair_Report2_20260924.md) |
| `Phase2_Section10_IPTW_QA_Repair_Report3_20260924.md` | [sources/...](20260924_141100_012/sources/Phase2_Section10_IPTW_QA_Repair_Report3_20260924.md) |
| `implementation_plan_009_0924.md` | [sources/...](20260924_141100_012/sources/implementation_plan_009_0924.md) |
| `implementation_plan_010_0924.md` | [sources/...](20260924_141100_012/sources/implementation_plan_010_0924.md) |
| `implementation_plan_011_0924.md` | [sources/...](20260924_141100_012/sources/implementation_plan_011_0924.md) |
| `implementation_plan_012_0924.md` | [sources/...](20260924_141100_012/sources/implementation_plan_012_0924.md) |
| `iptw_qa_repair_execution_001_0924.md` | [sources/...](20260924_141100_012/sources/iptw_qa_repair_execution_001_0924.md) |
| `iptw_qa_repair_execution_002_0924.md` | [sources/...](20260924_141100_012/sources/iptw_qa_repair_execution_002_0924.md) |
| `iptw_qa_repair_execution_003_0924.md` | [sources/...](20260924_141100_012/sources/iptw_qa_repair_execution_003_0924.md) |
| `person_time_section11_execution_001_0924.md` | [sources/...](20260924_141100_012/sources/person_time_section11_execution_001_0924.md) |

### 残置したアクティブ文書（当時・再採番なし）

- Section 11/12 / QA-0001 文書は **Batch 014** でアーカイブ済み（`archived_summary_014_0925.md`）。
- Section 13 文書は **Batch 013** でアーカイブ済み（`archived_summary_013_0925.md`）。
