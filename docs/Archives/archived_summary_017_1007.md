# アーカイブサマリー 017：standardize-evidence-run-output-contract 計画・QA成果物の完了整理

created: 2026-10-07 10:35 (JST)  
author: GPT-5.4  
対象期間: 2026-10-06 〜 2026-10-07  
対象ブランチ / コミット: `main` @ `73ad8fc`

---

## 1. 対象と結論

本アーカイブは、`standardize-evidence-run-output-contract` に関する実装計画書群（`implementation_plan_003_1006.md`〜`implementation_plan_006_1006.md`）および独立QAサイクル `c1`〜`c4` を、完了済み案件の証跡として `docs/Archives/` へ退避した記録である。

対象変更は現在 `main` に `feat: standardize evidence run output contract`（`73ad8fc`）として集約済みであり、OpenSpec Change も archive 済み、最新QAサイクル `c4` は `PASS` である。計画書 `004`〜`006` のヘッダ状態表示には stale な記述が残るが、Repo 現況・実装反映・QA結果・回帰確認に基づき、実質的には完了済みの履歴資料と判断した。

---

## 2. 確定した決定と理由

| 計画ID / 資料 | 決定事項 | 決定の理由・背景 |
|---|---|---|
| `implementation_plan_003_1006.md` | `README.md` と `AGENTS.md` の責務分離を完了済み計画として退避 | 対象文書の整理結果が `main` に反映され、追加の実装タスクが残っていないため |
| `implementation_plan_004_1006.md` | ヘッダは `レビュー待ち` だが、実質完了済みとして退避 | 対象の `AGENTS.md` と `vcd-categorical-reporting/references/interface.md` が `main` に反映済みで、後続の統合Change・QAで閉じているため |
| `implementation_plan_005_1006.md` | 実装本体の統合計画として退避 | 変更対象全体の inventory・spec・tests・検証計画が後続実装とQAの土台になっており、案件履歴として保存価値が高いため |
| `implementation_plan_006_1006.md` | main集約・cleanup計画も実質完了済みとして退避 | 現在のRepoが計画の完了条件（main集約、topic保持、QA証跡保持、`evidence_runs/` 整理）を満たしているため |
| `qa_cycles/standardize-evidence-run-output-contract/` | `c1`〜`c4` を一括退避 | QA履歴は案件単位でまとまって初めて意味を持ち、最終 `c4=PASS` まで追跡可能性を保持できるため |

---

## 3. 主要成果と検証の限界

### 主要成果
1. **Skill出力契約の標準化完了**:
   - `evidence_runs/<skill_slug>/run_<canonical_id>[_N]/` を正規契約として統一。
   - namespace外・`..`・symlink逸脱拒否、questionnaire legacy読取互換、Pass 0 inspection例外を整備。
2. **文書・仕様・実装・検証の整合**:
   - `README.md`、`AGENTS.md`、OpenSpec specs、各Skill資料、shared runtime、tests が最終的に整合。
3. **独立QAの完結**:
   - `c1=HOLD`、`c2=PASS`、`c3=HOLD`、`c4=PASS`。
   - 最終サイクルで `QA-TEST-H01` が CLOSED となり、Blocking項目は解消済み。
4. **現行 `main` の確認**:
   - `main` は `origin/main` と一致し、`evidence_runs/` は空、topic branch は保持されている。

### 検証の限界
- 一部計画書ヘッダの状態表示（特に `004`, `005`, `006`）は、実態より古いままである。
- QA文書では一部「独立実行未実施」と明記された検証（例: OpenSpec validate）があるため、全検証を各QAサイクルが完全再現したわけではない。
- 本アーカイブ作業では、履歴退避の正当性確認を主目的とし、統計ロジックや全テストスイートの再実行は行っていない。

---

## 4. 未解決事項と引継ぎ

- **未解決事項**: なし（本案件の実装・QA・main集約は完了済みと判断）。
- **引継ぎ**:
  - 計画書ヘッダの stale 状態表示は、今後の履歴閲覧時に混乱の余地があるため、本サマリーを正本の補助説明として参照する。
  - 今後同案件を再度参照する場合は、まず `main` の実装状態と `docs/Artifacts/qa_cycles/.../c4` 相当の最終判断を確認する。

---

## 5. 元文書と復元情報

| 元文書パス（退避前） | 退避先パス（アーカイブ内） | 作成日 | 復元用コミット |
|---|---|---|---|
| `docs/Artifacts/plans/implementation_plan_003_1006.md` | [20261007_103530_017/plans/implementation_plan_003_1006.md](20261007_103530_017/plans/implementation_plan_003_1006.md) | 2026-10-06 | `73ad8fc` |
| `docs/Artifacts/plans/implementation_plan_004_1006.md` | [20261007_103530_017/plans/implementation_plan_004_1006.md](20261007_103530_017/plans/implementation_plan_004_1006.md) | 2026-10-06 | `73ad8fc` |
| `docs/Artifacts/plans/implementation_plan_005_1006.md` | [20261007_103530_017/plans/implementation_plan_005_1006.md](20261007_103530_017/plans/implementation_plan_005_1006.md) | 2026-10-06 | `73ad8fc` |
| `docs/Artifacts/plans/implementation_plan_006_1006.md` | [20261007_103530_017/plans/implementation_plan_006_1006.md](20261007_103530_017/plans/implementation_plan_006_1006.md) | 2026-10-06 | `73ad8fc` |
| `docs/Artifacts/qa_cycles/standardize-evidence-run-output-contract/` | [20261007_103530_017/qa_cycles/standardize-evidence-run-output-contract/](20261007_103530_017/qa_cycles/standardize-evidence-run-output-contract/) | 2026-10-06〜2026-10-07 | `73ad8fc` |
