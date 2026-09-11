#!/usr/bin/env Rscript
source(".agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/report_view_model.R")
result <- list(
  status = "PARTIAL_HOLD",
  input_summary = list(variables = list("Class", "Sex", "Survived"), total_n = 10,
    n_cells = 4, levels = list(Class = list("1st"), Sex = list("F"), Survived = list("Yes"))),
  models = list(M1 = list(id = "M1", structure = "[A][B][C]", formula = "n ~ A+B+C",
    status = "REGULAR", status_reasons = list(), warnings = list(), deviance = 1, df_residual = 2,
    bic_multinomial_n = 3, inference = list(log_p_value = -1, reason = "asymptotic")),
    M2 = list(id = "M2", structure = "[AB][C]", formula = "n ~ A*B+C", status = "HOLD",
      status_reasons = list("boundary"), warnings = list(), deviance = NULL, df_residual = 1,
      bic_multinomial_n = NULL, inference = list(log_p_value = NULL, reason = "hold"))),
  comparisons = list(), cells = list(), posterior = list(), decisions = list(), provenance = list()
)
vm <- build_report_view_model(result)
stopifnot(vm$status_class == "hold", vm$model_hold_count == 1L, vm$lowest_bic_id == "M1")
stopifnot(vm$factors[[1]]$symbol == "A", vm$factors[[1]]$name == "Class")
stopifnot(report_fmt(NULL) == "保留／未算出")
