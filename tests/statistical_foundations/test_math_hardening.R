#!/usr/bin/env Rscript
source(".agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R")

check <- function(name, value) {
  if (!isTRUE(value)) stop(paste("FAIL:", name))
  message("PASS: ", name)
}
close <- function(x, y, atol = 1e-8, rtol = 1e-6) {
  length(x) == length(y) && all(is.finite(x)) && all(is.finite(y)) &&
    all(abs(x - y) <= atol + rtol * abs(y))
}

expected_structures <- c(
  M1 = "[A][B][C]", M2 = "[AB][C]", M3 = "[AC][B]",
  M4 = "[BC][A]", M5 = "[AB][AC]", M6 = "[AB][BC]",
  M7 = "[AC][BC]", M8 = "[AB][AC][BC]", M9 = "[ABC]"
)
expected_conditional <- c(
  M5 = "B ⟂ C | A", M6 = "A ⟂ C | B", M7 = "A ⟂ B | C"
)
check("M1〜M9生成クラス", identical(model_structures, expected_structures))
check("M5〜M7条件付き独立", identical(model_conditional_independence, expected_conditional))
expected_formulas <- c(
  M1="n ~ A + B + C",M2="n ~ A * B + C",M3="n ~ A * C + B",
  M4="n ~ B * C + A",M5="n ~ A * B + A * C",M6="n ~ A * B + B * C",
  M7="n ~ A * C + B * C",M8="n ~ (A + B + C)^2",M9="n ~ A * B * C"
)
actual_formulas <- vapply(model_formulas, function(x) paste(deparse(x), collapse=""), character(1))
check("M1〜M9 formula", identical(actual_formulas, expected_formulas))

hair <- as.data.frame(HairEyeColor, stringsAsFactors = FALSE)
names(hair) <- c("A", "B", "C", "n")
hair_fit <- fit_models(hair)
check("HairEyeColor M7 oracle", close(hair_fit$models$M7$deviance, 156.67789, atol = 1e-5) && hair_fit$models$M7$df_residual == 18L)
check("HairEyeColor M8 oracle", close(hair_fit$models$M8$deviance, 6.76125, atol = 1e-5) && hair_fit$models$M8$df_residual == 9L)
m7_m8 <- Filter(function(x) identical(x$id, "M7_to_M8"), hair_fit$comparisons)[[1]]
check("HairEyeColor M7からM8 oracle", close(m7_m8$delta_g2, 149.91664, atol = 1e-5) && m7_m8$delta_rank == 9L)
check("モデルstatus分離", all(c("computation_status", "model_fit_status", "chi_square_inference_status", "bic_approximation_status") %in% names(hair_fit$models$M7)))
check("比較status分離", all(c("chi_square_inference_status", "bic_approximation_status") %in% names(m7_m8)))

hair_cells <- cell_diagnostics(hair, hair_fit$fits, "M7")$cells
idx <- which(hair$A == "Blond" & hair$B == "Blue" & hair$C == "Female")
cell <- hair_cells[[idx]]
check("局所scoreとexact LRTを別保持", !close(cell$pearson_residual^2, cell$local_score_chisq) && !close(cell$local_score_chisq, cell$local_delta_g2))
check("d二乗/Nを保持", close(cell$signed_deviance_sq_per_n, cell$deviance_residual^2 / sum(hair$n)))
check("Pearson/sqrtNをd/sqrtNと区別", close(cell$pearson_residual_per_sqrt_n, cell$pearson_residual / sqrt(sum(hair$n))) && !close(cell$pearson_residual_per_sqrt_n, cell$signed_deviance_per_sqrt_n))
check("Stability未評価", identical(cell$stability_status, "NOT_EVALUATED"))
check("診断flagをStabilityから分離", all(c("zero_observed", "sparse_expected", "high_leverage") %in% names(cell$diagnostic_flags)))

scaled <- hair
scaled$n <- 100 * scaled$n
scaled_fit <- fit_models(scaled)
scaled_cells <- cell_diagnostics(scaled, scaled_fit$fits, "M7")$cells
invariant_fields <- c("oe_ratio", "log_oe_ratio", "pearson_residual_per_sqrt_n", "signed_deviance_per_sqrt_n", "signed_deviance_sq_per_n", "delta_g2_per_n", "leverage")
check("HairEyeColor 100倍の局所不変量", all(vapply(seq_along(hair_cells), function(i) {
  all(vapply(invariant_fields, function(field) close(hair_cells[[i]][[field]], scaled_cells[[i]][[field]]), logical(1)))
}, logical(1))))
check("HairEyeColor 100倍のG2倍率性", close(100 * hair_fit$models$M7$deviance, scaled_fit$models$M7$deviance))
check("HairEyeColor 100倍の局所G2倍率性", close(100 * cell$local_delta_g2, scaled_cells[[idx]]$local_delta_g2))

tiny <- expand.grid(A = c("a", "b"), B = c("a", "b"), C = c("a", "b"), stringsAsFactors = FALSE)
tiny$n <- c(10, 20, 30, 40, 15, 25, 35, 45)
conditional_or <- function(d) {
  z <- subset(d, C == "a")
  (z$n[z$A == "a" & z$B == "a"] * z$n[z$A == "b" & z$B == "b"]) /
    (z$n[z$A == "a" & z$B == "b"] * z$n[z$A == "b" & z$B == "a"])
}
tiny_scaled <- tiny
tiny_scaled$n <- 100 * tiny_scaled$n
check("100倍で条件付きodds ratio不変", close(conditional_or(tiny), conditional_or(tiny_scaled)))

check("metric ontology", all(c("oe_ratio", "local_score_chisq", "local_delta_g2", "leverage", "stability_status", "posterior_cell_probability", "practical_relevance_status") %in% names(metric_ontology)))
check("BIC近似を漸近量として分類", identical(metric_ontology$log_bf_bic_approx$inferential_status, "asymptotic"))
check("全表BFをprior依存として分類", identical(metric_ontology$exact_table_bf$inferential_status, "exact_prior_dependent"))
