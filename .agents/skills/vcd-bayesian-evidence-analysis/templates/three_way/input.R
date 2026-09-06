# 3元集計表の入力契約。任意のR式は評価しない。
fail <- function(message, status = "ERROR") {
  stop(structure(list(message = message, call = NULL, status = status),
                 class = c("analysis_condition", "error", "condition")))
}
scalar_text <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
keys <- function(x, allowed, label) {
  if (!is.list(x) || (length(x) && (is.null(names(x)) || anyDuplicated(names(x))))) fail(paste(label, "はキー付きオブジェクトが必要"))
  if (length(setdiff(names(x), allowed))) fail(paste(label, "の未知キー:", paste(setdiff(names(x), allowed), collapse = ",")))
}
number <- function(x, lo, hi = Inf, integer = FALSE) {
  is.numeric(x) && length(x) == 1L && is.finite(x) && x >= lo && x <= hi && (!integer || x == floor(x))
}
sha256 <- function(path) {
  if (!file.exists(path)) fail(paste("ファイルなし:", path))
  out <- system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE)
  if (!is.null(attr(out, "status"))) fail("SHA-256計算失敗")
  strsplit(out[1], " ")[[1]][1]
}
read_config <- function(path) {
  cfg <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  keys(cfg, c("schema_version", "input", "vars", "freq", "response_var", "output_dir", "run_id", "sampling", "levels", "missing_policy", "absent_cell_policy", "structural_zeros", "filters", "prior", "seed", "consultation"), "設定")
  required <- c("schema_version","input","vars","freq","output_dir","run_id","sampling","levels","missing_policy","absent_cell_policy","consultation")
  if (length(setdiff(required, names(cfg)))) fail("必須設定が不足")
  if (!identical(cfg$schema_version, "3way-foundation-v1")) fail("schema_version不一致")
  for (k in c("input", "freq", "output_dir", "run_id")) if (!scalar_text(cfg[[k]])) fail(paste(k, "は非空文字列が必要"))
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9_-]*$", cfg$run_id)) fail("run_idは英数字・_・-のみ")
  vs <- unlist(cfg$vars, use.names = FALSE)
  if (!is.character(vs) || length(vs) != 3L || anyNA(vs) || any(!nzchar(vs)) || anyDuplicated(vs) || cfg$freq %in% vs) fail("異なる3変数と度数列が必要")
  cfg$vars <- vs
  if (!is.null(cfg$response_var) && (!scalar_text(cfg$response_var) || !cfg$response_var %in% vs)) fail("response_varは3変数のいずれか")
  if (!scalar_text(cfg$missing_policy) || !cfg$missing_policy %in% c("reject", "hold")) fail("missing_policy不正")
  if (!scalar_text(cfg$absent_cell_policy) || !cfg$absent_cell_policy %in% c("reject", "sample_zero", "hold")) fail("absent_cell_policy不正")
  keys(cfg$sampling, c("unit","total_n_meaning","independence_assumption","is_scaled","scaling_factor","lineage"), "sampling")
  for (k in c("unit", "total_n_meaning", "independence_assumption")) if (!scalar_text(cfg$sampling[[k]])) fail(paste("sampling", k, "が必要"))
  if (!cfg$sampling$independence_assumption %in% c("assumed_independent","unverified","dependent_blocked")) fail("独立性設定不正")
  if (!identical(cfg$sampling$independence_assumption, "assumed_independent")) fail("標本単位の独立性が未解決", "HOLD")
  if (!is.logical(cfg$sampling$is_scaled) || length(cfg$sampling$is_scaled) != 1L || is.na(cfg$sampling$is_scaled)) fail("is_scaledは真偽値が必要")
  if (cfg$sampling$is_scaled && (!number(cfg$sampling$scaling_factor, 1) || !scalar_text(cfg$sampling$lineage))) fail("倍率と来歴が必要")
  if (length(cfg$structural_zeros)) fail("構造ゼロを含む推論は未対応", "HOLD")
  keys(cfg$levels, vs, "levels")
  if (!setequal(names(cfg$levels), vs)) fail("全3変数の水準指定が必要")
  for (v in vs) {
    lev <- unlist(cfg$levels[[v]], use.names = FALSE)
    if (!is.character(lev) || length(lev) < 2L || anyNA(lev) || any(!nzchar(lev)) || anyDuplicated(lev)) fail(paste(v, "の水準不正"))
    cfg$levels[[v]] <- lev
  }
  if (prod(lengths(cfg$levels)) > 512) fail("初期版は512セル以内。層別・次元設計を再相談", "HOLD")
  if (is.null(cfg$prior)) cfg$prior <- list(total_alpha = 1, sensitivity = c(0.1,10), draws = 20000L)
  keys(cfg$prior, c("total_alpha", "sensitivity", "draws"), "prior")
  if (!number(cfg$prior$total_alpha, .Machine$double.eps)) fail("正の総集中度が必要")
  a <- unlist(cfg$prior$sensitivity, use.names = FALSE)
  if (length(a) && (!is.numeric(a) || any(!is.finite(a) | a <= 0))) fail("事前感度設定不正")
  cfg$prior$sensitivity <- a
  if (is.null(cfg$prior$draws)) cfg$prior$draws <- 20000L
  if (!number(cfg$prior$draws, 20000, 100000, TRUE)) fail("drawsは20000〜100000の整数")
  if (is.null(cfg$seed)) cfg$seed <- 20260906L
  if (!number(cfg$seed, 0, .Machine$integer.max, TRUE)) fail("seed不正")
  keys(cfg$consultation, c("inspection", "input_sha256", "rationale"), "consultation")
  for (k in c("inspection", "input_sha256", "rationale")) if (!scalar_text(cfg$consultation[[k]])) fail(paste("Pass 0",k,"が必要"))
  if (!identical(sha256(cfg$input), cfg$consultation$input_sha256)) fail("Pass 0後に入力が変更された")
  inspection <- jsonlite::fromJSON(cfg$consultation$inspection)
  if (is.null(inspection$file) || normalizePath(inspection$file, mustWork = TRUE) != normalizePath(cfg$input, mustWork = TRUE)) fail("検分と入力が一致しない")
  if (!identical(inspection$input_sha256, cfg$consultation$input_sha256)) fail("検分の入力ハッシュ不一致。Pass 0を再実行")
  cfg
}
normalize_input <- function(cfg) {
  df <- read.csv(cfg$input, check.names = FALSE, stringsAsFactors = FALSE, colClasses = "character", na.strings = c("", "NA"))
  if (anyDuplicated(names(df)) || !all(c(cfg$vars,cfg$freq) %in% names(df))) fail("列名が不足または重複")
  raw_rows <- nrow(df)
  if (!is.null(cfg$filters)) {
    if (!is.list(cfg$filters) || !is.null(names(cfg$filters))) fail("filtersは条件オブジェクトの配列が必要")
    for (f in cfg$filters) {
      keys(f, c("column", "op", "values"), "filter")
      if (!scalar_text(f$column) || !f$column %in% names(df) || !scalar_text(f$op) || !f$op %in% c("==", "in")) fail("抽出列・演算子不正")
      val <- unlist(f$values, use.names = FALSE)
      if (!length(val) || !(is.character(val) || is.numeric(val)) || anyNA(val) || (f$op == "==" && length(val) != 1L)) fail("抽出値不正")
      df <- df[!is.na(df[[f$column]]) & df[[f$column]] %in% as.character(val), , drop = FALSE]
    }
  }
  if (!nrow(df)) fail("抽出結果は0行")
  if (anyNA(df[c(cfg$vars,cfg$freq)])) fail("変数または度数が欠測", if (cfg$missing_policy == "hold") "HOLD" else "ERROR")
  y <- suppressWarnings(as.numeric(df[[cfg$freq]]))
  if (any(!is.finite(y) | y < 0 | y != floor(y)) || !is.finite(sum(y)) || sum(y) <= 0 || sum(y) > 2^53) fail("度数は正の総和を持つ有限な非負整数、総和2^53以下が必要")
  for (v in cfg$vars) if (any(!df[[v]] %in% cfg$levels[[v]])) fail(paste("未指定水準:",v))
  norm <- data.frame(A = df[[cfg$vars[1]]], B = df[[cfg$vars[2]]], C = df[[cfg$vars[3]]], n = y)
  ag <- aggregate(n ~ A+B+C, norm, sum)
  grid <- expand.grid(setNames(cfg$levels[cfg$vars], c("A","B","C")), stringsAsFactors = FALSE)
  ag <- merge(grid, ag, by = c("A","B","C"), all.x = TRUE, sort = FALSE)
  absent <- sum(is.na(ag$n))
  if (absent && cfg$absent_cell_policy != "sample_zero") fail("未記載セルの意味が未解決", if (cfg$absent_cell_policy == "hold") "HOLD" else "ERROR")
  ag$n[is.na(ag$n)] <- 0
  # 行順は参照計算と共通の文字列順。表示水準順は設定に保存する。
  ag <- ag[do.call(order, ag[c("A","B","C")]), ]; rownames(ag) <- NULL
  for (i in 1:3) ag[[i]] <- factor(ag[[i]], levels = cfg$levels[[cfg$vars[i]]])
  list(data = ag, summary = list(input_rows = raw_rows, filtered_rows = nrow(df), duplicate_rows_aggregated = nrow(df)-nrow(unique(norm[1:3])), absent_cells_completed = absent, n_cells = nrow(ag), total_n = sum(y), zero_cells = sum(ag$n == 0), variables = cfg$vars, levels = cfg$levels, response_var = cfg$response_var, sampling = cfg$sampling))
}
