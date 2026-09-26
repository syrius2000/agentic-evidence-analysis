# Phase 2 Section 10 IPTW QA修復 #2 実施記録

created: 2026-09-24 01:11 (JST)
update: 2026-09-24 01:11 (JST)
author: Codex (GPT-6)

## 1. 参照と追跡

修復は[implementation_plan_010_0924.md](implementation_plan_010_0924.md)に従い、Repair #1のIDと履歴は[implementation_plan_009_0924.md](implementation_plan_009_0924.md)に保持した。QA報告2は[Phase2_Section10_IPTW_QA_Repair_Report2_20260924.md](Phase2_Section10_IPTW_QA_Repair_Report2_20260924.md)を参照元とし、その提案IDを実装記録の正本IDとして再利用せず、OpenSpecでは10.R12〜10.R19で追跡した。

## 2. 実施内容

- design-aware evidence overrideのraw descriptive countsは`iptw.raw_patient_counts`から取得する。レポート入力の群別countsと完全一致することを出力ディレクトリ確保前に検証し、不一致は`EVIDENCE_REPORT_PROVENANCE_MISMATCH`で停止する。
- レポートではraw descriptive N/eventsとESSを別列・別ラベルにした。design-aware overrideではFisher exactを既定で出力せず、明示的な別オプションを使う場合も別列に分ける。
- 現行の「別患者データのIPTW evidenceと無関係なaggregate rowsを結合する」テストを、同じ患者データからevidenceと群別countsを作る統合fixtureに置換した。不一致countsの拒否、ESS表示、Fisher非混入、bootstrap表現も確認する。
- `comparative-evidence-v1.json`のIPTW要件にdraws schemaと同じprovenance項目を追加し、項目欠落・enum・値域を検証する。
- 純R schema validatorに`maximum`、`exclusiveMinimum`、`exclusiveMaximum`、非有限数値拒否を追加し、各制約の負例を追加した。
- bootstrap refit成功反復について、clipping発生反復数、lower/upper合計、最大clipping割合を集計し、evidence/draw metadataとschemaへ追加した。
- `max_failure_rate`既定値0.05、raw/clamped PS用語、bootstrap重複の非警告、小セル抑制未採用をOpenSpec/Skillに揃えた。QA報告の`N < 10`表示抑制はOwner要件として確定していないため実装せず、計画010の範囲外として保留した。

## 3. 検証結果

- `Rscript tests/test_iptw_inference.R`: **69 PASS / 0 FAIL**
- `Rscript tests/test_comparative_schemas.R`: **71 PASS / 0 FAIL**
- `Rscript tests/test_vcd_categorical_reporting.R`: **35 PASS / 0 FAIL**
- `Rscript tests/run_regression_suite.R`: **41/41 PASS**, 0 FAIL, 0 NOT_FOUND
- `openspec validate comparative-evidence-reporting-v3 --strict --json`: **valid**, 0 issues
- `git diff --check`: **clean**

IPTW単体テスト内の分離fixtureでは`glm`警告が13件発生した。分離を含む境界動作fixtureからの警告であり、テスト失敗はない。

## 4. 判定と未完了項目

計画010に含む実装修復と自動検証は完了した。ただし、独立再QAによるH3-01/H3-02の再評価は未実施のため、Section 10全体を`ACCEPT`とは判定しない。次段階は独立QAとOwner裁定である。

小セル抑制（Nが10未満の場合の表示方針）はOwner要件が未確定のため未実装。raw count表示は現在マスキングせず、ESSと別に表示する。commit、push、archiveは行っていない。
