# 移動ジャーナル (Batch 008)

- **作成日時**: 2026-09-20 18:48 (JST)
- **バッチID**: 20260920_173500_008
- **担当**: Antigravity

## 1. 移動概要

ユーザーからの明示指示（「実行して。それとともに、docs/Archivesのレン版が002からはじまるのがブサイクです。001より始める」）に基づき、OpenSpec change `shared-dashboard-theme-assets` の修復・最終QA検証に関する計画書および報告書計 6 件を、`docs/Archives/20260920_173500_008/sources/` へ安全に退避移動した。

## 2. 移動対象と整合性検証

| 元ファイル | 退避先 | 元 SHA-256 | 退避先 SHA-256 | リンク調整 |
|---|---|---|---|---|
| `docs/plans/implementation_plan_009_0920_shared_dashboard_repair.md` | `sources/implementation_plan_009_0920_shared_dashboard_repair.md` | `5ed54987736dc445cc2eeedbdb62941d66c6a2fc9afa11e87e3fa54761241659` | `5ed54987736dc445cc2eeedbdb62941d66c6a2fc9afa11e87e3fa54761241659` | 不変（外部参照なし） |
| `docs/plans/test_plan_005_0920_shared_dashboard_final_qa.md` | `sources/test_plan_005_0920_shared_dashboard_final_qa.md` | `8c81de30bf2b8a858aaa36f9e3435bfc8e9fbd4a1bfa08a109a107f7d72d1890` | `8c81de30bf2b8a858aaa36f9e3435bfc8e9fbd4a1bfa08a109a107f7d72d1890` | 不変（外部参照なし） |
| `docs/Artifacts/implementation_plan_020_0920.md` | `sources/implementation_plan_020_0920.md` | `bfb7a3259bf13412b1e8bb9713e165111bc3f30aad31d0d9ef8d31e2ead712df` | （リンク調整済み） | `../plans/` を `./`（同階層）へ更新 |
| `docs/Artifacts/verification_shared_dashboard_005_0920.md` | `sources/verification_shared_dashboard_005_0920.md` | `32be5bf455a77af7ba0537c4f83584252a5fb89db40ea637c8c00fe79d2e95a1` | `32be5bf455a77af7ba0537c4f83584252a5fb89db40ea637c8c00fe79d2e95a1` | 不変 |
| `docs/Artifacts/verification_shared_dashboard_006_0920.md` | `sources/verification_shared_dashboard_006_0920.md` | `e1cadc6cba40b13316682dc60a68b6766bd64cc3e97a05edbe2e0a097b76c167` | `e1cadc6cba40b13316682dc60a68b6766bd64cc3e97a05edbe2e0a097b76c167` | 不変 |
| `docs/Artifacts/verification_shared_dashboard_007_0920.md` | `sources/verification_shared_dashboard_007_0920.md` | `602d183bd01ad7a236a4c5179cc4b894563faf380d5bc4a32a4d97da718700bd` | `602d183bd01ad7a236a4c5179cc4b894563faf380d5bc4a32a4d97da718700bd` | 不変 |

## 3. 保留・維持文書

- `docs/plans/sha256-inspection-contract-improvement-plan.md`: Pass 0 / Pass 1 SHA-256 改善計画（別件・未着手のため現行保持）
- `docs/Artifacts/quality_loop_manual_001_0912.md`: Quality Loop 恒久運用マニュアルのため現行保持
