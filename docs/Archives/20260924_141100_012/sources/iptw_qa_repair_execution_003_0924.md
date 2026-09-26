# Phase 2 Section 10 IPTW 受入後QA修復 実施記録 003

created: 2026-09-24 01:33 (JST)
update: 2026-09-24 01:33 (JST)
author: Codex (GPT-6)

## 1. 対象と判定

[実装計画011](implementation_plan_011_0924.md)に基づき、[QA報告3](Phase2_Section10_IPTW_QA_Repair_Report3_20260924.md)のM4-01・M4-02を受入後タスク10.R20〜10.R22として修復した。開始時のHEADは`4829cb0`。QA報告3に記録されたSection 10の`PASS / ACCEPT`判定は変更していない。本記録は実装・実行証拠であり、独立QAの再実施やOwner裁定を示すものではない。

## 2. 実施内容

| タスク | 変更 | 結果 |
|---|---|---|
| 10.R20 | evidence/draws両schemaのPS境界`upper`を`exclusiveMaximum: 1`に変更。共有PS要約schemaを新設し、effective/rawの4要約に適用。raw要約とeffective common supportを必須化し、PS値・support境界を`[0,1]`に制限。 | 実行時生成のevidence/drawsは有効。`upper=1`、raw要約欠落、空要約、effective重なり判定欠落、PS要約値`1.1`、support境界`1.1`の負例は無効。 |
| 10.R21 | Batch 011要約のSection 9方式名をATT set-weighted推定量と原子単位セット・クラスターブートストラップに訂正し、matched-pairの実装・テストパスを正本名に修正。 | 要約中の列挙済み実装・テストパス8件は全て実在。条件付きロジスティック回帰および旧パスの記載は0件。退避済み原本文書は変更なし。 |
| 10.R22 | 指定された検証を実行し、OpenSpecタスク状態を更新。 | 下表のとおり。 |

共有schema `schemas/comparative-ps-summary-v1.json` はevidence schemaから相対参照されるため、schemaをリポジトリ外へ配布する場合は両ファイルを同じ相対配置で含める必要がある。

## 3. 検証結果

| 検証 | 実測結果 |
|---|---|
| `Rscript tests/test_comparative_schemas.R` | 85 PASS / 0 FAIL。実行時生成payloadの正例と10.R20負例を含む。 |
| `Rscript tests/run_regression_suite.R` | 41/41 PASS、FAIL 0、NOT_FOUND 0。 |
| `openspec validate comparative-evidence-reporting-v3 --strict --json` | valid、issue 0。 |
| JSON構文確認 | 変更した3つのschema全てが`python3 -m json.tool`で正常。 |
| Batch 011要約の静的確認 | 旧方式名・旧パス0件。列挙された実装・テストパス8件すべて実在。 |
| `git diff --check` | エラーなし。 |

## 4. 変更境界と残事項

- 作業開始時から存在する未追跡のQA報告3は保持した。追加した計画011と本実施記録、共有schemaは未追跡のまま、その他の修正は未コミットである。
- 実行時エンジン、レポート生成処理、依存関係、データ、小セル抑制方針は変更していない。
- 新規の独立QA、Owner裁定、commit、push、archiveは未実施。
