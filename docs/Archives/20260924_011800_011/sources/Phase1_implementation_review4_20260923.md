# Phase 1 Implementation Repair — Independent Review #4

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Reviewed commit:** `fc85e040aed5888e6d2c83d17d4160e996b60e7d`  
**Baseline:** `8174a47003c133ba7bd16d86f9130253fd10c28e`  
**Intermediate repair commit:** `7fabe58bb5709349aca00be1d76afdedfbe30750`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Independent static implementation/contract review using GitHub connector  
**Verdict:** **PASS — Phase 1 implementation is ready to proceed, with documentation/evidence cleanup noted below**

---

## 1. Executive Summary

The commit `fc85e040...` closes the only substantive High finding left by Independent Review #3.

The previous implementation introduced a real Draft-7 validation path through Python packages:

```text
jsonschema
referencing
```

That solved schema validation functionally but created an undeclared cross-language dependency in the canonical regression suite.

The present commit removes that dependency completely:

```text
tests/validate_comparative_schema.py
```

is deleted, and `tests/test_comparative_schemas.R` now contains a self-contained validator implemented with the already-required R package:

```text
jsonlite
```

For the **actual three comparative schemas in this repository**, the R validator implements every validation keyword currently used by those schemas:

```text
$ref
type
required
properties
enum
minimum
items
additionalProperties
not(required)
```

The schemas do not currently use unsupported validation keywords.

Therefore the Python dependency/reproducibility issue identified in Review #3 is resolved without weakening the current schema regression contract.

No regression was found in the B-01/B-02 or H-01–H-07 repairs from the previous commit.

---

# 2. Commit Scope

Comparison:

```text
7fabe58bb5709349aca00be1d76afdedfbe30750
    ↓
fc85e040aed5888e6d2c83d17d4160e996b60e7d
```

contains only:

```text
tests/test_comparative_schemas.R
tests/validate_comparative_schema.py
```

Changes:

- Python validator removed entirely.
- Pure-R schema validator added to `test_comparative_schemas.R`.
- No production statistical code changed.
- No run-control code changed.
- No Safety adapter code changed.
- No OpenSpec statistical contract changed.

This is appropriately narrow for the final dependency repair.

---

# 3. Review #3 Finding N-01 — Python schema-validator dependency

## Previous finding

The canonical regression suite transitively required:

```text
Python
jsonschema
referencing
```

but those dependencies were not part of the repository's deterministic environment contract.

## Current status

\[
\boxed{\text{RESOLVED}}
\]

`tests/validate_comparative_schema.py` has been removed.

`tests/test_comparative_schemas.R` contains no references to:

```text
python
jsonschema
referencing
validate_comparative_schema.py
```

Schema validation is now executed entirely inside R using `jsonlite`.

This restores the intended single-environment/offline regression model.

---

# 4. Does the Pure-R Validator Actually Cover the Current Schemas?

## Verdict

\[
\boxed{\text{YES, for the current schema set}}
\]

The validator implements:

### `$ref`

```r
if (!is.null(sc[["$ref"]])) {
  ref_sc <- load_schema(sc[["$ref"]])
  check_node(val, ref_sc, path)
}
```

This is sufficient for the current reference:

```json
"$ref": "comparative-evidence-v1.json#"
```

because all current references target the root of another local schema.

### `type`

It supports:

```text
object
array
string
number
integer
boolean
null
```

including union types such as:

```json
"type": ["number", "null"]
```

### `required`

Required object fields are checked recursively.

### `properties`

Known object members are recursively checked.

### `enum`

Enumerated string/value contracts are checked.

### `minimum`

Used by `num_draws >= 1`.

### `items`

Array element schemas are recursively checked.

### `additionalProperties`

This is especially important for:

```text
comparative-evidence-batch-v1
```

where arbitrary contrast IDs are validated against:

```json
"$ref": "comparative-evidence-v1.json#"
```

### `not`

The current use:

```json
"not": {
  "required": ["robust"]
}
```

is explicitly enforced.

---

# 5. Schema Keyword Audit

A recursive audit of all three current schemas found no validation keyword outside the implemented subset.

## `comparative-draws-v1.json`

Relevant validation vocabulary:

```text
type
required
properties
enum
minimum
items
```

All supported.

## `comparative-evidence-v1.json`

Relevant validation vocabulary:

```text
type
required
properties
enum
items
not
```

All supported for the forms currently used.

## `comparative-evidence-batch-v1.json`

Relevant validation vocabulary:

```text
type
required
properties
additionalProperties
$ref
enum
```

All supported.

Therefore replacing the Python validator does **not** currently reduce effective validation coverage.

---

# 6. Important Terminology Qualification

The test currently prints:

```text
Offline JSON Schema validation (Pure R jsonlite)
```

and assertion messages include:

```text
validates against Draft 7 schema (pure R)
```

This is acceptable if interpreted as:

> validates these repository Draft-7 schemas using the subset of Draft-7 keywords they currently employ.

However, the custom function is **not a general-purpose complete Draft 7 implementation**.

For example, it does not claim to implement every possible Draft-7 feature such as:

```text
oneOf
anyOf
allOf
if/then/else
patternProperties
dependencies
contains
minItems
maxItems
pattern
format
exclusiveMinimum
```

None of these are presently used.

### Recommendation

Rename the helper/comment slightly more precisely, e.g.:

```text
validate_payload_against_supported_draft7_subset()
```

or document:

```text
Supports the Draft-7 keyword subset used by comparative-*.json.
```

This is a documentation-hardening recommendation, not a Phase 1 blocker.

---

# 7. Regression of Prior Repairs

Because `fc85e040...` modifies no production code, the previous repairs remain intact.

## B-01 `%||%`

**RESOLVED / no regression**

Standalone `pass0_routing.R` and `safety_adapter.R` retain explicit null checks.

## B-02 run lifecycle

**RESOLVED / no regression**

`vcd-categorical-reporting` remains registered in:

- `read_run_control()`
- manifest roles
- canonical primary result handling

and the reporter retains:

```text
artifact creation
→ results manifest
→ run_meta with manifest hash
→ pass1=completed
→ manifest verification
```

## H-01 input hashing

**RESOLVED / no regression**

In-memory data SHA-256 contract remains recorded.

## H-02 Safety denominators

**RESOLVED / no regression**

Per-study named denominator lists and pooled `Reduce('+', ...)` remain intact.

## H-04 binary `robust`

**RESOLVED / no regression**

The schema still rejects the legacy `robust` field.

The test continues to verify this using the new R validator.

## H-05 Task 7.4

**RESOLVED / no regression**

Departmental policy mode remains intentionally incomplete.

## H-06 duplicates

**RESOLVED / no regression**

`DUPLICATE_THEME_GROUP` fail-fast remains intact.

## H-07 run scope

**RESOLVED / no regression**

`SHARED_RUN_SCOPE_UNAVAILABLE` fail-fast remains mandatory.

## M-01 neutral rendering

**RESOLVED / no regression**

`practical_neutral` remains neutral gray.

## M-05 delta grid

**RESOLVED / no regression**

`delta_thresholds` remains persisted in run metadata and batch evidence.

---

# 8. One Documentation Inconsistency Remains

## Finding D-01 — MEDIUM documentation drift

`docs/Artifacts/implementation_plan_002_0923.md` still states that schema validation uses:

```text
Python jsonschema
referencing
```

and records versions:

```text
jsonschema 4.26.0
referencing 0.37.0
```

That statement is now obsolete after `fc85e040...`.

### Recommended correction

Replace that paragraph with something like:

```text
JSON Schema verification is implemented as a repository-local,
pure-R validator using jsonlite. It supports the Draft-7 keyword
subset currently used by comparative-draws-v1,
comparative-evidence-v1, and comparative-evidence-batch-v1.
No Python runtime or Python package dependency is required.
```

This should be fixed for audit trail consistency.

It does **not** invalidate the implementation.

---

# 9. Independent Execution Evidence

GitHub currently reports for:

```text
fc85e040aed5888e6d2c83d17d4160e996b60e7d
```

- no associated workflow runs;
- no combined commit statuses.

The implementation plan records local results:

```text
38/38 regression tests PASS
OpenSpec strict validation valid
git diff --check PASS
```

but this review did not independently execute them.

Therefore distinguish:

### Implementation/contract review

\[
\boxed{\text{PASS}}
\]

### Independent executable CI evidence

\[
\boxed{\text{NOT YET ATTACHED}}
\]

This is evidence provenance, not a code defect.

---

# 10. Phase 1 Gate

The substantive sequence is now:

```text
e9806f3  initial Phase 1
  ↓
8174a47  first repair
  ↓
7fabe58  Review #2 blockers/high findings repaired
  ↓
fc85e04  Python dependency removed
```

At `fc85e04`, the original Phase 1 issues and the Review #3 dependency issue are closed.

## Final implementation verdict

\[
\boxed{\text{PHASE 1 PASS}}
\]

No further statistical or architectural repair is required before Phase 2.

---

# 11. Recommended Close-Out Before Phase 2

Only two lightweight close-out actions remain:

1. synchronize `implementation_plan_002_0923.md` with the new pure-R validator;
2. preserve an independently reproducible execution record when convenient:
   - CI run, or
   - committed verification log.

Neither requires reopening Phase 1 statistical implementation.

After documentation synchronization, the Change is suitable for Owner final adjudication and Phase 2 transition.

---

# 12. Final Assessment

The Python-removal change is a good design correction.

It improves the repository in three ways simultaneously:

1. **offline determinism** — no additional language runtime package dependency;
2. **test portability** — canonical regression remains R-centered;
3. **dependency governance** — no hidden Python environment prerequisite.

The custom validator should be understood as a **purpose-built validator for the Draft-7 subset used by the comparative schemas**, rather than a universal JSON Schema implementation.

Within that boundary, it is sufficient and appropriately tested.

**Final: PASS / READY FOR PHASE 2 after minor documentation synchronization.**
