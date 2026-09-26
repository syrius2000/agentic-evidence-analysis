# 実装計画 028 — Section 13.13.R3（refit feature canonical 強制）

created: 2026-09-25 17:22 (JST)
update: 2026-09-25 17:50 (JST)
author: Auto (Composer)
approval: ユーザー指示「承認します。実装して」を本範囲の実装承認として扱う
review: [s13_10_13_phase_c_qa_review2_001_0925.md](s13_10_13_phase_c_qa_review2_001_0925.md)

## 1. 目的

Re-QA Review2 残余 **M13.13-03** を閉じる（13.13.R3）。前回 High/Medium（R1/R2 系）は CLOSED 維持。

| ID | 指摘 | 修復 |
|---|---|---|
| **13.13.R3** | `refit_features()` 出力に `assert_evidence_feature_v1()` 未適用 | Gower 前に各 unit feature を canonical 検証 |
| 回帰 | cluster / regression / OpenSpec | |

## 2. 範囲外（本バッチ）

- Section 14
- 実装者自己点検 Medium（再 QA 後バックログ。本計画承認後または 13.13.R3 CLOSED 後に別計画へ追記）:
  - precedent `decided_at_jst` JST 正規化（ledger/trajectory とパリティ）
  - `attach_cluster_stability` の NOT_ASSESSED 付け替え時 stale フィールド掃除
  - discordance × truncated neighborhood の API 注記

## 3. 契約

1. `refit_features` が返した named list の各要素に対し、Gower 前に `assert_evidence_feature_v1(feat, context=...)`。
2. 非 canonical（`source` 欠落・core 不完全等）は Fail-Fast（当該 replicate を failed にカウントするか、即 stop か）。**推奨: Fail-Fast stop**（契約違反の callback は bootstrap 継続より明示失敗）。QA 文言は「掛ければ閉じる」なので assert 失敗で replicate/全体が止まる形で可。実装は **各 feature で assert → 失敗なら当該 replicate を `n_bootstrap_failed` に計上して next**（悪 callback でも全停止せず診断可能）とする。全 replicate が failed なら既存どおり `STABILITY_BOOTSTRAP_FAILED`。
3. テスト fixture の `refit_features` は canonical `evidence-feature-v1` を返すよう置換。負例: 非 canonical minimal → ASSESSED に到達しない。

## 4. 変更対象

- `.agents/shared/evidence_cluster.R`（`assess_cluster_stability`）
- `tests/test_evidence_cluster.R`
- `openspec/.../tasks.md`（13.13.R3）
- 実行証跡

## 5. 検証

```bash
Rscript tests/test_evidence_cluster.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict
git diff --check
```

## 6. 承認ゲート

- 本計画の明示承認があるまでコード変更しない。
- 独立再 QA・commit / push は別指示まで行わない。
