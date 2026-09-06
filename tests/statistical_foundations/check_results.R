# 数値許容差は計画で固定。閉形式も総合判定に必ず含める。
close_values <- function(x,r) length(x)==length(r) && all(is.finite(x)) && all(is.finite(r)) && all(abs(x-r)<=1e-8+1e-6*abs(r))
check_results <- function(df,fit,refs=extract_reference_values(df,c("A","B","C"),"n")) {
  checks<-lapply(names(fit$models),function(id) {
    m<-fit$models[[id]];r<-refs$models[[id]]
    if(m$status!="REGULAR") return(list(id=id,status="HOLD",reason="非正則モデルは通常の参照合格と区別",passed=NA))
    cf<-!r$has_closed_form||close_values(m$fitted_values,r$closed_form_fitted)
    fv<-close_values(m$fitted_values,r$loglin_fitted)
    dv<-close_values(m$deviance,r$loglin_deviance)
    dd<-identical(as.integer(m$df_residual),as.integer(r$loglin_df))
    list(id=id,status=if(cf&&fv&&dv&&dd) "PASS" else "FAIL",passed=cf&&fv&&dv&&dd,closed_form_passed=cf,ipf_passed=fv,deviance_passed=dv,df_passed=dd,max_fitted_error=max(abs(m$fitted_values-r$loglin_fitted)),deviance_error=m$deviance-r$loglin_deviance)
  })
  list(status=if(any(vapply(checks,function(x)identical(x$passed,FALSE),logical(1)))) "FAIL" else "PASS_WITH_HOLDS_ALLOWED",
    passed=!any(vapply(checks,function(x)identical(x$passed,FALSE),logical(1))),per_model=checks,
    tolerance=list(absolute=1e-8,relative=1e-6))
}
