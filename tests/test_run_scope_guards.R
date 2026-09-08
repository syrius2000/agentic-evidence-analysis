# 確定境界・回復・排他の回帰試験。実データは使用しない。
source('.agents/shared/run_scope.R')
root <- normalizePath(tempdir())
root <- file.path(root, 'guard_cases'); dir.create(root)
reject <- function(expr) {
  value <- tryCatch({ force(expr); FALSE }, error = function(e) TRUE)
  stopifnot(value)
}
make_run <- function(id) {
  r <- reserve_run_output_dir(root, 'vcd-bayesian-evidence-analysis', id)
  writeLines('{}', file.path(r, 'evidence_results.json'))
  m <- write_results_manifest(r, 'vcd-bayesian-evidence-analysis', list(list(path='evidence_results.json', role='primary_results')))
  write_run_meta(root,r,'vcd-bayesian-evidence-analysis',id,extra=list(results_manifest_sha256=m$manifest_sha256))
  r
}
meta <- function(r) read_run_control(r)
hash <- function(r) meta(r)$results_manifest_sha256
stage <- function(r,name,text='内容') {
  p <- file.path(get_run_staging_dir(r),name); writeLines(text,p); p
}
finish2 <- function(r) finalize_pass2(r, source_staging_path=stage(r,'executive_summary.md'), expected_results_manifest_sha256=hash(r))
unchanged <- function(r) {
  files <- sort(list.files(r,recursive=TRUE,all.files=TRUE,full.names=TRUE))
  setNames(vapply(files,sha256_file,character(1)),substring(files,nchar(r)+2))
}
r <- make_run('guards')
finish2(r)
before <- unchanged(r)
reject(finalize_pass2(r,source_staging_path=file.path(r,'staging/executive_summary.md'),expected_results_manifest_sha256=hash(r)))
stopifnot(identical(before,unchanged(r)))
reject(publish_run_preview(r,'executive_summary_preview.md',function(p)writeLines('stub',p)))
writeLines('改ざん',file.path(r,'executive_summary.md'))
s <- stage(r,'dashboard.html','<html>test</html>')
reject(finalize_pass3(r,source_staging_path=s,expected_results_manifest_sha256=hash(r)))
stopifnot(!file.exists(file.path(r,'dashboard.html')))

# 未完了runではCLIと内部関数の両方を拒絶。
r <- make_run('partial')
m <- meta(r); m$pass_status$pass1 <- 'partial'; atomic_run_json(m,file.path(r,'run_meta.json'))
s <- stage(r,'executive_summary.md')
reject(finalize_pass2(r,source_staging_path=s,expected_results_manifest_sha256=hash(r)))
cmd <- c('.agents/shared/finalize_run_stage.R','--stage','pass2','--run-dir',r,'--source-artifact',s,'--target-name','executive_summary.md','--expected-results-manifest-sha256',hash(r))
stopifnot(system2('Rscript',shQuote(cmd),stdout=FALSE,stderr=FALSE)!=0L)
handover <- write_run_handover(r,m$skill,hash(r))
stopifnot(length(handover$next_actions)==0L,nzchar(handover$stop_reason))

# promotion後クラッシュからsourceなしでCLI回復。
r <- make_run('recovery'); s <- stage(r,'executive_summary.md'); h <- hash(r)
options(run_scope.after_promotion=function()stop('故障注入'))
reject(finalize_pass2(r,source_staging_path=s,expected_results_manifest_sha256=h))
options(run_scope.after_promotion=NULL)
stopifnot(!file.exists(s), file.exists(file.path(r,'executive_summary.md')), meta(r)$pass_status$pass2=='pending')
target_h <- sha256_file(file.path(r,'executive_summary.md'))
cmd <- c('.agents/shared/finalize_run_stage.R','--stage','pass2','--run-dir',r,'--source-artifact',s,'--target-name','executive_summary.md','--expected-results-manifest-sha256',h)
stopifnot(system2('Rscript',shQuote(cmd),stdout=FALSE,stderr=FALSE)==0L,
          identical(sha256_file(file.path(r,'executive_summary.md')),target_h), meta(r)$pass_status$pass2=='completed')

r <- make_run('no_evidence'); writeLines('無証跡',file.path(r,'executive_summary.md'))
reject(finalize_pass2(r,source_staging_path=file.path(r,'staging/executive_summary.md'),expected_results_manifest_sha256=hash(r)))

# staging検査はpromotionより前。
r <- make_run('staging'); finish2(r); s <- stage(r,'dashboard.html','<html>test</html>'); junk <- stage(r,'junk.tmp')
reject(finalize_pass3(r,source_staging_path=s,expected_results_manifest_sha256=hash(r)))
stopifnot(file.exists(s),!file.exists(file.path(r,'dashboard.html')))
unlink(junk)
finalize_pass3(r,source_staging_path=s,expected_results_manifest_sha256=hash(r))
before <- unchanged(r)
reject(publish_run_preview(r,'dashboard_preview.html',function(p)writeLines('preview',p)))
reject(get_run_staging_dir(r)); reject(write_results_manifest(r,meta(r)$skill,list(list(path='evidence_results.json',role='primary_results'))))
stopifnot(identical(before,unchanged(r)))

# 共通ロックを別プロセスから取得できず、previewは公開されない。
r <- make_run('parallel'); lock <- acquire_stage_lock(r,'run')
child <- tempfile(fileext='.R')
writeLines(c(sprintf('source(%s)',deparse(file.path(RUN_SCOPE_REPO_ROOT,'.agents/shared/run_scope.R'))),
 sprintf('publish_run_preview(%s,"dashboard_preview.html",function(p)writeLines("preview",p))',deparse(r))),child)
stopifnot(system2('Rscript',shQuote(child),stdout=FALSE,stderr=FALSE)!=0L,!file.exists(file.path(r,'dashboard_preview.html')))
release_stage_lock(lock)

# 古い所有者による解放を拒絶し、現在の所有者のロックを残す。
lock <- acquire_stage_lock(r,'run'); fake <- lock; fake$info$token <- 'wrong'
reject(release_stage_lock(fake)); stopifnot(dir.exists(lock$lock_dir)); release_stage_lock(lock)

# .run_locks symlink先へ一切書かない。
other_root <- tempfile('symlink_root'); dir.create(other_root)
r <- file.path(other_root,'run_test');dir.create(r);write_run_meta(other_root,r,'vcd-bayesian-evidence-analysis','test')
ext <- tempfile('outside');dir.create(ext);file.symlink(ext,file.path(other_root,'.run_locks'))
reject(acquire_stage_lock(r,'run'));stopifnot(length(list.files(ext,all.files=TRUE,no..=TRUE))==0L)

# schema：別名パス、skillのrole違反、run内symlink、上書き。
r <- make_run('schema'); art <- list(list(path='./evidence_results.json',role='primary_results'))
reject(validate_manifest_entries(r,meta(r)$skill,art,TRUE))
reject(validate_manifest_entries(r,meta(r)$skill,list(list(path='evidence_results.json',role='figure')),TRUE))
file.symlink(file.path(r,'evidence_results.json'),file.path(r,'linked.json'))
reject(assert_path_within_run_dir('linked.json',r))

# supersedeは保存ハッシュ、循環を検査。
r <- make_run('supersede'); h <- hash(r); writeLines('{"changed":1}',file.path(r,'evidence_results.json'))
manifest <- jsonlite::read_json(file.path(r,'results_manifest.json'));manifest$artifacts[[1]]$sha256<-sha256_file(file.path(r,'evidence_results.json'))
atomic_run_json(manifest,file.path(r,'results_manifest.json'))
reject(verify_superseded_run(r,meta(r)$skill))
r <- make_run('cycle');m<-meta(r);m$supersedes_run<-r;atomic_run_json(m,file.path(r,'run_meta.json'));reject(verify_superseded_run(r,m$skill))

# legacy previewは外部だけに一回公開。
r <- make_run('legacy');m<-meta(r);m$interface_version<-'1.0';atomic_run_json(m,file.path(r,'run_meta.json'));before<-unchanged(r)
out <- tempfile('legacy_preview');dir.create(out)
reject(publish_run_preview(r,'dashboard_preview.html',function(p)writeLines('警告preview',p),TRUE))
publish_run_preview(r,'dashboard_preview.html',function(p)writeLines('警告preview',p),TRUE,out)
stopifnot(identical(before,unchanged(r)),file.exists(file.path(out,'dashboard_preview.html')))
reject(publish_run_preview(r,'dashboard_preview.html',function(p)writeLines('preview',p),TRUE,out))
cat('確定境界・回復・排他の回帰試験：全件成功\n')

# 実プロセス同士の予約・確定競合。
reserved <- parallel::mclapply(1:2, function(i) reserve_run_output_dir(root,'vcd-bayesian-evidence-analysis','same_second'),mc.cores=2)
stopifnot(length(unique(unlist(reserved)))==2L)
r <- make_run('finalizer_race');h<-hash(r)
sources <- c(stage(r,'first.md','first'),stage(r,'second.md','second'))
results <- parallel::mclapply(sources,function(s)tryCatch({finalize_pass2(r,source_staging_path=s,expected_results_manifest_sha256=h);TRUE},error=function(e)FALSE),mc.cores=2)
stopifnot(sum(unlist(results))==1L,meta(r)$pass_status$pass2=='completed')

# 互換探索は親直下＋子runを合算して曖昧性を拒絶。
parent <- make_run('discovery');child<-file.path(parent,'run_child');dir.create(child)
writeLines('{}',file.path(child,'evidence_results.json'))
reject(resolve_pass3_run_dir(parent,'evidence_results.json',discover_single_run=TRUE))

# lock_info欠損と不明所有者の回復拒絶。
r<-make_run('broken_lock');control<-run_control_dir(r);dir.create(file.path(control,'run.lock'))
reject(acquire_stage_lock(r,'run',recover_stale=TRUE));stopifnot(dir.exists(file.path(control,'run.lock')))

# 複数入力の保存とbuiltinのhash_only。
r<-reserve_run_output_dir(root,'vcd-bayesian-evidence-analysis','multi_input')
inputs<-list(list(role='data',source_kind='builtin',sha256=sha256_df(data.frame(x=1)),snapshot_policy='hash_only'),
             list(role='auxiliary',source_kind='builtin',sha256=sha256_df(data.frame(y=2)),snapshot_policy='hash_only'))
m<-write_run_meta(root,r,'vcd-bayesian-evidence-analysis','multi_input',extra=list(inputs=inputs))
stopifnot(identical(m$inputs,inputs),m$pass_status$pass1=='pending',is.null(m$timestamps$pass1_completed))

# handoverは別cwdから起動した生成者でも実行可能なリポジトリcwdを記録。
r<-make_run('cwd');wd<-getwd();setwd(tempdir());handover<-write_run_handover(r,meta(r)$skill,hash(r));setwd(wd)
stopifnot(identical(handover$cwd,RUN_SCOPE_REPO_ROOT))
setwd(handover$cwd)
argv<-handover$next_actions$pass2_stub_preview$argv
stopifnot(system2(argv[1],shQuote(argv[-1]),stdout=FALSE,stderr=FALSE)==0L)
setwd(wd)
cat('追加の実競合・探索・入力・cwd試験：全件成功\n')

# 事前証跡保存の故障ではpromotionしない。
local({
  r<-make_run('transaction_failure'); s<-stage(r,'executive_summary.md'); h<-hash(r)
  original<-atomic_run_json
  assign('atomic_run_json',function(value,path) {
    if (grepl('transaction_',basename(path))) stop('事前証跡保存失敗の注入')
    original(value,path)
  },envir=.GlobalEnv)
  on.exit(assign('atomic_run_json',original,envir=.GlobalEnv))
  reject(finalize_pass2(r,source_staging_path=s,expected_results_manifest_sha256=h))
  stopifnot(file.exists(s),!file.exists(file.path(r,'executive_summary.md')),meta(r)$pass_status$pass2=='pending')
})

# 回復証跡の改ざんを拒絶し、公開済み成果物を保持。
r<-make_run('transaction_tamper');s<-stage(r,'executive_summary.md');h<-hash(r)
options(run_scope.after_promotion=function()stop('中断'))
reject(finalize_pass2(r,source_staging_path=s,expected_results_manifest_sha256=h));options(run_scope.after_promotion=NULL)
tx_path<-file.path(run_control_dir(r),'transaction_pass2.json');tx<-jsonlite::read_json(tx_path)
target_hash<-sha256_file(file.path(r,'executive_summary.md'));tx$sha256<-paste(rep('0',64),collapse='');atomic_run_json(tx,tx_path)
reject(finalize_pass2(r,source_staging_path=s,expected_results_manifest_sha256=h))
stopifnot(identical(target_hash,sha256_file(file.path(r,'executive_summary.md'))),meta(r)$pass_status$pass2=='pending')
cat('証跡保存故障・証跡改ざん試験：全件成功\n')
