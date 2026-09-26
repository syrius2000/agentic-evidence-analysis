# .agents/shared/dependency_check.R
# 共有 R 依存関係検査モジュール
# 実行時の暗黙的外部取得（install.packages / p_load）を排除し、
# 不足パッケージを検出して親切な手動導入案内（日本語）を出力して即時停止（Fail-Fast）する。

check_r_dependencies <- function(required, context = "実行") {
  if (is.null(required) || length(required) == 0L) {
    return(invisible(TRUE))
  }
  required <- unique(as.character(required))
  required <- required[nzchar(trimws(required))]

  missing <- required[
    !vapply(required, requireNamespace, logical(1L), quietly = TRUE)
  ]

  if (length(missing) > 0L) {
    install_hint <- sprintf(
      'install.packages(c(%s))',
      paste(sprintf('"%s"', missing), collapse = ", ")
    )

    msg <- sprintf(
      paste0(
        "[ERROR] %sに必要なRパッケージが不足しています: %s\n",
        "セキュリティおよび再現性確保のため、実行時の自動インストールは行いません。\n",
        "事前に次を実行してください:\n  %s\n"
      ),
      context,
      paste(missing, collapse = ", "),
      install_hint
    )
    stop(msg, call. = FALSE)
  }

  invisible(TRUE)
}
