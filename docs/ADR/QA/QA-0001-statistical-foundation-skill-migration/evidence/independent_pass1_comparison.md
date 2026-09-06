# Independent Pass 1 comparison (reviewer)

created: 2026-09-06 22:45 (JST)
update: 2026-09-06 22:45 (JST)
author: Cursor (Grok 4.6)

Classification: `CONFIRMED` unless noted.

## Engine vs validation

| Quantity | Validation report | Independent 1x | Class |
|---|---|---|---|
| M1 explicit BIC | 1,160.18 | 1160.1817 | CONFIRMED |
| 1st Male No h_ii | 0.591 | 0.5913 | CONFIRMED |
| 1st Male No T^score | 42.80 | 42.8217 | CONFIRMED |
| JSON old keys | must be absent | Evidence_Score/Intensity_Level absent | CONFIRMED |

## 1x vs 100x (independent)

| Axis | 1x | 100x | Class |
|---|---|---|---|
| log(O/E) 1st Female Yes | +1.8389 | +1.8389 | CONFIRMED identical |
| log(O/E) Crew Female No | -3.7529 | -3.7529 | CONFIRMED identical |
| T 1st Female Yes | 719.1598 | 71915.9789 | CONFIRMED ~100x |
| leverage 1st Female Yes | 0.1278 | 0.1278 | CONFIRMED identical |
| Cramér's V | 0.5178 | 0.5208 | CONFLICT with Plan 5.3 exact match |
| best model | M9 | M9 | CONFIRMED |

## Pass 2 vs Pass 1 JSON (author local artifacts)

| Cell | JSON (Pass 1) | executive_summary.md | Class |
|---|---|---|---|
| 3rd Male No log(O/E) | 0.1157 | +0.7672 | CONFLICT |
| 3rd Male No T | 16.6576 | 327.91 | CONFLICT |
| 3rd Male No h | 0.6603 | 0.1874 | CONFLICT |
| 2nd Female Yes T | 311.1194 | 328.79 | CONFLICT |

## Other executed checks

- `pass2_stub.R`: overview N=NULL / dimensions empty; Top-K 4-axis lines present. `FAILED` vs Plan 2.7 completeness.
- 4-way `examples/titanic.csv`: `dplyr::arrange(bic)` error. `FAILED`.
- `tests/test_vcd_bayesian_help.R`: FAIL (`--threshold_k` absent).
