#!/usr/bin/env Rscript
# Pass 2/2.5の成果と数値根拠を確認し、ネットワーク不要のHTMLを出力。
a<-commandArgs(trailingOnly=TRUE)
if(length(a)!=1L) stop("使い方: Rscript render_report.R <run_dir>")
dir<-a[1];path<-file.path(dir,"evidence_results.json")
r<-jsonlite::fromJSON(path,simplifyVector=FALSE)
if(!identical(r$schema_version,"three-way-results-v1") || !r$status %in% c("COMPUTED","PARTIAL_HOLD")) stop("未計算または検証不合格の結果")
for(f in c("executive_summary.md","quality_check.md","narrative_claims.json")) if(!file.exists(file.path(dir,f))) stop(paste("Pass 2/2.5不足:",f))
claims<-jsonlite::fromJSON(file.path(dir,"narrative_claims.json"),simplifyVector=FALSE)
hash<-strsplit(system2("shasum",c("-a","256",shQuote(path)),stdout=TRUE)[1]," ")[[1]][1]
if(!identical(claims$result_sha256,hash)||!identical(claims$status,"REVIEWED")) stop("考察対象ハッシュ・レビュー状態不一致")
resolve<-function(pointer) {
  x<-r
  for(k in strsplit(pointer,"/",fixed=TRUE)[[1]][-1]) {
    k<-gsub("~1","/",gsub("~0","~",k,fixed=TRUE),fixed=TRUE)
    x<-if(is.null(names(x))) x[[as.integer(k)+1L]] else x[[k]]
  }
  x
}
if(!length(claims$claims)) stop("数値根拠が必要")
for(c in claims$claims) {
  value<-resolve(c$pointer)
  if(!is.numeric(value)||length(value)!=1||!is.numeric(c$value)||abs(value-c$value)>1e-8+1e-6*abs(value)) stop(paste("考察の数値不一致:",c$pointer))
}
out<-file.path(dir,"dashboard.html");if(file.exists(out)) stop("既存HTMLは上書きしない")
esc<-function(x) as.character(htmltools::htmlEscape(as.character(x)))
fmt<-function(x) if(is.null(x)||!length(x)) "保留／未算出" else if(is.numeric(x)) format(signif(x,5),trim=TRUE) else as.character(x)
table_html<-function(headers,rows) paste0('<div class="scroll"><table><thead><tr>',paste0('<th>',esc(headers),'</th>',collapse=''),'</tr></thead><tbody>',paste(vapply(rows,function(row) paste0('<tr>',paste0('<td>',vapply(row,function(x)esc(fmt(x)),character(1)),'</td>',collapse=''),'</tr>'),character(1)),collapse=''),'</tbody></table></div>')
parts<-c('<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>3次元探索レポート</title><style>body{font:16px/1.75 system-ui,sans-serif;color:#183344;background:#f4f7f9;margin:0}main{max-width:1200px;margin:auto;padding:32px}section{background:white;padding:24px;margin:20px 0;border-radius:12px}h1,h2,h3{line-height:1.4}.scroll{overflow:auto;max-height:650px}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:9px;border-bottom:1px solid #dde5e9;text-align:left;white-space:nowrap}th{background:#eaf0f4;position:sticky;top:0}a{color:#086080}.notice{background:#fff1d5;padding:16px;border-left:4px solid #b27812}svg{max-width:100%;height:auto}details{margin:20px 0}footer{font-size:13px;color:#48606a}code{overflow-wrap:anywhere}</style><main><h1>3次元探索レポート</h1>',
 paste0('<p>',esc(paste(r$input_summary$variables,collapse=' × ')),' ／ 総度数 ',fmt(r$input_summary$total_n),' ／ ',fmt(r$input_summary$n_cells),'セル ／ ',esc(r$status),'</p>'),
 paste0('<p class="notice">',esc(r$decisions$scaled),'。セル比較と信用区間は探索的で、多重性を調整した確証的判定ではありません。</p>'),
 '<section><h2>分析者の考察</h2>',commonmark::markdown_html(paste(readLines(file.path(dir,"executive_summary.md"),warn=FALSE),collapse='\n'),extensions=TRUE),'</section>')
modelrows<-lapply(r$models,function(m)list(m$id,m$structure,m$status,m$deviance,m$df_residual,m$bic_multinomial_n,m$inference$log_p_value))
parts<-c(parts,'<section><h2>関連構造を比較する</h2><p>A・B・Cは上記変数の順です。BICは固定総度数の多項尤度と自由パラメータ数を使用。小さい値を比較の参考にしますが、自動的な勝者は決めません。</p>',table_html(c('モデル','構造','推定状態','逸脱度G²','残差df','多項BIC(N)','適合検定 log P'),modelrows),'<details><summary>入れ子モデルの比較</summary>',table_html(c('基準→拡張','ΔG²','Δdf','ΔG²/N','近似log BF','log P','近似状態'),lapply(r$comparisons,function(x)list(x$id,x$delta_g2,x$delta_rank,x$delta_g2_per_n,x$log_bf_bic_approx,x$inference$log_p_value,x$approximation_status))),'</details><p>log Pはカイ二乗による漸近値です。小期待度数・非正則推定では保留します。BIC差による近似log BFを厳密BFやモデル事後確率と同一視しません。</p></section>')
# 第3変数の水準別に、全セルのlog(O/E)を同じ色尺度で表示する。
for(base in names(r$cells)) {
 cs<-r$cells[[base]]$cells
 if(!length(cs)) next
 vals<-vapply(cs,function(c)if(is.null(c$log_oe_ratio)) NA_real_ else c$log_oe_ratio,numeric(1));scale<-max(abs(vals),na.rm=TRUE);if(!is.finite(scale)||scale==0)scale<-1
 parts<-c(parts,paste0('<section><h2>セル診断：基準 ',base,'</h2><p>各層で A × B を表示。青は期待より少なく、赤は多いセル。色は log(O/E)、同じ基準の全層で共通尺度です。灰色はlog比が有限でないセル。</p>'))
 A<-unlist(r$input_summary$levels[[1]]);B<-unlist(r$input_summary$levels[[2]]);C<-unlist(r$input_summary$levels[[3]])
 for(layer in C) {
  svg<-paste0('<h3>',esc(r$input_summary$variables[[3]]),' = ',esc(layer),'</h3><svg role="img" aria-label="層別セル診断" viewBox="0 0 ',150+110*length(B),' ',70+62*length(A),'">')
  for(j in seq_along(B)) svg<-paste0(svg,'<text x="',155+(j-1)*110,'" y="25" font-size="13">',esc(B[j]),'</text>')
  for(i in seq_along(A)) {
   svg<-paste0(svg,'<text x="5" y="',70+(i-1)*62,'" font-size="13">',esc(A[i]),'</text>')
   for(j in seq_along(B)) {
    cc<-Filter(function(c) c$levels$A==A[i]&&c$levels$B==B[j]&&c$levels$C==layer,cs)[[1]];v<-cc$log_oe_ratio
    fill<-if(is.null(v)) '#dddddd' else {z<-min(abs(v)/scale,1);if(v>=0) rgb(1,1-.55*z,1-.65*z) else rgb(1-.65*z,1-.35*z,1)}
    svg<-paste0(svg,'<rect x="',145+(j-1)*110,'" y="',40+(i-1)*62,'" width="106" height="58" fill="',fill,'"><title>',esc(paste(cc$cell_id,'O=',cc$observed,'E=',fmt(cc$expected),'log(O/E)=',fmt(v))),'</title></rect><text x="',150+(j-1)*110,'" y="',73+(i-1)*62,'" font-size="12">',esc(if(is.null(v)) 'ゼロ／保留' else fmt(v)),'</text>')
   }
  };parts<-c(parts,paste0(svg,'</svg>'))
 }
 parts<-c(parts,'<details><summary>全セルの数値と推定状態</summary>',table_html(c('セル','A','B','C','O','E','log(O/E)','d/√N','局所ΔG²','ΔG²/N','score統計量','leverage','局所状態','近似状態'),lapply(cs,function(c)list(c$cell_id,c$levels$A,c$levels$B,c$levels$C,c$observed,c$expected,c$log_oe_ratio,c$signed_deviance_per_sqrt_n,c$local_delta_g2,c$delta_g2_per_n,c$local_score_chisq,c$leverage,c$local_fit_status,c$approximation_status))),'</details><p>局所ΔG²はセルダミーを追加して再適合した改善量です。score統計量は局所近似、leverageはモデル行列の診断です。実際の影響度や再標本化安定性は未評価です。</p></section>')
}
post<-r$posterior
parts<-c(parts,'<section><h2>ベイズ推定と不確実性</h2>',paste0('<p>飽和多項モデルに総集中度 a=',fmt(post$prior$total_alpha),' のDirichlet事前を指定。独立対飽和の厳密 log BF（飽和／独立）は ',fmt(post$exact_bf$log_bf_sat_over_ind),'。これは指定した事前に依存する表全体の比較であり、セルBFではありません。</p>'))
if(identical(post$conditional$status,'COMPUTED')) parts<-c(parts,table_html(c('セル','条件群','群の観測度数','生の割合','事後平均','下限','上限'),lapply(post$conditional$probabilities,function(p)list(p$cell_id,paste(unlist(p$denominator$levels),collapse=' / '),p$denominator$observed_n,p$raw_proportion,p$mean,p$lower,p$upper))),'<details><summary>条件群間の割合差（first − second）</summary>',table_html(c('差ID','first','second','差の平均','下限','上限','Pr(差>0)'),lapply(post$conditional$contrasts,function(x)list(x$contrast_id,x$first_cell,x$second_cell,x$mean,x$lower,x$upper,x$probability_positive))),'</details>')
parts<-c(parts,table_html(c('事前総集中度','厳密log BF'),lapply(post$sensitivity,function(x)list(x$total_alpha,x$exact_bf$log_bf_sat_over_ind))),'<p>95%区間は点ごとの等裾信用区間です。事前感度の条件付き結果とMonte Carlo精度はJSONに保存しています。ベイズ推定も標本サイズと事前分布の影響を受けます。</p></section><section><h2>品質確認・限界・再現情報</h2>',commonmark::markdown_html(paste(readLines(file.path(dir,"quality_check.md"),warn=FALSE),collapse='\n'),extensions=TRUE),paste0('<p>入力SHA-256: <code>',esc(r$provenance$input_sha256),'</code></p><p>',esc(r$provenance$r_version),' ／ ',esc(r$provenance$executed_at),'</p><p><a href="evidence_results.json">全結果JSON</a> ・ <a href="analysis_config.json">解析設定</a> ・ <a href="narrative_claims.json">考察の数値根拠</a></p></section><footer>3次元探索支援。観察された関連を因果効果と解釈しません。</footer></main></html>'))
writeLines(parts,out,useBytes=TRUE);message("保存: ",out)
