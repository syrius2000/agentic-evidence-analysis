# Smoke tests: base R + datasets only (no vcd/gt required for CI).
# Run: Rscript tests/test_vcd_categorical_smoke.R

stopifnot(getRversion() >= "4.0.0")

suppressPackageStartupMessages({
  if (!base::requireNamespace("pacman", quietly = TRUE)) {
    utils::install.packages("pacman", repos = "https://cloud.r-project.org")
  }
  pacman::p_load(datasets)
})

tab2 <- margin.table(Titanic, c(1L, 4L))
ct <- suppressWarnings(chisq.test(tab2))
stopifnot(dim(ct$residuals) == dim(tab2))
stopifnot(length(ct$residuals) == length(tab2))

d3 <- as.data.frame(HairEyeColor)
fit <- glm(Freq ~ Hair * Eye * Sex, family = poisson, data = d3)
stopifnot(isTRUE(fit$converged))

m0 <- glm(Freq ~ Hair + Eye + Sex, family = poisson, data = d3)
m1 <- glm(Freq ~ (Hair + Eye + Sex)^2, family = poisson, data = d3)
m2 <- glm(Freq ~ Hair * Eye * Sex, family = poisson, data = d3)
a <- anova(m0, m1, m2, test = "Chisq")
stopifnot(nrow(a) >= 3L)

message("OK: vcd_categorical smoke tests passed.")
