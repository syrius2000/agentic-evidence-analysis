# Evidence

Store small reproducible evidence or references here. Do not store secrets.

## Baseline (git)

- HEAD: `3d5fb36d1ab02210a721b10fe0c8b56b9a987b09`
- Reviewer independent Pass 1 commands (2026-09-06 JST):

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --input tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv \
  --vars Class,Sex,Survived --freq Freq --response_var Survived \
  --output_dir /tmp/qa_sf_mig_1x --run-id qa_titanic_1x

Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --input tests/fixtures/statistical_foundations/titanic_scaled_100x_3way.csv \
  --vars Class,Sex,Survived --freq Freq --response_var Survived \
  --output_dir /tmp/qa_sf_mig_100x --run-id qa_titanic_100x

Rscript tests/test_vcd_bayesian_help.R   # FAIL: --threshold_k missing from --help
```

## Author Pass 2/3 artifacts (gitignore, local only)

- `skill_out/titanic_std_v2/run_run_std_v2/`
- `skill_out/titanic_100x_v2/run_run_100x_v2/`

These are not in git. Cell-level JSON vs summary mismatch is recorded in `independent_pass1_comparison.md`.
