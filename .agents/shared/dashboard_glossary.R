# Shared dashboard glossary: common definitions + dimension-specific context.
# Emits raw HTML only. Does not recompute analysis values.

if (!exists("%||%", mode = "function", inherits = FALSE)) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

html_esc <- function(x) {
  x <- as.character(x %||% "")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

dashboard_unconfirmed <- function(x) {
  if (is.null(x)) return("未確認")
  if (is.character(x) && (length(x) == 0L || !nzchar(trimws(paste(x, collapse = ","))))) {
    return("未確認")
  }
  if (is.numeric(x) && (length(x) == 0L || any(!is.finite(x)))) return("未確認")
  x
}

dashboard_fmt_alpha <- function(alpha) {
  if (is.null(alpha) || length(alpha) != 1L || !is.finite(as.numeric(alpha))) return("未確認")
  a <- as.numeric(alpha)
  if (abs(a - 0.5) < 1e-12) return("0.5")
  if (abs(a - 1.0) < 1e-12) return("1.0")
  format(a, digits = 6, trim = TRUE)
}

dashboard_prior_name <- function(spec) {
  if (is.null(spec) || !is.list(spec)) return("未確認")
  alpha <- suppressWarnings(as.numeric(spec$alpha %||% NA_real_))
  name <- spec$name %||% NULL
  if (!is.null(name) && nzchar(as.character(name))) {
    n <- tolower(as.character(name))
    if (identical(n, "jeffreys")) return("多項Jeffreys")
    if (identical(n, "uniform") || identical(n, "laplace")) return("単体上一様（Dirichlet(1,…,1)）")
    return(as.character(name))
  }
  if (is.finite(alpha) && abs(alpha - 0.5) < 1e-12) return("多項Jeffreys")
  if (is.finite(alpha) && abs(alpha - 1.0) < 1e-12) return("単体上一様（Dirichlet(1,…,1)）")
  "未確認"
}

dashboard_prior_title <- function(spec, role_fallback) {
  role <- spec$role %||% role_fallback
  alpha_lab <- dashboard_fmt_alpha(spec$alpha)
  name_lab <- dashboard_prior_name(spec)
  if (identical(alpha_lab, "未確認") && identical(name_lab, "未確認")) {
    return(paste0(role_fallback, "（未確認）"))
  }
  sprintf("%s: %s（α = %s）", role_fallback, name_lab, alpha_lab)
}

dashboard_join_levels <- function(x) {
  if (is.null(x) || length(x) == 0L) return("未確認")
  paste(as.character(x), collapse = ", ")
}

gl_item <- function(title, def, meta = NULL, caution = NULL) {
  paste0(
    '<div class="glossary-item">',
    '<div class="glossary-item-title">', title, '</div>',
    '<div class="glossary-def">', def, '</div>',
    if (!is.null(meta)) paste0('<span class="glossary-meta"><strong>どこを見るか:</strong> ', meta, '</span>') else "",
    if (!is.null(caution)) paste0('<span class="glossary-caution"><strong>誤解しないこと:</strong> ', caution, '</span>') else "",
    '</div>'
  )
}

gl_accordion <- function(summary, items, open = FALSE) {
  paste0(
    '<details class="glossary-accordion"', if (isTRUE(open)) " open" else "", '>',
    '<summary>', summary, '</summary>',
    '<div class="glossary-body">',
    paste(items, collapse = "\n"),
    '</div></details>'
  )
}

glossary_common_header <- function(question_text) {
  paste0(
    '<div style="background:#f8fafc; border-left:4px solid #1f4d7a; padding:14px 18px; border-radius:4px; margin-bottom:18px;">',
    '<div style="font-weight:700; color:#152238; font-size:15px; margin-bottom:4px;">統計的・科学的問い:</div>',
    '<div style="color:#1e293b; font-size:14px; line-height:1.65;">', question_text, '</div>',
    '<div style="margin-top:10px; font-size:13.5px; color:#475569; border-top:1px dashed #e2e8f0; padding-top:8px; line-height:1.6;">',
    '<strong>3大利用原則:</strong> ① P値単独判定の排除（全体検定の有意差のみで実務的重要性や個別セルを判定しない） / ② 局所効果（Effect）と統計的証拠（Evidence）を分けて読む（標本数が増えると、小さな差にも強い証拠が得られる場合があります） / ③ 不確実性の明示（点推定と等裾信用区間を併せて精度を評価）',
    '</div></div>',
    '<p style="font-size:14px; color:#475569; margin-bottom:18px;">',
    '※ 各項目をクリックして開閉できます。臨床・疫学およびリアルワールドデータ分析におけるエビデンス解釈の拠り所としてご活用ください。',
    '</p>'
  )
}

glossary_axis_items <- function(ctx) {
  dim <- as.integer(ctx$dimension %||% NA_integer_)
  zero_conv <- ctx$zero_cell_convention %||% "未確認"
  candidate_rule <- ctx$candidate_rule %||% "未確認"
  base_model <- dashboard_unconfirmed(ctx$base_model_id)

  effect_def <- paste0(
    "基準モデルの期待度数 E に対する観測度数 O の局所対数効果比 λ = log(O/E)。これは倍率そのものではなく倍率の自然対数です。",
    "同じ度数構成を c 倍し、同一モデルを再適合した場合に Effect は不変です。"
  )
  effect_caution <- paste0(
    "因果効果ではありません。",
    if (identical(zero_conv, "nonfinite")) {
      " 2次元JSONでは O = 0 かつ E &gt; 0 の log(O/E) は −∞ という非有限状態として別途表現します。"
    } else if (identical(zero_conv, "continuity_0.5")) {
      " 現行3次元診断は O = 0 かつ E &gt; 0 のとき log(0.5/E) という補正値を格納します。補正値を厳密な log(O/E) として解釈しません。"
    } else {
      " ゼロセルの対数変換規約は未確認です。"
    },
    " 一般の追加標本や帰無仮説のもとで常に N 比例と断定しません。"
  )

  evid_def <- paste0(
    "レバレッジ補正スコア z = (O − E) / sqrt(E(1 − h))、T<sub>score</sub> = z<sup>2</sup>。",
    "同じ構成比で度数を c 倍し同一モデルを再適合すると、その条件で T<sub>score</sub> は c 倍です。"
  )
  evid_caution <- paste0(
    "正規／χ<sup>2</sup> 近似には帰無仮説と適切な漸近条件が必要です。h = 1 等の退化では有限な通常式を主張しません。",
    "実務的重要性を単独で証明しません。"
  )

  if (identical(dim, 2L)) {
    lev_def <- paste0(
      "2次元独立モデルでは閉形式 h<sub>ij</sub> = p<sub>i+</sub> + p<sub>+j</sub> − p<sub>i+</sub> p<sub>+j</sub> です。",
      "当該セルが分割表全体のパラメータ推定に与える潜在的な影響（てこ比）を示します。"
    )
    lev_caution <- "積項の係数は −1 です（−2 ではありません）。高レバレッジは潜在的影響であり、実際の削除影響量そのものではありません。モデル異常やデータ誤りと同一視しません。"
  } else {
    lev_def <- paste0(
      "一般の3次元モデルではハット行列 H = W<sup>1/2</sup> X (X′WX)<sup>−</sup> X′ W<sup>1/2</sup> の対角成分を用います（基準モデル: ",
      html_esc(as.character(base_model)), "）。2次元独立モデルの閉形式は流用しません。"
    )
    lev_caution <- "高レバレッジは潜在的影響であり、実際の削除影響量そのものではありません。データ異常や外れ値と同一視しません。"
  }

  stab_def <- "運用上の隔離条件: ① 観測度数 O = 0、② 期待度数 E &lt; 5.0、③ 高レバレッジ h ≥ 0.80 のいずれか。"
  stab_caution <- "E &lt; 5 や h ≥ 0.80 は運用上の隔離条件であり、近似精度を保証する定理ではありません。第三の臨床群や削除すべき不正データではありません。"

  dual_def <- paste0(
    "探索的候補抽出です。FWER / FDR は保証しません。現行の候補規約: ",
    html_esc(as.character(candidate_rule)), "。"
  )
  dual_caution <- if (identical(dim, 2L)) {
    "2次元は N ≥ 2000 を候補条件に含めます。機械的合否判定ではありません。"
  } else if (identical(dim, 3L)) {
    "現行3次元の候補式は large_n_threshold を参照しておらず、N &gt; 2000 でのみ計算されると表示しません。この計算差は本表示共通化で変更していません。"
  } else {
    "次元が未確認のため、N 閾値の有無を断定しません。"
  }

  items <- list(
    gl_item("【第1軸】Effect (局所対数効果比: log(O/E))", effect_def, ctx$section_effect %||% "局所セル診断", effect_caution),
    gl_item("【第2軸】Evidence (Leverage補正Score統計量 T_score / 対数P値)", evid_def, ctx$section_evidence %||% "局所セル診断", evid_caution),
    gl_item("【第3軸】Influence (レバレッジ h_ii)", lev_def, ctx$section_influence %||% "局所セル診断", lev_caution),
    gl_item("【第4軸】Stability (隔離条件 QUARANTINED)", stab_def, ctx$section_stability %||% "局所セル診断", stab_caution),
    gl_item("大標本 Dual-Filter 原則", dual_def, "探索候補セル", dual_caution)
  )

  if (identical(dim, 2L)) {
    items <- c(items, list(gl_item(
      "調整標準化残差 (Adjusted Standardized Residual z_ij)",
      "Haberman (1973) に基づく z<sub>ij</sub> = (O<sub>ij</sub> − E<sub>ij</sub>) / √(E<sub>ij</sub> (1 − h<sub>ii</sub>))。独立帰無仮説からの局所的乖離度です。",
      "Section 4（棒グラフ: 正の偏り #0F766E / 負の偏り #B45309）",
      "残差の統計的有意性は効果量そのものではありません。漸近正規近似には帰無仮説と適切な標本条件が必要です。"
    )))
  }
  items
}

glossary_global_2d_items <- function(ctx = list()) {
  sec_global <- ctx$section_global %||% "Section 2（全体連関構造と効果量）"
  list(
    gl_item(
      "Pearson X² 独立性検定統計量",
      "行変数と列変数の相互独立帰無仮説 (H0: π<sub>ij</sub> = π<sub>i+</sub> π<sub>+j</sub>) のもとで算出される漸近カイ二乗統計量 X<sup>2</sup> = Σ (O<sub>ij</sub> − E<sub>ij</sub>)<sup>2</sup> / E<sub>ij</sub>（自由度 (I−1)(J−1)）。",
      sec_global,
      "大標本下では微小な差異でも X<sup>2</sup> が極大化し P 値が飽和するため、臨床的・実務的効果の大きさを測る指標としては用いません。"
    ),
    gl_item(
      "Cramér's V",
      "分割表全体の連関度合いを 0〜1 で標準化した効果量指標 V = √((X<sup>2</sup> / N) / min(I−1, J−1))。",
      sec_global,
      "標本サイズ N が有限のとき上方にバイアス（過大評価傾向）を持ちます。"
    ),
    gl_item(
      "偏り補正 Cramér's Ṽ (Bergsma 2013)",
      "有限標本における自由度と標本サイズに基づく漸近バイアス低減量。",
      paste0(sec_global, "（95% CI と併記）"),
      "有限標本バイアスの低減量であり、厳密な意味での最小分散「不偏推定量」ではありません。"
    )
  )
}

glossary_ll_3d_items <- function(ctx) {
  base_model <- dashboard_unconfirmed(ctx$base_model_id)
  list(
    gl_item(
      "階層的対数線形モデル群 (M1〜M9)",
      paste0(
        "3つの因子 A, B, C の度数データに対して定義される階層構造モデル。M1: [A][B][C] 完全相互独立。",
        "M2–M4 は1対2の複合独立、M5–M7 は条件付き独立、M8 は全2因子交互作用、M9 は飽和モデルです。",
        "本解析の基準モデルID: ", html_esc(as.character(base_model)), "。"
      ),
      "対数線形モデル比較表（モデルと仮定、生成クラス）",
      "対数線形モデルは変数間の対称な連関構造をモデル化するものであり、単独で有向な因果関係を主張しません。M1〜M9 / BIC の説明は3次元に限定します。"
    ),
    gl_item(
      "総度数 N 基準の明示式 BIC",
      paste0(
        "正本はポアソン完全尤度の BIC = −2ℓ̂ + p log N です。",
        "K を同じ支持集合のセル数、df = K − p とすると BIC = (G<sup>2</sup> − df log N) + (K log N − 2ℓ<sub>sat</sub>) です。",
        "後半は同一データ・支持集合・尤度でモデル共通の定数であり、前半と絶対値は等しくありません。",
        "一般の G<sup>2</sup> = 2Σ[O log(O/E) − (O − E)] で、線形項を落とせるのは総適合度数と総観測度数が一致する場合です。"
      ),
      "対数線形モデル比較表（BIC 列、ΔBIC 列）および最良モデル要約帯",
      "順位・ΔBIC の等価性は同じデータ・支持集合・尤度に限定します。セル数 K ではなく総観測度数 N をペナルティに用いる理由は過剰パラメータ抑制であり、真の独立の証明ではありません。"
    ),
    gl_item(
      "セル追加モデルの局所改善量",
      "基準モデルにセル固有の追加項を許して再適合する場合、ΔG²は適合改善、ΔBIC = ΔG² − Δp log N は明示した入れ子モデル間のBIC改善を表します。Rao scoreは基準適合だけから同じ追加方向を検定する統計量です。",
      "セル診断の数理解説",
      "旧Evidence Score（残差二乗から罰則を引く式）と同一ではありません。局所BIC差は正確なセルBayes factor、多重性調整、実務的重要性を表さず、境界・ランク不足・探索後解釈の限界があります。"
    ),
    gl_item(
      "相対評価の原則 (Principle of Relative Evaluation)",
      "最良モデル（BIC 最小モデル）の採択は、提示された候補モデル集合（M1〜M9）の中での相対的な優位性を示すものです。",
      "最良モデル表示帯の注記、次点モデルとの ΔBIC",
      "最良モデルに選定されたことは、真の独立性や因果メカニズムが成立していることを証明しません。"
    )
  )
}

glossary_bayes_items <- function(ctx) {
  dim <- as.integer(ctx$dimension %||% NA_integer_)
  primary <- ctx$prior %||% NULL
  sensitivity <- ctx$sensitivity_prior %||% NULL
  interval <- ctx$interval_level %||% NULL
  interval_lab <- if (!is.null(interval) && is.finite(as.numeric(interval))) {
    sprintf("%g%%", 100 * as.numeric(interval))
  } else {
    "未確認"
  }
  resp <- dashboard_unconfirmed(ctx$response_var)
  comp <- dashboard_unconfirmed(ctx$compare_var)
  strat <- dashboard_unconfirmed(ctx$stratify_var)
  num <- dashboard_join_levels(ctx$numerator_levels)
  den <- dashboard_join_levels(ctx$denominator_levels)
  support_k <- ctx$support_k %||% NULL
  k_lab <- if (!is.null(support_k) && is.finite(as.numeric(support_k))) as.character(as.integer(support_k)) else "未確認"

  primary_title <- dashboard_prior_title(primary, "主事前")
  primary_alpha <- dashboard_fmt_alpha(primary$alpha)
  primary_family <- dashboard_unconfirmed(primary$family %||% NULL)
  conc_note <- if (!identical(primary_alpha, "未確認") && !identical(k_lab, "未確認")) {
    sprintf("総事前濃度は Kα = %s × %s です。α = 0.5 でも影響が無視できるとは限りません。", k_lab, primary_alpha)
  } else {
    "総事前濃度は Kα です。α = 0.5 でも影響が無視できるとは限りません。"
  }

  jeffreys_def <- paste0(
    "Jeffreys 事前の密度は、K−1 個の自由座標で √(det I) に比例します。多項モデルでは Dirichlet(1/2,…,1/2) です。",
    "滑らかな一対一再パラメータ化に対する不変性を述べます。",
    "本成果物の主事前: 分布族 ", html_esc(as.character(primary_family)),
    "、α = ", html_esc(primary_alpha), "、名称 ", html_esc(dashboard_prior_name(primary)), "。",
    conc_note
  )
  if (identical(primary_alpha, "1.0")) {
    jeffreys_def <- paste0(
      "本成果物の主事前は Dirichlet(1,…,1)（単体上の一様、α = 1.0）です。これを Jeffreys（α = 0.5）と表示しません。",
      "単体上で一様であることと、各成分の周辺分布が一様であることは同義ではありません。",
      conc_note
    )
  } else if (identical(primary_alpha, "未確認")) {
    jeffreys_def <- paste0(
      "結果JSONに主事前αの記録がありません。推測したαは埋め込みません。",
      "Jeffreys は √(det I) に比例する事前であり、行列式そのものや局所ハールとは記載しません。"
    )
  }

  sens_title <- dashboard_prior_title(sensitivity, "感度事前")
  sens_alpha <- dashboard_fmt_alpha(sensitivity$alpha)
  sens_def <- if (identical(sens_alpha, "未確認")) {
    "感度事前の記録がありません。旧JSONの欠落を現在の既定値で補填しません。"
  } else {
    paste0(
      "対照事前 α = ", html_esc(sens_alpha), "（", html_esc(dashboard_prior_name(sensitivity)), "）との比較です。",
      if (identical(sens_alpha, "1.0")) " Dirichlet(1,…,1) は単体上で一様であり、各成分の周辺一様を意味しません。" else ""
    )
  }

  eti_def <- paste0(
    "データ・モデル・事前のもとで定まる事後分位区間です。",
    interval_lab, " なら対応する両側分位点です。本解析の区間水準: ", html_esc(interval_lab), "。"
  )

  cond_def <- if (identical(dim, 2L)) {
    paste0(
      "行条件付き P(B|A) = π<sub>ij</sub> / π<sub>i+</sub>、列条件付き P(A|B) = π<sub>ij</sub> / π<sub>+j</sub> の事後分布です。",
      "同一条件・支持集合の次の1観測に対する予測確率は E[q|data]（事後平均）であり、中央値ではありません。"
    )
  } else {
    paste0(
      "条件付き割合 q は指定した分子／分母水準のセル確率比です。",
      "応答: ", html_esc(as.character(resp)),
      " / 比較: ", html_esc(as.character(comp)),
      " / 層別: ", html_esc(as.character(strat)),
      " / 分子: ", html_esc(num),
      " / 分母: ", html_esc(den), "。",
      "次の1観測の予測確率は対応する q の事後平均であり、中央値ではありません。",
      "分母 d セル中 m セルをまとめた誘導事前は Beta(mα, (d−m)α) であり、セル α = 0.5 を常に Beta(0.5, 0.5) と同一視しません。"
    )
  }

  items <- list(
    gl_item(primary_title, jeffreys_def, ctx$section_prior %||% "事後推論",
            "「局所ハール」「過度な平滑化が起きない」とは断定しません。旧成果物のα=1.0を表示だけJeffreysへ変更しません。"),
    gl_item(sens_title, sens_def, ctx$section_sensitivity %||% "事前感度分析",
            "事前分布間で推論が変動することは自然な挙動であり、モデル誤りや解析の欠陥と自動判定しません。"),
    gl_item(
      paste0("等裾信用区間 (Equal-Tailed Interval: ", interval_lab, " ETI)"),
      eti_def,
      ctx$section_eti %||% "信用区間",
      "「真の範囲」や頻度論的被覆の保証とは呼びません。区間幅の狭さは臨床的重要性や有意性そのものではありません。"
    ),
    gl_item(
      if (identical(dim, 2L)) "条件付き事後予測確率 P(B|A) / P(A|B)" else "条件付き割合の事後要約と予測",
      cond_def,
      ctx$section_conditional %||% "条件付き確率",
      paste0(
        "条件付けの方向は因果方向ではありません。",
        "同一条件の全カテゴリを含む各ドローとその平均の和は1です（数値誤差・丸めは別）。",
        "中央値／分位点の総和は一般には1に制約されませんが、2カテゴリの連続分布では中央値が補数となり和が1となる場合があります。"
      )
    )
  )

  if (identical(dim, 2L)) {
    items <- c(items, list(gl_item(
      "独立モデルからの事後対数乖離 (Log Divergence)",
      "各ドローの log(π<sub>ij</sub> / (π<sub>i+</sub> π<sub>+j</sub>))。事後分布スケールでの独立性からの乗法的乖離です。",
      "Section 9（0 を独立基準線とする分布プロット）",
      "独立モデルそのものを適合した事後分布や観測 log(O/E) と同一視しません。0 をまたぐか否かだけで自動二値判定しません。"
    )))
  } else {
    items <- c(items, list(gl_item(
      "条件付き割合とシンプソン・パラドックス (Simpson's Paradox)",
      "周辺集計における見かけの関連が、層別変数で条件付けた場合に消失または逆転する現象です。3次元の選択モデルからのセル診断（log(O/E) 等）とは分けて解釈します。",
      "条件付き割合プロット",
      "単一の周辺集計だけで偏りがあると結論づけません。条件付けを因果方向と呼びません。"
    )))
  }
  items
}

glossary_references_items <- function(dim) {
  refs_2d <- c(
    "<li>American Statistical Association (2016). Statement on Statistical Significance and P-Values. <em>The American Statistician</em>, 70(2), 129–133.</li>",
    "<li>Agresti, A. (2013). <em>Categorical Data Analysis</em> (3rd ed.). John Wiley &amp; Sons.</li>",
    "<li>Bergsma, W. (2013). A bias-correction for Cramér's V and Tschuprow's T. <em>Journal of the Korean Statistical Society</em>, 42(3), 323–328.</li>",
    "<li>Haberman, S. J. (1973). The analysis of residuals in cross-classification tables. <em>Biometrics</em>, 29(1), 205–220.</li>",
    "<li>Pregibon, D. (1981). Logistic regression diagnostics. <em>The Annals of Statistics</em>, 9(4), 705–724.</li>",
    "<li>Rao, C. R. (1948). Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation. <em>Mathematical Proceedings of the Cambridge Philosophical Society</em>, 44(1), 50–57.</li>",
    "<li>Gelman, A., Carlin, J. B., Stern, H. S., Dunson, D. B., Vehtari, A., &amp; Rubin, D. B. (2013). <em>Bayesian Data Analysis</em> (3rd ed.). Chapman &amp; Hall/CRC.</li>"
  )
  refs_3d <- c(
    "<li>Agresti, A. (2013). <em>Categorical Data Analysis</em> (3rd ed.). John Wiley &amp; Sons.</li>",
    "<li>Haberman, S. J. (1973). The analysis of residuals in cross-classification tables. <em>Biometrics</em>, 29(1), 205–220.</li>",
    "<li>Haberman, S. J. (1974). <em>The Analysis of Frequency Data</em>. University of Chicago Press.</li>",
    "<li>Rao, C. R. (1948). Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation. <em>Mathematical Proceedings of the Cambridge Philosophical Society</em>, 44(1), 50–57.</li>",
    "<li>Schwarz, G. (1978). Estimating the dimension of a model. <em>The Annals of Statistics</em>, 6(2), 461–464.</li>",
    "<li>Pregibon, D. (1981). Logistic regression diagnostics. <em>The Annals of Statistics</em>, 9(4), 705–724.</li>",
    "<li>Gelman, A., Carlin, J. B., Stern, H. S., Dunson, D. B., Vehtari, A., &amp; Rubin, D. B. (2013). <em>Bayesian Data Analysis</em> (3rd ed.). Chapman &amp; Hall/CRC.</li>",
    "<li>Okabe, M., &amp; Ito, K. (2008). Color Universal Design (CUD) — How to make figures and presentations that are friendly to Colorblind people.</li>"
  )
  chosen <- if (identical(as.integer(dim), 3L)) refs_3d else refs_2d
  paste0('<div class="glossary-item"><ol>', paste(chosen, collapse = "\n"), "</ol></div>")
}

render_dashboard_glossary <- function(ctx) {
  if (is.null(ctx) || !is.list(ctx)) {
    stop("[ERROR] render_dashboard_glossary: 利用側コンテキストがありません。", call. = FALSE)
  }
  dim <- as.integer(ctx$dimension %||% NA_integer_)
  if (!dim %in% c(2L, 3L)) {
    stop("[ERROR] render_dashboard_glossary: dimension は 2 または 3 を明示してください。", call. = FALSE)
  }
  section_id <- ctx$section_id %||% "section-glossary"
  heading <- if (identical(dim, 2L)) {
    '<h2>Appendix — 統計用語集・方法論解説・学術リファレンス (Glossary &amp; Scientific References)</h2>'
  } else {
    '<div class="section-title">統計用語集・方法論解説・学術リファレンス (Glossary &amp; Scientific References)</div>'
  }
  question <- if (identical(dim, 2L)) {
    "本ダッシュボードで使用されている統計指標、診断アルゴリズム、および数理モデルの定義・解釈境界および学術的出典は何か？"
  } else {
    "本ダッシュボードで使用されている3次元対数線形モデル、4軸セル診断、Raoスコア検定、およびベイズDirichlet推論の定義・解釈境界および学術的出典は何か？"
  }

  parts <- list(glossary_common_header(question))
  n <- 1L
  if (identical(dim, 2L)) {
    parts <- c(parts, gl_accordion(
      sprintf('<span>%d.</span> 全体連関・効果量 (Global Association &amp; Effect Size) ── [対応: %s]', n, ctx$section_global_summary %||% "Section 2"),
      glossary_global_2d_items(ctx)
    ))
    n <- n + 1L
  }
  parts <- c(parts, gl_accordion(
    sprintf('<span>%d.</span> 局所セル診断と 4 軸フレームワーク (Four-Axis Local Cell Diagnostics)%s',
            n, if (identical(dim, 2L)) " ── [対応: Sections 3–5]" else ""),
    glossary_axis_items(ctx),
    open = identical(dim, 3L)
  ))
  n <- n + 1L
  if (identical(dim, 3L)) {
    parts <- c(parts, gl_accordion(
      sprintf('<span>%d.</span> 3次元対数線形モデル群と明示式 BIC (Hierarchical Log-Linear Models &amp; Explicit BIC)', n),
      glossary_ll_3d_items(ctx)
    ))
    n <- n + 1L
  }
  parts <- c(parts, gl_accordion(
    sprintf('<span>%d.</span> %s', n,
            if (identical(dim, 2L)) "ベイズ事後推論と不確実性 (Bayesian Posterior &amp; Uncertainty) ── [対応: Sections 6–10]"
            else "多項 Dirichlet 事後推論と条件付き確率 (Bayesian Dirichlet &amp; Conditional Inference)"),
    glossary_bayes_items(ctx)
  ))
  n <- n + 1L
  parts <- c(parts, gl_accordion(
    sprintf('<span>%d.</span> 学術リファレンス・参考文献 (Scientific References)', n),
    list(glossary_references_items(dim))
  ))

  paste0(
    '<div class="section-card" id="', html_esc(section_id), '"',
    if (identical(dim, 3L)) ' style="margin-top: 32px;"' else "", '>',
    heading,
    paste(parts, collapse = "\n"),
    "</div>"
  )
}
