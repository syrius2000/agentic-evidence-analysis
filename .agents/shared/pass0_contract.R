# Pass 0 成果物と Pass 1 設定の由来を検証する共通契約。

PASS0_CONTRACT_VERSION <- "1.0"

pass0_sha256_file <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    stop("[ERROR] ハッシュ対象ファイルが存在しません: ", path, call. = FALSE)
  }
  if (exists("sha256_file", mode = "function")) {
    return(sha256_file(path))
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("[ERROR] Pass 0 由来検証には digest パッケージが必要です。", call. = FALSE)
  }
  digest::digest(file = path, algo = "sha256")
}

pass0_resolve_path <- function(path, config_path = NULL, repo_root = getwd()) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(trimws(path))) {
    return(NULL)
  }
  candidates <- path
  if (!is.null(config_path) && nzchar(config_path)) {
    candidates <- c(candidates, file.path(dirname(normalizePath(config_path, winslash = "/", mustWork = FALSE)), path))
  }
  if (!is.null(repo_root) && nzchar(repo_root)) {
    candidates <- c(candidates, file.path(repo_root, path))
  }
  for (candidate in unique(candidates)) {
    if (file.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  NULL
}

pass0_is_sha256 <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && grepl("^[0-9a-f]{64}$", value)
}

pass0_scalar_string <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && nzchar(trimws(value))
}

validate_pass0_provenance <- function(config_data, config_path, expected_skill, repo_root = getwd()) {
  if (!is.list(config_data) || is.data.frame(config_data)) {
    stop("[ERROR] analysis_config.json は JSON object である必要があります。", call. = FALSE)
  }
  provenance <- config_data$pass0_provenance
  if (is.null(provenance) || !is.list(provenance)) {
    stop("[ERROR] Pass 0 の由来情報 pass0_provenance がありません。vcd-pass0-consultation を完了して設定を作成してください。", call. = FALSE)
  }

  required <- c("contract_version", "inspection_results", "inspection_results_sha256", "input_sha256", "finalized_at_jst", "target_skill")
  missing <- required[!vapply(required, function(key) !is.null(provenance[[key]]), logical(1))]
  if (length(missing) > 0L) {
    stop("[ERROR] pass0_provenance の必須項目がありません: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!identical(as.character(provenance$contract_version), PASS0_CONTRACT_VERSION)) {
    stop("[ERROR] 未対応の Pass 0 契約バージョンです: ", provenance$contract_version, call. = FALSE)
  }
  if (!identical(as.character(provenance$target_skill), expected_skill)) {
    stop("[ERROR] Pass 0 設定の対象スキルが一致しません。期待値: ", expected_skill, " / 設定値: ", provenance$target_skill, call. = FALSE)
  }
  if (!pass0_scalar_string(provenance$finalized_at_jst)) {
    stop("[ERROR] pass0_provenance.finalized_at_jst は空でないJST日時文字列である必要があります。", call. = FALSE)
  }
  if (!pass0_is_sha256(provenance$inspection_results_sha256) || !pass0_is_sha256(provenance$input_sha256)) {
    stop("[ERROR] pass0_provenance のSHA-256値が不正です。", call. = FALSE)
  }

  inspection_path <- pass0_resolve_path(provenance$inspection_results, config_path, repo_root)
  if (is.null(inspection_path)) {
    stop("[ERROR] Pass 0 検分成果物が見つかりません: ", provenance$inspection_results, call. = FALSE)
  }
  if (!identical(pass0_sha256_file(inspection_path), as.character(provenance$inspection_results_sha256))) {
    stop("[ERROR] Pass 0 検分成果物のSHA-256が設定記録と一致しません。", call. = FALSE)
  }

  has_scope_path <- !is.null(provenance$scope_document)
  has_scope_hash <- !is.null(provenance$scope_document_sha256)
  if (xor(has_scope_path, has_scope_hash)) {
    stop("[ERROR] pass0_provenance のscope_documentとscope_document_sha256は同時に必要です。", call. = FALSE)
  }
  if (has_scope_path) {
    if (!pass0_is_sha256(provenance$scope_document_sha256)) {
      stop("[ERROR] pass0_provenance.scope_document_sha256 が不正です。", call. = FALSE)
    }
    scope_path <- pass0_resolve_path(provenance$scope_document, config_path, repo_root)
    if (is.null(scope_path) || !identical(pass0_sha256_file(scope_path), as.character(provenance$scope_document_sha256))) {
      stop("[ERROR] Pass 0 スコープ文書のSHA-256が設定記録と一致しません。", call. = FALSE)
    }
  }

  inspection <- tryCatch(jsonlite::read_json(inspection_path, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(inspection) || !is.list(inspection)) {
    stop("[ERROR] Pass 0 検分成果物をJSONとして読めません。", call. = FALSE)
  }
  if (!identical(as.character(inspection$inspection_status), "ready")) {
    reason <- inspection$diagnostics[[1L]]$message %||% "入力構造を安全に解釈できません。"
    stop("[ERROR] Pass 0 検分は設定確定可能な状態ではありません: ", reason, call. = FALSE)
  }
  if (!identical(as.character(inspection$file_sha256), as.character(provenance$input_sha256))) {
    stop("[ERROR] Pass 0 検分成果物の入力SHA-256が設定記録と一致しません。", call. = FALSE)
  }

  input_path <- pass0_resolve_path(config_data$input, config_path, repo_root)
  if (is.null(input_path)) {
    stop("[ERROR] analysis_config.json の input が見つかりません: ", config_data$input, call. = FALSE)
  }
  if (!identical(pass0_sha256_file(input_path), as.character(provenance$input_sha256))) {
    stop("[ERROR] 入力CSVがPass 0検分後に変更されています。新しいPass 0を実施してください。", call. = FALSE)
  }

  invisible(list(inspection_path = inspection_path, input_path = input_path, provenance = provenance))
}

build_pass0_provenance <- function(inspection_results, input_path, target_skill, scope_path = NULL, finalized_at_jst = format(Sys.time(), "%Y-%m-%d %H:%M", tz = "Asia/Tokyo"), repo_root = getwd()) {
  inspection_abs <- pass0_resolve_path(inspection_results, repo_root = repo_root)
  input_abs <- pass0_resolve_path(input_path, repo_root = repo_root)
  if (is.null(inspection_abs) || is.null(input_abs)) {
    stop("[ERROR] Pass 0由来を作成するための検分成果物または入力CSVが見つかりません。", call. = FALSE)
  }
  inspection <- jsonlite::read_json(inspection_abs, simplifyVector = FALSE)
  if (!identical(as.character(inspection$inspection_status), "ready")) {
    stop("[ERROR] 設定確定前に入力構造の確認または整形が必要です。", call. = FALSE)
  }
  root_abs <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  rel <- function(path) {
    if (startsWith(path, paste0(root_abs, "/"))) substring(path, nchar(root_abs) + 2L) else path
  }
  provenance <- list(
    contract_version = PASS0_CONTRACT_VERSION,
    inspection_results = rel(inspection_abs),
    inspection_results_sha256 = pass0_sha256_file(inspection_abs),
    input_sha256 = pass0_sha256_file(input_abs),
    finalized_at_jst = finalized_at_jst,
    target_skill = target_skill
  )
  if (!is.null(scope_path)) {
    scope_abs <- pass0_resolve_path(scope_path, repo_root = repo_root)
    if (is.null(scope_abs)) stop("[ERROR] Pass 0 スコープ文書が見つかりません: ", scope_path, call. = FALSE)
    provenance$scope_document <- rel(scope_abs)
    provenance$scope_document_sha256 <- pass0_sha256_file(scope_abs)
  }
  provenance
}
