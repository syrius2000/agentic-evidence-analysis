#!/usr/bin/env Rscript
args<-commandArgs(trailingOnly=TRUE)
root<-if(length(args)) args[1] else "output/statistical_foundations/acceptance_0906"
m<-jsonlite::fromJSON(file.path(root,"case_manifest.json"),simplifyVector=FALSE)
status<-list()
for(id in names(m$configs)) {
  out<-file.path(root,"runs",paste0("run_",substr(id,1,16)))
  if(dir.exists(out)) stop(paste("既存結果を保持。新しい準備先を使用:",id))
  code<-system2("Rscript",c("tests/statistical_foundations/run_validation.R","--config",shQuote(m$configs[[id]])),stdout=file.path(root,paste0(id,".log")),stderr=file.path(root,paste0(id,".log")))
  status[[id]]<-code;message(id,": exit ",code)
}
jsonlite::write_json(status,file.path(root,"execution_status.json"),auto_unbox=TRUE,pretty=TRUE)
quit(status=if(any(unlist(status)!=0)) 1L else 0L)
