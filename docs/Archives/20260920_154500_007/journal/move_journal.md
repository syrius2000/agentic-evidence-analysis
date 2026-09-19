# アーカイブ移動記録 (Move Journal - Batch 007)

- **作成日時**: 2026-09-20 15:45 (JST)
- **バッチID**: 20260920_154500_007
- **担当エージェント**: Antigravity

---

## 1. 承認経緯

- ユーザーの `/artifacts-archiver` 指示に基づき、読み取り専用で `docs/Artifacts/` のインベントリ調査を実施。
- 恒久手引き `quality_loop_manual_001_0912.md` および `.gitkeep` を除外し、完了済みの 8 文書をアーカイブ候補として提示。
- ユーザーより「実行」の明示承認を受領後、ファイル移動・リンク修復・サマリー作成を実施。

---

## 2. 移動ファイル一覧とSHA-256ハッシュ

| 元パス | 移動先（退避先） | 移動前SHA-256 | リンク修復後SHA-256 |
| :--- | :--- | :--- | :--- |
| `docs/Artifacts/implementation_plan_007_0918.md` | `sources/implementation_plan_007_0918.md` | `54b453d91fc00bf4a1e11bdd73515b7506e15561fd0cccc29d30cbb2a2d2d8f7` | 不変（未変更） |
| `docs/Artifacts/section12_refresh_proposal_001_0918.md` | `sources/section12_refresh_proposal_001_0918.md` | `b115029882fcf2c52a2ea64806e38f12cd1cb24d1570550c36a530250a852241` | 不変（未変更） |
| `docs/Artifacts/implementation_plan_008_0919.md` | `sources/implementation_plan_008_0919.md` | `e2b24dc73b98e7955f8221234356abd3291265baea4d83ef75f07dd6da0f8b38` | `41f4f469ef7e224e77da4be3da6fa134d19313dbfe08282362c3325e6931752b` |
| `docs/Artifacts/change_record_shared_dashboard_001_0919.md` | `sources/change_record_shared_dashboard_001_0919.md` | `51015922743832b2d1fc409ea15556563e157b071e171ed1b5647a43262912e8` | `416d89df8c8038746df2fc9bc221f1e948c26bb94c1a5b820a40fa6b461aa795` |
| `docs/Artifacts/verification_shared_dashboard_001_0919.md` | `sources/verification_shared_dashboard_001_0919.md` | `eca5827496feac4caa5e973a3fabe260e7ae982d7b953a2b22b741010dd284da` | `9b5d259c775084931a0a544bbfb93fc72ea5a1e2fec4b44917f917511c1d0441` |
| `docs/Artifacts/verification_shared_dashboard_002_0919.md` | `sources/verification_shared_dashboard_002_0919.md` | `e10e34de215a7868c7b091815c979254d17c8733772e2f630de9fe27587da014` | 不変（未変更） |
| `docs/Artifacts/verification_shared_dashboard_003_0919.md` | `sources/verification_shared_dashboard_003_0919.md` | `19aa3d745a97a06689760c1141009721114ad780bb67aeca770e45f807250946` | `3781ec4561081b95ff813478d59dc81045da02c77d0f91c9535eb05cc030b776` |
| `docs/Artifacts/verification_shared_dashboard_004_0919.md` | `sources/verification_shared_dashboard_004_0919.md` | `570d83ba0ab6069b9ecac6cf9c28205eef9acd386414687afe0d7180430439c1` | 不変（未変更） |

---

## 3. 相対リンク修復

1. **移動元ファイル内部のリンク階層補正**:
   - ディレクトリの深さが 2 階層（`docs/Artifacts/`）から 4 階層（`docs/Archives/20260920_154500_007/sources/`）に深くなったため、ルート参照等の `../../` を `../../../../` に更新。
   - 同一ディレクトリ内参照（例: `implementation_plan_008_0919.md` など）は同ディレクトリ内に揃って移動したためパスを維持。
2. **外部（OpenSpec change）からの参照更新**:
   - `openspec/changes/shared-dashboard-theme-assets/proposal.md`
   - `openspec/changes/shared-dashboard-theme-assets/design.md`
   上記の `docs/Artifacts/implementation_plan_008_0919.md` への参照を `docs/Archives/20260920_154500_007/sources/implementation_plan_008_0919.md` に更新。

---

## 4. 除外・維持ファイル

- `docs/Artifacts/quality_loop_manual_001_0912.md`: 恒久手引きとして保持。
- `docs/Artifacts/.gitkeep`: ディレクトリ構造保持用として保持。
