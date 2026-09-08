# =============================================================================
# test_ai_interpretation_and_stub.R
# タスク 4.5 の検証テスト: AI 解釈文書整合性・pass2_stub.R 実行検証・取り違え検出
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
})

find_repo_root <- function() {
  curr <- getwd()
  for (i in 1:5) {
    if (file.exists(file.path(curr, ".agents"))) return(curr)
    curr <- dirname(curr)
  }
  getwd()
}
repo_root <- find_repo_root()

# -----------------------------------------------------------------------------
# 1. pass2_stub.R の実行検証 (タスク 4.5 (2))
# -----------------------------------------------------------------------------
test_that("タスク 4.5: pass2_stub.R の出力が構造化定義（bracket_expanded, description_ja）および相対採択注記を含む", {
  test_dir <- file.path(repo_root, "output/test_stub_eval")
  if (dir.exists(test_dir)) unlink(test_dir, recursive = TRUE)
  dir.create(test_dir, recursive = TRUE)
  
  # analysis.R でテスト用 run を生成
  cmd_analysis <- sprintf(
    "Rscript %s --input %s --vars Dept,Gender,Admit --freq Freq --response_var Admit --output_dir %s --run-id stub_test",
    shQuote(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")),
    shQuote(file.path(repo_root, "examples/ucb_admissions.csv")),
    shQuote(test_dir)
  )
  system(cmd_analysis, intern = TRUE)
  
  run_dirs <- list.dirs(test_dir, full.names = TRUE, recursive = FALSE)
  expect_true(length(run_dirs) >= 1L)
  run_dir <- run_dirs[1]
  json_path <- file.path(run_dir, "evidence_results.json")
  expect_true(file.exists(json_path))
  
  stub_summary_path <- file.path(run_dir, "executive_summary.md")
  
  # pass2_stub.R を実行
  cmd_stub <- sprintf(
    "Rscript %s --json %s --output %s",
    shQuote(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R")),
    shQuote(json_path),
    shQuote(stub_summary_path)
  )
  system(cmd_stub, intern = TRUE)
  
  expect_true(file.exists(stub_summary_path))
  summary_text <- paste(readLines(stub_summary_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  
  # 構造化定義情報の反映確認
  expect_match(summary_text, "最良モデルID.*: M5")
  expect_match(summary_text, "生成クラス（ブラケット記法）.*: `\\[AB\\]\\[AC\\]`")
  expect_match(summary_text, "実変数展開.*: `\\[Dept, Gender\\]\\[Dept, Admit\\]`")
  expect_match(summary_text, "構造仮定.*: Dept.*で層別したとき.*Gender.*と.*Admit.*は条件付き独立")
  expect_match(summary_text, "適合式 \\(R\\).*: `Freq ~ Dept \\* Gender \\+ Dept \\* Admit`")
  
  # 相対採択原則・非断定注記の反映確認
  expect_match(summary_text, "解釈上の重要注意（相対採択の原則）")
  expect_match(summary_text, "相対的優位性を支持するものであり.*差別の不存在を証明するものではありません")
  
  unlink(test_dir, recursive = TRUE)
})

# -----------------------------------------------------------------------------
# 2. AI 考察サンプルの照合と取り違え・断定検出 (タスク 4.5 (3))
# -----------------------------------------------------------------------------
# 監査関数: サマリーテキストが定義辞書と整合しているか、禁止された断定・取り違えがないかを検査
audit_ai_narrative <- function(narrative, results_json) {
  issues <- character(0)
  best_id <- results_json$models$best_model_id
  best_def <- results_json$models$definitions[[best_id]]
  
  # M5 と M7 の取り違え検出
  if (best_id == "M5") {
    # M7 の特徴（合否で層別、[AC][BC]、Admitで層別）が含まれている場合は検出
    if (grepl("\\[AC\\]\\[BC\\]", narrative)) {
      issues <- c(issues, "M7のブラケット記法 [AC][BC] が最良モデルM5の解釈に混入しています")
    }
    if (grepl("(合否|Admit).*層別.*(学科|Dept).*(性別|Gender).*独立", narrative)) {
      issues <- c(issues, "合否(Admit)所与での条件付き独立というM7の誤った構造仮定が記述されています")
    }
  }
  
  # 差別不存在等の絶対的断定の検出
  assertion_patterns <- c(
    "差別(は|が)(完全に)?存在しないことが証明",
    "バイアス(は|が)一切ないことが証明",
    "差別(は|が)ないことを断定",
    "不当な格差は存在しないと結論付けられる"
  )
  for (pat in assertion_patterns) {
    if (grepl(pat, narrative)) {
      issues <- c(issues, sprintf("モデル採択を根拠とする差別不存在の過度の断定表現が検出されました: '%s'", pat))
    }
  }
  
  # 正しい定義の引用確認
  if (!is.null(best_def)) {
    has_bracket <- grepl(gsub("\\[", "\\\\[", gsub("\\]", "\\\\]", best_def$bracket_notation)), narrative)
    if (!has_bracket) {
      issues <- c(issues, sprintf("最良モデル %s の正本ブラケット記法 %s が考察に引用されていません", best_id, best_def$bracket_notation))
    }
  }
  
  issues
}

test_that("タスク 4.5: 考察監査ロジックが M7/M5 取り違えおよび差別不存在断定を検出し、正しい考察を承認する", {
  baseline_json_path <- file.path(repo_root, "output/ucb_admissions/run_admit_bias/evidence_results.json")
  # pass1 で definitions を持たせた基準データを作成
  res_mock <- list(
    models = list(
      best_model_id = "M5",
      definitions = list(
        M5 = list(
          bracket_notation = "[AB][AC]",
          bracket_expanded = "[Dept, Gender][Dept, Admit]",
          independence = list(description_ja = "Deptで層別したときGenderとAdmitは条件付き独立である")
        )
      )
    )
  )
  
  # サンプル 1: M7 と M5 の取り違え（不合格と判定されるべき）
  sample_confused <- paste(
    "最良モデルは M5 [AC][BC] であり、合否(Admit)で層別したときに学科と性別が独立であることを示しています。",
    "したがって各合格区分において男女の志望傾向に差はありません。"
  )
  issues_confused <- audit_ai_narrative(sample_confused, res_mock)
  expect_true(length(issues_confused) >= 2L)
  expect_true(any(grepl("M7のブラケット記法", issues_confused)))
  expect_true(any(grepl("M7の誤った構造仮定", issues_confused)))
  
  # サンプル 2: 差別不存在の断定（不合格と判定されるべき）
  sample_assertive <- paste(
    "明示式BICにより最良モデル M5 [AB][AC] が採択されました。",
    "これにより、大学入試において性別による差別は完全に存在しないことが証明されました。"
  )
  issues_assertive <- audit_ai_narrative(sample_assertive, res_mock)
  expect_true(length(issues_assertive) >= 1L)
  expect_true(any(grepl("差別不存在の過度の断定表現", issues_assertive)))
  
  # サンプル 3: 正しい AI 考察（合格と判定されるべき）
  sample_sound <- paste(
    "明示式BICに基づき、最良モデルとして M5（生成クラス [AB][AC]、実変数展開 [Dept, Gender][Dept, Admit]）が採択された。",
    "これは「Dept（学科）で層別したときGender（性別）とAdmit（合否）は条件付き独立である」という構造仮定を支持している。",
    "ただし、本モデルの採択は候補モデル群における相対的優位性を支持するものであり、個々の学科内での偏りや差別の完全な不存在を絶対的に証明するものではない。",
    "実際、合格率の低い難関学科（Dept A, B以外）への女性出願比率が高いという出願構造の偏りが観察されている。"
  )
  issues_sound <- audit_ai_narrative(sample_sound, res_mock)
  expect_equal(length(issues_sound), 0L)
})
