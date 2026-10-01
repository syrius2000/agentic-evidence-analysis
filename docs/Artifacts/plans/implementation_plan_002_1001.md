# 稀な有害事象の既定閾値・感度設定と表示方針の実装計画

created: 2026-10-01 20:30 (JST)
update: 2026-10-01 22:45 (JST)
author: Codex (GPT-6)

## 1. 目的と今回の境界

`vcd-categorical-reporting` の有害事象比較で、引数を省略した場合は実務閾値0.001（1,000人あたり1人の絶対差）を自動適用し、感度検討の候補を0.0001・0.0005・0.001・0.005とする。毎回の閾値確認を省き、適用値と来歴を成果物で確認できるようにする。

この方針は探索的比較用の運用基準であり、臨床的重要性や許容可能なリスクの普遍的閾値ではない。重篤事象は閾値・U-Gradeにかかわらず別途レビューする。今回のCSVには重篤性情報がないため、PT名称から重篤性を推測・自動分類しない。

作業ブランチは `codex/reporting_metric_guides`。開始時には前ラウンドのSkill、Rコード、数理正本、仕様、テスト2本の追跡差分と計画001が存在する。これらを保持し、本ラウンドの変更を開始時diffと区別する。この計画は前ラウンドの承認範囲を拡張するため、承認後に実装する。

## 2. 実物照合と変更対象

現行の `generate_comparative_report()` は `primary_delta = NULL`、`delta_thresholds = c(0.01, 0.02, 0.05, 0.10)`、`domain = "safety"`。閾値は独立推論エンジンへ明示的に渡される。感度計算は共有エンジンの `delta_profile` に既に存在する。旧 `get_departmental_delta_policy()` の `default_mode = "none"` は他経路にも関係するため変更しない。

変更対象：

- [Skill指示](../../../.agents/skills/vcd-categorical-reporting/SKILL.md)：承認済み既定方針の自動適用、上書き・省略の条件、重篤事象のレビュー方針。
- [生成Rコード](../../../.agents/skills/vcd-categorical-reporting/comparative_reporting.R)：ローカルな既定方針、引数検証、来歴搬送、HTML・Markdown表示、感度結果提示。
- [数理正本](../../reference/comparative_evidence_math.md)と[報告仕様](../../../openspec/specs/comparative-evidence-reporting/spec.md)：自動適用の範囲・単位・提示・互換性の契約。
- [ダッシュボードテスト](../../../tests/test_comparative_dashboard_qa.R)と[報告テスト](../../../tests/test_vcd_categorical_reporting.R)：既定・明示指定・無効値・例外の回帰確認。

共通推論エンジン、他スキル、Pass 0全体の既定値、既存run、入力CSV、依存関係は変更しない。commit・push・独立QA・正式な有害事象再解析は含めない。

## 3. データと来歴の先行契約

### 入力の解決順序

`domain = "safety"` の本生成関数で、`missing(primary_delta)` が真なら0.001を、`missing(delta_thresholds)` が真なら新しい4候補を採用する。明示的な正の値・候補は利用者指定として優先する。非Safetyでは現行の既定挙動を保持する。

明示的な `primary_delta = NULL` を自動値へ置換しない。有害事象で評価を意図的に省略する場合は、新規引数 `allow_unevaluated = TRUE`（既定FALSE）を明示し、利用者の省略合意に基づくことをSkillで要求する。FALSEのままのNULLや未評価overrideは計算・最終成果物生成前に停止する。正の単一有限値、0より大きく1以下の割合尺度を検証する。感度候補も有限の正数で1以下とし、重複・順序は既存エンジンの正規化に従う。

`evidence_overrides` には既定閾値を後付けして再分類しない。各contrastの正本閾値を用い、未評価なら省略許可を確認する。既定0.001と異なる有効閾値は正本overrideの値として表示する。

### 表示に先行して搬送するデータ

| 内容 | 正本・搬送先 | 契約 |
|---|---|---|
| 新規の本スキル限定方針 | 生成Rコード内の新規 `REPORTING_SAFETY_POLICY` | `policy_version = "rare_ae_exploratory_v1"`、割合尺度、主閾値0.001、4感度候補を1か所に定義 |
| 実際の行別閾値 | `practical_region_support.primary_delta` → 新規要約列 `effective_primary_delta` | canonical値を搬送。未評価は欠測。表示層で再推定しない |
| 行別の設定元 | 新規要約列 `practical_threshold_source` | `default_policy` / `explicit_argument` / `evidence_override` / `explicit_none` を実行経路から確定 |
| 実行の設定来歴 | JSON既存 `run_meta` と `run_meta.json` の追加ブロック `practical_difference_policy` | 方針版、既定・明示の別、解決後の主閾値と感度候補、省略許可を記録。正本schemaとの整合を確認 |
| 感度結果 | `delta_profile[*].delta`、`p_rd_gt_delta`、`p_rd_lt_minus_delta`、`p_neutral` | 既存の計算結果を使い、HTML/Markdownで再計算しない |

新規識別子は本計画で定義した追加項目である。既存の42要約項目は保持し、追加2列もCSVと埋込JSONへ搬送する。RD・RR・方向支持・逆数RDの正本指標と乱数seedは変更しない。

## 4. ダッシュボードとSkillの変更

表の近くに主閾値・自然単位・設定元・感度候補を表示する。既定利用時は「稀な有害事象の探索的比較として0.001（1,000人あたり1人）を自動適用」と記載し、利用者が上書きした実行には実際の指定値を表示する。overrideの閾値が異なる場合、既定値で評価したと誤表示せず実務領域セルに各行の有効閾値を添える。

「重篤事象は、この閾値やU-Gradeにかかわらず別途レビューする。実務的中立は安全性の保証ではない」と明記する。重篤性情報がない入力では、重篤事象を自動識別していないことを案内する。

4候補の `delta_profile` は折りたたみの感度結果として提示し、主閾値のU-Gradeと区別する。候補ごとの新たなグレードや自動重要性ラベルは追加しない。メイン表の12列、実務領域セルだけの着色、自己完結型HTMLを維持する。

Skillは「用途に合う承認済み既定方針があれば自動適用する」に改定する。今回の実装承認を方針の採用承認として扱い、同じ用途で毎回再確認しない。新しい用途、個別PTの別閾値、明示的省略では対応する設定を確認する。

## 5. 検証マトリクス

| 入力例・境界 | 確認 | 期待結果 |
|---|---|---|
| Safety、閾値と感度候補を省略 | エンジン引数、JSON、要約、画面 | 0.001・4候補を自動適用、正本に一致、設定元は既定方針 |
| Safety、主閾値0.005と任意候補を明示 | 上書きと表示 | 指定を優先、画面に0.005を表示、既定0.001を適用済みと誤記しない |
| NULL、ゼロ、負数、NA、Inf、長さ2、1超 | 開始前の検証 | 不正値は停止。NULLは明示的省略許可がなければ停止 |
| NULLかつ省略許可TRUE | 例外 | NONEと理由を保持、閾値自動適用と誤表示しない |
| 評価済み・未評価・別閾値override | 各contrastの正本と来歴 | 正本を再分類しない。未評価許可なしは停止、許可ありは行別に適切な値・理由を表示 |
| 非Safetyで引数省略 | 互換性 | 現行の既定値・表示契約を保持 |
| 既存の正常・疎・ゼロ発生Fixture | 数値不変性 | 同じseedと入力でRD・RR・方向支持・E100・逆数RDが一致。実務評価と感度結果のみ設定差を反映 |
| 既存runと同じ主閾値・旧4候補を明示 | 後方互換性 | 既存canonical結果が一致 |
| Drug-Safty-example.csvのPT別件数を回帰Fixtureとして利用 | データ依存と来歴 | 既定方針で想定外NONEなし。PTをSOCへ単純合算せず、重篤性を推測しない |
| HTML・Markdown・CSV | 設定元・自然単位・感度表示・レビュー注記 | 全媒体で実際の設定と一致、44要約列、メイン12列保持 |
| ブラウザのマウス・Enter・Space・フィルタ・CSV | 既存UI操作と追加表示 | 既存操作を維持、外部アセット・OSパス依存なし |

対象回帰テスト、schema検証、テーマ契約、OpenSpec strict検証、Skill形式検証を実施する。必要な依存がなければ自動導入せず制約を報告する。生成結果は新規隔離runへ保存し、既存runと開始時差分を保持する。終了時diffで本ラウンドの編集境界を確定し、静的検証・実行・独立QA・Owner判断・commit・pushを区別して報告する。

## 6. 実装・検証結果

2026-10-01 22:45 JST時点で、承認された範囲の実装を完了した。

- Skillをversion 3.2へ更新し、Safety限定で引数省略時に `primary_delta = 0.001` と感度候補 `0.0001, 0.0005, 0.001, 0.005` を適用する契約、明示値優先、評価省略の明示許可、重篤事象の別途レビューを記載した。
- 生成Rコードで入力検証、要約行の評価状態・実効閾値・設定元、JSON/run metadataへの方針来歴、HTML/Markdownの方針説明と既存 `delta_profile` による感度結果を実装した。非Safetyの従来既定値と共有エンジンは変更していない。
- 数理正本とOpenSpec仕様、回帰テストを更新した。主表12列と実務領域セル限定の色付け契約を維持した。
- [Drug-Safty-example.csvを使った検証run](../../../evidence_runs/vcd_categorical_reporting/run_drug_safty_defau/dashboard.html)を隔離生成した。SOC/PTを連結したPT単位の250比較行すべてが `evaluated`、閾値0.001、設定元 `default_policy` であり、NONEは発生しなかった。重篤性は名称から推定していない。

| 検証 | 結果 |
|---|---|
| `tests/test_comparative_dashboard_qa.R` | 239 passed、0 failed |
| `tests/test_vcd_categorical_reporting.R` | 40 passed、0 failed |
| `tests/test_comparative_schemas.R` | 139 passed、0 failed。Python `jsonschema` がなく外部Draft-07照合は未実施（自動導入なし） |
| `tests/test_dashboard_theme_contract.R` | 88 passed、0 failed |
| `tests/test_pass0_routing.R` | 40 passed、0 failed |
| OpenSpec strict検証 | `comparative-evidence-reporting` valid |
| Skill形式検証 | `quick_validate.py`: Skill is valid |
| R構文・`git diff --check` | 成功 |

ブラウザ操作の個別キー・絞り込み確認と独立QAは未実施。commitおよびpushは行っていない。
