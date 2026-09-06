#!/usr/bin/env Rscript
# --config 設定 [--validate-only]。Pass 0証拠を検証してから計算する。
script_arg <- grep("^--file=",commandArgs(),value=TRUE)
script_dir <- dirname(normalizePath(if(sys.nframe()>0L) sys.frame(1)$ofile else sub("^--file=","",script_arg[1])))
source(file.path(script_dir,"input.R"));source(file.path(script_dir,"models.R"));source(file.path(script_dir,"bayes.R"))
write_result <- function(x,path) jsonlite::write_json(x,path,auto_unbox=TRUE,pretty=TRUE,digits=NA,na="null",null="null")
run_analysis <- function(config_path,validate_only=FALSE,checker=NULL) {
  cfg<-read_config(config_path);input<-normalize_input(cfg)
  if(validate_only) return(list(status="VALID",input_summary=input$summary))
  out<-file.path(cfg$output_dir,paste0("run_",substr(cfg$run_id,1,16)))
  if(dir.exists(out)||file.exists(out)) fail("実行先が存在。新しいrun_idを指定")
  if(!dir.create(out,recursive=TRUE)) fail("出力ディレクトリ作成失敗")
  write_result(cfg,file.path(out,"analysis_config.json"))
  file.copy(cfg$consultation$inspection,file.path(out,"inspection_results.json"))
  write.csv(input$data,file.path(out,"normalized_counts.csv"),row.names=FALSE)
  fit<-fit_models(input$data);post<-run_bayes(input$data,cfg)
  checks<-if(is.null(checker)) list(status="NOT_RUN",reason="独立参照照合は検証runnerで実施") else checker(input$data,fit)
  sensitivity_pass<-all(vapply(post$sensitivity,function(x) is.null(x$conditional$calibration)||isTRUE(x$conditional$calibration$passed),logical(1)))
  passed<-isTRUE(post$calibration$passed) && (is.null(post$conditional$calibration)||isTRUE(post$conditional$calibration$passed)) && sensitivity_pass && (is.null(checks$passed)||isTRUE(checks$passed))
  failed_fit<-any(vapply(fit$models,function(m)m$status=="ERROR",logical(1)))
  status<-if(!passed||failed_fit) "CHECK_FAILED" else if(any(vapply(fit$models,function(m)m$status!="REGULAR",logical(1)))) "PARTIAL_HOLD" else "COMPUTED"
  result<-list(schema_version="three-way-results-v1",status=status,
    provenance=list(run_id=cfg$run_id,executed_at=format(Sys.time(),tz="Asia/Tokyo",format="%Y-%m-%d %H:%M:%S JST"),input=normalizePath(cfg$input),input_sha256=sha256(cfg$input),config_sha256=sha256(config_path),r_version=R.version.string,locale=Sys.getlocale(),jsonlite_version=as.character(packageVersion("jsonlite")),source_sha256=setNames(lapply(c("input.R","models.R","bayes.R","analysis.R"),function(f) sha256(file.path(script_dir,f))),c("input.R","models.R","bayes.R","analysis.R")),consultation=cfg$consultation),
    input_summary=input$summary,models=fit$models,comparisons=fit$comparisons,
    cells=setNames(lapply(c("M1","M7","M8"),function(id) cell_diagnostics(input$data,fit$fits,id)),c("M1","M7","M8")),
    posterior=post,checks=checks,
    decisions=list(ebic="不採用: 9候補に対するモデル空間の追加罰則を正当化していない",legacy_score="監査列のみ。局所BFではない",multiplicity="探索的。FDR/FWER保証なし",leverage="モデル行列上の診断。実際の影響度とは区別",stability="bootstrap等の安定性は未評価",scaled=if(cfg$sampling$is_scaled) "人工倍率による感度実験。独立な新規観測を増やした証拠ではない" else "独立性は利用者の申告に依存",practical_importance="普遍的閾値なし。用途と分母を踏まえて判断",model_prior="未指定。モデル事後確率は算出しない"))
  write_result(result,file.path(out,"evidence_results.json"))
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
