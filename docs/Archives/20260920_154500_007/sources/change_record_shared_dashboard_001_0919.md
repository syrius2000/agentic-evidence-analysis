# 変更記録: shared-dashboard-theme-assets（共有資産・Jeffreys主事前・封印run）

created: 2026-09-19 16:50 (JST)
update: 2026-09-19 16:50 (JST)
author: Codex (Composer)

## 対象と位置付け

本記録は、OpenSpec change [`shared-dashboard-theme-assets`](../../../../openspec/changes/shared-dashboard-theme-assets/proposal.md) を中心に、本セッションで実施した実装・検証・Pass 2封印・git操作の変更履歴である。計画の正本は [implementation_plan_008_0919.md](implementation_plan_008_0919.md)。工程別の検証は [verification_shared_dashboard_001_0919.md](verification_shared_dashboard_001_0919.md)〜[004](verification_shared_dashboard_004_0919.md) を参照する。

新しい Change は作成していない。旧方針「3次元α=1.0維持」は計画008と更新済みChangeにより破棄し、主事前α=0.5・感度α=1.0へ移行した。

## 実施タイムライン（JST）

| 時刻帯 | 内容 | 証拠区分 |
| --- | --- | --- |
| 計画承認後 | 16タスク実装（共有CSS/DT/用語集、両dashboard適用、3次元Dirichlet主事前移行、契約テスト） | 実装 |
| 実装直後 | 数学・2D/3D HTML契約・計算エンジン・オフライン静的スキャン | 構文検証・実行結果 |
| 同日 01:00台 | 新規隔離run生成、preview HTML、検証002記録 | 実行結果 |
| 同日 01:20台 | Pass 2（考察・claims・quality）作成、Claims Gate、本番 `dashboard.html`、`run_state=sealed` | 実行結果 |
| 同日 01:20台 | commit `eea6918`（実装本体） | commit |
| 同日 01:25台 | commit `61225bd`（封印run・Archives）＋ `origin/main` へ push | commit / push |
| 同日午前（別担当記録） | 独立レビュー003、F1〜F3修正と検証004 | 独立QA・実装者検証 |

## 確定した決定

1. **表示共通化と主事前移行を工程分離**する。同一事前では計算値を変えず、主事前変更による数値差は意図した差として記録する。
2. **旧α=1.0成果物は保存**し、表示ラベルだけ Jeffreys にしない。旧JSONでα欠損時は「未確認」。
3. **Poisson BIC・局所診断・候補判定式は変更しない**。3次元候補式にN閾値が無い点は別論点のまま保持する。
4. **支持集合**は観測表行（`observed_table_rows`）。構造的ゼロを疑似度数で埋めない。
5. **新規主解析**は各セルα=0.5（jeffreys）、感度α=1.0（uniform）。`interval_level` と Dirichlet α を混同しない。
6. **規制当局がJeffreysを一律推奨する**との記載は入れない。

## 主な変更ファイル

### 共有プレゼンテーション

- `.agents/shared/dashboard_theme.css`（新設）
- `.agents/shared/dashboard_dt_ja.R`（新設）
- `.agents/shared/dashboard_glossary.R`（新設）
- `.agents/shared/run_scope.R`（renderer への `repo_root` 受け渡し等）

### 3次元経路（計算・契約・表示）

- `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R`
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R`
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/config_example.json`
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd`
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R`
- `.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json`
- `.agents/skills/vcd-bayesian-evidence-analysis/references/three_way_contract.md`
- `.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md`

### 2次元経路（表示のみ共有化）

- `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd`

### テスト・OpenSpec・計画/検証

- `tests/test_shared_dashboard_math.R`（新設）
- `tests/test_three_way_dashboard_html.R`
- `tests/test_vcd_categorical_dashboard_v4.R`
- `openspec/changes/shared-dashboard-theme-assets/`（proposal / design / specs / tasks）
- `docs/Artifacts/implementation_plan_008_0919.md`
- `docs/Artifacts/verification_shared_dashboard_00{1,2}_0919.md`（本セッション作成）
- 後続: `verification_shared_dashboard_00{3,4}_0919.md`（独立レビューとF1〜F3修正）

## Git

| SHA | メッセージ | 備考 |
| --- | --- | --- |
| `eea6918` | feat: 共有ダッシュボード資産と3次元Jeffreys主事前を導入する | 実装本体 25 files |
| `61225bd` | docs: Jeffreys主事前の封印済みUCB runと関連アーカイブを追加する | sealed run + Archives |

いずれも `main` に push 済み（`origin/main`）。

除外した追跡対象: `scratch/.../.run_locks/`、空の `staging/`（一時ファイル）。

## 封印済み再現run

- 経路: [`scratch/ucb_jeffreys_crv_0919_out/run_ucb_jeffreys_091/`](../../../../scratch/ucb_jeffreys_crv_0919_out/run_ucb_jeffreys_091/)

| 項目 | 値 |
| --- | --- |
| run_id | `ucb_jeffreys_0919` |
| 入力 | `examples/ucb_admissions.csv` |
| 主事前 | α=0.5 / jeffreys |
| 感度 | α=1.0 / uniform |
| 支持集合 K | 24 |
| `evidence_results.json` SHA-256 | `19289826998d061ee62e943d8e1fe662e6801cc0b67be0d28300674f1cd4736a` |
| 本番 `dashboard.html` SHA-256 | `ea790aa335da11fe3d368d39c884dfec78089ca2705ca7a7b6696d715b0f4df1` |
| `run_state` | `sealed`（pass2/pass3 completed） |
| Claims Gate | 21件照合成功 |

代表的な主事前差（旧fixture α=1.0相当 → 新α=0.5）: B Female 事後平均 0.6659 → 0.6724（+0.0065）。Poisson BIC（M5=332.3119 等）と M5診断件数（13/11/1）は不変。

## 本セッションで完了したこと / 後続記録との関係

本セッション完了時点（検証002）:

- OpenSpec tasks 1.1〜4.5（当時16タスク）を完了扱い
- Pass 2・本番HTML封印・commit/push

後続（検証003/004、本記録作成時点で Artifacts に存在）:

- 独立レビューで F1（希少確率の丸めゼロ化）等を指摘
- F1〜F3修正と tasks 5.1〜5.4 が追記・実施された記録あり

本変更記録は「セクション実施の履歴」であり、F1修正後の最終コード状態の再検証結果は [verification_shared_dashboard_004_0919.md](verification_shared_dashboard_004_0919.md) を優先する。

## 未実施（本セクション範囲外）

- OpenSpec change の archive（main specs への sync 含む）は、ユーザー明示指示があるまで未実施
- Cursor Usage / Auto運用方針は契約相談であり、本変更記録の対象外
