# if (!require("pacman")) install.packages("pacman")
# pacman::p_load(dplyr, jsonlite, readr)
library(dplyr)
library(jsonlite)
library(readr)

args <- commandArgs(trailingOnly = TRUE)
input_file <- if (length(args) > 0) args[1] else "examples/titanic.csv"

if (!file.exists(input_file)) {
  stop(paste("File not found:", input_file))
}

df <- read_csv(input_file, show_col_types = FALSE)

# Categorical details
cat_vars <- df %>% select(where(is.character), where(is.factor))
cat_details <- list()

if (ncol(cat_vars) > 0) {
  for (col_name in names(cat_vars)) {
    col_data <- cat_vars[[col_name]]
    cat_details[[col_name]] <- list(
      levels = unique(col_data) %>% as.character() %>% sort(),
      n_levels = n_distinct(col_data),
      top_counts = table(col_data) %>% sort(decreasing = TRUE) %>% head(5) %>% as.list()
    )
  }
}

output <- list(
  file = input_file,
  n_rows = nrow(df),
  n_cols = ncol(df),
  categorical_vars = cat_details,
  numeric_vars = df %>% select(where(is.numeric)) %>% names()
)

writeLines(toJSON(output, auto_unbox = TRUE, pretty = TRUE), "inspection_results.json")
message("[INFO] Inspection results saved to inspection_results.json")
