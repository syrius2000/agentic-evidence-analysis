# 固定総度数のDirichlet多項モデル。9対数線形モデル全体の事後ではない。
posterior_marginal <- function(alpha) {
  total <- sum(alpha)
  data.frame(mean=alpha/total,variance=alpha*(total-alpha)/(total^2*(total+1)),
    lower=qbeta(.025,alpha,total-alpha),upper=qbeta(.975,alpha,total-alpha))
}
draw_dirichlet <- function(alpha,S,seed) {
  set.seed(seed)
  g <- matrix(rgamma(S*length(alpha),shape=rep(alpha,each=S)),nrow=S)
  g/rowSums(g)
}
calibrate_draws <- function(draws,alpha) {
  S<-nrow(draws); analytic<-posterior_marginal(alpha)
  mcmean<-colMeans(draws); se<-apply(draws,2,sd)/sqrt(S)
  endpoints<-apply(draws,2,quantile,probs=c(.025,.975),names=FALSE)
  cdflo<-pbeta(endpoints[1,],alpha,sum(alpha)-alpha)
  cdfhi<-pbeta(endpoints[2,],alpha,sum(alpha)-alpha)
  mean_tol<-5*se+1e-8+1e-6*abs(analytic$mean)
  cdf_tol<-5*sqrt(.025*.975/S)+1e-4
  pass<-abs(mcmean-analytic$mean)<=mean_tol & abs(cdflo-.025)<=cdf_tol & abs(cdfhi-.975)<=cdf_tol
  list(passed=all(pass),n_draws=S,mean_tolerance="5 MCSE + 1e-8 + 1e-6 |参照値|",cdf_tolerance=cdf_tol,
       per_cell=data.frame(mc_mean=mcmean,analytic_mean=analytic$mean,mcse=se,mean_abs_error=abs(mcmean-analytic$mean),mean_tolerance=mean_tol,cdf_lower=cdflo,cdf_upper=cdfhi,passed=pass))
}
exact_bf <- function(df,a) {
  y<-df$n;N<-sum(y);K<-length(y);coef<-lgamma(N+1)-sum(lgamma(y+1))
  sat<-coef+lgamma(a)-lgamma(N+a)+sum(lgamma(y+a/K)-lgamma(a/K))
  ind<-coef
  for(v in c("A","B","C")) {
    counts<-tapply(y,df[[v]],sum);L<-length(counts)
    ind<-ind+lgamma(a)-lgamma(N+a)+sum(lgamma(counts+a/L)-lgamma(a/L))
  }
  list(total_alpha=a,log_marginal_saturated=sat,log_marginal_independent=ind,log_bf_sat_over_ind=sat-ind,
    status="ANALYTIC_EXPLICIT_PRIOR",prior="飽和: 各セルa/K。独立: 各変数の周辺に独立Dirichlet(a/水準数)。モデル事前確率は未指定")
}
conditional_summary <- function(df,draws,alpha,response) {
  if(is.null(response)) return(list(status="NOT_REQUESTED",reason="目的変数未指定。セル同時確率を参照"))
  predictors<-setdiff(c("A","B","C"),response)
  groups<-split(seq_len(nrow(df)),interaction(df[predictors],drop=TRUE,lex.order=TRUE))
  rows<-list(); conditional_draws<-matrix(NA_real_,nrow(draws),ncol(draws)); calibration<-list()
  for(g in groups) {
    denom<-rowSums(draws[,g,drop=FALSE]); d<-draws[,g,drop=FALSE]/denom
    conditional_draws[,g]<-d
    analytic<-posterior_marginal(alpha[g]);calibration[[length(calibration)+1L]]<-calibrate_draws(d,alpha[g])
    for(j in seq_along(g)) {
      i<-g[j]
      rows[[length(rows)+1L]]<-list(cell_id=sprintf("cell_%03d",i),levels=lapply(df[i,1:3],as.character),
        response=response,denominator=list(variables=predictors,levels=lapply(df[i,predictors,drop=FALSE],as.character),observed_n=sum(df$n[g])),
        raw_proportion=if(sum(df$n[g])>0) df$n[i]/sum(df$n[g]) else NULL,
        mean=analytic$mean[j],lower=analytic$lower[j],upper=analytic$upper[j],interval="点ごとの95%等裾信用区間")
    }
  }
  # 各説明変数の全水準対を、他の説明変数と応答水準を固定して比較。
  contrasts<-list()
  for(v in predictors) {
    fixed<-setdiff(c("A","B","C"),v)
    blocks<-split(seq_len(nrow(df)),interaction(df[fixed],drop=TRUE,lex.order=TRUE))
    for(block in blocks) if(length(block)>1) for(pair in combn(block,2,simplify=FALSE)) {
      i<-pair[1];j<-pair[2];delta<-conditional_draws[,i]-conditional_draws[,j]
      ci<-quantile(delta,c(.025,.975),names=FALSE)
      contrasts[[length(contrasts)+1L]]<-list(contrast_id=paste0("contrast_",length(contrasts)+1L),
        first_cell=sprintf("cell_%03d",i),second_cell=sprintf("cell_%03d",j),varying=v,
        direction="first_cell の条件付き割合 − second_cell の条件付き割合",
        mean=mean(delta),mcse=sd(delta)/sqrt(length(delta)),lower=ci[1],upper=ci[2],probability_positive=mean(delta>0),
        interval="同一同時標本による点ごとの95%等裾信用区間。多重性未調整")
    }
  }
  list(status="COMPUTED",response=response,probabilities=rows,contrasts=contrasts,
       calibration=list(passed=all(vapply(calibration,function(x)x$passed,logical(1))),groups=calibration))
}
run_bayes <- function(df,cfg) {
  y<-df$n;N<-sum(y);K<-length(y);a<-cfg$prior$total_alpha;S<-cfg$prior$draws
  alpha<-y+a/K;draws<-draw_dirichlet(alpha,S,cfg$seed)
  response<-if(is.null(cfg$response_var)) NULL else c("A","B","C")[match(cfg$response_var,cfg$vars)]
  conditional<-conditional_summary(df,draws,alpha,response)
  sensitivity<-lapply(unique(c(a,cfg$prior$sensitivity)),function(v) {
    aa<-y+v/K
    # 事前感度でも同じ同時標本方式を使い、条件付き割合と差を保存。
    dd<-if(v==a) draws else draw_dirichlet(aa,S,cfg$seed)
    list(total_alpha=v,marginal=posterior_marginal(aa),exact_bf=exact_bf(df,v),
      conditional=if(v==a) conditional else conditional_summary(df,dd,aa,response))
  })
  # 事前固定したFreeman–Tukey。飽和モデルの診断であり構造選択の保証ではない。
  set.seed(cfg$seed+1L)
  obs<-numeric(S);rep<-numeric(S)
  for(i in seq_len(S)) {
    mu<-N*draws[i,]; yy<-as.numeric(rmultinom(1,N,draws[i,]))
    obs[i]<-sum((sqrt(y)-sqrt(mu))^2);rep[i]<-sum((sqrt(yy)-sqrt(mu))^2)
  }
  list(prior=list(distribution="Dirichlet",total_alpha=a,per_cell=a/K),marginal=posterior_marginal(alpha),
    calibration=calibrate_draws(draws,alpha),conditional=conditional,sensitivity=sensitivity,
    exact_bf=exact_bf(df,a),seed=cfg$seed,n_draws=S,
    posterior_predictive=list(discrepancy="Freeman–Tukey: Σ(√y−√(Np))²",probability_rep_ge_observed=mean(rep>=obs),
      observed_mean=mean(obs),replicate_mean=mean(rep),limitation="飽和Dirichletモデルの確認。対数線形構造モデルの適合保証ではない"))
}
