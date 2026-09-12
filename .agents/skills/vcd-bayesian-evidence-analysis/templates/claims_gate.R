# =============================================================================
# vcd-bayesian-evidence-analysis: claims_gate.R
# Pass 2.5 主張ゲート（Narrative Claims Verification Gate）
# 結果JSONのSHA-256、JSON Pointer参照、数値一致を厳密に検証
# =============================================================================

resolve_json_pointer <- function(root_obj, pointer) {
  if (!is.character(pointer) || length(pointer) != 1L || !nzchar(pointer)) {
    stop(sprintf("[ERROR] 無効な JSON Pointer: %s", as.character(pointer)), call. = FALSE)
  }
  if (!startsWith(pointer, "/")) {
    stop(sprintf("[ERROR] JSON Pointer は '/' で始まる必要があります: %s", pointer), call. = FALSE)
  }

  tokens <- strsplit(pointer, "/", fixed = TRUE)[[1L]][-1L]
  curr <- root_obj

  for (t in tokens) {
    # RFC 6901 エスケープ解除: ~1 -> /, ~0 -> ~
    unescaped <- gsub("~1", "/", gsub("~0", "~", t, fixed = TRUE), fixed = TRUE)

    if (is.null(curr)) {
      stop(sprintf("[ERROR] JSON Pointer '%s' の途中でノードが NULL になりました (token: '%s')", pointer, unescaped), call. = FALSE)
    }

    if (is.list(curr) && !is.data.frame(curr)) {
      if (is.null(names(curr))) {
        # 配列インデックス（0始まり）
        idx <- suppressWarnings(as.integer(unescaped))
        if (is.na(idx) || idx < 0L || idx >= length(curr)) {
          stop(sprintf("[ERROR] JSON Pointer 配列インデックス範囲外: '%s' (token: '%s', length: %d)", pointer, unescaped, length(curr)), call. = FALSE)
        }
        curr <- curr[[idx + 1L]]
      } else {
        # オブジェクトキー
        if (!(unescaped %in% names(curr))) {
          stop(sprintf("[ERROR] JSON Pointer キーが存在しません: '%s' (key: '%s')", pointer, unescaped), call. = FALSE)
        }
        curr <- curr[[unescaped]]
      }
    } else if (is.data.frame(curr)) {
      # data.frame の場合: /0/col_name または /col_name/0
      idx <- suppressWarnings(as.integer(unescaped))
      if (!is.na(idx)) {
        if (idx < 0L || idx >= nrow(curr)) {
          stop(sprintf("[ERROR] data.frame 行インデックス範囲外: '%s' (index: %d, rows: %d)", pointer, idx, nrow(curr)), call. = FALSE)
        }
        curr <- curr[idx + 1L, , drop = FALSE]
      } else if (unescaped %in% names(curr)) {
        curr <- curr[[unescaped]]
      } else {
        stop(sprintf("[ERROR] data.frame 列が存在しません: '%s' (col: '%s')", pointer, unescaped), call. = FALSE)
      }
    } else if (is.atomic(curr) && length(curr) > 1L) {
      idx <- suppressWarnings(as.integer(unescaped))
      if (is.na(idx) || idx < 0L || idx >= length(curr)) {
        stop(sprintf("[ERROR] ベクトルインデックス範囲外: '%s' (index: %d, length: %d)", pointer, idx, length(curr)), call. = FALSE)
      }
      curr <- curr[idx + 1L]
    } else {
      stop(sprintf("[ERROR] JSON Pointer '%s' で末端プリミティブからのトラバースを試みました (token: '%s')", pointer, unescaped), call. = FALSE)
    }
  }

  curr
}

verify_narrative_claims <- function(results_json_path, claims_json_path, tolerance = 1e-4) {
  if (!file.exists(results_json_path)) {
    stop(sprintf("[ERROR] 結果JSONが存在しません: %s", results_json_path), call. = FALSE)
  }
  if (!file.exists(claims_json_path)) {
    stop(sprintf("[ERROR] narrative_claims.json が存在しません: %s", claims_json_path), call. = FALSE)
  }

  # 結果JSONハッシュ計算
  actual_hash <- digest::digest(file = results_json_path, algo = "sha256")

  results_data <- jsonlite::fromJSON(results_json_path, simplifyVector = FALSE)
  claims_data <- jsonlite::fromJSON(claims_json_path, simplifyVector = FALSE)

  # 1. レビュー状態検査
  if (!identical(claims_data$status, "REVIEWED")) {
    stop(sprintf("[ERROR] narrative_claims のレビュー状態が 'REVIEWED' ではありません (status: '%s')", as.character(claims_data$status)), call. = FALSE)
  }

  # 2. ハッシュ一致検査
  if (!identical(claims_data$result_sha256, actual_hash)) {
    stop(sprintf(
      "[ERROR] narrative_claims の記録ハッシュと結果JSON実ハッシュが一致しません。\n記録: %s\n実際: %s",
      as.character(claims_data$result_sha256), actual_hash
    ), call. = FALSE)
  }

  # 3. 主張配列の存在検査
  claims_list <- claims_data$claims
  if (is.null(claims_list) || length(claims_list) == 0L) {
    stop("[ERROR] narrative_claims に数値主張 claims 配列がありません。", call. = FALSE)
  }

  # 4. 各主張の照合
  for (i in seq_along(claims_list)) {
    cl <- claims_list[[i]]
    pointer <- cl$pointer
    claimed_val <- cl$value

    if (is.null(pointer) || !is.character(pointer)) {
      stop(sprintf("[ERROR] claim #%d に pointer がありません。", i), call. = FALSE)
    }
    if (is.null(claimed_val) || !is.numeric(claimed_val)) {
      stop(sprintf("[ERROR] claim #%d (pointer: %s) の claimed_value が数値ではありません。", i, pointer), call. = FALSE)
    }

    actual_val <- resolve_json_pointer(results_data, pointer)

    # HOLD または未定義ノードの検査
    if (is.character(actual_val) && (actual_val == "HOLD" || startsWith(actual_val, "HOLD_"))) {
      stop(sprintf("[ERROR] claim #%d (pointer: %s) は HOLD 状態の値を参照しています: '%s'", i, pointer, actual_val), call. = FALSE)
    }

    if (!is.numeric(actual_val) || length(actual_val) != 1L) {
      stop(sprintf("[ERROR] claim #%d (pointer: %s) の実測値が単一数値ではありません: %s", i, pointer, class(actual_val)), call. = FALSE)
    }

    diff_abs <- abs(actual_val - claimed_val)
    denom <- max(1.0, abs(actual_val))
    rel_diff <- diff_abs / denom

    if (diff_abs > tolerance && rel_diff > tolerance) {
      stop(sprintf(
        "[ERROR] claim #%d (pointer: %s) の数値が一致しません。\n主張値: %f\n実測値: %f\n誤差: %e (許容値: %e)",
        i, pointer, claimed_val, actual_val, diff_abs, tolerance
      ), call. = FALSE)
    }
  }

  message(sprintf("[SUCCESS] narrative_claims 検証合格: %d 件の数値主張が完全に照合されました。", length(claims_list)))
  invisible(TRUE)
}
