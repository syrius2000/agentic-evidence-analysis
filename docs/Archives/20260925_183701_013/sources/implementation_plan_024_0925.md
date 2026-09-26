# 実装計画 024 — Section 13.9（Append-only Tamper-Evident Decision Ledger）

created: 2026-09-25 09:18 (JST)
update: 2026-09-25 09:18 (JST)
author: Auto (Composer)
approval: ユーザー指示「13.9 計画作成して実装」を本範囲の実装承認として扱う

## 1. 目的

OpenSpec 13.9 / Evidence-Decision Consistency の **append-only, tamper-evident decision ledger** をスキーマ＋ランタイムで導入する。

## 2. 範囲

| ID | 内容 | 本計画 |
|---|---|---|
| **13.9** | ledger schema + 連鎖ハッシュ検証 + append API | **実施** |
| 13.10–13.13 | discordance / wording / trajectory / bootstrap | **含めない** |

## 3. 契約

1. レコードは `decision-ledger-record-v1`。必須:
   - `record_id`
   - `previous_record_sha256`（genesis のみ `null`）
   - `evidence_profile_sha256`（64 hex）
   - `decision_state`
   - `reviewer_justification_md`
   - `actor_id`
   - `decided_at_jst`（JST 文字列）
   - `record_sha256`（上記 payload の SHA-256）
2. genesis: `previous_record_sha256 = null`。後続は直前 `record_sha256` を参照。
3. `append_decision_ledger_record()` は既存レコードを書き換えず末尾追加のみ。
4. `verify_decision_ledger()` は連鎖整合と各 `record_sha256` 再計算を検証。破壊時は Fail-Fast。
5. 規制自動判定は行わない（記録のみ）。

## 4. 変更対象

- `schemas/decision-ledger-record-v1.json`（新規）
- `.agents/shared/evidence_ledger.R`（新規）
- `tests/test_evidence_ledger.R`（新規）+ regression 登録
- SKILL / tasks / 実行証跡

## 5. 検証

1. `Rscript tests/test_evidence_ledger.R`
2. `Rscript tests/run_regression_suite.R`
3. `openspec validate comparative-evidence-reporting-v3 --strict`
4. `git diff --check`
