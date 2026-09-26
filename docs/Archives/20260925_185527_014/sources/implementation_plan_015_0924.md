# 実装計画 015 — QA0001.R6/R7 受入後ハーネス硬化

created: 2026-09-24 14:02 (JST)
author: Auto (Composer)
approval: ユーザー指示「R6+R7 で計画作成して実装開始」を本範囲の実装承認として扱う
review: [s12_qa0001_cycle02_qa_001_0924.md](s12_qa0001_cycle02_qa_001_0924.md)

## 1. 目的

Cycle 2 受入後タスク **QA0001.R6**（純R Draft-07 validator 忠実度）と **QA0001.R7**（R表現正規化の文書化）を実施する。Section 12 を再オープンしない。R8 と Section 13 は本計画の対象外。

## 2. 範囲

| ID | 内容 | 受入 |
|---|---|---|
| R6 | `validate_payload_against_schema` に `minLength` / `uniqueItems` を追加。空文字・重複 `cluster_cols` / `matched_cols` の負例。可能なら実 Draft-07（Python `jsonschema`）で同 fixture を再検証し、結果を別記。 | ローカルが受容する payload を実 Draft-07 が拒否する状態を、使用中キーワードについて解消する。jsonschema 未導入時は SKIP を明示しローカル負例は必須 PASS。 |
| R7 | length-1 R character を JSON 配列の受理可能なネイティブ表現と明記。正本シリアライズは常に配列。round-trip テスト1件。 | R 便利形が JSON 契約を曖昧化しない。 |

## 3. 変更対象

- `tests/test_comparative_schemas.R`（validator + fixture + round-trip + 任意 Python 照合）
- `openspec/changes/comparative-evidence-reporting-v3/design.md`（R7 正規化契約）
- `openspec/changes/comparative-evidence-reporting-v3/tasks.md`（12.R5/R6 チェック）
- `docs/Artifacts/s12_qa0001_r6r7_exec_001_0924.md`（実施記録）
- 必要なら `.agents/shared/pass0_routing.R` に短い正規化コメントのみ（挙動変更なし）

統計エンジン・Pass 0 拒否ロジック・Section 13 は変更しない。

## 4. 検証

1. `Rscript tests/test_comparative_schemas.R`
2. `Rscript tests/test_pass0_routing.R`（回帰）
3. 実 Draft-07 照合（利用可能時）と実施記録への分離記載
4. `git diff --check`

commit / push は別指示まで行わない。
