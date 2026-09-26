# アーカイブ済みArtifactの要約

created: 2026-09-13 19:57 (JST)
update: 2026-09-13 19:57 (JST)
author: Codex (GPT-5)
対象期間: 2026-09-12 18:58 (JST) 〜 2026-09-12 23:35 (JST)
archive_batch_id: 20260913_195758_003
source_count: 3

## 目的

`docs/Artifacts/` に残っていた完了済みの実装計画書を、監査可能な原本として `docs/Archives/` に集約し、現在進行中の文書と完了済みの履歴を分離した。

## アーカイブ対象一覧

| 元ファイル | 判定 | 作成・更新日時 | 要約 | 保存先または状態 |
|---|---|---|---|---|
| `docs/Artifacts/implementation_plan_014_0912.md` | 完了 | 2026-09-12 18:58 / 19:10 (JST) | 条件付きセル順位再現性評価（CRR）のPhase 1実装計画。M1/M5、`abs_log_oe`、集計度数の多項再標本化、適格セル条件、品質ゲート、受入テストを定義した。 | [`sources/implementation_plan_014_0912.md`](sources/implementation_plan_014_0912.md) |
| `docs/Artifacts/implementation_plan_015_0912.md` | 完了 | 2026-09-12 21:52 (JST) | `docs/reference` の統計的整合性とスキル責務境界を是正する文書計画。ARM Lift、時刻意味論、漸近近似、疎セル解釈を対象とした。 | [`sources/implementation_plan_015_0912.md`](sources/implementation_plan_015_0912.md) |
| `docs/Artifacts/implementation_plan_016_0912.md` | 完了 | 2026-09-12 23:35 (JST) | Quality Loop初回運用マニュアルの作成計画。status、Role、実装許可、独立verify、Owner裁定の境界を定義した。 | [`sources/implementation_plan_016_0912.md`](sources/implementation_plan_016_0912.md) |

## 成果

- CRRの実装計画と受入仕様を履歴として保存した。
- `docs/reference` の統計的意味論と責務境界の是正計画を保存した。
- Quality Loop運用マニュアル作成の根拠計画を保存した。
- 各原本のSHA-256と移動状態を [`archive_manifest.json`](archive_manifest.json) に記録した。

## 保留・除外

- `docs/Artifacts/quality_loop_manual_001_0912.md` は現行運用マニュアルであり、既定のアーカイブ候補外として移動しなかった。
- 未完了または判定不能の計画書は今回の対象に含めていない。
- 原本の廃棄、Gitのstage、commit、push、リンクの一括修正は行っていない。

## 次のアクション

アーカイブ後のGit差分を確認し、必要に応じてユーザーが別途stage・commitを行う。アーカイブ原本を復元する場合は、manifestの保存先を元パスへ戻し、SHA-256を照合する。
