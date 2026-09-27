# machine_schema — `03_machine.json`

Required schema name: `blind-qa-cycle-v1`

```json
{
  "schema": "blind-qa-cycle-v1",
  "topic": "string",
  "cycle": 1,
  "baseline": "<full-sha>",
  "reviewed": "<full-sha>",
  "audience": "cloud",
  "remote_visibility": "pushed",
  "gate": "HOLD",
  "focus_packs": ["math-definitions"],
  "findings": [
    {
      "id": "QA-MATH-H01",
      "severity": "High",
      "status": "OPEN",
      "title": "short title",
      "repair_surface": "docs"
    }
  ],
  "tasks": [
    {
      "id": "T-01",
      "closes": "QA-MATH-H01",
      "done": false,
      "verify": "how to verify"
    }
  ]
}
```

## Field rules

| Field | Rule |
| :--- | :--- |
| `audience` | `local` \| `cloud` (required on new cycles) |
| `remote_visibility` | `local-only` \| `pushed` (must match audience) |
| `gate` | `PASS` \| `HOLD` \| `FAIL` \| `INCONCLUSIVE` only |
| `severity` | `High` \| `Medium` \| `Low` \| `PASS` (notes) |
| `status` | `OPEN` \| `CLOSED` |
| `repair_surface` | `docs` \| `code` \| `spec` \| `plan` |
| `closes` | Must equal a `findings[].id` |
| SHAs | Full 40-char preferred; never ambiguous short-only without resolve |

Additional keys are allowed; do not remove required keys.
