# VCD Pass 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the "Pass 0: Interactive Consultation" workflow, including the data inspection script, `analysis.R` extension, and the new skill definition.

**Architecture:** 
1. `inspect_data.R` (Statistics extraction)
2. `analysis.R` extension (Config loading)
3. `vcd-pass0-consultation` skill (AI-User dialogue)

**Tech Stack:** R (pacman, skimr, jsonlite), Markdown.

---

### Task 1: Implement Data Inspection Script

**Files:**
- Create: `.agent/shared/inspect_data.R`

- [ ] **Step 1: Write `inspect_data.R`**
```r
if (!require("pacman")) install.packages("pacman")
pacman::p_load(dplyr, jsonlite, skimr, readr)

args <- commandArgs(trailingOnly = TRUE)
input_file <- if (length(args) > 0) args[1] else "examples/titanic.csv"

if (!file.exists(input_file)) {
  stop(paste("File not found:", input_file))
}

df <- read_csv(input_file, show_col_types = FALSE)

# Basic Summary
summary_stats <- skim(df)

# Categorical details
cat_details <- df %>%
  select(where(is.character), where(is.factor)) %>%
  summarise(across(everything(), ~ list(
    levels = unique(.x),
    n_levels = n_distinct(.x),
    top_counts = table(.x) %>% sort(decreasing = TRUE) %>% head(5) %>% as.list()
  )))

output <- list(
  file = input_file,
  n_rows = nrow(df),
  n_cols = ncol(df),
  categorical_vars = cat_details,
  numeric_vars = df %>% select(where(is.numeric)) %>% names()
)

writeLines(toJSON(output, auto_unbox = TRUE, pretty = TRUE), "inspection_results.json")
message("[INFO] Inspection results saved to inspection_results.json")
```

- [ ] **Step 2: Verify with Titanic data**
Run: `Rscript .agent/shared/inspect_data.R examples/titanic.csv`
Expected: `inspection_results.json` exists and contains categorical levels.

### Task 2: Extend `analysis.R` with `--config` support

**Files:**
- Modify: `.agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`

- [ ] **Step 1: Add `--config` argument parsing and logic**
Locate the argument parsing section and add:
```r
# ... existing args ...
parser$add_argument("--config", type="character", help="Path to analysis_config.json")

# After parsing
if (!is.null(args$config)) {
  if (file.exists(args$config)) {
    config <- jsonlite::fromJSON(args$config)
    # Override args with config values if present
    for (name in names(config)) {
      args[[name]] <- config[[name]]
    }
    message("[INFO] Configuration loaded from ", args$config)
  }
}
```

- [ ] **Step 2: Test `--config` override**
Create a dummy `test_config.json` and run `analysis.R --config test_config.json`.

### Task 3: Create Pass 0 Skill Definition

**Files:**
- Create: `.agent/skills/vcd-pass0-consultation/SKILL.md`

- [ ] **Step 1: Write the skill content**
Include instructions for:
1. Running `inspect_data.R`
2. Analyzing the JSON
3. Presenting the 2 proposals (Dimensional reduction, Stratification)
4. Generating `data_analysis_scope.md` and `analysis_config.json`
5. Guiding the user to Pass 1.

### Task 4: Final Integration Test

- [ ] **Step 1: Run the full Pass 0 flow manually**
- [ ] **Step 2: Verify Pass 1 starts correctly using the generated config**
