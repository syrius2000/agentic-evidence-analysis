# Production-report validation. Keep this module free of presentation logic.
sha256_file <- function(path) {
  line <- system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE)[1]
  strsplit(line, " ", fixed = TRUE)[[1]][1]
}

resolve_json_pointer <- function(document, pointer) {
  value <- document
  keys <- strsplit(pointer, "/", fixed = TRUE)[[1]][-1]
  for (key in keys) {
    key <- gsub("~1", "/", gsub("~0", "~", key, fixed = TRUE), fixed = TRUE)
    value <- if (is.null(names(value))) value[[as.integer(key) + 1L]] else value[[key]]
  }
  value
}

validate_report_artifacts <- function(run_dir) {
  result_path <- file.path(run_dir, "evidence_results.json")
  if (!file.exists(result_path)) stop("evidence_results.json がありません")
  result <- jsonlite::fromJSON(result_path, simplifyVector = FALSE)
  if (!identical(result$schema_version, "three-way-results-v1") ||
      !result$status %in% c("COMPUTED", "PARTIAL_HOLD")) {
    stop("未計算または検証不合格の結果")
  }
  required <- c("executive_summary.md", "quality_check.md", "narrative_claims.json")
  for (name in required) if (!file.exists(file.path(run_dir, name))) stop(paste("Pass 2/2.5不足:", name))
  claims <- jsonlite::fromJSON(file.path(run_dir, "narrative_claims.json"), simplifyVector = FALSE)
  hash <- sha256_file(result_path)
  if (!identical(claims$result_sha256, hash) || !identical(claims$status, "REVIEWED")) {
    stop("考察対象ハッシュ・レビュー状態不一致")
  }
  if (!length(claims$claims)) stop("数値根拠が必要")
  for (claim in claims$claims) {
    value <- resolve_json_pointer(result, claim$pointer)
    if (!is.numeric(value) || length(value) != 1L || !is.numeric(claim$value) ||
        abs(value - claim$value) > 1e-8 + 1e-6 * abs(value)) {
      stop(paste("考察の数値不一致:", claim$pointer))
    }
  }
  list(result = result, result_sha256 = hash, claims = claims)
}
