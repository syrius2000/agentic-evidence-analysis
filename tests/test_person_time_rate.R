# Section 11 Gamma-Poisson person-time rate inference regression tests.

test_pass <- 0L
test_fail <- 0L
assert_true <- function(value, message) {
  if (isTRUE(value)) {
    cat(sprintf("[PASS] %s\n", message))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", message))
    test_fail <<- test_fail + 1L
  }
}
assert_error <- function(expr, code, message) {
  result <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
  assert_true(!is.null(result) && grepl(code, result, fixed = TRUE), message)
}

source(".agents/shared/person_time_rate.R")

cat("=== Section 11: 入力境界 ===\n")
for (bad in list(-1, 1.5, NA_real_, Inf, 2147483648)) {
  assert_error(run_person_time_rate(bad, 100, 1, 100), "INVALID_EVENT_COUNT",
               sprintf("不正なイベント数を拒否: %s", bad))
}
for (bad in list(0, -1, NA_real_, Inf)) {
  assert_error(run_person_time_rate(1, bad, 1, 100), "INVALID_EXPOSURE",
               sprintf("不正な曝露量を拒否: %s", bad))
}
assert_error(run_person_time_rate(1, 100, 1, 100, exposure_unit = "days"), "INVALID_EXPOSURE_UNIT",
             "未対応の曝露単位を拒否")
assert_error(run_person_time_rate(1, 100, 1, 100, num_draws = 9), "INVALID_NUM_DRAWS",
             "10未満のdraw数を拒否")
assert_error(run_person_time_rate(1, 100, 1, 100, seed = Inf), "INVALID_SEED",
             "非有限seedを拒否")
assert_error(run_person_time_rate(1, 100, 1, 100, level = 1), "INVALID_INTERVAL_LEVEL",
             "不正なETI水準を拒否")

cat("=== Section 11: 事後分布とcontrast ===\n")
result <- run_person_time_rate(3, 100, 1, 120, num_draws = 10000L, seed = 31L,
                               persist_raw_draws = TRUE)
ev <- result$evidence
dr <- result$draws
assert_true(identical(ev$schema_version, "comparative-rate-evidence-v1"), "率専用evidence schemaを使用")
assert_true(identical(ev$inferential_semantics, "posterior") &&
              identical(ev$incidence_rate_difference$estimate$source, "posterior_median") &&
              identical(ev$incidence_rate_ratio$interval$method, "posterior_eti"),
            "事後中央値とETIの意味を明示")
assert_true(identical(dr$person_time_metadata$gamma_parameterization, "shape_rate") &&
              isTRUE(all.equal(dr$person_time_metadata$target_shape, 3.5)) &&
              isTRUE(all.equal(dr$person_time_metadata$reference_shape, 1.5)),
            "Jeffreys事後Gammaのshape-rateを記録")
assert_true(abs(ev$target_cohort$incidence_rate$estimate$value -
                stats::qgamma(0.5, shape = 3.5, rate = 100)) < 0.003,
            "目標群の事後中央値が解析的Gamma分位点に近い")
assert_true(abs(ev$reference_cohort$incidence_rate$interval$upper -
                stats::qgamma(0.975, shape = 1.5, rate = 120)) < 0.006,
            "参照群の95% ETI上限が解析的Gamma分位点に近い")
assert_true(isTRUE(all.equal(ev$incidence_rate_difference$estimate$value,
                              unname(stats::median(dr$target_draws - dr$reference_draws)))),
            "IRDは対応するdrawの差の事後中央値")
assert_true(isTRUE(all.equal(ev$incidence_rate_ratio$estimate$value,
                              unname(stats::median(dr$target_draws / dr$reference_draws)))),
            "IRRは対応するdrawの比の事後中央値")
assert_true(isTRUE(all.equal(ev$incidence_rate_ratio$mean,
                              (3.5 / 100) * (120 / 0.5))),
            "有限なIRR理論平均は解析式から算出")
assert_true(isTRUE(all.equal(ev$incidence_rate_difference$additional_events_per_100_person_years,
                              100 * ev$incidence_rate_difference$estimate$value)),
            "人年入力のIRDを100人年当たりへ換算")

again <- run_person_time_rate(3, 100, 1, 120, num_draws = 10000L, seed = 31L,
                              persist_raw_draws = TRUE)
assert_true(identical(result$draws$target_draws, again$draws$target_draws) &&
              identical(result$draws$reference_draws, again$draws$reference_draws),
            "同一seedの率drawは決定論的に一致")
assert_true(length(dr$target_draws) == dr$num_draws && length(dr$reference_draws) == dr$num_draws,
            "永続化した両群draw配列長はnum_drawsと一致")
ephemeral <- run_person_time_rate(3, 100, 1, 120, num_draws = 100L, seed = 31L)
assert_true(identical(ephemeral$draws$draw_storage, "ephemeral") &&
              is.null(ephemeral$draws$target_draws) && is.null(ephemeral$draws$reference_draws),
            "既定ではraw drawを永続化しない")
assert_true(grepl("一定の発生率", ev$person_time$assumptions$limitations[[1L]], fixed = TRUE) &&
              grepl("反復イベント", ev$person_time$assumptions$limitations[[2L]], fixed = TRUE),
            "一定発生率と個人内反復イベント相関の限界を記録")

month <- run_person_time_rate(3, 1200, 1, 1440, exposure_unit = "person_months",
                              num_draws = 10000L, seed = 31L, persist_raw_draws = TRUE)
assert_true(identical(month$evidence$person_time$rate_unit, "events_per_person_month") &&
              isTRUE(all.equal(month$evidence$incidence_rate_difference$additional_events_per_100_person_years,
                               ev$incidence_rate_difference$additional_events_per_100_person_years)),
            "人月から100人年への換算が人年入力と一致")
many_events <- run_person_time_rate(5, 2, 3, 2, num_draws = 100L, seed = 31L)
assert_true(many_events$evidence$target_cohort$events == 5L,
            "イベント数が曝露量を超える率入力も受け付ける")

cat("=== Section 11: ゼロイベント ===\n")
zero_ref <- run_person_time_rate(2, 100, 0, 120, num_draws = 10000L, seed = 31L)
assert_true(is.null(zero_ref$evidence$incidence_rate_ratio$mean) &&
              identical(zero_ref$evidence$incidence_rate_ratio$mean_is_finite, FALSE) &&
              identical(zero_ref$evidence$incidence_rate_ratio$diagnostic, "ZERO_REFERENCE_EVENTS"),
            "参照群0件のIRR理論平均を報告しない")
assert_true(is.finite(zero_ref$evidence$incidence_rate_ratio$estimate$value) &&
              is.finite(zero_ref$evidence$incidence_rate_ratio$interval$upper),
            "参照群0件でもIRR中央値とETIは有限")
zero_both <- run_person_time_rate(0, 100, 0, 120, num_draws = 10000L, seed = 31L)
assert_true(is.finite(zero_both$evidence$incidence_rate_difference$estimate$value) &&
              is.finite(zero_both$evidence$incidence_rate_ratio$estimate$value),
            "両群0件でもIRD/IRR事後中央値は有限")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
