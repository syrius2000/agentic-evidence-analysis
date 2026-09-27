# Cloud QA成果物契約

## 依頼の手渡し（handoff）

| 状況 | Cloud への渡し方 |
| :--- | :--- |
| `/blind-qa-cycle cloud` 成功（invite が origin 上） | **相対パス1行** `docs/Artifacts/qa_cycles/<topic>/c<N>/00_invite.md`（既定） |
| push / preflight 失敗、または invite 未 push | `00_invite.md` と同等の**本文**を fenced で貼付（フォールバック） |
| Audience=`local` | 本文のみ。GitHub Cloud へ貼らない |

cloudレビュアーは、パス手渡しの場合は git 上の `00_invite.md` を読み、本文手渡しの場合は貼付ブロックを単独で読める前提とします。指定された `docs/Artifacts/qa_cycles/<topic>/c<N>/` に次の4ファイルを作成します。既存の `00_invite.md` は変更しません。

1. `01_review.md` — 日本語の結論と根拠付きFindings。
2. `02_tasks.md` — 修復担当者が着手・完了確認できるタスク。
3. `03_machine.json` — [`machine_schema.md`](machine_schema.md) の `blind-qa-cycle-v1`。
4. `STATUS.md` — Gateを示す単一語。

## `01_review.md`

```markdown
# 独立QAレビュー

- Repository: `<repo>`
- Branch: `<branch>`
- Baseline: `<full-sha>`
- Reviewed: `<full-sha>`
- Cycle: `<N>`
- Audience: `cloud`
- Remote visibility: `pushed`
- Focus packs: `<ids>`
- Gate: `PASS | HOLD | FAIL | INCONCLUSIVE`

## 結論
<!-- Blocking項目だけを簡潔に記載 -->

## Findings
<!-- 各指摘: ID、Severity、Status、Evidence (path:line)、Expected、repair_surface -->

## Re-QA
- 推奨Baseline: `<reviewed SHA>`
- 再確認対象: `<finding IDs>`
```

Findingは差分または必要な一次情報で確認した不一致に限ります。Aligned項目の羅列、実装者説明を根拠にしたPASS、OwnerのACCEPT/ARCHIVE判断は含めません。

## `02_tasks.md`

```markdown
# 修復タスク

- [ ] T-01 (closes: QA-AREA-H01) severity=High; path=`path/to/file`; action=<具体的な修正内容>; done_when=<観察可能な完了条件>; verify=<確認手順と期待結果>
```

- 対応が必要な各Findingをタスクに結び付けます。Severityの語彙は [`machine_schema.md`](machine_schema.md) に合わせ、Highは必須です。
- Finding ID、対象パス、実施内容、完了条件、検証方法と期待結果を記載します。
- 複数の独立修復を1タスクにまとめず、推測が残る修復案は条件付きであることを明示します。
- PASSメモだけならタスクは作りません。

## `03_machine.json` と `STATUS.md`

- JSONの必須キー、enum、ID対応は [`machine_schema.md`](machine_schema.md) を正本とします。
- `findings[]` と `tasks[]` のID・severity・closesを相互照合します。High findingに未対応taskがあれば成果物完成として扱いません。
- `STATUS.md` の内容は `PASS`、`HOLD`、`FAIL`、`INCONCLUSIVE` のいずれか1語だけです。JSONの `gate` と一致させます。

## 提出前の完了確認

- 4ファイルがすべて指定ディレクトリに存在する。
- SHA、topic、cycle、Audience、visibilityが依頼と一致する。
- Findingの証拠が `path:line` で特定でき、taskの `closes` が実在Finding IDと一致する。
- JSONを構文確認し、必須キーとGate語彙を満たす。
- Reviewerの最終返信は5項目以内で、Gate、出力先、Blocking数、Task数、次の行動、および **Artifacts git SHA** または **`ingest-needed`** を伝える。

## Review 成果物の git 帰着

| 状況 | 手順 |
| :--- | :--- |
| Audience=`cloud` かつ topic clone で push 可能 | 4ファイルのみ stage → `Yip: QA review <topic> c<N>` + trailer `Blind-QA-Review-Artifacts: <topic>` → topic-only `git push -u origin HEAD`。`00_invite.md` と製品コードは触らない。 |
| Cloud が push / clone 書き込み不可 | repo 永続化を主張しない。4ファイル本文を依頼者へ返す → 依頼者が `/blind-qa-cycle ingest`。 |
| Audience=`local` | 同一 clone の Output dir へ書けばよい。artifact push は既定しない。 |

製品コード変更・Reviewed SHA の付け替え・main マージ・force-push は禁止のままです。「push 禁止」は **製品変更の push 禁止**であり、上記の **QA 成果物のみの topic push** は `review`（cloud）/ `ingest` の明示契約で許可します。
