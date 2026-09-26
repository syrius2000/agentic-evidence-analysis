# 実装計画 013 — Section 11受入後修復とSection 12反復測定境界

created: 2026-09-24 02:07 (JST)
update: 2026-09-24 02:07 (JST)
author: Codex (GPT-6)

## 1. 目的と承認範囲

[Section 11 QA報告1](s11_person_time_qa_review1_001_0924.md)の受入後修復11.R7〜11.R11と、OpenSpec `comparative-evidence-reporting-v3` の次タスク12.1〜12.4を実施する。ユーザーの「一部の訂正」「次のタスク実装を許可します」という指示を本範囲への実装承認として扱う。Section 10・11の`PASS / ACCEPT`を再開せず、Section 13以降には進まない。

## 2. 開始時の状態

- HEADはQA報告が対象とした`1d42f4a`。作業ツリーにはQA報告1の未追跡ファイルだけがあり、保持する。
- Section 11の実施記録は人年率テストを30 assertions、schemaテストを96 assertions、正規回帰を42 scriptsとして区別している。誤った「人年率42件」は現行実施記録には存在しない。新しい実施記録にも時点別件数を明記する。
- 既存Pass 0は設計列の検出とPT/SOC重複診断を行うが、反復観測行から被験者単位の二値状態へ安全に集約できるかの判定と、その結果を用いたルーティングは未実装である。

## 3. 受入後修復

| ID | 修復内容 | 受入条件 |
|---|---|---|
| 11.R7 | `design=person_time`のdrawに`inferential_semantics=posterior`を条件付きで必須化する。 | 不正なbootstrap状態をschema拒否し、既存デザインと正しい率drawは有効。 |
| 11.R8 | draw metadataとrate evidenceの`exposure_unit`・`rate_unit`を人年/人月で組として検証する。 | 正しい2組のみ有効、逆の2組は無効。 |
| 11.R9 | 参照群0件時のIRR平均`null`、`mean_is_finite=false`、診断コードをschemaで同時拘束し、正値件数の補完状態も拘束する。 | 0件時の不整合3種は無効、実行時正例は有効。 |
| 11.R10 | person-timeに限り、persistedは正値配列各10件以上、ephemeralは両drawを`null`とする条件付き契約を加える。配列長と`num_draws`の一致は実行時テストで確認する。 | 欠落/空/非正値persistedは無効、正しい両モードは有効。 |
| 11.R11 | 実測件数をassertion数とテストスクリプト数に分けて記録し、対象・正規回帰・OpenSpec・Draft-07・差分を再確認する。 | 第11節当時の30/96/42を時点付きで保持し、今回の実測値は別に記録。 |

## 4. Section 12実装契約

| ID | 実施内容 | 受入条件 |
|---|---|---|
| 12.1 | Pass 0設定の明示的な`repeated_rows`方針（被験者ID列、群列、二値結果列、`any_event`規則、確認済みフラグ）に基づき、同一被験者内の群不一致、欠測、非二値結果、階層クラスタを拒否する。条件が満たされれば被験者単位で`any(event=1)`を算出し、各群のイベント人数・被験者数を診断として返す。 | 安全集約・不一致・欠測・未確認・未対応クラスタのfixture。元データは変更しない。 |
| 12.2 | 確認済みで安全な集約だけを独立二群二値エンジンへルーティングし、集約した群別整数countsと元入力ハッシュをrouting decisionに保存する。 | 対象engine/moduleとcountsが一致し、未確認・不正入力は停止。 |
| 12.3 | 被験者より上位のクラスタを単位にした将来のbootstrap拡張インターフェース（cluster ID、原子単位再抽出、再推定範囲、出力診断）を設計文書に記す。 | 現行実装が上位クラスタを誤って独立標本へ流さず、文書が将来の接続点を明示。 |
| 12.4 | GLMM/GEE推定は今回の実装対象外であり、必要時は別OpenSpec Changeを要することを設計・仕様・テストで確認する。 | 文書に境界が明示され、未対応入力は黙って処理されない。 |

## 5. 変更対象

- `schemas/comparative-draws-v1.json`、`schemas/comparative-rate-evidence-v1.json`、`tests/test_comparative_schemas.R`
- `.agents/shared/pass0_routing.R`、`schemas/pass0-config-v1.json`、`tests/test_pass0_routing.R`
- `tests/test_person_time_rate.R`（persisted配列長の確認）
- `openspec/changes/comparative-evidence-reporting-v3/design.md`、`specs/pass0-analysis-routing/spec.md`、`tasks.md`
- `docs/Artifacts/s11_s12_boundary_exec_001_0924.md`（新規実施記録）

本計画にない実行時エンジン、解析データ、依存関係、Section 13以降、退避済み文書は変更しない。設計前提が崩れ、変更対象や処理方式を広げる必要があれば計画を更新して再承認を得る。

## 6. 検証と終了条件

1. `Rscript tests/test_person_time_rate.R`
2. `Rscript tests/test_comparative_schemas.R`
3. `Rscript tests/test_pass0_routing.R`
4. `Rscript tests/run_regression_suite.R`
5. `openspec validate comparative-evidence-reporting-v3 --strict --json`
6. Draft-07 validatorによる正例・負例確認、`git diff --check`、開始時の未追跡QA報告の保持確認

各結果は構文、対象テスト、正規回帰、独立QA、Owner判断に分けて報告する。commit、push、archiveは行わない。
