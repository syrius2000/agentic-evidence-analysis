# Focus pack: openspec-coherence

Use when the invite lists `openspec-coherence`.

## Audit criteria

1. Diffed docs/specs must not redefine presentation or statistical contracts that already passed Planning/Implementation QA unless the Change explicitly MODIFIES them.
2. Cross-check in order: `openspec/specs/<capability>/spec.md` → runtime modules → any new `docs/reference/*.md`.
3. Flag renamed diagnostic codes, column orders, default draws (`num_draws`), and parameterization (e.g. Gamma shape-rate vs scale) that disagree across layers.
4. `openspec validate` relevant capabilities when the environment allows; if not run, mark `未検証` in the finding or summary (do not invent PASS).

## Typical surfaces

- `comparative-evidence-reporting` 12-column hierarchy vs dashboard renderer
- `comparative-design-inference` matched-set / IPTW / person-time contracts
- Schema names (`comparative-evidence-v1`, batch-v1) vs docs wording
