# Phase 2 Section 11 人年発生率エンジン 実施記録 001

created: 2026-09-24 01:48 (JST)
update: 2026-09-24 01:48 (JST)
author: Codex (GPT-6)

## 1. 実施範囲と境界

[実装計画012](implementation_plan_012_0924.md)の承認に基づき、OpenSpec Change `comparative-evidence-reporting-v3` のSection 11、タスク11.1〜11.6を実装した。作業開始時のHEADは`4829cb0`。既存のSection 10受入後修復差分と未追跡の[QA報告3](Phase2_Section10_IPTW_QA_Repair_Report3_20260924.md)は保持した。

本実施は集計イベント数・曝露人時を入力とする率推論エンジンまでであり、レポート画面への人年率表示、患者内反復イベント相関、時間変化する発生率の推定は対象外である。

## 2. 実装結果

| タスク | 実装・確認内容 |
|---|---|
| 11.1 | 各群のイベント数を非負整数、曝露量を有限・正値として検証し、`Gamma(shape=x+0.5, rate=T)`から事後率drawを生成。イベント数が曝露量を超える人年率入力も許容。 |
| 11.2 | 目標群・参照群の事後率中央値と95% ETIを出力。`inferential_semantics=posterior`、`estimate.source=posterior_median`、`interval.method=posterior_eti`を明示。raw drawは既定で非永続。 |
| 11.3 | 共有contrastモジュールに率専用変換を追加し、draw単位でIRD・IRRを算出。二値リスクの既存項目名は流用せず、率専用evidence schemaを使用。 |
| 11.4 | 人年・人月単位、shape-rate、イベント数、曝露分母、事後shapeをdraw metadataへ記録。100人年当たり追加イベント数を単位に応じ換算。schema正例・負例を追加。 |
| 11.5 | 一定発生率の仮定と、同一被験者内反復イベントのクラスタリングを扱わない限界を構造化出力へ記載。 |
| 11.6 | 参照群0件時にはIRRの理論平均を`null`、`mean_is_finite=false`とし、中央値・ETIは保持。両群0件のfixtureを確認。 |

参照群イベント数が1件以上のとき、独立Gamma事後分布に基づくIRR平均は解析式`(x_T+0.5)/T_T × T_R/(x_R-0.5)`から算出する。人月入力の率差は、100人年当たり表示で12か月/年を反映する。

## 3. 検証結果

| 検証 | 実測結果 |
|---|---|
| `Rscript tests/test_person_time_rate.R` | 30 PASS / 0 FAIL。入力境界、Gamma分位点、seed再現性、IRD/IRR、人月換算、0件を確認。 |
| `Rscript tests/test_comparative_schemas.R` | 96 PASS / 0 FAIL。Section 10のschema契約を含む。 |
| `Rscript tests/run_regression_suite.R` | 42/42 PASS、FAIL 0、NOT_FOUND 0。 |
| `openspec validate comparative-evidence-reporting-v3 --strict --json` | valid、issue 0。 |
| Draft-07 schema検証 | 変更したdraw schemaと新規率evidence schemaがmeta-schemaに適合。実行時生成のdraw/evidenceを`jsonschema.Draft7Validator`で検証し、両方適合。 |
| `git diff --check` | エラーなし。新規ファイルの末尾改行・行末空白も確認。 |

OpenSpec CLIの進捗は201タスク中145完了・56残件。Section 11の6タスクは全て完了として記録した。

## 4. 残事項と証拠区分

- 人年率の結果は率専用schema `comparative-rate-evidence-v1`で返す。既存の二値リスク用`comparative-evidence-v1`やレポート画面に率を混入させていない。
- 本記録は実装者によるテスト・実行証拠である。独立QA、Owner判断、commit、push、archiveは未実施。
