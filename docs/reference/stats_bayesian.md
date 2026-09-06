# ベイズ推定とモデル比較の基礎

created: 2026-09-06 23:50 (JST)
update: 2026-09-06 23:50 (JST)
author: Codex (GPT-5)

## 1. ベイズ因子とは何か

モデル `M_0` と `M_1` のベイズ因子は、周辺尤度の比です。

\[
  BF_{10}=\frac{p(y\mid M_1)}{p(y\mid M_0)},\qquad
  p(y\mid M)=\int p(y\mid\theta,M)\,p(\theta\mid M)\,d\theta
\]

したがって、尤度だけではなく、各モデルのパラメータ事前分布に依存します。モデルの事前確率を追加すれば、モデル事後確率へ変換できますが、ベイズ因子だけでモデル事後確率にはなりません。

## 2. BIC近似と厳密BFを分ける

正則な大標本モデルでは、SchwarzのBICを使って

\[
  \log BF_{10}\approx \frac{\operatorname{BIC}_0-\operatorname{BIC}_1}{2}
\]

と近似できます。この式は、適切な尤度、自由パラメータ数、標本サイズ、正則性、モデルの入れ子関係を前提にした近似です。局所 `ΔG²` をそのままBFと呼ぶことはできません。

現行の3次元経路は次を区別します。

| 種類 | 現行の扱い |
| --- | --- |
| モデル比較のBIC近似 | 多項尤度、総度数N、パラメータ数`rank−1`で比較。正則な場合だけ近似log BFを表示 |
| 厳密BF | 明示事前の独立モデル対飽和モデルだけを解析計算 |
| セル診断 | `ΔG²`、score統計量、効果量を保存。全体BFをセルBFにしない |
| モデル事後確率 | モデル事前確率を指定していないため算出しない |

KassとRafteryは、BICがベイズ因子の粗い近似になることと、近似や事前の感度を説明しています。[Kass & Raftery (1995)](https://www.stat.cmu.edu/~kass/papers/bayesfactors.pdf)

## 3. 現行のDirichlet事後

`K`セルの確率ベクトルを `p=(p_1,...,p_K)`、総集中度を `a` として、飽和多項モデルに

\[
  p\sim\operatorname{Dirichlet}(a/K,\ldots,a/K),
  \qquad y\mid p\sim\operatorname{Multinomial}(N,p)
\]

を置くと、共役性から

\[
  p\mid y\sim\operatorname{Dirichlet}(y_1+a/K,\ldots,y_K+a/K)
\]

です。セル周辺分布はBeta分布になり、セル `i` の平均は

\[
  E[p_i\mid y]=\frac{y_i+a/K}{N+a}
\]

です。現行の主設定は `a=1`、感度設定は `a=0.1,10` です。これは教材と探索の初期設定であり、全データに対する普遍的な推奨事前ではありません。[R `Beta`公式](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/Beta.html)、[Dirichlet-Multinomial共役の解説](https://www.ccs.neu.edu/home/vip/teach/DMcourse/5_topicmodel_summ/LDA_TM/dirichlet-conjugate-prior.pdf)

### 条件付き割合

目的変数 `Y`を指定すると、説明変数の組合せ `g`ごとに、同時事後標本を分母内で再正規化して

\[
  \theta_{y\mid g}=\frac{p_{g,y}}{\sum_{y'}p_{g,y'}}
\]

を計算します。異なる層の差は同じ事後標本から計算し、依存関係を保ちます。信用区間は点ごとの95%等裾信用区間で、全セルを同時に覆う区間ではありません。

## 4. 独立対飽和の厳密log BF

現行の厳密計算は、飽和多項モデルのセルDirichlet事前と、3つの周辺分布に独立Dirichlet事前を置く相互独立モデルを比較します。多項係数の共通項を含めて周辺尤度を解析計算し、`log BF_sat_over_ind`として保存します。

セル確率に `Dirichlet(α_1,…,α_K)` を置いたときの多項周辺尤度は

\[
 p(y\mid\alpha)=
 \frac{N!}{\prod_i y_i!}
 \frac{\Gamma(\alpha_0)}{\Gamma(\alpha_0+N)}
 \prod_i\frac{\Gamma(\alpha_i+y_i)}{\Gamma(\alpha_i)},
 \qquad \alpha_0=\sum_i\alpha_i
\]

です。実装では桁あふれを避けるため、階乗とガンマ関数を対数に変換して計算します。独立モデル側も各周辺表について同じ形を使い、共通する多項係数を含めて差を取ります。

これは、指定した事前に依存する表全体の比較です。条件付き独立M5〜M7、均一連関M8、セルごとの局所仮説について厳密BFを計算済みという意味ではありません。

## 5. ベイズでも消えない問題

同じ構成比で度数を100倍すると、事後平均はほぼ同じでも信用区間は狭くなり、BFは強く変化します。人工的な複製は新しい独立情報を増やしません。標本設計が依存していれば、形式的なDirichlet計算の精密さは実質的な情報量を増やしません。

また、事前感度でBFの方向が変わることがあります。その場合は、単一のBFを決定的結論にせず、事前の意味、モデルの比較対象、効果量、次に必要なデータを説明します。

## 6. 参考文献

- Kass, R. E., & Raftery, A. E. (1995). “Bayes Factors.” *Journal of the American Statistical Association*, 90, 773–795. [PDF](https://www.stat.cmu.edu/~kass/papers/bayesfactors.pdf)
- Schwarz, G. (1978). “Estimating the Dimension of a Model.” *The Annals of Statistics*, 6, 461–464. [DOI](https://doi.org/10.1214/aos/1176344136)
- Agresti, A. (2013). *Categorical Data Analysis*, 3rd ed., Wiley. [書誌情報](https://www.wiley.com/en-us/General+%26+Introductory+Statistics/Categorical+Data+Analysis-c-ST53)
- R Core Team. `Beta`、`pchisq`、`glm`の公式マニュアル。[R statsマニュアル](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/00Index.html)
