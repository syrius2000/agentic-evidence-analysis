# docs/Artifacts — 置き場契約

created: 2026-09-27 10:29 (JST)
update: 2026-09-28 00:55 (JST)
author: Cursor (Composer)

作業中の計画書・独立 QA・メタ反省を置くディレクトリの**置き場正本**です。完了バッチの退避先は [`../Archives/`](../Archives/) です。

---

## 1. ディレクトリ構成（新規はここへ）

| パス | 置くもの | 置かないもの |
| :--- | :--- | :--- |
| [`plans/`](plans/) | `implementation_plan_NNN_MMDD.md` のみ | QA 本文、メタ反省 |
| [`qa_cycles/`](qa_cycles/) | 独立ブラインド QA（`blind-qa-cycle` 正本） | 実装計画、Owner 裁定の代用 |
| [`meta/`](meta/) | 反省・品質分析・エージェントフィードバック | 計画 ID を持つ実装計画 |
| [`planning_qa/`](planning_qa/)（任意・未必須） | OpenSpec 前段の計画レビュー | 独立 QA サイクル |

独立 QA のパス規約:

```text
docs/Artifacts/qa_cycles/<topic>/c<N>/
  00_invite.md
  01_review.md
  02_tasks.md
  03_machine.json
  STATUS.md
```

- `<topic>`: OpenSpec change 名（なければ短い kebab-case slug）
- `c<N>`: サイクル番号（`c1`, `c2`, …）。再 QA は必ず新フォルダ
- **Audience:** `local`（`/blind-qa-cycle local`、未 push 可・本文手渡し）／`cloud`（`/blind-qa-cycle cloud`。Reviewed → invite → topic push → パス手渡し。`review` は **QA 成果物4ファイルのみ** commit+topic push、不可時は `/blind-qa-cycle ingest`。Re-QA は `cloud re-qa`。main マージ・force-push はしない）。詳細はスキル参照。

スキル手順: [`.agents/skills/blind-qa-cycle/SKILL.md`](../../.agents/skills/blind-qa-cycle/SKILL.md)

---

## 2. 禁止事項

1. **`docs/Artifacts/` 直下への新規 Markdown 作成を禁止**（本 `README.md` と既存凍結ファイル以外）。
2. **`implementation_plan_NNN_*.md` の上書き禁止**。別案件は新しい NNN（`plans/` 内の最大番号 + 1）。
3. **flat 形式の新規独立 QA 禁止**（例: `independent_qa_*.md` を直下に新規作成しない）。新規は必ず `qa_cycles/`。
4. **flat 形式の新規 implementation / planning QA レビュー禁止**。独立 QA は `qa_cycles/`、計画レビューは `planning_qa/` またはサイクル運用に寄せる。
5. **`docs/ADR/QA/` への新規独立 QA 案件追加を禁止**（legacy。正本は `qa_cycles/`）。

---

## 3. 既存 flat ファイル（移行方針）

直下に残る既存 `.md` は**読取互換・パス維持**とする（一括移動は別明示コミット）。

- 新規作成は上記サブディレクトリへ
- 完了し参照頻度が低いバッチは `docs/Archives/` へ退避

---

## 4. 完了・アーカイブ

フェーズ完了後、関連 Artifacts を `docs/Archives/YYYYMMDD_HHMMSS_NNN/` へ移し、トレーサビリティ要約を残す（既存 Archives 運用に従う）。
