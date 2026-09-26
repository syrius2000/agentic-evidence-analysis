# Section 11受入後修復・Section 12反復測定境界 実施記録 001

created: 2026-09-24 02:17 (JST)
update: 2026-09-24 02:17 (JST)
author: Codex (GPT-6)

## 1. 対象と受入判定

[実装計画013](implementation_plan_013_0924.md)に基づき、[Section 11 QA報告1](s11_person_time_qa_review1_001_0924.md)の受入後項目11.R7〜11.R11と、OpenSpecのSection 12（12.1〜12.4）に対応した。開始時のHEADは`1d42f4a`。QA報告によるSection 10・11の`PASS / ACCEPT`判定は変更していない。未追跡のQA報告原本は保持した。

## 2. QA指摘対応

| ID | 対応結果 |
|---|---|
| 11.R7 | `design=person_time`のdrawで`inferential_semantics=posterior`を条件付きで必須化。bootstrap偽装を拒否し、他デザインのdraw正例を保持。 |
| 11.R8 | 人年と`events_per_person_year`、人月と`events_per_person_month`の組だけをdraw metadataとrate evidenceで許容。逆の組を拒否。 |
| 11.R9 | 参照群0件のIRR平均`null`、有限性`false`、診断`ZERO_REFERENCE_EVENTS`をschemaで同時拘束。参照群正値時の補完状態も拘束。 |
| 11.R10 | person-timeのpersisted drawに両群の正値配列各10件以上を要求。ephemeralは両群`null`を明示的な正本形式とした。配列長と`num_draws`の一致は実行時テストで検証。 |
| 11.R11 | 実測件数をassertionとテストスクリプトで区別し、対象・正規回帰・OpenSpec・Draft-07・差分を再検証。 |

## 3. Section 12実装

| ID | 対応結果 |
|---|---|
| 12.1 | Pass 0に確認済みの`repeated_rows`方針を追加。被験者ID・群・二値結果列、`any_event`規則を明示し、同一被験者の群不一致、欠測、非二値結果、マッチング構造、上位クラスタを拒否。 |
| 12.2 | 安全集約時だけ被験者単位のイベント人数・総人数を`routing_decision.subject_level_counts`へ記録し、独立二群二値エンジンへルーティング。元CSVは変更せず入力SHA-256を保持。集約方針なしの重複被験者行も停止。 |
| 12.3 | 将来のクラスタ単位bootstrapの原子単位ID、全クラスタ再抽出、再推定範囲、失敗・区間診断の接続点をOpenSpec設計文書に記載。現行推定器は追加していない。 |
| 12.4 | GLMM/GEEは別OpenSpec Changeで推定量・相関仮定・検証を定める境界を設計・仕様に記載。上位クラスタ入力は独立二群エンジンへ黙って送らない。 |

## 4. 件数の訂正と検証結果

QAレビュー対象コミット`1d42f4a`に対応する既存[Section 11実施記録](../../20260924_141100_012/sources/person_time_section11_execution_001_0924.md)の値は、**人年率30 assertions PASS、schema96 assertions PASS、正規回帰42/42テストスクリプトPASS**である。Section 10受入後修復時のschema85 assertionsは、その時点の別記録であり矛盾しない。人年率テストを「42 assertions PASS」とする記載は採用しない。

| 今回の検証 | 実測結果 |
|---|---|
| `Rscript tests/test_person_time_rate.R` | 31 assertions PASS / 0 FAIL。 |
| `Rscript tests/test_comparative_schemas.R` | 111 assertions PASS / 0 FAIL。 |
| `Rscript tests/test_pass0_routing.R` | 31 assertions PASS / 0 FAIL。 |
| `Rscript tests/run_regression_suite.R` | 42/42テストスクリプトPASS、FAIL 0、NOT_FOUND 0。 |
| `openspec validate comparative-evidence-reporting-v3 --strict --json` | valid、issue 0。 |
| Draft-07 | 変更したdraw/rate evidence/Pass 0 schemaはmeta-schemaに適合。実行時draw/evidenceの正例と、誤った推論意味・単位組・IRR状態・persisted drawの負例、計18 payloadを実際のvalidatorで確認。Pass 0設定も正例と不正設計・未確認・不正規則の負例を確認。 |
| `git diff --check` | エラーなし。新規Artifactの行末空白・末尾改行も確認。 |

## 5. 残る境界

- 被験者内の`any_event`集約は明示確認済みの独立二群二値設計に限る。階層クラスタ、GLMM/GEE、クラスタbootstrap推定器は未実装。
- 本記録は実装と実行検証の証拠であり、新たな独立QA、Owner裁定、commit、push、archiveを示さない。
