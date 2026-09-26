# 実装計画 025 — Section 13.9 QA修復（13.9.R1 / 13.9.R2）

created: 2026-09-25 09:47 (JST)
update: 2026-09-25 09:48 (JST)
author: Auto (Composer)
approval: ユーザー指示「もう一度確認して実装計画を立て、計画実行。おまかせします」を本範囲の実装承認として扱う
review: [s13_9_ledger_qa_review1_001_0925.md](s13_9_ledger_qa_review1_001_0925.md)

## 1. 目的

Independent QA Review1 HOLD を閉じる。

| ID | 指摘 | 修復 |
|---|---|---|
| **13.9.R1** | H13.9-01: 追加プロパティが拒否されず hash 対象外 | 正規フィールド厳密拘束 |
| **13.9.R2** | M13.9-01: `decided_at_jst` が任意文字列 | `YYYY-MM-DD HH:MM:SS JST` + 暦検証 |
| **13.9.R3** | 回帰ゲート | ledger / regression / OpenSpec / diff-check |

## 2. 範囲外

- 13.10–13.13（High クローズまで着手禁止）
- 署名 / WORM（レビュー非指摘）

## 3. 契約

1. `LEDGER_RECORD_FIELDS = LEDGER_HASH_FIELDS + record_sha256`。extra / missing / unnamed / duplicate names は Fail-Fast。
2. `decided_at_jst` は正規表現 `^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} JST$` かつ `as.POSIXct(..., tz="Asia/Tokyo")` の round-trip 成功。
3. schema に同 pattern を mirror。

## 4. 変更対象

- `.agents/shared/evidence_ledger.R`
- `schemas/decision-ledger-record-v1.json`
- `tests/test_evidence_ledger.R`
- tasks / QA チェック / 実行証跡

## 5. 検証

```bash
Rscript tests/test_evidence_ledger.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict
git diff --check
```
