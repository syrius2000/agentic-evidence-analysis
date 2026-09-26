# Section 13.9 — Independent QA Review 1

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `feat/comparative-evidence-reporting-v3`
- Baseline: `0221b9b990299b5a62768e89ab45575b8d6a5cc9`
- Reviewed commit: `98cf82d24544e1c28c059032f78d3529d6320cde`
- Scope: Section 13.9 only — append-only tamper-evident decision ledger
- Out of scope: 13.10–13.13
- Review date: 2026-09-25 JST
- Reviewer: GPT-5.6 Sol

## Decision

```text
Section 13.9:
HOLD

Blocker: 0
High:    1
Medium:  1
```

Do not start 13.10–13.13 until the High finding is closed.

## 1. Commit / Scope Verification

The requested range is exactly one commit:

```text
0221b9b990299b5a62768e89ab45575b8d6a5cc9
    ↓
98cf82d24544e1c28c059032f78d3529d6320cde
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = 0221b9b...
```

No commit-bound GitHub status or workflow run was present for the reviewed commit.

Implementer execution claims:

```text
tests/test_evidence_ledger.R : 15 PASS / 0 FAIL
full regression             : 47/47 PASS
OpenSpec strict             : valid
git diff --check            : clean
```

These remain implementer claims; R was not independently rerun in the reviewer runtime.

## 2. Positive Findings

The core ledger design is structurally sound.

- `record_sha256` is computed from canonical payload fields excluding itself.
- Genesis requires `previous_record_sha256 = null`.
- Later records link to the prior `record_sha256`.
- `verify_decision_ledger()` verifies self-hash, chain linkage, genesis semantics, duplicate IDs, and empty-ledger rejection.
- `append_decision_ledger_record()` verifies the existing chain before appending and does not rewrite prior list elements.

Current tests correctly demonstrate payload tamper detection, broken-link detection, duplicate record IDs, invalid evidence SHA, and append growth without rewriting prior hashes.

## 3. H13.9-01 — Extra Properties Are Neither Rejected nor Hashed

Severity: HIGH
Gate: Blocking Section 13.9

The JSON schema declares:

```json
"additionalProperties": false
```

but `assert_decision_ledger_record()` does not enforce an exact field set.

It reads known fields, then builds a new normalized object containing only canonical fields. Any unknown field in the original record is silently discarded.

The hash function likewise hashes only `LEDGER_HASH_FIELDS`.

Therefore this mutation:

```r
r <- ledger[[1]]
r$override_note <- "modified after approval"
```

does not change any field in `LEDGER_HASH_FIELDS`, so the stored `record_sha256` remains valid and runtime verification can still succeed.

Draft-07 would reject the same record because `additionalProperties=false`.

This violates both runtime/schema parity and the tamper-evident ledger boundary: a persisted ledger record can be modified by adding an unhashed field without detection.

### Required repair — 13.9.R1

Require the exact canonical field set at runtime:

```r
LEDGER_RECORD_FIELDS <- c(
  LEDGER_HASH_FIELDS,
  "record_sha256"
)

missing <- setdiff(LEDGER_RECORD_FIELDS, names(record))
extra   <- setdiff(names(record), LEDGER_RECORD_FIELDS)

if (length(missing) > 0L || length(extra) > 0L) {
  stop("[INVALID_LEDGER_RECORD] ...")
}
```

Also reject duplicate field names and unnamed fields.

Required tests:

```text
valid record + unknown field -> runtime reject
valid record + unknown field -> Draft-07 reject
missing canonical field      -> runtime reject
duplicate/ambiguous names    -> runtime reject
```

Acceptance criterion:

```text
Any ledger-record mutation must either:
1. alter a hashed canonical field and cause hash mismatch, or
2. make the record structurally invalid.

No unhashed mutable extension surface may remain.
```

## 4. M13.9-01 — `decided_at_jst` Is Only a Non-Empty String

Severity: MEDIUM
Gate: Repair with H13.9-01

The OpenSpec requirement says the ledger captures a JST timestamp.

The implementation generates a good default:

```r
format(Sys.time(), "%Y-%m-%d %H:%M:%S JST", tz = "Asia/Tokyo")
```

but validation only checks that the value is a non-empty string, and the schema only specifies `minLength: 1`.

So values such as:

```text
"UTC"
"yesterday"
"banana"
"2026-09-25 00:20:00 UTC"
```

are accepted as `decided_at_jst`.

### Required repair — 13.9.R2

Define one canonical timestamp format, e.g.:

```text
YYYY-MM-DD HH:MM:SS JST
```

Add runtime format validation and mirror it in the JSON schema with `pattern`.

Prefer parse/round-trip validation as well so impossible dates are rejected.

Required tests:

```text
canonical JST timestamp -> accept
UTC suffix              -> reject
missing JST suffix      -> reject
malformed date          -> reject
```

## 5. Cryptographic Scope Note

Not raised as a finding:

A plain SHA-256 hash chain is only tamper-evident relative to a trusted copy or trusted anchor. An actor able to rewrite the entire ledger and recompute all later hashes can create a new internally valid chain.

That is a general hash-chain limitation and is outside the current OpenSpec, which asks for SHA-256 chain integrity rather than signatures or WORM storage.

## 6. Repair Tasks

### 13.9.R1 — Enforce Exact Ledger Record Shape

Priority: P0
Severity: High

- [x] require exact canonical field set;
- [x] reject additional properties;
- [x] reject missing fields before hash verification;
- [x] reject duplicate/unnamed fields;
- [x] add runtime + Draft-07 parity negatives;
- [x] verify extra-field mutation cannot pass chain verification.

### 13.9.R2 — Enforce Canonical JST Timestamp

Priority: P1
Severity: Medium

- [x] define canonical JST timestamp format;
- [x] validate at runtime;
- [x] mirror with schema `pattern`;
- [x] add positive/negative timestamp fixtures.

### 13.9.R3 — Regression Gate

Run and record:

```bash
Rscript tests/test_evidence_ledger.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict
git diff --check
```

## 7. Final Gate

Current (post implementer 13.9.R1/R2; independent Re-QA pending):

```text
Section 13.9:
REPAIR COMPLETE (implementer) — awaiting independent Re-QA

Blocker 0
High    0 open (H13.9-01 repaired)
Medium  0 open (M13.9-01 repaired)
```

Expected after independent Re-QA:

```text
13.9.R1: CLOSED
13.9.R2: CLOSED

Blocker 0
High    0
Medium  0

Section 13.9:
PASS / ACCEPT
```

## QA comment

## Section 13.9 独立QA結果

**Baseline:** `0221b9b990299b5a62768e89ab45575b8d6a5cc9`
**Reviewed:** `98cf82d24544e1c28c059032f78d3529d6320cde`
**Scope:** 13.9 ledger のみ

### 判定

- **Section 13.9: HOLD**
- **Blocker 0 / High 1 / Medium 1**
- **13.10–13.13 はまだ開始しない**判定です。

hash-chain 本体は良好です。genesis、previous hash、record self-hash、duplicate ID、payload tamper、broken link の Fail-Fast は妥当です。

### High — H13.9-01

最大の問題は、schema が

```json
"additionalProperties": false
```

なのに、runtime verifier が **追加フィールドを拒否せず、しかも hash 対象にも含めていない**ことです。

例えば valid record に、

```r
record$override_note <- "modified after approval"
```

を追加しても、`LEDGER_HASH_FIELDS` は変わらないため `record_sha256` はそのまま一致し、runtime の chain verification が通り得ます。

つまり **ledger record が変更されても検知されない mutation surface** が残っています。これは tamper-evident 契約に直接反するため High です。

修復は、runtime で canonical field set を厳密に固定し、extra / missing / duplicate / unnamed fields を拒否すれば閉じられます。

### Medium — M13.9-01

`decided_at_jst` は現状 **non-empty string** であれば何でも通ります。

```text
banana
UTC
2026-09-25 00:20:00 UTC
```

も受理可能です。

OpenSpec は JST timestamp を要求しているため、例えば

```text
YYYY-MM-DD HH:MM:SS JST
```

に固定して runtime + JSON Schema の両方で検証するのがよいです。

実装者の `15 PASS / 0 FAIL`, `47/47 PASS` は今回も claim 扱いです。

修復 Tasks **13.9.R1 / R2 / R3** をまとめました。
