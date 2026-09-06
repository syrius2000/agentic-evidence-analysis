# ベイズ推定とモデル比較の数理リファレンス

created: 2026-09-06 23:50 (JST)
update: 2026-09-07 00:35 (JST)
author: Codex (GPT-5) / Antigravity

この文書は、カテゴリカルデータ分析におけるベイズ推論、モデル比較、および事後不確実性評価の数理的基礎を解説する正本リファレンスです。

---

## 1. ベイズ因子（Bayes Factor）の数学的定義

競合する 2 つの統計モデル $M_0$（帰無モデル/単純モデル）と $M_1$（対立モデル/複雑モデル）のベイズ因子 $BF_{10}$ は、観測データ $y$ が得られた下での**周辺尤度（Marginal Likelihood / Integrated Likelihood）の比**として厳密に定義されます（Kass & Raftery, 1995）：

\[
  BF_{10} = \frac{p(y \mid M_1)}{p(y \mid M_0)}
\]

各モデル $M_m$ ($m \in \{0, 1\}$) の周辺尤度は、パラメータ空間 $\Theta_m$ におけるパラメータ事前分布 $p(\theta_m \mid M_m)$ に関する積分によって得られます：

\[
  p(y \mid M_m) = \int_{\Theta_m} p(y \mid \theta_m, M_m) \, p(\theta_m \mid M_m) \, d\theta_m
\]

モデル事前確率 $P(M_0), P(M_1)$ が与えられた場合、ベイズの定理によりモデル事後オッズは次のように更新されます：

\[
  \frac{P(M_1 \mid y)}{P(M_0 \mid y)} = BF_{10} \times \frac{P(M_1)}{P(M_0)}
\]

> [!NOTE]
> ベイズ因子は「データがどちらのモデルを何倍強く支持しているか」を表す相対的証拠強度であり、モデル事前確率を仮定しない限り、単体では「モデルが正しい確率（事後確率）」を意味しません。

---

## 2. 大標本 BIC 近似と厳密ベイズ因子の区別

### 2.1 Schwarz の BIC 近似（大標本極限）
パラメータ次元が正則で、事前分布が真値の近傍で平坦であり、標本サイズ $N$ が十分に大きいとき、ラプラス近似（Laplace approximation）により対数周辺尤度は次のように展開されます（Schwarz, 1978; Kass & Raftery, 1995）：

\[
  \log p(y \mid M) = \ell(\hat{\theta}) - \frac{p}{2} \log N + \mathcal{O}(1) = -\frac{1}{2} \mathrm{BIC}_{\mathrm{explicit}} + \mathcal{O}(1)
\]

したがって、2 モデル間の対数ベイズ因子 $\log BF_{10}$ は BIC の差分によって漸近近似されます：

\[
  \log BF_{10} \approx \frac{\mathrm{BIC}_0 - \mathrm{BIC}_1}{2}
\]

### 2.2 本ツールキットにおける比較の厳格な区分
本分析基盤では、モデル比較とセル診断において以下の峻別を行っています：

| 比較・診断の種別 | 算出方法・統計的性質 | 解釈上の制約 |
| :--- | :--- | :--- |
| **全 9 モデル間の BIC 比較** | 総度数 $N$ 基準の明示式 $\mathrm{BIC}_{\mathrm{explicit}} = -2\ln L + p\ln N$ | 大標本・正則条件下での粗い log BF 近似 |
| **独立対飽和の厳密ベイズ因子** | Dirichlet 事前分布に基づく解析的周辺尤度比（後述） | 明示された Dirichlet 事前分布に依存 |
| **セル診断（局所 $\Delta G_i^2$）** | セルダミー追加モデルの尤度比統計量 | 局所尤度比改善。大域 BF をセルへ転用しない |
| **セルスコア検定（$T_i^{\rm score}$）** | Rao (1948) の局所スコア検定統計量 $\frac{r_{P,i}^2}{1-h_{ii}}$ | 局所的な帰無仮説（$H_0: \text{局所効果}=0$）の検定 |

---

## 3. 多項 Dirichlet 事後推論（Multinomial Dirichlet Inference）

### 3.1 共役事前分布と事後分布の解析的導出
$K$ 個の離散セルからなる多項表において、セル生起確率ベクトルを $\boldsymbol{\pi} = (\pi_1, \ldots, \pi_K)^T$（ただし $\sum_{i=1}^K \pi_i = 1$）、観測度数ベクトルを $\boldsymbol{y} = (y_1, \ldots, y_K)^T$（総度数 $N = \sum y_i$）とします。

共役事前分布として、ハイパーパラメータ $\boldsymbol{\alpha} = (\alpha_1, \ldots, \alpha_K)^T$（総集中度 $\alpha_0 = \sum \alpha_i$）を持つ Dirichlet 分布を仮定します（Good, 1965; Gelman et al., 2013）：

\[
  p(\boldsymbol{\pi} \mid \boldsymbol{\alpha}) = \frac{\Gamma(\alpha_0)}{\prod_{i=1}^K \Gamma(\alpha_i)} \prod_{i=1}^K \pi_i^{\alpha_i - 1}
\]

尤度関数が多項分布 $p(\boldsymbol{y} \mid \boldsymbol{\pi}) = \frac{N!}{\prod y_i!} \prod \pi_i^{y_i}$ であるため、Dirichlet-Multinomial 共役性により事後分布は再び同一族の Dirichlet 分布となります：

\[
  p(\boldsymbol{\pi} \mid \boldsymbol{y}) = \operatorname{Dirichlet}(\boldsymbol{y} + \boldsymbol{\alpha}) = \frac{\Gamma(N + \alpha_0)}{\prod_{i=1}^K \Gamma(y_i + \alpha_i)} \prod_{i=1}^K \pi_i^{y_i + \alpha_i - 1}
\]

### 3.2 周辺 Beta 分布と事後期待値
各セル $i$ の周辺事後分布は、他のセル確率を積分消去することで Beta 分布に従います：

\[
  \pi_i \mid \boldsymbol{y} \sim \operatorname{Beta}\left(y_i + \alpha_i, \; N - y_i + \alpha_0 - \alpha_i\right)
\]

セル確率 $\pi_i$ の事後期待値（事後平均）は次式で与えられます：

\[
  \mathbb{E}[\pi_i \mid \boldsymbol{y}] = \frac{y_i + \alpha_i}{N + \alpha_0}
\]

これは、最尤推定量 $\hat{\pi}_i = y_i / N$ と事前期待値 $\alpha_i / \alpha_0$ の凸結合（加重平均）であり、総度数 $N$ が大きくなるにつれてデータ（最尤推定量）へ収束する平滑化（shrinkage）特性を持ちます。

### 3.3 条件付き割合の同時事後サンプリング
目的変数 $Y$（水準 $y$）と説明変数層 $G$（組合せ $g$）が指定された場合、各層 $g$ における条件付き確率：

\[
  \theta_{y \mid g} = \frac{\pi_{g, y}}{\sum_{y'} \pi_{g, y'}}
\]

を評価します。同時事後分布 $\operatorname{Dirichlet}(\boldsymbol{y} + \boldsymbol{\alpha})$ からのモンテカルロ・サンプリング（Monte Carlo draws）により、層間差 $\Delta \theta = \theta_{y \mid g_1} - \theta_{y \mid g_2}$ の完全な事後分布を標本化し、95% 等裾信用区間（Equal-Tailed Interval: ETI）および最高事後密度区間（Highest Posterior Density Interval: HDI）を導出します。

---

## 4. 独立モデル対飽和モデルの解析的厳密ベイズ因子

完全相互独立モデル $M_1$（各周辺分布に独立な Dirichlet 事前分布を置くモデル）と飽和モデル $M_9$（全セル同時 Dirichlet 事前分布を置くモデル）の比較において、周辺尤度は解析的に積分可能です。

飽和モデル $M_9$ の多項周辺尤度は次式で与えられます：

\[
  p(\boldsymbol{y} \mid M_9) = \frac{N!}{\prod_{i,j,k} n_{ijk}!} \cdot \frac{\Gamma(\alpha_0)}{\Gamma(N + \alpha_0)} \prod_{i,j,k} \frac{\Gamma(n_{ijk} + \alpha_{ijk})}{\Gamma(\alpha_{ijk})}
\]

独立モデル $M_1$ の周辺尤度は、周辺度数 $n_{i\cdot\cdot}, n_{\cdot j\cdot}, n_{\cdot\cdot k}$ に対する周辺 Dirichlet-Multinomial の積として表現されます。多項係数 $\frac{N!}{\prod n_{ijk}!}$ は共通因子として相殺され、厳密な対数ベイズ因子 $\log BF_{91} = \log p(\boldsymbol{y} \mid M_9) - \log p(\boldsymbol{y} \mid M_1)$ が対数ガンマ関数 `lgamma()` を用いて桁あふれなく計算されます。

---

## 5. Freeman-Tukey 統計量による事後予測チェック（PPP-value）

モデルの過分散（overdispersion）や系統的乖離を診断するため、事後予測チェック（Posterior Predictive Check: PPC）を実施します（Gelman et al., 2013）。

セル観測度数 $y_i$ と事後予測度数 $y_i^{\mathrm{rep}}$ に対して、平方根変換により分散を安定化させた Freeman-Tukey 逸脱統計量を定義します（Freeman & Tukey, 1950）：

\[
  T(y, \pi) = \sum_{i=1}^K \left( \sqrt{y_i} - \sqrt{N \pi_i} \right)^2
\]

事後予測 P 値（Posterior Predictive P-value: PPP-value）は、事後標本から生成された仮想データ $y^{\mathrm{rep}}$ の統計量が観測データの統計量を超える確率として算出されます：

\[
  \mathrm{PPP} = \Pr\left( T(y^{\mathrm{rep}}, \pi) \ge T(y, \pi) \mid \boldsymbol{y} \right)
\]

$\mathrm{PPP} \approx 0.50$ はモデルが完全適合していることを示し、$0.05$ 未満または $0.95$ 超の極端な値は、事前分布の不整合やモデルの不適合（過少適合または過適合）を示唆します。

---

## 6. 参考文献（Primary Literature）

1. **Kass, R. E., & Raftery, A. E. (1995)**. "Bayes factors." *Journal of the American Statistical Association*, 90(430), 773–795. [DOI:10.1080/01621459.1995.10476572](https://doi.org/10.1080/01621459.1995.10476572)
2. **Schwarz, G. (1978)**. "Estimating the dimension of a model." *The Annals of Statistics*, 6(2), 461–464. [DOI:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)
3. **Good, I. J. (1965)**. *The Estimation of Probabilities: An Essay on Modern Bayesian Methods*. Research Monograph No. 30, The M.I.T. Press, Cambridge, Massachusetts.
4. **Gelman, A., Carlin, J. B., Stern, H. S., Dunson, D. B., Vehtari, A., & Rubin, D. B. (2013)**. *Bayesian Data Analysis* (3rd ed.). Chapman and Hall/CRC, Boca Raton, Florida. [ISBN:978-1-4398-4095-5](https://www.routledge.com/Bayesian-Data-Analysis/Gelman-Carlin-Stern-Dunson-Vehtari-Rubin/p/book/9781439840955)
5. **Freeman, M. F., & Tukey, J. W. (1950)**. "Transformations related to the angular and the square root." *The Annals of Mathematical Statistics*, 21(4), 607–611. [DOI:10.1214/aoms/1177729756](https://doi.org/10.1214/aoms/1177729756)
6. **Agresti, A. (2013)**. *Categorical Data Analysis* (3rd ed.). John Wiley & Sons, Hoboken, New Jersey.
