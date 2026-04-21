# Standardization of Analysis Pipeline with analysis_config.json

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standardize all skills to accept `analysis_config.json` as the "Single Source of Truth," established by `vcd-pass0-consultation`. This includes refactoring CLI arguments, updating AI guidance in `SKILL.md`, and synchronizing all test cases.

**Architecture:**
1. `vcd-pass0-consultation` generates a flat `analysis_config.json`.
2. All R scripts use `--config <json_path>` to load parameters.
3. `questionnaire-batch-analysis` renames its `--config` (CSV) to `--question-config`.
4. All `SKILL.md` files include a "Pre-requisite: Pass 0" section.

**Tech Stack:** R (jsonlite, optparse/base), Markdown, Shell (sed/grep for batch updates).

---

## Task 1: Refactor questionnaire-batch-analysis

**Files:**
- Modify: `.agent/skills/questionnaire-batch-analysis/templates/batch_runner.R`
- Modify: `.agent/skills/questionnaire-batch-analysis/SKILL.md`

- [ ] **Step 1: Update `batch_runner.R` arguments**
Rename `--config` to `--question-config` and add a new `--config` for JSON.
```r
option_list <- list(
  optparse::make_option("--data", type = "character"),
  optparse::make_option("--config", type = "character", help = "Path to analysis_config.json (Pass 0)"),
  optparse::make_option("--question-config", type = "character", help = "Path to question config CSV"),
  optparse::make_option("--out", type = "character", default = "./skill_out/questionnaire"),
  optparse::make_option("--run-id", type = "character", default = "run")
)
# ... Load JSON if --config is present ...
if (!is.null(opt$config) && file.exists(opt$config)) {
  cfg_json <- jsonlite::fromJSON(opt$config)
  if (!is.null(cfg_json$input)) opt$data <- cfg_json$input
  if (!is.null(cfg_json$question_config)) opt$`question-config` <- cfg_json$question_config
  if (!is.null(cfg_json$output_dir)) opt$out <- cfg_json$output_dir
  if (!is.null(cfg_json$run_id)) opt$`run-id` <- cfg_json$run_id
}
```

- [ ] **Step 2: Update `questionnaire-batch-analysis/SKILL.md`**
Update the usage examples to show `--config analysis_config.json` and `--question-config questions.csv`.

### Task 2: Synchronize vcd-categorical-reporting

**Files:**
- Modify: `.agent/skills/vcd-categorical-reporting/SKILL.md`

- [ ] **Step 1: Add JSON awareness to the reporting skill**
Update the AI instructions: "Before writing the report, check for `analysis_config.json` to identify the correct output directories and variable roles."

### Task 3: Enhance vcd-pass0-consultation

**Files:**
- Modify: `.agent/skills/vcd-pass0-consultation/SKILL.md`

- [ ] **Step 1: Update JSON generation logic**
Ensure it outputs all necessary keys: `input`, `vars`, `freq`, `output_dir`, `run_id`, and `question_config` (if applicable).

### Task 4: Batch Update Test Cases

**Files:**
- Modify: `tests/*.R` (Files using `batch_runner.R`)

- [ ] **Step 1: Identify and replace `--config` with `--question-config`**
Use `grep` to find tests calling `batch_runner.R` and update the argument name.

### Task 5: Final Verification & Pipeline Test

- [ ] **Step 1: Run a complete 4-Pass flow for Titanic**
- [ ] **Step 2: Run a complete 4-Pass flow for Questionnaire (UCB Admissions)**
- [ ] **Step 3: Verify all tests pass**
