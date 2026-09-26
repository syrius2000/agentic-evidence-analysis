# アーカイブ移動記録

archive_batch_id: 20260913_195758_003
created: 2026-09-13 19:57 (JST)
author: Codex (GPT-5)

## 移動前スナップショット

移動前に対象ファイルの存在、通常ファイルであること、保存先の不存在、Git作業ツリーの状態を確認した。対象ファイルは次の3件であり、移動前のSHA-256を記録した。移動後、アーカイブ位置で解決しないリポジトリ内リンク1件を相対パスへ修正し、manifestには修正後のSHA-256を記録する。

| 元ファイル | 保存先 | SHA-256 |
|---|---|---|
| `docs/Artifacts/implementation_plan_014_0912.md` | `sources/implementation_plan_014_0912.md` | 移動前: `d6b35f2290918f1ec1c8e2dbd83fb4f9fbd591bc3b9d0d6ed4d5fb19e56ff51c` |
| `docs/Artifacts/implementation_plan_015_0912.md` | `sources/implementation_plan_015_0912.md` | `41d631d6ef23e8a23b1b68f74904026fe8c5afca3b39986bb08a8a56fae60bb5` |
| `docs/Artifacts/implementation_plan_016_0912.md` | `sources/implementation_plan_016_0912.md` | `4676f777d79b1c45f33e99b2e854ea019225386b15e1e42b733881cd8dcb808e` |

原本の廃棄、計画本文の内容編集、リンクの一括変更は行わない。移動後に解決不能だったリポジトリ内リンク2件だけをアーカイブ位置から解決できる相対パスへ修正した。復元時は保存先を元パスへ戻し、移動前またはmanifest記録のSHA-256を照合する。

移動後のリンク修正後SHA-256（manifest記録値）:

- `sources/implementation_plan_014_0912.md`: `120ca182f9d8dbdb8e6521de9181ab032f5be7ee6c46175753a9f31f5e70b71f`
- `sources/implementation_plan_015_0912.md`: `41d631d6ef23e8a23b1b68f74904026fe8c5afca3b39986bb08a8a56fae60bb5`
- `sources/implementation_plan_016_0912.md`: `4676f777d79b1c45f33e99b2e854ea019225386b15e1e42b733881cd8dcb808e`
