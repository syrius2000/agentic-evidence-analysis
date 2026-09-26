# 実装計画 020 — Section 13 Phase B バッチ1（13.6 K-means + 13.14 ガバナンス試験）

created: 2026-09-25 05:33 (JST)
update: 2026-09-25 05:35 (JST)
author: Auto (Composer)
approval: ユーザー指示「実装！」を本範囲（13.6 + 13.14）の実装承認として扱う

## 1. 目的

Section 13.5 ACCEPT 後、推奨手順の**第1グループ**のみを実装する。

- **13.6** 連続特徴限定の標準化 K-means
- **13.14** クラスタ割当単独では規制アクション／ラベル変更を起こさないことの試験固定

## 2. 範囲

| ID | 内容 | 本計画 |
|---|---|---|
| **13.6** | 標準化 K-means（連続特徴のみ、スケーリング検証） | **実施** |
| **13.14** | 割当単独で規制アクションを起こさないガバナンス試験 | **実施** |
| 13.7–13.8 | 版バインド / 先例検索 | **含めない** |
| 13.9–13.12 | ledger / discordance / wording / trajectory | **含めない** |
| 13.13 | patient-level bootstrap 安定性 | **含めない**（`NOT_ASSESSED` 維持） |

次グループ（13.7–13.8）へ進む前に、本バッチの独立 QA ACCEPT と計画更新・再承認を要する。

## 3. 契約（13.6）

1. **位置づけ**: HAC が主経路。K-means は **optional secondary**。既定呼び出しは HAC のまま。
2. **アルゴリズム**: 純 R `stats::kmeans`（追加パッケージ禁止）。`nstart` は明示引数（既定は実装で固定し provenance に記録）。
3. **特徴制限**: `frozen_reference_range` 上で `type == "numeric"` のキーのみ許可。categorical / logical を1つでも含めようとしたら Fail-Fast（例: `[KMEANS_NON_CONTINUOUS_FEATURE]`）。
4. **スケーリング**: 入力行列は列ごと標準化（平均0・分散1）。明示 `keys=` に分散0列が含まれる場合は Fail-Fast（`[KMEANS_ZERO_VARIANCE_FEATURE]`）。`keys=NULL` では定数列を自動除外し、残存キーが0なら Fail-Fast。スケール前後の要約（`scaled=true` + 使用キー + center/scale）を provenance に記録。
5. **分割**: `partition_mode = "fixed_k"`。明示整数 `k`（`2 <= k <= n`）必須。自動 K 推定なし。
6. **n**: `n >= 2` かつ連続特徴キー数 `p >= 1`。不足は Fail-Fast。
7. **安定性**: 本バッチでも `stability_status = "NOT_ASSESSED"`, `reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE"`。
8. **ガバナンス出力**: `exploratory_only = TRUE`, `decision_rule = FALSE`。規制アクション／ラベル変更 API は公開しない。

## 4. 契約（13.14）

1. HAC と K-means の双方について、割当結果オブジェクトに規制アクション副作用がないことをユニット試験で固定する。
2. 検証内容（最小）:
   - `decision_rule === FALSE` かつ `exploratory_only === TRUE`
   - 禁止キー（`regulatory_action` 等）を結果に含めない
   - 「割当 → ラベル変更／規制アクション」を行う公開関数が存在しないこと（または呼ぶと明示エラー）
3. 文字列監査で `wording` が exploratory-only 契約を維持すること。

## 5. 変更対象（予定）

- `.agents/shared/evidence_cluster.R`（`evidence_kmeans` / 連続特徴マトリクス組立・スケール検証を追加）
- `tests/test_evidence_cluster.R`（13.6 成功／拒否ケース + 13.14 ガバナンス）
- `tests/run_regression_suite.R`（必要なら登録維持のみ）
- `.agents/skills/evidence-decision-review/SKILL.md`（Phase B に K-means 追記）
- `openspec/.../tasks.md`（完了チェックは検証後）
- `openspec/.../design.md`（K-means 節を必要最小限更新）
- `docs/Artifacts/s13_6_kmeans_exec_001_0925.md`（実行証跡）

## 6. 検証

1. `Rscript tests/test_evidence_cluster.R`
2. `Rscript tests/test_evidence_gower.R`
3. `Rscript tests/run_regression_suite.R`
4. `openspec validate comparative-evidence-reporting-v3 --strict`
5. `git diff --check`

commit / push は別指示まで行わない。

## 7. 承認ゲート

- 本計画への明示承認（例: 「020承認」「バッチ1実装して」）があるまでコード変更しない。
- 範囲を 13.7 以降へ広げたい場合は本計画を更新して再承認する。
