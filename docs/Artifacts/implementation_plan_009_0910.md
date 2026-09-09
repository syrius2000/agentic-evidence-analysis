# AntigravityブランチへのGit除外設定同期計画

created: 2026-09-10 02:51 (JST)
update: 2026-09-10 02:51 (JST)
author: Codex (GPT-5)

## 目的

`agy-branch`へ追加済みの`/.playwright-mcp/`除外規則を、別worktreeの`Angigravity`にも同期し、両ブランチで自動生成ブラウザログを誤ってGit管理しない状態にする。

## 対象

- `Angigravity`の`.gitignore`へ`/.playwright-mcp/`を1行追加する。
- 本計画Artifactを`Angigravity`側へ保存する。
- 上記2ファイルだけをcommitする。
- `origin/Angigravity`へpushする。

## 対象外

- `.playwright-mcp/`のrawログの追加・削除
- `agy-branch`、`main`とのmerge・rebase
- 既存統計スキル、分析結果、設定、テストの変更
- branch削除、force push、履歴改変

## 検証

- stage対象が`.gitignore`と本Artifactだけであることを確認する。
- commit後、Angigravityの作業ツリーがcleanであることを確認する。
- `/.playwright-mcp/`がignore対象として解決されることを確認する。
- `HEAD`と`origin/Angigravity`が同じcommitを指すことを確認する。
