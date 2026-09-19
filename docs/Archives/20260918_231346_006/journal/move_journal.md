# アーカイブ移動記録

created: 2026-09-18 23:15 (JST)
update: 2026-09-20 15:52 (JST)
author: Codex (GPT-5) / Antigravity

archive_batch_id: 20260918_231346_006

## 承認済み範囲

利用者の「`implementation_plan_007_0918.md` 以外を対象にアーカイブしたい」との指定に対して、現行計画と恒久手引きを除外する対象一覧を確認し、「実行して」との明示承認を受けて実施した。対象は5件であり、削除ではなく `docs/Archives/20260918_231346_006/sources/` への移動である。

## 移動前のハッシュ

| 移動元 | 保存先 | 移動前SHA-256 |
| --- | --- | --- |
| `docs/Artifacts/Implementation-plan-vcd-categorical-analysis-v4.2.md` | `sources/Implementation-plan-vcd-categorical-analysis-v4.2.md` | `bd28aa26f8845c33215ae682c11a5524318bfef07ed352a43533055eb20f6b18` |
| `docs/Artifacts/implementation_plan_003_0918.md` | `sources/implementation_plan_003_0918.md` | `d7dda4d9c432184a9b7357cbffa2e897c21a0f45aa804390321350332d651e25` |
| `docs/Artifacts/implementation_plan_004_0918.md` | `sources/implementation_plan_004_0918.md` | `da9ab5d6bf30f57fd97df045f9110b21a6fab8dfc8fe94d24eba8d4478d269a4` |
| `docs/Artifacts/implementation_plan_005_0918.md` | `sources/implementation_plan_005_0918.md` | `8fc89d187b6cceacad739d0018cfa3e87658e12b3f0920ee62cb7a69ceefcb87` |
| `docs/Artifacts/implementation_plan_006_0918.md` | `sources/implementation_plan_006_0918.md`（削除済み） | `5c7d6d2ae4564ae60717bf6ae8006791950b7ca6c47b2337cb6892dfd6c78d88` |

## 最小リンク修復

アーカイブ後に有効でなくなる `implementation_plan_005_0918.md` 内の相対リンク3件だけを修復した。本文の計画内容・検証結論・未完了事項は変更していない。

| 修復対象 | 修復後の相対リンク |
| --- | --- |
| ダッシュボードテンプレート | `../../../../.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd` |
| ダッシュボードテスト | `../../../../tests/test_vcd_categorical_dashboard_v4.R` |
| OpenSpecアーカイブのタスク | `../../../../openspec/changes/archive/2026-09-18-vcd-categorical-scientific-dashboard/tasks.md` |

修復後の `sources/implementation_plan_005_0918.md` のSHA-256は `303864d30e335d28b873b5366bec86a281347cb7bf30ca0fa1814bb0e47438a0` である。

## 移動後の検証

- `sources/` に対象4件が存在することを確認した（初期5件、後述の通り1件削除）。
- `implementation_plan_004_0918.md` から初期計画への同階層リンクが解決することを確認した。
- 上表の3つの修復先がすべて存在することを確認した。
- アーカイブ文書の末尾空白を検査し、問題がないことを確認した。

## 事後更新（2026-09-20）

- `implementation_plan_006_0918.md` は Playwright ドライバ取得失敗による未完了チェックリストであったが、後続の `shared-dashboard-theme-assets`（Batch 007）において自動回帰テストおよびプレビュー検証によって完全代替・解決されたため、ユーザー承認に基づき物理削除した。
- 台帳（`archive_manifest.json`）および要約（`archived_summary_006_0918.md`）を現存 4 件に整合させた。
