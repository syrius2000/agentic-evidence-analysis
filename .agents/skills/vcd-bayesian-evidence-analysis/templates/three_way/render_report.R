#!/usr/bin/env Rscript
# Validated, offline three-way dashboard renderer.
a <- commandArgs(trailingOnly = TRUE)
if (length(a) != 1L) stop("使い方: Rscript render_report.R <run_dir>")
dir <- a[[1]]
args_all <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args_all, value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else getwd()
source(file.path(script_dir, "report_validation.R"), local = TRUE)
source(file.path(script_dir, "report_view_model.R"), local = TRUE)
validated <- validate_report_artifacts(dir)
r <- validated$result
vm <- build_report_view_model(r)
out<-file.path(dir,"dashboard.html");if(file.exists(out)) stop("既存HTMLは上書きしない")
esc<-function(x) as.character(htmltools::htmlEscape(as.character(x)))
fmt<-function(x) if(is.null(x)||!length(x)) "保留／未算出" else if(is.numeric(x)) format(signif(x,5),trim=TRUE) else as.character(x)
table_html<-function(headers,rows) paste0('<div class="scroll"><table><thead><tr>',paste0('<th>',esc(headers),'</th>',collapse=''),'</tr></thead><tbody>',paste(vapply(rows,function(row) paste0('<tr>',paste0('<td>',vapply(row,function(x)esc(fmt(x)),character(1)),'</td>',collapse=''),'</tr>'),character(1)),collapse=''),'</tbody></table></div>')
factor_cards <- paste(vapply(vm$factors, function(factor) paste0(
  '<article class="factor"><b class="symbol">', esc(factor$symbol), '</b><div><strong>', esc(factor$name),
  '</strong><small>', esc(paste(factor$levels, collapse = " · ")), '</small></div></article>'), character(1)), collapse = '')
status_note <- if (identical(vm$status, "COMPUTED"))
  '計算済み。以下の近似状態と個別の保留を併せて確認してください。' else
  'PARTIAL_HOLD：一部の推定または推論が保留です。保留箇所を成功として解釈しないでください。'
css <- paste(readLines(file.path(script_dir, "dashboard.css"), warn = FALSE), collapse = "\n")
parts <- c('<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>3次元探索レポート</title><style>', css,
  '</style></head><body><a class="skip" href="#content">本文へ移動</a><header class="hero"><div><p class="eyebrow">EVIDENCE-DRIVEN CATEGORICAL ANALYSIS</p><h1>3次元探索レポート</h1><p>',
  esc(paste(vm$variables, collapse = ' × ')), '</p></div><span class="badge ', vm$status_class, '">', esc(vm$status), '</span></header><main id="content">',
  '<div class="metrics" aria-label="分析概要"><article><span>総度数</span><strong>', fmt(vm$total_n), '</strong></article><article><span>セル数</span><strong>', fmt(vm$n_cells), '</strong></article><article><span>候補モデル</span><strong>', length(vm$models), '</strong></article><article><span>モデル保留</span><strong>', vm$model_hold_count, '</strong></article></div>',
  '<aside class="notice ', if (vm$status_class == "hold") 'danger' else '', '" role="status"><strong>', esc(vm$status), '</strong> — ', esc(status_note), '</aside>',
  '<section><div class="section-title"><p>FACTOR MAP</p><h2>因子記号と実変数</h2></div><div class="factors">', factor_cards, '</div><p class="muted">角括弧のモデル表記（例：[AB][AC]）は、この対応を用います。数式表示機能やネットワーク接続は不要です。</p></section>',
  paste0('<p class="notice">', esc(r$decisions$scaled), '。セル比較と信用区間は探索的で、多重性を調整した確証的判定ではありません。</p>'),
  '<section class="narrative"><div class="section-title"><p>PASS 2 / REVIEWED</p><h2>分析者の考察</h2></div>', commonmark::markdown_html(paste(readLines(file.path(dir, "executive_summary.md"), warn = FALSE), collapse = '\n'), extensions = TRUE), '</section>')
modelrows <- lapply(vm$models, function(m) list(
  htmltools::HTML(paste0('<a class="model-link" href="#', m$anchor, '" data-model="', m$anchor, '">', esc(m$id), '</a>')),
  m$structure, m$status, m$deviance, m$df, m$bic, m$inference$log_p_value))
table_html_raw <- function(headers, rows) paste0('<div class="scroll"><table><thead><tr>', paste0('<th>', esc(headers), '</th>', collapse=''), '</tr></thead><tbody>', paste(vapply(rows, function(row) paste0('<tr>', paste0('<td>', vapply(row, function(x) if (inherits(x, "html")) as.character(x) else esc(fmt(x)), character(1)), '</td>', collapse=''), '</tr>'), character(1)), collapse=''), '</tbody></table></div>')
model_details <- paste(vapply(seq_along(vm$models), function(i) {
  m <- vm$models[[i]]
  warning_text <- c(unlist(m$status_reasons), unlist(m$warnings), m$inference$reason)
  if (!length(warning_text)) warning_text <- "個別警告なし"
  highlight <- if (!is.null(vm$lowest_bic_id) && identical(m$id, vm$lowest_bic_id)) '<span class="tag">適格モデル中で最小BIC</span>' else ''
  paste0('<details class="model-detail" id="', m$anchor, '"', if (i == 1L) ' open' else '', '><summary><span tabindex="-1" class="model-heading">', esc(m$id), ' · <code>', esc(m$structure), '</code></span>', highlight, '<span class="badge ', if (identical(m$status,"REGULAR")) 'computed' else 'hold', '">', esc(m$status), '</span></summary><div class="detail-grid"><p><b>構造</b><code>', esc(m$structure), '</code></p><p><b>適合式</b><code>', esc(fmt(m$formula)), '</code></p><p><b>逸脱度 / df</b>', esc(fmt(m$deviance)), ' / ', esc(fmt(m$df)), '</p><p><b>多項 BIC(N)</b>', esc(fmt(m$bic)), '</p></div><div class="model-warning"><b>推論・警告</b><br>', esc(paste(warning_text, collapse=" / ")), '</div></details>')
}, character(1)), collapse='')
parts <- c(parts, '<section><div class="section-title"><p>MODEL STRUCTURE</p><h2>関連構造を比較する</h2></div><p>BICは固定総度数の多項尤度と自由パラメータ数を使用します。強調は「適格に適合した候補中で最小BIC」を示すだけで、真のモデルや自動的な勝者を意味しません。</p>', table_html_raw(c('モデル','構造','推定状態','逸脱度G²','残差df','多項BIC(N)','適合検定 log P'), modelrows), '<h3>候補モデルの詳細</h3>', model_details, '<details><summary>入れ子モデルの比較</summary>', table_html(c('基準→拡張','ΔG²','Δdf','ΔG²/N','近似log BF','log P','近似状態'), lapply(r$comparisons,function(x)list(x$id,x$delta_g2,x$delta_rank,x$delta_g2_per_n,x$log_bf_bic_approx,x$inference$log_p_value,x$approximation_status))), '</details><p class="notice">log Pはカイ二乗による漸近値です。BIC差による近似log BFを厳密BFやモデル事後確率と同一視しません。</p></section>')
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
parts<-c(parts,table_html(c('事前総集中度','厳密log BF'),lapply(post$sensitivity,function(x)list(x$total_alpha,x$exact_bf$log_bf_sat_over_ind))),'<p>95%区間は点ごとの等裾信用区間です。事前感度の条件付き結果とMonte Carlo精度はJSONに保存しています。ベイズ推定も標本サイズと事前分布の影響を受けます。</p></section><section><h2>品質確認・限界・再現情報</h2>',commonmark::markdown_html(paste(readLines(file.path(dir,"quality_check.md"),warn=FALSE),collapse='\n'),extensions=TRUE),paste0('<p>入力SHA-256: <code>',esc(r$provenance$input_sha256),'</code></p><p>',esc(r$provenance$r_version),' ／ ',esc(r$provenance$executed_at),'</p><p><a href="evidence_results.json">全結果JSON</a> ・ <a href="analysis_config.json">解析設定</a> ・ <a href="narrative_claims.json">考察の数値根拠</a></p></section><footer>3次元探索支援。観察された関連を因果効果と解釈しません。</footer></main>'))
parts <- c(parts, '<script>(function(){function openModel(id){var d=document.getElementById(id);if(!d)return;d.open=true;var h=d.querySelector(".model-heading");if(h){h.focus();h.scrollIntoView({block:"center"});}}document.querySelectorAll(".model-link").forEach(function(a){a.addEventListener("click",function(e){e.preventDefault();openModel(a.dataset.model);history.replaceState(null,"","#"+a.dataset.model);});a.addEventListener("keydown",function(e){if(e.key==="Enter"){e.preventDefault();openModel(a.dataset.model);}});});if(location.hash)openModel(location.hash.slice(1));})();</script></body></html>')
writeLines(parts, out, useBytes = TRUE)
message("保存: ", out)
