# 実装計画 010 — Phase 2 Section 10 IPTW QA修復 #2

created: 2026-09-24 00:56 (JST)
update: 2026-09-24 00:56 (JST)
author: Codex (GPT-6)

## 1. 目的

[QA報告2](Phase2_Section10_IPTW_QA_Repair_Report2_20260924.md)のH3-01/H3-02およびM3-01〜M3-04を、Repair #1の正本計画である[implementation_plan_009_0924.md](implementation_plan_009_0924.md)と整合させて修復する。Repair #1の作業履歴・IDの意味は変更しない。

## 2. 現状と境界

- 現在のHEADはQA報告がレビューした `cee26ff`。実装差分はなく、作業ツリーには既存QA報告の削除とReport1/Report2の未追跡ファイルがある。これら既存変更を保持する。
- 本計画は計画009の範囲を拡張せず、修復#2を新しいID（10.R12以降）で扱う。
- Rscriptが利用可能。計画承認後、対象テストから正規回帰まで実行する。
- `<10` raw count抑制（10.R14）は報告内でOwner承認を前提としているため、現時点では実装対象外とする。小セル抑制の要否・閾値・JSON出力方針についてOwner判断を得た場合のみ、計画を更新して対象に含める。

## 3. 修復タスク

| ID | 優先度 | 実施内容 | 受入証拠 |
|---|---|---|---|
| 10.R12 | P0 | Repair #1を計画009の履歴として固定し、計画010・実施記録・OpenSpecでRepair #2 IDと用語を統一する。failure threshold既定値0.05、PS用語`raw_ps`/`clamped_ps`、小セル抑制未決、pseudo-repeat警告なしを明記する | 計画・仕様・実施記録のID/既定値/用語一致 |
| 10.R13 | P0 | evidence override時は evidence内raw countを真値源とし、report入力行のcountsと照合して不一致なら`EVIDENCE_REPORT_PROVENANCE_MISMATCH`で停止する。raw descriptive N/eventsとESSを別ラベル・別列で表示し、evidence override時はFisher検定を既定で実施しない | 同一データ統合fixture、一致しないcountsのfail-fast、FisherがNA、ESSの分離表示 |
| 10.R15 | P0 | evidence schemaの`iptw`にruntimeと同じprovenance項目を必須化・型/enum/範囲検証し、draw schemaとの意味的な契約を揃える | 必須項目欠落・enum・boundsのschema negative tests |
| 10.R16 | P1 | 純R Draft-07 validatorに`maximum`、`exclusiveMinimum`、`exclusiveMaximum`、非有限数拒否を追加する | IPTW境界、一般境界、NaN/Infのnegative tests |
| 10.R17 | P0 | 異なる患者データ由来evidenceと集計値を混ぜる現行テストを撤去し、単一患者データから解析・表示情報を導く統合テストに置換する | 同一ソース表示値、provenance mismatch、Fisher非混入、ESS、bootstrapラベルを検証 |
| 10.R18 | P1 | 各PS再推定bootstrap反復のclipping発生数、上下clipping総数、最大clipping割合を集計してevidence/draw metadataとschemaに追加する | 分離/near-separation fixtureで全診断値が非ゼロかつ整合することを検証 |
| 10.R19 | P0 | 対象テスト、正規回帰、OpenSpec strict、diff checkを実行し、独立再QAに渡す修復記録を作る | すべての実行結果を実施記録に記載 |

### 3.1 小セル抑制の保留項目（10.R14）

QA報告が触れている`N < 10`表示抑制は、既存の計画009/OpenSpec契約に含まれない。Ownerが要件として明示決定するまで、正確なraw countsの表示ポリシーを変更しない。承認された場合は、threshold=10の境界（9と10）、Markdown/HTML/CSV、構造化JSONの扱いを含む改訂計画を作成する。

## 4. 想定変更対象

- `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
- `.agents/shared/iptw_inference.R`
- `schemas/comparative-evidence-v1.json`、`schemas/comparative-draws-v1.json`
- `tests/test_comparative_schemas.R` と `tests/test_vcd_categorical_reporting.R`、必要に応じ `tests/test_iptw_inference.R`
- `openspec/changes/comparative-evidence-reporting-v3/` の設計・仕様・タスク
- QA修復実施記録 `docs/Artifacts/iptw_qa_repair_execution_002_0924.md`

上記以外に変更が必要と分かった場合は、対象を追加する前に本計画を更新して承認を得る。

## 5. 検証

1. `Rscript tests/test_iptw_inference.R`
2. `Rscript tests/test_comparative_schemas.R`
3. `Rscript tests/test_vcd_categorical_reporting.R`
4. `Rscript tests/run_regression_suite.R`
5. `openspec validate comparative-evidence-reporting-v3 --strict --json`
6. `git diff --check`、変更ファイルと既存差分の保持を確認

テスト通過は独立QAやOwner裁定の代替としない。Gateは修復状況と未裁定項目を分けて報告する。

## 6. 実施境界

- この計画の作成と読み取り専用調査は実装承認を意味しない。
- QA報告2は新規の実装対象と出力契約を含むため、コード・スキーマ・テスト・OpenSpec変更は本計画の明示承認後に開始する。
- 小セル抑制は独立したOwner判断が得られない限り実装しない。
- commit、push、branch削除、archiveは対象外とする。
