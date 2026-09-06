# Poisson GLM表現。変数名は内部A/B/Cに写像し、入力文字列を式として評価しない。
model_formulas <- list(M1 = n ~ A+B+C, M2 = n ~ A*B+C, M3 = n ~ A*C+B,
 M4 = n ~ B*C+A, M5 = n ~ A*B+A*C, M6 = n ~ A*B+B*C,
 M7 = n ~ A*C+B*C, M8 = n ~ (A+B+C)^2, M9 = n ~ A*B*C)
model_structures <- c(M1="[A][B][C]",M2="[AB][C]",M3="[AC][B]",M4="[BC][A]",M5="[AB][AC]",M6="[AB][BC]",M7="[AC][BC]",M8="[AB][AC][BC]",M9="[ABC]")
fit_one <- function(formula, df) {
  warnings <- character()
  fit <- tryCatch(withCallingHandlers(glm(formula, family = poisson(), data = df,
    x = TRUE, y = TRUE, control = glm.control(epsilon = 1e-9, maxit = 200)),
    warning = function(w) {warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")}), error = identity)
  if (inherits(fit,"error")) return(list(fit=NULL, status="ERROR", reasons=conditionMessage(fit)))
  reasons <- character()
  if (!fit$converged) reasons <- c(reasons,"収束不良")
  if (fit$rank < ncol(fit$x)) reasons <- c(reasons,"列の非識別")
  # 数値的境界の保守的判定。分離の完全な解析的判定ではない。
  if (fit$boundary || any(fitted(fit) < 1e-7) || any(!is.finite(coef(fit)))) reasons <- c(reasons,"境界または係数非有限")
  list(fit=fit, status=if(length(reasons)) "HOLD" else "REGULAR", reasons=reasons, warnings=warnings)
}
chi_tail <- function(g, df, valid) {
  if (!valid || !is.finite(g) || df <= 0) return(list(p_value=NULL, log_p_value=NULL, status="HOLD",reason="非正則・疎な期待度数または自由度不足"))
  lp <- pchisq(max(0,g), df, lower.tail=FALSE, log.p=TRUE)
  p <- exp(lp)
  list(p_value=if(p==0) NULL else p, log_p_value=lp,
       status=if(p==0) "UNDERFLOW_LOG_AVAILABLE" else "ASYMPTOTIC", reason="カイ二乗近似。厳密検定ではない")
}
fit_models <- function(df) {
  N <- sum(df$n); K <- nrow(df)
  fits <- lapply(model_formulas, fit_one, df=df)
  models <- lapply(names(fits), function(id) {
    item <- fits[[id]]; f <- item$fit
    if(is.null(f)) return(list(id=id,status=item$status,status_reasons=item$reasons))
    ll <- as.numeric(logLik(f)); rank <- f$rank
    # Poissonの総数に関する共通項。固定総数の多項尤度の絶対値を再構成。
    constant <- N*log(N)-N-lgamma(N+1)
    ll_mult <- ll-constant
    regular <- item$status == "REGULAR"
    list(id=id,structure=model_structures[[id]],formula=paste(deparse(formula(f)),collapse=""),
      status=item$status,status_reasons=item$reasons,warnings=item$warnings,
      rank=rank,df_residual=f$df.residual,loglik_poisson=ll,loglik_multinomial=ll_mult,
      total_count_constant=constant,parameters_multinomial=rank-1L,deviance=deviance(f),
      bic_multinomial_n=if(regular) -2*ll_mult+(rank-1)*log(N) else NULL,
      bic_poisson_n=if(regular) -2*ll+rank*log(N) else NULL,
      bic_stats_rows=BIC(f),fitted_values=unname(fitted(f)),
      inference=chi_tail(deviance(f),f$df.residual,regular && all(fitted(f)>=5)))
  }); names(models) <- names(fits)
  comparisons <- list()
  for (small in names(fits)) for (large in names(fits)) {
    a <- fits[[small]]; b <- fits[[large]]
    if(is.null(a$fit)||is.null(b$fit)||a$fit$rank>=b$fit$rank) next
    # モデル空間への射影で包含を確認する。
    if(qr(cbind(b$fit$x,a$fit$x))$rank != b$fit$rank) next
    delta <- deviance(a$fit)-deviance(b$fit); dr <- b$fit$rank-a$fit$rank
    regular <- a$status=="REGULAR" && b$status=="REGULAR"
    approximation_ok <- regular && all(fitted(a$fit)>=5) && all(fitted(b$fit)>=5)
    comparisons[[length(comparisons)+1L]] <- list(id=paste(small,large,sep="_to_"),baseline=small,alternative=large,
       delta_g2=delta,delta_rank=dr,delta_g2_per_n=delta/N,
       log_bf_bic_approx=if(approximation_ok) (delta-dr*log(N))/2 else NULL,
       approximation_status=if(approximation_ok) "REGULAR_ASYMPTOTIC" else "HOLD",
       inference=chi_tail(delta,dr,approximation_ok))
  }
  list(models=models,comparisons=comparisons,fits=fits)
}
cell_diagnostics <- function(df, fits, base_id) {
  b <- fits[[base_id]]; N <- sum(df$n); K <- nrow(df)
  if(is.null(b$fit)) return(list(status="HOLD",reason="基準モデル適合失敗",base_model=base_id))
  mu <- fitted(b$fit); rp <- residuals(b$fit,"pearson"); rd <- residuals(b$fit,"deviance"); h <- rowSums(qr.Q(qr(sqrt(mu)*b$fit$x))[,seq_len(b$fit$rank),drop=FALSE]^2)
  cells <- lapply(seq_len(K),function(i) {
    dat <- df; dat$cell_dummy <- as.integer(seq_len(K)==i)
    extra <- fit_one(update(model_formulas[[base_id]], . ~ . + cell_dummy),dat)
    dr <- if(!is.null(extra$fit)) extra$fit$rank-b$fit$rank else NA_real_
    valid <- df$n[i] > 0 && b$status=="REGULAR" && extra$status=="REGULAR" && is.finite(dr) && dr>0 && (1-h[i])>1e-8
    reason <- if(valid) "正則な局所再適合" else paste(c(b$reasons,extra$reasons,if(df$n[i]==0) "ゼロ観測セルのダミーは境界",if(!is.finite(dr)||dr<=0) "ダミーが非識別",if(1-h[i]<=1e-8) "leverageが1"),collapse="; ")
    delta <- if(valid) deviance(b$fit)-deviance(extra$fit) else NULL
    if(!is.null(delta) && delta < -1e-8) {valid<-FALSE;reason<-"尤度改善が負: 数値不良";delta<-NULL}
    if(!is.null(delta)) delta <- max(0,delta)
    approx <- valid && all(mu>=5) && all(fitted(extra$fit)>=5)
    list(cell_id=sprintf("cell_%03d",i),levels=lapply(df[i,1:3],as.character),
      observed=df$n[i],expected=unname(mu[i]),base_model=base_id,
      pearson_residual=unname(rp[i]),deviance_residual=unname(rd[i]),leverage=unname(h[i]),
      oe_ratio=unname(df$n[i]/mu[i]),log_oe_ratio=if(df$n[i]>0) unname(log(df$n[i]/mu[i])) else NULL,
      log_oe_status=if(df$n[i]>0) "FINITE" else "NEGATIVE_INFINITY_ZERO_OBSERVED",
      signed_deviance_per_sqrt_n=unname(rd[i]/sqrt(N)),rate_difference=unname((df$n[i]-mu[i])/N),
      local_score_chisq=if(b$status=="REGULAR" && 1-h[i]>1e-8) unname(rp[i]^2/(1-h[i])) else NULL,
      legacy_residual_score=unname(rp[i]^2-log(N)),legacy_status="監査専用。局所BF・実質的重要性の判定に使わない",
      local_delta_g2=delta,local_delta_rank=if(is.finite(dr)) dr else NULL,
      delta_g2_per_n=if(valid) delta/N else NULL,
      local_bic_difference=if(approx) delta-dr*log(N) else NULL,
      local_log_bf_bic_approx=if(approx) (delta-dr*log(N))/2 else NULL,
      local_fit_status=if(valid) "REGULAR" else "HOLD",local_fit_reason=reason,
      approximation_status=if(approx) "REGULAR_ASYMPTOTIC" else "HOLD",
      inference=chi_tail(if(valid) delta else NA_real_,dr,approx))
  })
  list(base_model=base_id,evaluated_cells=K,selection="全セルを保存。自動採択なし",multiplicity="FDR/FWER・選択後推論を保証しない探索",cells=cells)
}
