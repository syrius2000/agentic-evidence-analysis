# 実装計画 011 — Phase 2 Section 10 IPTW 受入後QA対応

created: 2026-09-24 01:29 (JST)
update: 2026-09-24 01:29 (JST)
author: Codex (GPT-6)

## 1. 目的と判定境界

[QA報告3](Phase2_Section10_IPTW_QA_Repair_Report3_20260924.md)のM4-01・M4-02を、受入後の10.R20〜10.R22として修復する。報告3によるSection 10の`PASS / ACCEPT`は維持し、既に解消した10.R12〜10.R19を再開しない。

## 2. 現状

- 作業開始時のHEADは`4829cb0`。既存の未追跡ファイルとしてQA報告3があり、保持する。
- evidence/draws両schemaのPS境界`upper`は`maximum: 1`であり、実行時の`upper < 1`より緩い。
- evidence schemaの`positivity`はraw PS要約およびeffective common supportを必須としておらず、PS要約の内部項目・範囲も検査していない。
- Batch 011要約にSection 9の条件付きロジスティック回帰という誤記、および存在しないmatched-pairの実装・テストパスがある。その他の列挙された実装・テストパスは現時点で存在する。

## 3. 実施内容

| ID | 対応 | 受入条件 |
|---|---|---|
| 10.R20 | 両schemaでPS境界`upper`を`exclusiveMaximum: 1`にする。PS要約の共通schemaを追加し、evidence positivityのeffective/raw各要約に適用する。raw要約とeffective common supportの各項目を必須化し、PS値とsupport境界を`[0,1]`に制約する。 | 実行時生成のevidence/drawsが有効。`upper=1`、raw要約欠落、空要約、effective重なり判定欠落、PS値`1.1`は無効。 |
| 10.R21 | Batch 011要約だけでSection 9の方式名とmatched-pairの2パスを修正し、他の実装・テストパスの実在を確認する。 | Section 9の説明がATT set-weighted推定量と原子単位セット・クラスターブートストラップに一致し、列挙パスが実在する。 |
| 10.R22 | 対象schemaテスト、正規回帰、OpenSpec strict検証、静的確認、`git diff --check`を実行し、実施記録を作る。 | 各結果と未検証事項を区別して記録する。 |

## 4. 変更対象

- `schemas/comparative-evidence-v1.json`
- `schemas/comparative-draws-v1.json`
- `schemas/comparative-ps-summary-v1.json`（4つのPS要約で共有する新規schema）
- `tests/test_comparative_schemas.R`
- `docs/Archives/archived_summary_011_0924.md`（要約のみ。退避済み原本文書は変更しない）
- `openspec/changes/comparative-evidence-reporting-v3/tasks.md`（受入後タスクの追跡のみ）
- `docs/Artifacts/iptw_qa_repair_execution_003_0924.md`（新規実施記録）

実行時エンジン、レポート生成処理、データ、依存関係、小セル抑制方針は変更しない。対象や方式を変える必要が出た場合は計画を更新して再承認を得る。

## 5. 検証と完了条件

1. `Rscript tests/test_comparative_schemas.R`
2. `Rscript tests/run_regression_suite.R`
3. `openspec validate comparative-evidence-reporting-v3 --strict --json`
4. `git diff --check`と対象差分・既存未追跡ファイルの保持を確認
5. Batch 011要約に条件付きロジスティック回帰の記載がなく、matched-pairを含む列挙パスが実在することを確認

各検証の実測結果は実施記録に記載する。新しい独立QA、Owner裁定、commit、push、archiveは本計画に含めない。

## 6. 承認境界

本計画は調査・計画段階の成果物である。リポジトリの`AGENTS.md`にある段階的承認ルールに従い、コード・schema・テスト・文書の修正、および実行フェーズは、本計画と対象範囲への明示的承認後に行う。
