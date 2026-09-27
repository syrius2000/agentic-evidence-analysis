# Focus pack: provenance-plans

Use when the invite lists `provenance-plans`.

## Audit criteria

1. **Plan ID immutability:** `implementation_plan_NNN_*.md` must not be overwritten by a different case. New work uses NNN = max existing + 1 under `docs/Artifacts/plans/` (legacy flat plans remain readable).
2. **Source-of-truth file lists** in plans must name modules that exist in the reviewed tree (no hallucinated paths).
3. Portal docs (`AGENTS.md`, root `README.md`, `docs/reference/README.md`) must not contradict newly added “P0 satisfied / missing” status within the same reviewed commit.
4. Repair surface for provenance breaks is usually `plan` or `docs`, not silent history rewrite.

## Placement contract

See [`docs/Artifacts/README.md`](../../../../docs/Artifacts/README.md): no new Markdown at Artifacts root; no flat `independent_qa_*` for new independent QA.
