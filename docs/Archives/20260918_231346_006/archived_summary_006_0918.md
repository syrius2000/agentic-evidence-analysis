# アーカイブ済みArtifactの要約

created: 2026-09-18 23:15 (JST)
update: 2026-09-18 23:15 (JST)
author: Codex (GPT-5)

対象期間: 2026-09-18 06:45 (JST) 〜 2026-09-18 22:54 (JST)
archive_batch_id: 20260918_231346_006
source_count: 5

## 対象と結論

`docs/Artifacts` にあった完了済みまたは参照記録として保持すべき計画書5件を、このバッチの `sources/` へ移動した。削除ではなく、内容・追跡可能性・復元可能性を保持する通常アーカイブである。

| 移動元 | 保存先 | 状態 | 内容の位置付け |
| --- | --- | --- | --- |
| `Implementation-plan-vcd-categorical-analysis-v4.2.md` | `sources/Implementation-plan-vcd-categorical-analysis-v4.2.md` | アーカイブ済み | 後続計画で置換された初期計画 |
| `implementation_plan_003_0918.md` | `sources/implementation_plan_003_0918.md` | アーカイブ済み | バックアップ復旧検証の完了記録 |
| `implementation_plan_004_0918.md` | `sources/implementation_plan_004_0918.md` | アーカイブ済み | 条件付き事後推論契約の完了計画 |
| `implementation_plan_005_0918.md` | `sources/implementation_plan_005_0918.md` | アーカイブ済み | 11セクション科学ダッシュボードの完了計画 |
| `implementation_plan_006_0918.md` | `sources/implementation_plan_006_0918.md` | アーカイブ済み | ブラウザ受入検証の未完了記録 |

## 確定した決定と理由

- `implementation_plan_007_0918.md` は、選択済みの臨床・学術標準テーマを実装するための現行計画であり、`docs/Artifacts` に残した。
- `quality_loop_manual_001_0912.md` は、現在も参照される恒久的な運用手引きであるため、アーカイブ対象から除外した。
- `implementation_plan_006_0918.md` は未完了の検証を含むが、将来のブラウザ検証時に失敗条件と未実施項目を追跡できるよう、廃棄せずアーカイブとして保存した。

## 主要成果と検証の限界

- `implementation_plan_003_0918.md` は、欠落していた補助テスト対象の発見と既存復旧検証の記録を残す。
- `implementation_plan_004_0918.md` と `implementation_plan_005_0918.md` は、条件付き事後推論契約および自己完結型科学ダッシュボードの完了経緯を残す。
- `implementation_plan_006_0918.md` では、Playwright のブラウザドライバ取得が失敗し、コンソール・ネットワーク・視覚構造・DataTables に関する受入確認が未完了のままである。この限界は解消済みとは扱わない。
- 移動に伴い `implementation_plan_005_0918.md` の内部相対リンク3件だけを最小修復した。数理・実装・検証方針の本文は変更していない。

## 未解決事項と引継ぎ

- ダッシュボードの臨床・学術標準テーマの実装は、現行の [`implementation_plan_007_0918.md`](../../Artifacts/implementation_plan_007_0918.md) を対象に、別途承認された実装範囲で進める。
- `implementation_plan_006_0918.md` に記録されたブラウザ受入検証は、実行可能なブラウザ環境を確保した後に改めて実施する必要がある。
- 今回はアーカイブ操作のみであり、コミットおよびリモートへの push は行っていない。

## 元文書と復元情報

移動前後のSHA-256、相対リンク修復、検証結果は [`journal/move_journal.md`](journal/move_journal.md) に記録した。機械可読な一覧は [`archive_manifest.json`](archive_manifest.json) を参照する。

## 保留・除外

- `docs/Artifacts/implementation_plan_007_0918.md`: 現行計画として保持。
- `docs/Artifacts/quality_loop_manual_001_0912.md`: 継続利用する手引きとして保持。
- `docs/Artifacts/.gitkeep`: ディレクトリ保持用として保持。
- `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd` および `tests/test_vcd_categorical_dashboard_v4.R` の既存変更: 今回のアーカイブ対象外として一切変更していない。
