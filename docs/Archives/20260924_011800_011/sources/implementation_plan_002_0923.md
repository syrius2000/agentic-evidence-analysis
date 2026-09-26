# Phase 1 比較エビデンス報告の再レビュー指摘修復計画

created: 2026-09-23 12:17 (JST)
update: 2026-09-23 13:27 (JST)
author: Codex (GPT-6)

## 1. 対象と承認境界

本計画は、[承認済み Phase 1 計画](implementation_plan_001_0923.md)に対し、[再レビュー](Phase1_implementation_review2_20260923.md)で指摘された Phase 1 の欠陥だけを修復するための改定計画である。対象 Change は `comparative-evidence-reporting-v3`。現行 HEAD は `8174a47`。再レビュー文書は作業開始時から未追跡であり、変更しない。

OpenSpec の `proposal`、`specs`、`design`、`tasks` は作成済みで、`openspec status` の計画成果物は 4/4 完了である。この数値は実装完了を意味しない。実装、テスト、OpenSpec のタスク状態変更は、本改定計画への明示承認後に行う。commit、push、アーカイブ、Phase 2 への移行は対象外とする。

## 2. 修復方針と変更対象

| 指摘 | 対応方針 | 主な変更対象・確認点 |
| --- | --- | --- |
| B-01 | `pass0_routing.R` と `safety_adapter.R` の `%||%` を明示的な `NULL` 判定に置き換える。共有 `run_scope.R` を演算子のためだけに読み込まない。 | `.agents/shared/pass0_routing.R`、`.agents/shared/safety_adapter.R`、対応する独立プロセステスト |
| B-02、H-07 | `vcd-categorical-reporting` を共有 run 制御の許可スキル、manifest role、主成果物に登録する。reporter からの共有基盤読み込み失敗は `SHARED_RUN_SCOPE_UNAVAILABLE` で停止する。成果物の生成後に manifest と検証可能なハッシュを確定し、Pass 1 を `completed` にする。 | `.agents/shared/run_scope.R`、`.agents/skills/vcd-categorical-reporting/comparative_reporting.R`、run 制御テスト |
| H-01 | ファイル入力はファイル SHA-256、メモリ上の `df` は安定した列名・型・順序・値の正規化表現から SHA-256 を計算し、入力種別とハッシュを `run_meta.json` に記録する。ハッシュ対象の行順を契約に明記する。 | reporter、run metadata、再現性テスト |
| H-02 | 複数試験では試験 ID ごとの群別分母を必須とし、各値が有限・正の整数であることを確認する。記述的 pooled 分母は試験別分母の和とする。明示 pooled 分母を認める場合はその出典と整合条件を別途契約化するまで受け付けない。単一の群別ベクトルを複数試験へ流用しない。 | `.agents/shared/safety_adapter.R`、試験別・pooled 数値テスト |
| H-03 | 3 つの比較スキーマに対して実際のオフライン JSON Schema 検証を行う。ephemeral draw、永続 draw、単一 evidence、書き出した batch evidence を対象とする。既存依存で実現できない場合は依存変更として計画を再改定する。 | `tests/test_comparative_schemas.R`、必要なテスト fixture |
| H-04 | 未承認の `0.20` 判定による二値 `robust` を廃止し、連続的な感度差と事前分布条件を残す。`robust` を要求する既存 schema・Spec との整合を確認し、契約変更が必要なら実装前に本計画を再改定する。 | `.agents/shared/independent_beta_binomial.R`、schema、Change 文書、テスト |
| H-05 | Phase 1 では `mode=policy` の終端までの対応を主張しない。OpenSpec Task 7.4 を未完了に戻し、承認済み `none` / `fixed_delta` のみを Phase 1 の実装済み範囲として記録する。後続実装の時期は別途判断する。 | `openspec/changes/comparative-evidence-reporting-v3/tasks.md`、Pass 0 テスト |
| H-06 | 集計入力で同じ `(theme, group)` が複数行なら明示エラーにする。暗黙の先頭行選択や合算はしない。 | reporter、重複行テスト |
| M-01 | `practical_neutral` の色を中立色に変更し、明示的な同等性推定量がない限り「同等」と表現しない。 | reporter の HTML/CSS、文言確認 |
| M-02、M-03 | `ZERO_BOTH` の RR 理論平均が `NULL`、`mean_is_finite` が `FALSE` であることを直接検証する。主要 fixture の中央値、区間、方向確率の基準値と許容差を固定する。 | `tests/test_independent_beta_binomial.R` |
| M-04 | 既知の計数列を特定できないとき、無関係な数値列を計数と見なさず、イベント・分母列の明示指定を要求する。 | `.agents/shared/pass0_routing.R`、ルーティングテスト |
| M-05 | reporter API から `delta_thresholds` を受け取り、評価に用いたグリッドを run metadata と evidence に記録する。 | reporter、schema 整合、再現性テスト |

## 3. 実施順序と受入基準

1. 現行コード、Spec、schema、テストを再照合し、上表の契約変更が既存の正本と衝突しないことを確認する。衝突があれば実装を止め、計画を再改定する。
2. B-01 と B-02 の実行阻害を解消し、独立 R プロセスで読み込みと run 制御往復を確認する。
3. 入力来歴、Safety 分母、重複拒絶、run 制御の失敗時処理を実装する。
4. 実 JSON Schema 検証、感度分析の表現、実務差・表示・数値基準を整える。変更が確認できたタスクだけチェック状態を更新する。
5. 次の検証を実行し、コマンドごとの成功・失敗を記録する。

```text
Rscript tests/test_pass0_routing.R
Rscript tests/test_safety_adapter.R
Rscript tests/test_comparative_schemas.R
Rscript tests/test_independent_beta_binomial.R
Rscript tests/test_domain_invariance.R
Rscript tests/test_practical_difference.R
Rscript tests/test_vcd_categorical_reporting.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

加えて生成した run で `read_run_control(run_output_dir)` が成功し、`skill = vcd-categorical-reporting`、`pass_status.pass1 = completed`、入力 SHA-256、検証可能な結果 manifest、`comparative_evidence.json` の主成果物登録を確認する。OpenSpec の strict validation は文書構造の証拠として報告し、実行結果や独立 QA と区別する。

## 4. 現在の状態

Owner は本計画と第5節の契約改定をそれぞれ明示承認した。B-01、B-02、H-01〜H-07、M-01〜M-05 の対象修復を実装した。H-04 は Spec・design・tasks・schema を連続指標に一致させ、未承認の二値 `robust` 判定を廃止し、Task 3.11 を検証後に完了へ戻した。Task 7.4 は部門別 `mode=policy` が未実装のため未完了のままとした。H-04 反映後の `tests/run_regression_suite.R` は 38/38、OpenSpec strict validation は valid、`git diff --check` は合格した。独立 QA、Owner の最終裁定、commit、push、アーカイブは未実施。

## 5. H-04 契約改定（Owner 再承認済み）

改定前の Task 3.11 は「robustness flag」を必須とし、Change の Spec は「robustness indicators」を要求していた。design も「reporting robustness」と記載し、`comparative-evidence-v1.json` には任意の二値 `diagnostics.prior_sensitivity.robust` があった。本計画 H-04 の未承認閾値 `0.20` と二値判定の廃止に対し、Owner は次の契約変更を再承認した。

1. Change の `specs/comparative-evidence-reporting/spec.md` で、事前感度分析の出力を「RD 中央値差、方向支持差、U-grade の変化という連続・記述的指標」と明記し、未承認の二値判定を要求しない。
2. `design.md` と Task 3.11 を同じ出力契約に改める。感度分析は primary U-grade を変更しない。
3. `schemas/comparative-evidence-v1.json` の `robust` プロパティを廃止し、既存の `comparison` フィールドの連続指標を維持する。スキーマは同じ v1 名で未凍結であることを確認してから変更する。
4. `.agents/shared/independent_beta_binomial.R` の隠れた `0.20` 閾値と `robust` 出力を除き、感度分析の連続値が保持されることをテストする。Task 3.11 はこの検証後にのみ完了とする。

JSON Schema 検証は、外部 Python への依存（`jsonschema`, `referencing`）を完全撤廃し、他の既存テストと同様に純粋な R（`jsonlite`）を用いて Draft 7 スキーマ（`schemas/*.json`）の `required`、`type`、`properties`、`enum`、`not` 制約を再帰的に直接検証する自己完結型の検証器（`validate_payload_against_schema()`）を `tests/test_comparative_schemas.R` 内に実装した。これにより、Python 環境や外部ライブラリを一切要求せず、決定論的に全スキーマ検証が R 単体で完結する。

再承認された第1〜4項を実装し、感度分析の全モード、主解析 U-grade の不変性、旧 `robust` payload の schema 拒絶を確認した。Phase 1 修復の実装者検証は完了したが、独立 QA と Owner の最終裁定は別工程である。
