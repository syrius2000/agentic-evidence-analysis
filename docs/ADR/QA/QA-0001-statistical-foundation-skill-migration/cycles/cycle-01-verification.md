---
case_id: QA-0001
cycle: 1
action: reviewer-verification
performed_by:
  agent_id: "cursor-reviewer"
  role: reviewer
  tool: cursor
completed_at: "2026-09-06T23:16:52+09:00"
reviewed_revision: "c0ecbc16057a66c61fcf1e4aeb0b4b207eb08480"
head_revision: "d12daeba1f258fdb4de04255899087f152919edb"
outcome: partially-fixed
next_cycle_required: true
---

# Reviewer Verification — Cycle 1

## Revision verified

Implementation fix: `c0ecbc16057a66c61fcf1e4aeb0b4b207eb08480`  
QA-record commit also present: `d12daeba1f258fdb4de04255899087f152919edb`

Author claims were not treated as evidence. Runtime and code inspection were repeated.

## Finding verification

### QA-0001-F01

Result: `fixed-and-verified`

Evidence: local `executive_summary.md` / `dashboard.html` match JSON for 3rd Male No (`log_oe=0.1157`, `T=16.6576`, `h=0.6603`) and 2nd Female Yes (`T=311.1194`). Report 4.1 uses the same cells.

Residual risk: Pass 2/3 binaries remain gitignored.

### QA-0001-F02

Result: `fixed-and-verified`

Evidence: generator no longer computes `$r^2-\log N$`; SKILL CLI flags removed; 12 tests in `tests/legacy_quarantine/`; report inventories the quarantine.

Residual risk: historical fixtures, `vcd-pass0-consultation`, Archives, and the analysis_config schema still mention old keys (schema leftover tracked as F06).

### QA-0001-F03

Result: `fixed-and-verified`

Evidence: independent `Rscript tests/test_vcd_bayesian_help.R` and `tests/test_vcd_bayesian_run_id.R` exit 0. Report §5 no longer claims an unbounded all-pass.

Residual risk: author-response overclaimed `--model_family` / `--min_freq` / `--leverage_threshold`; those flags are absent from `analysis.R`. The updated help test does not require them.

### QA-0001-F04

Result: `partially-fixed`

Evidence: `pass1_compute.R` now uses `lev >= 0.80`.

Remaining: documented Stability formula still omits `y==0` (code quarantines zeros); no fixture crosses `h=0.80` (Titanic max `h=0.6927`).

### QA-0001-F05

Result: `fixed-and-verified`

Evidence: dashboard glossary and `docs/reference/loglinear_models_bic.md` use $\mathrm{BIC}=-2\ln L+p\ln N$. `stats_bayesian.md` is archived.

### QA-0001-F06

Result: `partially-fixed`

Evidence: SKILL.md options table no longer lists `--threshold_k` / `--ebic_*` / `--arm_*`.

Remaining: `config_validation.R` and `references/analysis_config.schema.json` still allow those keys. Requested schema cleanup is incomplete.

### QA-0001-F07

Result: `fixed-and-verified`

Evidence: stub on Titanic JSON prints `N=2,201`, `Class × Sex × Survived`, `V=0.5178`. Existing stub test still uses the old top-level schema and passes via fallbacks.

### QA-0001-F08

Result: `fixed-and-verified`

Evidence: 4-way Titanic run stops with a Japanese error stating 2/3-way only (`指定変数数: 4`). SKILL example uses three vars.

### QA-0001-F09

Result: `fixed-and-verified`

Evidence: report note 1 records `0.5178` vs `0.5208` and withdraws strict invariance.

### QA-0001-F10

Result: `fixed-and-verified`

Evidence: `log_p` column and Top-K caption/sort text use $|\log(O/E)|$.

Residual risk: full-cell DT still default-sorts by Score. Author-response called `log_p` `-\log_{10}(P)`; engine `log_p` is $\ln p$.

## Cycle outcome

- High: 3 resolved
- Medium: 5 verified, 2 partially-fixed (F04, F06)
- Next: Cycle 2 author-response for F04 and F06
- Case not closable
