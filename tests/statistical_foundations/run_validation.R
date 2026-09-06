#!/usr/bin/env Rscript
# リポジトリルートから実行する独立参照付き入口。
source(".agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R")
source("tests/statistical_foundations/reference_values.R")
source("tests/statistical_foundations/check_results.R")
cli_main(check_results)
