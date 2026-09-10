#!/usr/bin/env Rscript
# --config 設定 [--validate-only]。Pass 0証拠を検証してから計算する。
script_arg <- grep("^--file=",commandArgs(),value=TRUE)
script_dir <- dirname(normalizePath(if(sys.nframe()>0L) sys.frame(1)$ofile else sub("^--file=","",script_arg[1])))
source(file.path(script_dir,"input.R"));source(file.path(script_dir,"models.R"));source(file.path(script_dir,"bayes.R"))
repo_root <- local({
  d <- normalizePath(script_dir, winslash = "/", mustWork = TRUE)
  for (i in seq_len(8L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) break
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  d
})
source(file.path(repo_root, ".agents", "shared", "run_scope.R"))
write_result <- function(x,path) jsonlite::write_json(x,path,auto_unbox=TRUE,pretty=TRUE,digits=NA,na="null",null="null")
run_analysis <- function(config_path,validate_only=FALSE,checker=NULL) {
  cfg<-read_config(config_path);input<-normalize_input(cfg)
  if(validate_only) return(list(status="VALID",input_summary=input$summary))
  out<-reserve_run_output_dir(cfg$output_dir,"vcd-bayesian-evidence-analysis",cfg$run_id)
  snapshot <- save_config_snapshot(out,cfg,config_origin="pass0_file",config_source_path=config_path)
  if(!file.copy(cfg$consultation$inspection,file.path(out,"inspection_results.json"),overwrite=FALSE)) fail("検分結果保存失敗")
  write.csv(input$data,file.path(out,"normalized_counts.csv"),row.names=FALSE)
  fit<-fit_models(input$data);post<-run_bayes(input$data,cfg)
  checks<-if(is.null(checker)) list(status="NOT_RUN",reason="独立参照照合は検証runnerで実施") else checker(input$data,fit)
  sensitivity_pass<-all(vapply(post$sensitivity,function(x) is.null(x$conditional$calibration)||isTRUE(x$conditional$calibration$passed),logical(1)))
  passed<-isTRUE(post$calibration$passed) && (is.null(post$conditional$calibration)||isTRUE(post$conditional$calibration$passed)) && sensitivity_pass && (is.null(checks$passed)||isTRUE(checks$passed))
  failed_fit<-any(vapply(fit$models,function(m)m$status=="ERROR",logical(1)))
  status<-if(!passed||failed_fit) "CHECK_FAILED" else if(any(vapply(fit$models,function(m)m$status!="REGULAR",logical(1)))) "PARTIAL_HOLD" else "COMPUTED"
  model_fit_status<-if(failed_fit) "ERROR" else if(any(vapply(fit$models,function(m)m$status!="REGULAR",logical(1)))) "PARTIAL_HOLD" else "REGULAR"
  chi_square_inference_status<-if(any(vapply(fit$models,function(m)m$chi_square_inference_status=="HOLD",logical(1)))) "PARTIAL_HOLD" else "REGULAR_ASYMPTOTIC"
  bic_approximation_status<-if(any(vapply(fit$models,function(m)m$bic_approximation_status=="HOLD",logical(1)))) "PARTIAL_HOLD" else "REGULAR_LAPLACE"
  consultation_ref <- run_scope_portable_path(cfg$consultation$inspection, repo_root, out)
  consultation <- cfg$consultation
  consultation$inspection <- if (!is.null(consultation_ref) && consultation_ref$path_kind != "external") consultation_ref$path else basename(cfg$consultation$inspection)
  result<-list(schema_version="three-way-results-v1",status=status,
    status_ontology=list(computation_status=status,model_fit_status=model_fit_status,
      chi_square_inference_status=chi_square_inference_status,bic_approximation_status=bic_approximation_status,
      stability_status="NOT_EVALUATED"),metric_ontology=metric_ontology,
    provenance=list(run_id=cfg$run_id,executed_at=format(Sys.time(),tz="Asia/Tokyo",format="%Y-%m-%d %H:%M:%S JST"),input=basename(cfg$input),input_path_kind="logical_label",input_sha256=sha256(cfg$input),config_sha256=snapshot$config_sha256,r_version=R.version.string,locale=Sys.getlocale(),jsonlite_version=as.character(packageVersion("jsonlite")),source_sha256=setNames(lapply(c("input.R","models.R","bayes.R","analysis.R"),function(f) sha256(file.path(script_dir,f))),c("input.R","models.R","bayes.R","analysis.R")),consultation=consultation),
    input_summary=input$summary,models=fit$models,comparisons=fit$comparisons,
    cells=setNames(lapply(c("M1","M7","M8"),function(id) cell_diagnostics(input$data,fit$fits,id)),c("M1","M7","M8")),
    posterior=post,checks=checks,
    decisions=list(ebic="不採用: 9候補に対するモデル空間の追加罰則を正当化していない",legacy_score="監査列のみ。局所BFではない",multiplicity="探索的。FDR/FWER保証なし",leverage="モデル行列上の診断。実際の影響度とは区別",stability="bootstrap等の安定性は未評価",scaled=if(cfg$sampling$is_scaled) "人工倍率による感度実験。独立な新規観測を増やした証拠ではない" else "独立性は利用者の申告に依存",scaled_observation_status=if(cfg$sampling$is_scaled) "SCALED_SENSITIVITY_NOT_INDEPENDENT_NEW_OBSERVATIONS" else "ORIGINAL_OR_INDEPENDENCE_USER_ASSERTED",structural_zero_status="NOT_MODELED: sampling zeroと区別し、指定時はPass 0でHOLD",clustered_rwd_status="NOT_EVALUATED: 同一患者反復、施設・医師cluster、反復episode、複雑標本は集計表から復元しない",practical_importance="普遍的閾値なし。用途と分母を踏まえて判断",model_prior="未指定。モデル事後確率は算出しない"))
  write_result(result,file.path(out,"evidence_results.json"))
  manifest <- write_results_manifest(out,"vcd-bayesian-evidence-analysis",list(list(path="evidence_results.json",role="primary_results")))
  write_run_meta(cfg$output_dir,out,"vcd-bayesian-evidence-analysis",cfg$run_id,cfg$input,extra=list(
    requested_run_id=cfg$run_id,config_origin="pass0_file",config_source_path=config_path,
    config_snapshot=snapshot$config_snapshot,config_sha256=snapshot$config_sha256,
    results_manifest_sha256=manifest$manifest_sha256,
    pass_status=list(pass0="completed",pass1="completed",pass2="pending",pass3="pending")))
  write_run_handover(out,"vcd-bayesian-evidence-analysis",manifest$manifest_sha256,config_path="analysis_config.json")
  list(status=status,dir=out,results=result)
}
cli_main <- function(checker=NULL) {
  args<-commandArgs(trailingOnly=TRUE)
  pos<-match("--config",args)
  tryCatch({
    if(is.na(pos)||pos==length(args)||any(!args[-c(pos,pos+1)] %in% "--validate-only")) fail("使い方: --config <analysis_config.json> [--validate-only]")
    res<-run_analysis(args[pos+1],"--validate-only" %in% args,checker)
    if(identical(res$status,"VALID")) cat(jsonlite::toJSON(res$input_summary,auto_unbox=TRUE,pretty=TRUE,digits=NA),"\n")
    message(res$status, if(!is.null(res$dir)) paste0(": ",res$dir))
    quit(status=if(res$status=="CHECK_FAILED") 1L else if(res$status=="PARTIAL_HOLD") 2L else 0L)
  },error=function(e) {message(if(inherits(e,"analysis_condition")) e$status else "ERROR",": ",conditionMessage(e));quit(status=if(inherits(e,"analysis_condition")&&e$status=="HOLD") 2L else 1L)})
}
if(sys.nframe()==0L) cli_main()
