# 既存ブランチのWIPコミット連携

この手順は、すでに存在するトピックブランチで開発を続けながら、今回分の差分だけを独立QAへ渡すためのものです。作業開始時点のコミットをチェックポイントとして記録し、その後の変更コミットをレビュー対象にします。モード名は **`checkpoint` のまま**です（`setup` へリネームしない）。

```text
既存topic branch
  ├─ stagedな作業前WIP → Yip checkpoint commit     (/blind-qa-cycle checkpoint)
  ├─ 実装・文書変更（スキル外）
  └─ stagedな今回分
        → Yip reviewed commit
        → cN/00_invite.md
        → Yip invite commit（Reviewed に混ぜない）
        → topic-only push
        → Cloud へ相対パス1行
                         baseline..reviewed の差分が審査範囲
```

## `/blind-qa-cycle checkpoint`

1. 現在のブランチが `main` / `master` ではないことを確認します。
2. 利用者が選んでステージしたファイルだけを対象にします。indexが空、未ステージ差分あり、未追跡ファイルありの場合は、コミットせず停止します。
3. 対象パスと差分概要を示し、明示的な `checkpoint` 起動に基づいてindexだけをコミットします。
4. commit subjectは `Yip: WIP QA checkpoint <topic>`、本文末尾の識別トレーラーは `Blind-QA-Checkpoint: <topic>` とします。
5. コミット後の完全SHAを表示します。これが同じtopicの通常 `cloud` QAでBaselineになります。
6. push・invite作成はしません。

## `/blind-qa-cycle cloud`

明示起動 `/blind-qa-cycle cloud` は、次を**一通貫**で許可します（main マージはしない）。

1. 現ブランチが `main` / `master` なら **fail-fast で停止**（確認による続行は不可。Reviewed/invite commit・push へ進まない）。
2. 現ブランチのfirst-parent履歴から、同じtopicの最新 `Blind-QA-Checkpoint` トレーラーを持つコミットをBaselineとして特定します。該当しない場合は停止します（`cloud re-qa` を除く）。
3. 今回の変更を利用者がステージし、未ステージ差分・未追跡ファイルがないことを確認します。ステージ済みならパス一覧と概要を示し、indexだけを `Yip: WIP QA review <topic>` でコミットし、`Blind-QA-Reviewed: <topic>` トレーラーを付けます。
4. 同topicのReviewedトレーラーを持つコミットが既にHEADなら再利用します。空コミットや重複コミットは作りません。
5. Reviewed SHAを固定した**あと**で `docs/Artifacts/qa_cycles/<topic>/c<N>/00_invite.md` を作成します（Reviewed 差分へ混入させない）。
6. invite ファイルだけをステージし、`Yip: QA invite <topic> c<N>`（trailer **必須** `Blind-QA-Invite: <topic>`）で追従コミットします。
7. **topic のみ** `git push -u origin HEAD` を実行します（この明示モードが認可）。force-push や main マージはしません。
8. preflight（Baseline / Reviewed が `origin/<branch>` の祖先）成功後、Cloud 手渡しは次の**相対パス1行**を既定とします。

   ```text
   docs/Artifacts/qa_cycles/<topic>/c<N>/00_invite.md
   ```

9. push または preflight に失敗した場合はローカルコミットを保持し、パス手渡しを主張せず、手動 push 手順と**本文フォールバック**を出して停止します。

## `/blind-qa-cycle cloud re-qa`

1. 現ブランチが `main` / `master` なら **fail-fast で停止**（`cloud` と同じ。確認による続行は不可）。
2. 凍結済み cycle（通常 HOLD/FAIL）の **Reviewed SHA** を Baseline 既定とします。新規 checkpoint は必須ではありません。
3. 修復後 tip を Reviewed とし、`c{N+1}` に invite を作り、通常 cloud と同じく invite コミット → topic push → パス手渡しへ進みます。
4. 前 cycle のファイルは変更しません。

## Review / ingest の成果物コミット

```text
cloud review（または ingest）
  → 現ブランチが main/master なら fail-fast STOP
  → Output dir に 01/02/03/STATUS のみ
  → Yip: QA review <topic> c<N>  + Blind-QA-Review-Artifacts
  → topic-only push
```

- `00_invite.md` と製品ツリーは変更しません。
- `main` / `master` では artifact commit も push もしません（確認による続行不可）。
- push できない Cloud は4ファイルを返し、依頼側が `/blind-qa-cycle ingest` します（ingest も非-main topic 限定）。

## 保護条件

- 明示的な `checkpoint` / `cloud` 起動で許可される製品WIPコミットは、既存indexの内容だけです。
- `git add -A`、暗黙のstage、unstaged/untrackedを含む製品コミット、変更の破棄は行いません。
- `cloud` の invite 追従コミットに限り、作成した `00_invite.md` だけをステージしてよいです。
- `review` / `ingest` の成果物コミットに限り、Output dir の4ファイルだけをステージしてよいです。
- index以外に変更がある場合は、対象ファイルを利用者が整理・stageした後に再実行します。
- ブランチ作成、commit修正、reset、rebase、main マージ、force-pushはこのフローに含めません。
- QA成果物（invite / review artifacts）はReviewedコミット確定後に作成するため、レビュー対象差分へ混入しません。
- topicを変えて同じブランチでQAする場合は、新しいtopicのチェックポイントを作ります。
- 通常の新規実装差分では修復前に checkpoint を推奨します。Re-QA（`cloud re-qa`）では前回 Reviewed を Baseline にできるため checkpoint 再取得は必須ではありません。

## Git上の確認

```bash
git show -s --format='%H%n%s%n%b' <commit>
git diff --name-status <baseline> <reviewed>
git diff --stat <baseline> <reviewed>
```

トレーラーはコミット履歴に残り、別cloneでもSHAとともに追跡できます。invite と review 成果物はトピックブランチ上の別コミットとして保存します。
