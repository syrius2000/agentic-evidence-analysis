# 実装計画 023 — Section 13.7.R1b（runtime/schema パリティ）

created: 2026-09-25 09:10 (JST)
update: 2026-09-25 09:10 (JST)
author: Auto (Composer)
approval: ユーザー指示「QA対応を実施」を本範囲の実装承認として扱う
review: [s13_7_8_precedent_qa_review2_001_0925.md](s13_7_8_precedent_qa_review2_001_0925.md)

## 1. 目的

Re-QA Review2 残余 **M13.7-02** を閉じる（13.7.R1b）。

| ID | 内容 |
|---|---|
| **13.7.R1b** | `delta.present` の boolean 強制 + `source.contrast_id`/`theme` の string\|null |
| 回帰 | feature / precedent テスト + regression |

## 2. 範囲外

- 13.8（CLOSED 維持）
- 13.9–13.13

## 3. 変更対象

- `.agents/shared/evidence_feature_extract.R`
- `tests/test_evidence_precedent.R`
- QA チェック更新 + 実行証跡
