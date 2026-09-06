# 対数線形ポアソンモデル族と明示式BICの数理

本ドキュメントは、多次元分割表における要因間の連関・交互作用構造を評価するための**ポアソン対数線形回帰（Poisson Log-Linear Models）**、そのパラメータ推定法、および総観測度数 $N$ を基準とした**明示式 BIC（Explicit Bayesian Information Criterion）** の数理的基礎を詳説する。

---

## 1. ポアソン対数線形モデルの定式化

### 1.1 基本モデル
分割表のセル数を $K$、各セル $i \in \{1, \dots, K\}$ における観測度数を $y_i$ とする。観測度数ベクトル $\mathbf{y} = (y_1, \dots, y_K)^T$ は互いに独立なポアソン分布に従うと仮定する：

$$y_i \sim \mathrm{Poisson}(\mu_i), \quad \mu_i = \mathbb{E}[y_i] > 0$$

対数線形モデル（Log-Linear Model）は、期待度数 $\mu_i$ の自然対数を線形予測子 $\eta_i = \mathbf{x}_i^T \boldsymbol{\beta}$ でモデル化する：

$$\ln \mu_i = \mathbf{x}_i^T \boldsymbol{\beta} = \sum_{j=1}^p x_{ij} \beta_j$$

ここで：
- $\mathbf{x}_i = (x_{i1}, \dots, x_{ip})^T$: セル $i$ のカテゴリ水準を表す計画行列（デザイン行列）の第 $i$ 行ベクトル
- $\boldsymbol{\beta} = (\beta_1, \dots, \beta_p)^T$: モデルパラメータベクトル（切片、主効果、交互作用効果）
- $X \in \mathbb{R}^{K \times p}$: 計画行列全体（$\mathrm{rank}(X) = p \le K$）

### 1.2 対数尤度関数と尤度方程式
ポアソン標本に対する対数尤度関数 $\ell(\boldsymbol{\beta})$ は以下で与えられる：

$$\ell(\boldsymbol{\beta}) = \sum_{i=1}^K \left[ y_i \ln \mu_i - \mu_i - \ln(y_i!) \right] = \sum_{i=1}^K \left[ y_i (\mathbf{x}_i^T \boldsymbol{\beta}) - \exp(\mathbf{x}_i^T \boldsymbol{\beta}) - \ln(y_i!) \right]$$

パラメータ $\boldsymbol{\beta}$ に関するスコアベクトル（勾配） $\mathbf{U}(\boldsymbol{\beta}) = \nabla_{\boldsymbol{\beta}} \ell(\boldsymbol{\beta})$ は：

$$\mathbf{U}(\boldsymbol{\beta}) = \sum_{i=1}^K (y_i - \mu_i) \mathbf{x}_i = X^T (\mathbf{y} - \boldsymbol{\mu})$$

最大尤度推定量 $\hat{\boldsymbol{\beta}}$ は、尤度方程式 $\mathbf{U}(\hat{\boldsymbol{\beta}}) = \mathbf{0}$、すなわち：

$$X^T \hat{\boldsymbol{\mu}} = X^T \mathbf{y}$$

を満たす解として得られる。これは「**モデル下での周辺合計期待値が観測周辺合計と完全に一致する**」というポアソンGLMの基本的性質（十分統計量の一致）を表す。

### 1.3 フィッシャー情報行列と推定アルゴリズム
対数尤度のヘッセ行列の期待値であるフィッシャー情報行列 $\mathcal{I}(\boldsymbol{\beta})$ は：

$$\mathcal{I}(\boldsymbol{\beta}) = -\mathbb{E}\left[ \frac{\partial^2 \ell}{\partial \boldsymbol{\beta} \partial \boldsymbol{\beta}^T} \right] = \sum_{i=1}^K \mu_i \mathbf{x}_i \mathbf{x}_i^T = X^T W X$$

ここで $W = \mathrm{diag}(\mu_1, \dots, \mu_K)$ は期待度数を対角要素とする重み行列である。最大尤度推定は、反復再重み付け最小二乗法（IRLS: Iteratively Reweighted Least Squares / Newton-Raphson 法）により解かれる：

$$\boldsymbol{\beta}^{(t+1)} = \boldsymbol{\beta}^{(t)} + \left( X^T W^{(t)} X \right)^{-1} X^T (\mathbf{y} - \boldsymbol{\mu}^{(t)})$$

---

## 2. 3元分割表における 9 候補モデル族の体系

3つの要因 $A$（水準数 $I$）、$B$（水準数 $J$）、$C$（水準数 $K$）からなる 3元クロス表（全セル数 $K_{\rm total} = I \times J \times K$）において、ポアソン対数線形モデルは階層的に 9 つの代表モデル族を形成する。

$$\ln \mu_{ijk} = \lambda + \lambda_i^A + \lambda_j^B + \lambda_k^C + \lambda_{ij}^{AB} + \lambda_{ik}^{AC} + \lambda_{jk}^{BC} + \lambda_{ijk}^{ABC}$$

| モデルID | モデル名 | 記号モデル式 | 含まれる項 | 統計的意味 |
| :---: | :--- | :--- | :--- | :--- |
| **M1** | 相互独立モデル | $[A][B][C]$ | $\lambda + \lambda^A + \lambda^B + \lambda^C$ | 3要因すべてが互いに完全に独立 |
| **M2** | 1組連関モデル (AB) | $[AB][C]$ | 主効果 $+ \lambda^{AB}$ | $A$ と $B$ は関連し、$C$ は $(A, B)$ と独立 |
| **M3** | 1組連関モデル (AC) | $[AC][B]$ | 主効果 $+ \lambda^{AC}$ | $A$ と $C$ は関連し、$B$ は $(A, C)$ と独立 |
| **M4** | 1組連関モデル (BC) | $[A][BC]$ | 主効果 $+ \lambda^{BC}$ | $B$ と $C$ は関連し、$A$ は $(B, C)$ と独立 |
| **M5** | 条件付き独立モデル (BC\|A) | $[AB][AC]$ | 主効果 $+ \lambda^{AB} + \lambda^{AC}$ | $A$ を与えたとき $B$ と $C$ が条件付き独立 |
| **M6** | 条件付き独立モデル (AC\|B) | $[AB][BC]$ | 主効果 $+ \lambda^{AB} + \lambda^{BC}$ | $B$ を与えたとき $A$ と $C$ が条件付き独立 |
| **M7** | 条件付き独立モデル (AB\|C) | $[AC][BC]$ | 主効果 $+ \lambda^{AC} + \lambda^{BC}$ | $C$ を与えたとき $A$ と $B$ が条件付き独立 |
| **M8** | 均一関連モデル | $[AB][AC][BC]$ | 主効果 $+ \lambda^{AB} + \lambda^{AC} + \lambda^{BC}$ | すべての2元交互作用が存在（3元交互作用なし） |
| **M9** | 飽和モデル | $[ABC]$ | 全項（3元交互作用 $\lambda^{ABC}$ 含む） | 完全適合モデル（$\hat{\mu}_{ijk} = y_{ijk}$） |

---

## 3. 逸脱度（Deviance）とモデル適合度

モデル $M$ の適合度は、飽和モデル（Saturated Model）の最大対数尤度 $\ell_{\rm sat}$ とモデル $M$ の最大対数尤度 $\ell_M$ の比に基づく**逸脱度（Deviance: $G^2$）** によって評価される：

$$G^2(M) = 2 \left[ \ell_{\rm sat} - \ell_M \right] = 2 \sum_{i=1}^K y_i \ln\left( \frac{y_i}{\hat{\mu}_i} \right)$$

ここで、観測値 $y_i = 0$ のセルについては極限 $\lim_{y \to 0} y \ln y = 0$ を適用する。

### 漸近分布
モデル $M$ が真のモデルである帰無仮説の下で、サンプルサイズ $N = \sum_i y_i \to \infty$ のとき、逸脱度 $G^2(M)$ は漸近的に自由度 $\nu_M$ のカイ二乗分布に従う：

$$G^2(M) \overset{d}{\longrightarrow} \chi^2(\nu_M), \quad \nu_M = K - p_M$$

ここで $p_M = \mathrm{rank}(X_M)$ はモデル $M$ で推定された独立パラメータ数である。

---

## 4. 総度数 $N$ 基準の明示式 BIC

### 4.1 なぜ標準の BIC() では破綻するのか？
Rの標準関数 `stats::BIC(model)` は、GLMオブジェクトの行数 $n_{\rm obs}$ を標本サイズとして用いる：

$$\mathrm{BIC}_{\rm R\_default} = G^2 + p \cdot \ln(K)$$

しかし、分割表データにおいて行数 $K$ は単なるカテゴリの組み合わせ数（例：タイタニックなら 16、HairEyeColor なら 32）であり、真の観測標本サイズではない。真の標本サイズは全セルの総観測度数 $N = \sum_{i=1}^K y_i$（数千〜数十万件）である。
行数 $K$ を標本サイズと見なすと、ペナルティ項 $\ln(K)$ が真のペナルティ $\ln(N)$ に比べて極端に小さくなり、**複雑な過剰適合モデルが誤って採択される致命的なバイアス**が生じる。

### 4.2 明示式 BIC の定義式
本分析基盤では、総観測度数 $N$ を正確に反映した明示式 BIC（Explicit BIC、ポアソン対数尤度基準）を採用する：

$$\mathrm{BIC}(M) = -2 \ln L(M) + p_M \cdot \ln(N)$$

- $\ln L(M) = \sum_{i=1}^K \left[ y_i \ln \hat{\mu}_i - \hat{\mu}_i - \ln(y_i!) \right]$: モデル $M$ の最大対数尤度（ポアソン分布）
- $p_M = \mathrm{rank}(X_M)$: モデル $M$ で推定されたパラメータ数（自由度消費数）
- $N = \sum_{i=1}^K y_i$: 分割表全体の総観測度数

#### 数値的一致の検証（タイタニック M1 の例）
- 対数尤度: $\ln L = -557.00 \implies -2 \ln L = 1114.00$
- パラメータ数: $p = 6$（各要因の主効果）
- 標本サイズペナルティ: $p \cdot \ln(N) = 6 \cdot \ln(2201) = 6 \times 7.6967 = 46.18$
- $\mathrm{BIC}(M_1) = 1114.00 + 46.18 = 1160.1817$
これはコードの出力値および検証値（$1160.18$）と小数点第4位まで厳密に一致する。

### 4.3 最良モデル選択（$\Delta\mathrm{BIC}$）
候補モデル集合 $\{M_1, \dots, M_9\}$ の中で、BIC が最小となるモデルを最良モデル $M^*$ とする：

$$M^* = \arg\min_{M \in \{M_1, \dots, M_9\}} \mathrm{BIC}(M)$$

各モデルの相対的劣後度は、最良モデルからの差分 $\Delta\mathrm{BIC}$ によって定量化される：

$$\Delta\mathrm{BIC}(M) = \mathrm{BIC}(M) - \mathrm{BIC}(M^*)$$

- $\Delta\mathrm{BIC} \le 2$: 実質的な支持（Substantial support）
- $4 \le \Delta\mathrm{BIC} \le 7$: 明確に劣る支持（Considerably less support）
- $\Delta\mathrm{BIC} > 10$: 決定的劣後・支持なし（Essentially no support, Burnham & Anderson, 2002）

---

## 5. ベイズ因子（Bayes Factor）の BIC 近似

2つの競合する対数線形モデル $M_0$（帰無モデル、例：相互独立モデル M1）と $M_1$（代替モデル、例：最良モデルまたは飽和モデル）の間のベイズ因子 $\mathrm{BF}_{10}$ は、各モデルの周辺尤度 $p(\mathbf{y} \mid M_m)$ の比として定義される：

$$\mathrm{BF}_{10} = \frac{p(\mathbf{y} \mid M_1)}{p(\mathbf{y} \mid M_0)}$$

ラプラス近似（Schwarz, 1978; Kass & Raftery, 1995）により、総度数 $N$ を基準とした明示式 BIC の差分から、対数ベイズ因子は極めて高精度に近似される：

$$\ln \mathrm{BF}_{10} \approx -\frac{1}{2} \left[ \mathrm{BIC}(M_1) - \mathrm{BIC}(M_0) \right] = \frac{\mathrm{BIC}(M_0) - \mathrm{BIC}(M_1)}{2}$$

### Jeffreys のエビデンス解釈基準 (Jeffreys Scale)

| $\mathrm{BF}_{10}$ | $\ln \mathrm{BF}_{10}$ | $M_1$（代替モデル）を支持する証拠の強さ |
| :---: | :---: | :--- |
| **$< 1$** | $< 0$ | $M_0$（帰無モデル・独立性）を支持 |
| **$1 \sim 3$** | $0 \sim 1.1$ | 弱い証拠（Anecdotal / Barely worth mentioning） |
| **$3 \sim 10$** | $1.1 \sim 2.3$ | 中程度の証拠（Substantial / Moderate） |
| **$10 \sim 30$** | $2.3 \sim 3.4$ | 強い証拠（Strong） |
| **$30 \sim 100$** | $3.4 \sim 4.6$ | 非常に強い証拠（Very Strong） |
| **$> 100$** | $> 4.6$ | **決定的な証拠（Decisive）** |

---

## 参考文献
- Agresti, A. (2013). *Categorical Data Analysis* (3rd ed.). John Wiley & Sons.
- Burnham, K. P., & Anderson, D. R. (2002). *Model Selection and Multimodel Inference: A Practical Information-Theoretic Approach* (2nd ed.). Springer.
- Kass, R. E., & Raftery, A. E. (1995). Bayes Factors. *Journal of the American Statistical Association*, 90(430), 773–795.
- McCullagh, P., & Nelder, J. A. (1989). *Generalized Linear Models* (2nd ed.). Chapman & Hall/CRC.
- Schwarz, G. (1978). Estimating the dimension of a model. *The Annals of Statistics*, 6(2), 461–464.
