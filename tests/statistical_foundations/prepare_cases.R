#!/usr/bin/env Rscript
# 記述的検分のみ。モデル適合はしない。元CSVは変更せず派生入力を隔離。
source(".agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/input.R")
args<-commandArgs(trailingOnly=TRUE)
out<-if(length(args)) args[1] else "output/statistical_foundations/acceptance_0906"
if(dir.exists(out)) stop("準備先が存在。新しいディレクトリを指定")
dir.create(out,recursive=TRUE)
inspect<-function(path,label) {
  dest<-file.path(out,paste0("inspection_",label))
  code<-system2("Rscript",c(".agents/shared/inspect_data.R",shQuote(path),"--out-dir",shQuote(dest)),stdout=FALSE,stderr=FALSE)
  if(code!=0) stop("Pass 0検分失敗")
  file.path(dest,"inspection_results.json")
}
raw<-"examples/titanic.csv";inspect(raw,"titanic_original")
titanic<-read.csv(raw);titanic<-aggregate(Freq~Class+Sex+Survived,titanic,sum)
hair<-as.data.frame(HairEyeColor)
g<-expand.grid(A=c("A1","A2"),B=c("B1","B2"),C=c("C1","C2"),stringsAsFactors=FALSE)
i<-match(g$A,c("A1","A2"));j<-match(g$B,c("B1","B2"));k<-match(g$C,c("C1","C2"))
syn1<-g;syn1$Freq<-c(1,2)[i]*c(2,3)[j]*c(3,4)[k]
syn2<-g;syn2$Freq<-ifelse(i==j,30,10)*c(1,2)[k]
syn3<-g;syn3$Freq<-ifelse((i==j)==(k==1),40,10)
cases<-list(titanic=titanic,hair=hair,syn_independent=syn1,syn_ab=syn2,syn_interaction=syn3)
paths<-list();manifest<-list()
for(name in names(cases)) {
  df<-cases[[name]];vs<-names(df)[1:3]; variants<-if(name %in% c("titanic","hair")) c(1,100) else 1
  for(mult in variants) {
    label<-paste0(name,"_",mult);d<-df;d$Freq<-d$Freq*mult;path<-file.path(out,paste0(label,".csv"));write.csv(d,path,row.names=FALSE)
    inspection<-inspect(path,label)
    modes<-if(name=="titanic") c("exploratory","directed") else if(name=="hair") "directed" else "exploratory"
    for(mode in modes) {
      id<-paste0(if(name=="titanic") "tit" else if(name=="hair") "hair" else name,"_",mult,"_",if(mode=="directed") "dir" else "exp")
      cfg<-list(schema_version="3way-foundation-v1",input=path,vars=vs,freq="Freq",response_var=if(mode=="directed") if(name=="titanic") "Survived" else "Eye" else NULL,
        output_dir=file.path(out,"runs"),run_id=id,
        sampling=list(unit=if(name=="titanic") "乗客・乗員" else if(name=="hair") "統計学生（教育用分割表）" else "人工観測単位",total_n_meaning=paste("集計総度数",sum(d$Freq)),independence_assumption="assumed_independent",is_scaled=mult!=1,scaling_factor=mult,lineage=if(name=="titanic") "examples/titanic.csv: Ageを合算しFreqのみ倍率変更" else if(name=="hair") "R datasets::HairEyeColor: Freqのみ倍率変更" else "事前指定した整数生成式"),
        levels=setNames(lapply(d[vs],function(x)sort(unique(as.character(x)))),vs),missing_policy="reject",absent_cell_policy="sample_zero",structural_zeros=list(),filters=list(),
        prior=list(total_alpha=1,sensitivity=c(.1,10),draws=20000L),seed=20260906L,
        consultation=list(inspection=inspection,input_sha256=sha256(path),rationale="ユーザー合意: 3次元探索、原表と人工100倍の感度比較。集計度数を展開せず、欠測拒否・標本ゼロ・独立性仮定の限界を明示。目的変数指定は条件付き割合の説明に使う。"))
      cp<-file.path(out,paste0(id,"_config.json"));jsonlite::write_json(cfg,cp,auto_unbox=TRUE,pretty=TRUE,null="null")
      paths[[id]]<-cp
    }
    manifest[[label]]<-list(input=path,sha256=sha256(path),cells=nrow(d),total_n=sum(d$Freq),inspection=inspection)
  }
}
jsonlite::write_json(list(cases=manifest,configs=paths,source_sha256=sha256(raw),tolerance=list(absolute=1e-8,relative=1e-6,mcse_multiplier=5,cdf_extra=1e-4),synthetic_formulas=c("u=(1,2),v=(2,3),w=(3,4); n=u*v*w","AB同水準30、異水準10; C倍率(1,2)","C1の対角40/非対角10、C2は逆転")),file.path(out,"case_manifest.json"),auto_unbox=TRUE,pretty=TRUE)
message("Pass 0と設定作成完了: ",out)
