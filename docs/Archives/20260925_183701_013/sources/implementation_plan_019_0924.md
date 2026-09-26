# 実装計画 019 — Section 13 Phase B（13.5 Hierarchical Agglomerative Clustering）

created: 2026-09-24 15:41 (JST)
author: Auto (Composer)
approval: ユーザー指示「新規の実装 finding はありません。修復計画書も不要です。次は 13.5 Hierarchical Agglomerative Clustering に進めます。」を本範囲の実装承認として扱う

## 1. 目的

Section 13.4 ACCEPT 後、OpenSpec タスク **13.5** のみを実装する。

## 2. 範囲

| ID | 内容 | 本計画 |
|---|---|---|
| **13.5** | Gower 距離行列上の階層的凝集クラスタ、探索的割当、provenence | **実施** |
| 13.6 | 標準化 K-means | **含めない** |
| 13.7–13.8 | 版バインド / 先例検索 | **含めない** |
| 13.13 | patient-level bootstrap 安定性 | **含めない**（本タスクでは `NOT_ASSESSED` を明示） |

## 3. 契約（R4-04 / R4-05 反映）

1. **入力**: `gower_distance_matrix()` が返す対称非負距離行列（対角 0）。または feature リスト + frozen range から一括実行するラッパ。
2. **アルゴリズム**: 純 R `stats::hclust`（追加パッケージ禁止）。既定 linkage は **`average`**（Gower 非類似度向け。Ward 系は拒否）。
3. **許可 linkage**: `average` / `complete` / `single` のみ。値は provenance に必須記録。
4. **分割**: `cluster_partition.mode = "fixed_k"`。割当を返すには明示的な整数 `k`（`2 <= k <= n`）が必須。自動 K 推定はしない。
5. **n**: クラスタリングには `n >= 2`。`n < 2` は Fail-Fast。
6. **安定性**: 本タスクでは患者行がない前提のため `stability_status = "NOT_ASSESSED"`, `reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE"` を常に返す（13.13 で置換予定）。
7. **ガバナンス**: 割当は exploratory grouping aids のみ。決定ラベル変更・規制アクションを起こさない（API 文言とテストで固定）。

## 4. 変更対象

- `.agents/shared/evidence_cluster.R`（新規）
- `tests/test_evidence_cluster.R`（新規）
- `tests/run_regression_suite.R`（登録）
- `.agents/skills/evidence-decision-review/SKILL.md`
- `openspec/.../tasks.md`、`design.md`（必要最小）
- `docs/Artifacts/s13_5_hac_exec_001_0924.md`

## 5. 検証

1. `Rscript tests/test_evidence_cluster.R`
2. `Rscript tests/test_evidence_gower.R`
3. `Rscript tests/run_regression_suite.R`
4. `openspec validate comparative-evidence-reporting-v3 --strict`
5. `git diff --check`

commit / push は別指示まで行わない。13.6 へ進む前に計画更新と再承認を得る。
