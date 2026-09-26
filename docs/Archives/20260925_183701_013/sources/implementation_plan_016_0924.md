# 実装計画 016 — Section 13 Phase A（Evidence-Decision Review 基盤）

created: 2026-09-24 14:12 (JST)
author: Auto (Composer)
approval: ユーザー指示「Section 13 着手」を **Phase A（13.1–13.3）** の実装承認として扱う

## 1. 目的

OpenSpec `comparative-evidence-reporting-v3` の Section 13（Evidence-Decision Review Engine）を開始する。本計画の実装範囲は **13.1–13.3 のみ**。Gower・クラスタリング・台帳・Discordance（13.4 以降）は含めない。

## 2. Phase 分割

| Phase | タスク | 本計画 |
|---|---|---|
| **A** | 13.1 skill 初期化、13.2 `evidence-feature-v1`、13.3 決定ラベル除外検証 | **実施** |
| B | 13.4–13.8 Gower / 階層クラスタ / K-means / 先例検索 | 別計画 |
| C | 13.9–13.14 台帳 / Discordance / 軌道 / 安定性 / ガバナンス | 別計画 |

## 3. Phase A 契約

| ID | 内容 | 受入 |
|---|---|---|
| 13.1 | `.agents/skills/evidence-decision-review/` を新設。推奨出力 `evidence_runs/evidence_decision_review/run_<id>/`。`run_scope` の manifest skill 登録。 | skill 文書・slug・run 予約のテスト |
| 13.2 | `schemas/evidence-feature-v1.json` と抽出器。core（必須統計）と delta_dependent（`primary_delta` 依存）を分離。 | schema 正例/負例 + extractor テスト |
| 13.3 | 臨床決定コード・規制ラベル等の禁止キーを特徴量に入れない。混入時は Fail-Fast。 | 禁止キー注入の負例ユニットテスト |

## 4. 変更対象

- `.agents/skills/evidence-decision-review/SKILL.md`（新規）
- `.agents/shared/evidence_feature_extract.R`（新規）
- `schemas/evidence-feature-v1.json`（新規）
- `.agents/shared/run_scope.R`（manifest 登録）
- `tests/test_evidence_feature_extract.R`（新規）
- `tests/run_regression_suite.R`（登録）
- `openspec/.../tasks.md`、`design.md`（Phase A 追記）
- `docs/Artifacts/s13_phaseA_exec_001_0924.md`

## 5. 検証

1. `Rscript tests/test_evidence_feature_extract.R`
2. `openspec validate comparative-evidence-reporting-v3 --strict --json`
3. `git diff --check`

commit / push は別指示まで行わない。Phase B へ進む前に計画更新と再承認を得る。
