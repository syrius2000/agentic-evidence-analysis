#!/usr/bin/env Rscript
source(".agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R")
source("tests/statistical_foundations/reference_values.R")
source("tests/statistical_foundations/check_results.R")
args<-commandArgs(trailingOnly=TRUE)
root<-if(length(args)) args[1] else "output/statistical_foundations/verified_0906"
cfgpath<-file.path(root,"tit_1_dir_config.json");cfg<-read_config(cfgpath)
d<-normalize_input(cfg)$data
results<-list();check<-function(name,value) {if(!isTRUE(value)) stop(paste("FAIL:",name));results[[name]]<<-TRUE;message("PASS: ",name)}
expect_error<-function(expr,status="ERROR") {
 e<-tryCatch({force(expr);NULL},error=identity)
 inherits(e,"error") && (!inherits(e,"analysis_condition")||identical(e$status,status))
}
mutcfg<-function(edit) {
 c<-jsonlite::fromJSON(cfgpath,simplifyVector=FALSE);c<-edit(c)
 p<-tempfile(fileext=".json");on.exit(unlink(p));write_result(c,p);read_config(p)
}
check("未知キー拒否",expect_error(mutcfg(function(c){c$subset_expr<-"TRUE";c})))
check("変数重複拒否",expect_error(mutcfg(function(c){c$vars<-c("Class","Class","Survived");c})))
check("response拒否",expect_error(mutcfg(function(c){c$response_var<-"unknown";c})))
check("独立性保留",expect_error(mutcfg(function(c){c$sampling$independence_assumption<-"unverified";c}),"HOLD"))
check("構造ゼロ保留",expect_error(mutcfg(function(c){c$structural_zeros<-list(list(A="1st"));c}),"HOLD"))
check("事前負値拒否",expect_error(mutcfg(function(c){c$prior$total_alpha<--1;c})))
check("ハッシュ不一致拒否",expect_error(mutcfg(function(c){c$consultation$input_sha256<-"bad";c})))
check("runパス拒否",expect_error(mutcfg(function(c){c$run_id<-"../bad";c})))
check("未知水準拒否",expect_error({x<-cfg;x$levels$Class<-c("1st","2nd");normalize_input(x)}))
check("未知抽出演算子拒否",expect_error({x<-cfg;x$filters<-list(list(column="Sex",op="eval",values="TRUE"));normalize_input(x)}))
check("未知抽出列拒否",expect_error({x<-cfg;x$filters<-list(list(column="bad",op="==",values="x"));normalize_input(x)}))
x<-cfg;x$filters<-list(list(column="Sex",op="in",values=c("Female")));x$absent_cell_policy<-"sample_zero"
check("構造化抽出",normalize_input(x)$summary$total_n==470)
raw<-read.csv(cfg$input)
withdata<-function(df,fun) {p<-tempfile(fileext=".csv");on.exit(unlink(p));write.csv(df,p,row.names=FALSE);x<-cfg;x$input<-p;fun(x)}
check("重複集約",withdata(rbind(raw,raw),function(x) all(normalize_input(x)$data$n==2*d$n)))
check("負度数拒否",withdata(transform(raw,Freq=-Freq),function(x)expect_error(normalize_input(x))))
check("非整数拒否",withdata(transform(raw,Freq=Freq+.1),function(x)expect_error(normalize_input(x))))
check("無限度数拒否",withdata(transform(raw,Freq=Inf),function(x)expect_error(normalize_input(x))))
check("総和ゼロ拒否",withdata(transform(raw,Freq=0),function(x)expect_error(normalize_input(x))))
miss<-raw;miss$Freq[1]<-NA
check("欠測拒否",withdata(miss,function(x)expect_error(normalize_input(x))))
check("欠測保留",withdata(miss,function(x){x$missing_policy<-"hold";expect_error(normalize_input(x),"HOLD")}))
check("未記載保留",withdata(raw[-1,],function(x){x$absent_cell_policy<-"hold";expect_error(normalize_input(x),"HOLD")}))
check("未記載を明示ゼロ補完",withdata(raw[-1,],function(x)normalize_input(x)$summary$absent_cells_completed==1))
f<-fit_models(d);ref<-extract_reference_values(d,c("A","B","C"),"n")
check("9モデル独立参照",check_results(d,f,ref)$passed)
ref$models$M1$closed_form_fitted[1]<-ref$models$M1$closed_form_fitted[1]+1
check("閉形式の故意不一致検出",!check_results(d,f,ref)$passed)
zero<-d;zero$n[1]<-0;fz<-fit_models(zero)
check("飽和境界の保留",fz$models$M9$status=="HOLD")
cd<-cell_diagnostics(zero,fz$fits,"M1")$cells[[1]]
check("ゼロセルの局所保留",cd$local_fit_status=="HOLD"&&is.null(cd$log_oe_ratio))
sat<-cell_diagnostics(d,f$fits,"M9")
check("従属セルダミー保留",all(vapply(sat$cells,function(x)x$local_fit_status=="HOLD",logical(1))))
# 等度数2×2×2、総集中度8。階乗の有限積から独立に導いた比。
tiny<-expand.grid(A=c("a","b"),B=c("a","b"),C=c("a","b"));tiny$n<-1
sat_integral<-factorial(7)/factorial(15)
ind_integral<-(factorial(7)*factorial(7)^2/(factorial(15)*factorial(3)^2))^3
check("厳密BFの独立階乗参照",close_values(exact_bf(tiny,8)$log_bf_sat_over_ind,log(sat_integral/ind_integral)))
for(id in names(f$models)) {
 m<-f$models[[id]]
 check(paste("多項尤度直接計算",id),close_values(m$loglik_multinomial,lgamma(sum(d$n)+1)-sum(lgamma(d$n+1))+sum(d$n*log(m$fitted_values/sum(d$n)))))
}
check("BIC差一致",close_values(f$models$M1$bic_multinomial_n-f$models$M8$bic_multinomial_n,f$models$M1$bic_poisson_n-f$models$M8$bic_poisson_n))
draw<-draw_dirichlet(d$n+1/nrow(d),20000,20260906)
check("MC校正",calibrate_draws(draw,d$n+1/nrow(d))$passed)
bad<-draw;bad[,1]<-bad[,1]+.01
check("MCの故意偏り検出",!calibrate_draws(bad,d$n+1/nrow(d))$passed)
check("seed再現",identical(draw,draw_dirichlet(d$n+1/nrow(d),20000,20260906)))
conditional<-conditional_summary(d,draw,d$n+1/nrow(d),"C")
check("条件付き平均分母",close_values(conditional$probabilities[[1]]$mean,(d$n[1]+1/16)/(sum(d$n[1:2])+2/16)))
check("条件付きMC校正",conditional$calibration$passed)
ct<-conditional$contrasts[[1]];i<-as.integer(sub("cell_","",ct$first_cell));j<-as.integer(sub("cell_","",ct$second_cell))
group<-function(i) which(d$A==d$A[i]&d$B==d$B[i])
delta<-draw[,i]/rowSums(draw[,group(i),drop=FALSE])-draw[,j]/rowSums(draw[,group(j),drop=FALSE])
check("層間差の同時標本参照",close_values(ct$mean,mean(delta))&&close_values(c(ct$lower,ct$upper),quantile(delta,c(.025,.975),names=FALSE)))
check("極端P値の対数保持",is.null(chi_tail(1e6,1,TRUE)$p_value)&&is.finite(chi_tail(1e6,1,TRUE)$log_p_value))
write_result(results,file.path(root,"contract_test_results.json"))
