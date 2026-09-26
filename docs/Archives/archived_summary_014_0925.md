# アーカイブ済みArtifactの要約 (Batch 014)

- **created**: 2026-09-25 18:55 (JST)
- **author**: Auto (Composer)
- **対象期間**: 2026-09-24 02:07 (JST) 〜 2026-09-25 18:50 (JST)
- **archive_batch_id**: 20260925_185527_014
- **source_count**: 10

---

## 1. 対象と結論

本ドキュメントは、`docs/Artifacts/` にあった OpenSpec `comparative-evidence-reporting-v3` **Section 11（Person-Time 受入後硬化）/ Section 12（反復測定境界）/ QA-0001** の完了文書 10 件を精査し、原本を [20260925_185527_014/sources/](20260925_185527_014/sources/) へ退避・集約したアーカイブです。

### アーカイブ対象文書一覧

1. 実装計画 `implementation_plan_013_0924.md` 〜 `015_0924.md`（3 件）
2. Section 11 QA / 境界実施 `s11_person_time_qa_review1_001_0924.md`、`s11_s12_boundary_exec_001_0924.md`（2 件）
3. QA-0001 Cycle1/2 と R6/R7 証跡 `s12_qa0001_*`（4 件）
4. 独立 QA（R6/R7 受入後）`s11_s12_qa0001_r6r7_qa_001_0925.md`（1 件）

### 結論

Section 11 は `PASS / ACCEPT`（reviewed `1d42f4a`）後に 11.R7〜11.R11 を硬化。Section 12 は 12.1〜12.4 と QA-0001 Cycle1 修復（H01/M01–M03）を経て Cycle2 で `PASS / ACCEPT`。受入後 M03A 残件は QA0001.R6/R7（commit `7cd4b11`）で閉じ、独立 QA（`s11_s12_qa0001_r6r7_qa_001_0925.md`、HEAD `ac82b9e`）で **Sec11/Sec12 PASS/ACCEPT、R6/R7 受入可、M03A CLOSED**（新規 Blocker/High/Medium = 0）。**本バッチ文書は安全にアーカイブできる。**

---

## 2. 確定した決定と理由

| 元文書群 | 確定した決定事項 | 理由・背景 | 集約先 |
| :--- | :--- | :--- | :--- |
| plan013 / s11 QA / boundary exec | person-time draw を posterior 拘束、単位組・IRR 0件原子状態・persisted/ephemeral draw 契約を schema 化。`repeated_rows` で被験者単位 any_event 集約と fail-fast。 | 率推論の意味を二値リスクと混同させず、依存構造を黙って独立標本へ流さないため。 | §3.1–3.2 |
| plan014 / Cycle1 QA+repair | 依存列の宣言+heuristic マージ、`no_other_subject_dependence_confirmed`、`engine_input` ハンドオフ、`pass0-routing-v1` schema。 | H01 安全性境界と M01–M03 契約ギャップを同一サイクルで閉じるため。 | §3.2 |
| plan015 / Cycle2 / R6R7 exec+QA | 純R Draft-07 に `minLength`/`uniqueItems`、length-1 R character を native・正本 JSON は配列。 | M03A（ハーネス忠実度）を閉じ、R 便利形が JSON 契約を曖昧化しないため。 | §3.3 |

---

## 3. 主要成果と検証の限界

### 3.1 Section 11（Person-Time 受入後）

1. Gamma–Poisson Jeffreys（shape-rate）、IRD/IRR、単位組、ZERO_REFERENCE_EVENTS 原子状態。
2. 独立 QA 再確認で後退なし。

### 3.2 Section 12（反復測定境界）

1. Pass 0 `repeated_rows`、クラスタ/マッチ拒否、独立二群エンジンへの `engine_input` ハンドオフ。
2. GLMM/GEE・cluster bootstrap 推定器は未実装（設計境界のみ）。

### 3.3 QA-0001 / R6–R7

1. Cycle2 で H01/M01/M02 CLOSED、M03 PARTIAL → R6/R7 で M03A CLOSED。
2. 独立実行（QA 報告実測）: person_time 31 / pass0 40 / schemas 133 PASS、OpenSpec strict valid。Python Draft7 43 fixture 一致（レビュアー独立実行）。

### 3.4 検証の限界

- R8（routing atomicity 双方向拘束）は任意残件。
- Low L01/L02（混在型列の暗黙文字列化、`config_sha256` 表現依存）は任意 hardening。
- ADR/QA 案件メタデータは `draft`/cycle0 のまま（本バッチ対象外）。
- フル回帰スイートは当該独立 QA では未再実行（対象 3 テストのみ）。

---

## 4. 未解決事項と引継ぎ

1. **Section 14（Dashboard / Self-Contained Report QA）** へ進行可（Section 13 は Batch 013 で既アーカイブ）。
2. **任意バックログ（非ブロッカー）**: QA0001.R8、L01、L02。
3. **ADR/QA `QA-0001-comparative-section11-section12/`**: 必要なら別判断でメタデータ更新またはアーカイブ。
4. **Artifacts**: 本バッチ後は `.gitkeep` のみ。計画番号の再採番は行わない。

---

## 5. 元文書と復元情報

退避先: [20260925_185527_014/sources/](20260925_185527_014/sources/)
移動時点の作業ツリー HEAD: `ac82b9e4eee99b6642a8f07d534bdfc6aed89e45`
復元: `git checkout <commit> -- docs/Artifacts/<filename>` または sources 配下のコピーを戻す。

| 元ファイル名 | 退避先相対パス |
| :--- | :--- |
| `implementation_plan_013_0924.md` | [sources/...](20260925_185527_014/sources/implementation_plan_013_0924.md) |
| `implementation_plan_014_0924.md` | [sources/...](20260925_185527_014/sources/implementation_plan_014_0924.md) |
| `implementation_plan_015_0924.md` | [sources/...](20260925_185527_014/sources/implementation_plan_015_0924.md) |
| `s11_person_time_qa_review1_001_0924.md` | [sources/...](20260925_185527_014/sources/s11_person_time_qa_review1_001_0924.md) |
| `s11_s12_boundary_exec_001_0924.md` | [sources/...](20260925_185527_014/sources/s11_s12_boundary_exec_001_0924.md) |
| `s11_s12_qa0001_r6r7_qa_001_0925.md` | [sources/...](20260925_185527_014/sources/s11_s12_qa0001_r6r7_qa_001_0925.md) |
| `s12_qa0001_cycle01_qa_001_0924.md` | [sources/...](20260925_185527_014/sources/s12_qa0001_cycle01_qa_001_0924.md) |
| `s12_qa0001_cycle01_repair_exec_001_0924.md` | [sources/...](20260925_185527_014/sources/s12_qa0001_cycle01_repair_exec_001_0924.md) |
| `s12_qa0001_cycle02_qa_001_0924.md` | [sources/...](20260925_185527_014/sources/s12_qa0001_cycle02_qa_001_0924.md) |
| `s12_qa0001_r6r7_exec_001_0924.md` | [sources/...](20260925_185527_014/sources/s12_qa0001_r6r7_exec_001_0924.md) |

### 残置したアクティブ文書

- `docs/Artifacts/.gitkeep` のみ（新規計画は次番号から作成）
- `docs/ADR/QA/QA-0001-comparative-section11-section12/`（案件メタデータ、未更新）
