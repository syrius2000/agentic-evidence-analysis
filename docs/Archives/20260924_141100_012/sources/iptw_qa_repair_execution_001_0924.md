# Phase 2 Section 10 IPTW QA修復 実施記録

created: 2026-09-24 00:40 (JST)
update: 2026-09-24 00:40 (JST)
author: Codex (GPT-6)

## 1. 目的と参照文書

独立QA報告で指摘されたPhase 2 Section 10（IPTW）の契約・診断・報告上の問題を、承認済みの[実装計画009](implementation_plan_009_0924.md)に従って修復した。

- QA報告: [Phase2_Section10_IPTW_QA_Repair_Report_20260924.md](Phase2_Section10_IPTW_QA_Repair_Report_20260924.md)
- 親計画: [implementation_plan_008_0923.md](../Archives/20260924_011800_011/sources/implementation_plan_008_0923.md)
- 対象OpenSpec: [comparative-evidence-reporting-v3](../../openspec/changes/comparative-evidence-reporting-v3/)

## 2. 修復結果

- IPTW report rendererがbootstrap evidence overrideを受け取り、bootstrap percentile intervalとbootstrap support fractionを表示するようにした。CSV列名を中立化し、Bayesian reportでは従来のposterior/ETI表現を維持する自動テストを追加した。
- PS境界clampを公開引数`ps_boundary`で指定可能にし、raw/effective PS要約、境界、上下clipping件数を記録した。positivity overlapはraw PSに基づいて判定する。
- weighted cohortからraw `events`/`total`を除き、raw countsは`iptw.raw_patient_counts`に保持する。
- `max_failure_rate`を公開APIへ追加し、有限範囲を検証してevidence/draw metadataに記録した。閾値0のarm-loss fixtureでfail-fastを確認した。
- arm別truncationの上下限を手計算した期待値と照合するテストに置換した。extreme weight warningとno-overlap診断を検証した。
- `subject_id_col`指定時に欠損ID・重複IDを拒否する。
- IPTW draw metadata/schemaを拡張し、PS refit、truncation、ATT scaling、PS model/covariates、PS境界処理、failure thresholdを記録・検証する。
- ATTの`stabilization = TRUE`は`marginal_odds_scaled`の場合だけ許容する。
- comparative-design Skill、OpenSpec design/spec/tasksに修復後の契約を反映した。

## 3. 検証結果

- `Rscript tests/test_iptw_inference.R`: **66 PASS / 0 FAIL**
- `Rscript tests/test_comparative_schemas.R`: **54 PASS / 0 FAIL**
- `Rscript tests/test_vcd_categorical_reporting.R`: **31 PASS / 0 FAIL**
- `Rscript tests/run_regression_suite.R`: **41/41 PASS**, 0 FAIL, 0 NOT_FOUND
- `openspec validate comparative-evidence-reporting-v3 --strict --json`: **valid**, 0 issues
- `git diff --check`: **clean**

IPTW単体テストの分離fixtureでは`glm`から13件の警告が出た。これは意図的に分離・極端PSを発生させてboundary governanceを検証するfixtureに由来し、テスト結果はPASSである。

## 4. Gate状態

自動検証可能なQA修復項目は実装し、検証した。独立QA報告のAcceptance Gateを独立に解除したわけではないため、現時点の状態は**修復完了・独立再QA/Owner裁定待ち**とする。commit、push、branch削除は行っていない。
