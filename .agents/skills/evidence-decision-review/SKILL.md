---
name: evidence-decision-review
description: "Use when auditing concordance between decision-label-free statistical evidence profiles and historical expert decisions via exploratory clustering and precedent retrieval, without imposing automated regulatory decisions."
license: MIT
metadata:
  author: agentic-evidence-analysis
  version: "0.1"
---

# Evidence-Decision Review

比較解析の統計プロファイルを**決定ラベル無し**の特徴量へ変換し、歴史的先例との整合を探索的に監査する。クラスタ割当や Discordance は **QA Review Candidate** の助言に限り、規制判断・ラベル変更を自動実行しない。

## 出力レイアウト（evidence-run-layout）

推奨ルート:

```text
evidence_runs/evidence_decision_review/run_<canonical_id>[_N]/
  ├── run_meta.json
  ├── evidence_feature.json      # evidence-feature-v1（主成果物）
  ├── results_manifest.json
  └── ...
```

- Run は `reserve_run_output_dir(..., skill = "evidence-decision-review")` / `init_evidence_decision_run()` で隔離する。
- 出力ルート直下への書き込み禁止。

## Phase A（実装済み）

1. `comparative-evidence-v1` から `evidence-feature-v1` を抽出（`.agents/shared/evidence_feature_extract.R`）。
2. 臨床決定コード・規制ラベル等の禁止キー混入は `[DECISION_LABEL_IN_FEATURE_SOURCE]` で Fail-Fast。
3. 特徴量は `core`（必須統計）と `delta_dependent`（`primary_delta` があるときのみ）に分割する。

## Phase B（現行: 13.4–13.8）

1. Gower 非類似度は `.agents/shared/evidence_gower.R`。
2. 数値スケールは版付き `frozen_reference_range`（既定: `schemas/fixtures/frozen_reference_range_default_v1.json`）。
3. 数値寄与 $d_j = \min(1, |x_i-x_j|/R_j)$（観測値は範囲境界へクリップしない。寄与のみ 1 で上限）。凍結範囲外は `GOWER_REFERENCE_RANGE_EXCEEDED` を記録する。部分キー選択は明示的 `keys=` のみ。選択キーはすべて frozen range に定義必須（`FROZEN_RANGE_MISSING_FEATURE`）。
4. カテゴリ／論理は一致 0 / 不一致 1。
5. `gower_distance_matrix()` は対角ショートカット前に range / schema / キー網羅を検証する（`n=1` 含む）。
6. 階層 HAC は `.agents/shared/evidence_cluster.R`（`stats::hclust`）。既定 linkage=`average`（`complete`/`single` 可。Ward 系は拒否）。分割は `fixed_k`（明示 `k` 必須）。割当は exploratory only。既定の安定性スタブは `NOT_ASSESSED` / `CROSS_THEME_DEPENDENCE_UNAVAILABLE`（13.13 で患者行 bootstrap に置換可能）。
7. 任意の標準化 K-means は同ファイルの `evidence_kmeans()`（`stats::kmeans`）。連続（`type=numeric`）特徴のみ。明示 `keys=` に categorical や分散0列を含めると Fail-Fast。`keys=NULL` では numeric に絞り定数列を除外。標準化後に `k <= n_distinct` を検証（`KMEANS_INSUFFICIENT_DISTINCT_CASES`）。既定 `nstart=10`, `algorithm=Hartigan-Wong`。割当は exploratory only。`promote_cluster_to_regulatory_action()` は常に拒否する。
8. 歴史先例は `.agents/shared/evidence_precedent.R` + `schemas/historical-precedent-case-v1.json`。`evidence_feature` は `assert_evidence_feature_v1()`（および schema `$ref`）で正規 `evidence-feature-v1` を強制。必須版バインド: `dictionary_release_version` / `delta_policy_version` / `feature_schema_version`。不一致は `version_compatible=false` + `version_mismatches` で明示。feature-schema 不一致は `distance_scorable=false` / `NOT_COMPARABLE` として距離計算せず、辞書・delta 不一致のみのケースは距離可能のまま返す。`retrieve_nearest_precedents()` は Gower 距離昇順で近傍と `decision_context` を返す（単一処方はしない）。

## Phase C（現行: 13.9–13.13）

1. 決定台帳は `.agents/shared/evidence_ledger.R` + `schemas/decision-ledger-record-v1.json`。
2. 各レコードは `record_sha256`（payload 自己ハッシュ）と `previous_record_sha256`（genesis は `null`）で連鎖。正規フィールド集合以外（追加・欠落・重複・無名）は拒否。
3. `append_decision_ledger_record()` は既存レコードを書き換えず末尾追加のみ。`verify_decision_ledger()` で連鎖改ざんを Fail-Fast。
4. 必須フィールド: `record_id` / `evidence_profile_sha256` / `decision_state` / `reviewer_justification_md` / `actor_id` / `decided_at_jst`（形式 `YYYY-MM-DD HH:MM:SS JST`）。
5. Discordance は `.agents/shared/evidence_discordance.R` + `schemas/discordance-advisory-v1.json`。方針は `k_neighbors` または `distance_radius`。乖離は **QA Review Candidate**（`severity=advisory`）のみ。workflow は停止しない。同票は `tie=true` で候補にしない。
6. 文言契約（13.11）: `assert_discordance_wording_contract()` は **system 文言**（`wording`/`severity`/`advisory_flag`）のみ禁止語監査。`REJECT`/`REJECTED` 等の決定ラベルはスキャンしない。
7. 軌道追跡は `.agents/shared/evidence_trajectory.R` + `schemas/decision-trajectory-v1.json`。`build_decision_trajectory()` / `trajectory_from_ledger()`（後者は `verify_decision_ledger()` 必須）。
8. クラスタ安定性は `assess_cluster_stability()`。`patient_rows`（`subject_id`+`unit_id`）+ `refit_features` + `frozen_range` があるときのみ patient-level bootstrap co-clustering（`ASSESSED`）。`refit_features` 出力は Gower 前に `assert_evidence_feature_v1()` で検証。欠落時は `NOT_ASSESSED` / `CROSS_THEME_DEPENDENCE_UNAVAILABLE`。`attach_cluster_stability()` は n/k/linkage/labels 互換を検証。

## 鉄則

1. 実行中にパッケージを自動インストールしない。
2. 特徴量に人間の臨床裁決・規制ラベルを含めない。
3. クラスタ結果だけで規制アクションやラベル変更を起こさない。
4. 生成 HTML を出す場合は Zero-External-Asset を守る（本 Phase では HTML 未実装）。

## Run lifecycle（13.A.R1）

`complete_evidence_decision_feature_run()` が次を一括実行する:

1. `reserve_run_output_dir`（衝突時は `_2` サフィックス）
2. `evidence_feature.json` 書き込み
3. `results_manifest.json`（primary=`evidence_feature.json`）
4. `run_meta.json`（`results_manifest_sha256` 結合、`skill=evidence-decision-review`）

`read_run_control()` / `verify_results_manifest()` で監査可能であること。
