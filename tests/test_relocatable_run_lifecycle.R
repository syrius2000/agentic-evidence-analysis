# 可搬 run メタデータ契約の回帰試験
suppressPackageStartupMessages(source(".agents/shared/run_scope.R"))

stopifnot(identical(run_scope_relative_path("/repo/data.csv", "/repo"), "data.csv"))
stopifnot(is.null(run_scope_relative_path("/repo2/data.csv", "/repo")))
stopifnot(identical(run_scope_resolve_path("data.csv", "repo_relative", "/repo", "/repo/out/run_x"), "/repo/data.csv"))
stopifnot(inherits(try(run_scope_resolve_path("../secret", "repo_relative", "/repo", "/repo/out/run_x"), silent = TRUE), "try-error"))

base <- normalizePath(tempfile("relocatable_"), winslash = "/", mustWork = FALSE)
dir.create(base, recursive = TRUE)
on.exit(unlink(base, recursive = TRUE), add = TRUE)
out <- file.path(base, "out")
run <- file.path(out, "run_portable")
dir.create(run, recursive = TRUE)
input <- file.path(base, "external.csv")
writeLines("a,b\n1,2\n", input)
writeLines('{"value": 1}', file.path(run, "evidence_results.json"))
manifest <- write_results_manifest(run, "vcd-bayesian-evidence-analysis", list(list(path = "evidence_results.json", role = "primary_results")))
meta <- write_run_meta(out, run, "vcd-bayesian-evidence-analysis", "portable", input_data_path = input,
                       extra = list(results_manifest_sha256 = manifest$manifest_sha256))
raw <- jsonlite::read_json(file.path(run, "run_meta.json"), simplifyVector = FALSE)
txt <- paste(readLines(file.path(run, "run_meta.json"), warn = FALSE), collapse = "\n")
stopifnot(identical(raw$path_schema_version, "1.0"), identical(raw$run_output_dir_path_kind, "run_relative"),
          identical(raw$inputs[[1]]$source_path_kind, "external"), is.null(raw$inputs[[1]]$source_path),
          !grepl("/Users/|/home/|Skill_Development_Gemini|file://", txt))

# run を別ルートへコピーしても manifest と runtime 解決が維持される。
relocated_parent <- file.path(base, "relocated")
dir.create(relocated_parent)
relocated <- file.path(relocated_parent, "run_portable")
file.copy(run, relocated_parent, recursive = TRUE)
relocated_meta <- read_run_control(relocated)
stopifnot(identical(relocated_meta$run_output_dir, normalizePath(relocated, winslash = "/")),
          identical(verify_results_manifest(relocated)$manifest_sha256, manifest$manifest_sha256),
          is.null(get_run_input_data(relocated_meta)),
          identical(get_run_input_sha256(relocated_meta), sha256_file(input)))

# handover の保存値にはホスト固有パスを含めず、同一プロセス戻り値は解決済み。
handover <- write_run_handover(relocated, "vcd-bayesian-evidence-analysis", manifest$manifest_sha256)
handover_raw <- jsonlite::read_json(file.path(relocated, "run_handover.json"), simplifyVector = FALSE)
handover_txt <- paste(readLines(file.path(relocated, "run_handover.json"), warn = FALSE), collapse = "\n")
stopifnot(identical(handover_raw$cwd_kind, "repo_root_marker"), identical(handover_raw$cwd, "."),
          identical(handover$cwd, RUN_SCOPE_REPO_ROOT),
          !grepl("/Users/|/home/|Skill_Development_Gemini|file://", handover_txt))

# 移設先でも Pass 2 -> Pass 3 の確定と封印が成立する。
staging <- get_run_staging_dir(relocated)
writeLines("# 移設先の考察", file.path(staging, "executive_summary.md"))
finalize_pass2(relocated, source_staging_path = file.path(staging, "executive_summary.md"),
               expected_results_manifest_sha256 = manifest$manifest_sha256)
writeLines("<html>移設先</html>", file.path(staging, "dashboard.html"))
finalize_pass3(relocated, source_staging_path = file.path(staging, "dashboard.html"),
               expected_results_manifest_sha256 = manifest$manifest_sha256)
stopifnot(identical(read_run_control(relocated)$run_state, "sealed"))

# legacy は明示読み取りのみ許可し、可搬 v2 と混在しても再出力しない。
legacy <- file.path(base, "legacy")
dir.create(legacy)
jsonlite::write_json(list(interface_version = "1.0", skill = "vcd-bayesian-evidence-analysis"), file.path(legacy, "run_meta.json"), auto_unbox = TRUE)
stopifnot(inherits(try(read_run_control(legacy), silent = TRUE), "try-error"))
stopifnot(identical(read_run_control(legacy, allow_legacy = TRUE)$interface_version, "1.0"))
cat("可搬 run lifecycle tests: PASS\n")
