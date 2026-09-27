# 独立QAスキル簡便マニュアル

created: 2026-09-27 17:40 (JST)
update: 2026-09-28 01:45 (JST)
author: Codex (GPT-6); Cursor (Composer)

この文書は、既存トピックブランチでWIPコミットを作り、変更差分を独立QAへ渡す手順の早見表です。詳しい安全条件は[スキル正本](../../.agents/skills/blind-qa-cycle/SKILL.md)と[Git WIPフロー](../../.agents/skills/blind-qa-cycle/references/git_wip_flow.md)、cloud成果物の形式は[cloud QA成果物契約](../../.agents/skills/blind-qa-cycle/references/cloud_output_contract.md)を参照してください。

## 基本の流れ

```text
既存topic branchで対象変更をstage
  → /blind-qa-cycle checkpoint          # きれいな Baseline（名称は checkpoint のまま）
  → 実装・修正（スキル外）
  → 今回レビューする変更だけをstage
  → /blind-qa-cycle cloud               # Reviewed → invite → invite commit → topic push → パス
  → Cloud には相対パス1行を渡す
  → cloud QA が4成果物を書き、**artifact commit + topic push**（不可なら本文返却 → ingest）
```

### 1. 作業前チェックポイント

対象変更を明示的にstageして、次を起動します。

```text
/blind-qa-cycle checkpoint
```

スキルはindexのパスと概要を示し、`Yip: WIP QA checkpoint <topic>` のコミットを作ります。コミットには `Blind-QA-Checkpoint: <topic>` トレーラーが付き、同topicでの通常 cloud QAのBaselineになります。pushやinvite作成はしません。

### 2. 変更後のcloud QA依頼（一通貫）

今回の変更ファイルだけをstageし、未stage変更や未追跡ファイルがない状態で起動します。

```text
/blind-qa-cycle cloud
```

スキルは順に次を行います。

1. 現ブランチが `main` / `master` なら **即停止**（確認でも続行しない）
2. stage済み変更を `Yip: WIP QA review <topic>`（`Blind-QA-Reviewed`）としてコミットし Reviewed SHA を固定
3. `docs/Artifacts/qa_cycles/<topic>/c<N>/00_invite.md` を作成（Reviewed 差分には混ぜない）
4. invite だけを `Yip: QA invite <topic> c<N>`（trailer **必須** `Blind-QA-Invite: <topic>`）で追従コミット
5. **topic のみ** `git push -u origin HEAD`（この明示起動が認可。main マージではない）
6. 成功時の Cloud 手渡しは次の**相対パス1行**（既定）

```text
docs/Artifacts/qa_cycles/<topic>/c<N>/00_invite.md
```

push や preflight に失敗した場合はローカルコミットを保持し、パス手渡しを主張せず、手動 push 手順と本文フォールバックを出します。

### 3. Re-QA

```text
/blind-qa-cycle cloud re-qa
```

前回 cycle の Reviewed を Baseline 既定とします。新規 checkpoint は必須ではありません。成果物は必ず `c{N+1}` に作り、凍結済み cycle は変更しません。

### 4. cloud QAの成果物と git 帰着

レビュアーは指定された `docs/Artifacts/qa_cycles/<topic>/c<N>/` に、次を作成します。

| ファイル | 内容 |
|---|---|
| `01_review.md` | 日本語の結論と根拠付きFinding |
| `02_tasks.md` | Finding ID、対象パス、作業内容、完了条件、検証方法を持つ修復タスク |
| `03_machine.json` | `blind-qa-cycle-v1` の機械可読結果 |
| `STATUS.md` | Gateを示す単一語 (`PASS` / `HOLD` / `FAIL` / `INCONCLUSIVE`) |

**git 帰着（必須）:**

1. **Cloud が push 可能:** 現ブランチが `main`/`master` なら停止。非-main topic でのみ、上記4ファイルだけを `Yip: QA review <topic> c<N>`（`Blind-QA-Review-Artifacts`）で commit し、topic-only push。製品コードと `00_invite.md` は触らない。
2. **Cloud が push 不可:** 4ファイル本文を返す（repo 保存済みと偽らない）。依頼側で:

```text
/blind-qa-cycle ingest
```

が同 Output dir へ書いて artifact commit + topic push する（ingest も `main`/`master` では fail-fast）。

### 5. 安全条件と停止時の対応

- 製品WIPのコミット対象は利用者がstageしたindexだけです。`git add -A`や暗黙のstageはしません。
- invite 追従コミットに限り、作成した `00_invite.md` だけをステージしてよいです。
- 未stage変更、未追跡ファイル、空のindexがある場合（Reviewed 作成時）、コミットせず状態を示します。
- `main` / `master` ではWIP checkpointを作りません。
- 通常 cloud で対応するcheckpointが見つからない場合、Baselineを推測せず停止します。
- topic-only push は `/blind-qa-cycle cloud` / `cloud re-qa` / cloud `review` の成果物コミット / `ingest` のみ。いずれも **非-main topic** 限定（`main`/`master` は fail-fast）。force-push・main マージ・reset・rebase・変更破棄・製品修復実装は範囲外（または別明示指示）です。

## レビュー後

レビュー結果は独立検証の成果です。実装修復、Owner裁定は別工程です。修復後の再QAは `/blind-qa-cycle cloud re-qa` を推奨します。各QAサイクルは新しい `c<N+1>` に保存され、前サイクルは変更しません。
