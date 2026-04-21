# 共通統計リファレンス: ベイズ統計とエビデンス評価

このドキュメントは、ベイズ統計的手法を用いたモデル比較や、大規模データにおけるエビデンス評価（Evidence Score）の基礎概念をまとめたものです。

## 1. ベイズ因子 (Bayes Factor: $BF_{10}$)

ベイズ因子は、2つの競合するモデル（例：独立モデル $M_0$ と 関連ありモデル $M_1$）がデータを生成する尤度の比です。

### 数式（BIC近似）
計算コストを抑えるため、一般にベイズ情報量基準 (BIC) の差分を用いた近似式が利用されます。
$$\log BF_{10} \approx \frac{BIC_{M_0} - BIC_{M_1}}{2}$$

### 解釈基準 (Jeffreys Scale)
ベイズ因子の値に応じて、エビデンスの強さを以下のように言語化します（Jeffreys, 1961）。
- **$BF > 100$**: 決定的エビデンス (Decisive)
- **$30 \sim 100$**: 非常に強いエビデンス (Very Strong)
- **$10 \sim 30$**: 強いエビデンス (Strong)
- **$3 \sim 10$**: 中程度のエビデンス (Moderate)
- **$1 \sim 3$**: 弱いエビデンス (Anecdotal)

---

## 2. Evidence Score (大標本エビデンス・スコア)

サンプルサイズ ($N$) が極端に大きい場合の「P値の飽和」を防ぎ、特定のセルにおける「偏り」を評価する指標です。

### 数理的背景 ($M_0$ vs $M_1$ モデル比較)
エビデンススコアは、以下の 2 つのモデルの比較に基づいています。

1. **帰無モデル ($M_0$): 主効果（ベースライン）モデル**
    すべてのセルに共通する全体的な構造を記述します。
    $$\log(\mu_{ijk}) = \lambda + \lambda_i^A + \lambda_j^B + \lambda_k^C$$
    ($\lambda_i^A, \lambda_j^B, \lambda_k^C$ は各要因の主効果。分割表における「独立モデル」に相当)

2. **代替モデル ($M_1$): セル固有の特異効果を追加したモデル**
    特定のセル $(i, j, k)$ だけに適用されるダミー変数 $I$ と、その局所パラメータ $\delta_{ijk}$ を **1つだけ** 追加します。
    $$\log(\mu_{ijk}) = \lambda + \lambda_i^A + \lambda_j^B + \lambda_k^C + I_{(x=i, y=j, z=k)} \delta_{ijk}$$

この比較により、「全体的な傾向 ($M_0$) から見て、この特定のセルだけ特異なシグナルが出ているか」を検証します。パラメータが 1 つだけ追加されるため、BIC 近似によるペナルティはぴったり $\log(N)$ となります。

### 数式
$$\text{Evidence Score}_i = r_i^2 - k \cdot \log(N)$$
- $r_i$: ピアソン残差
- $\log(N)$: $M_1$ で追加された 1 自由度に対する BIC ペナルティ
- $k$: 多段階閾値係数

---

## 3. 拡張 BIC (Extended BIC: EBIC)

モデル空間の複雑さ（パラメータ数 $j$）に追加のペナルティ $\gamma$ を課し、特に多次元データにおける過剰適合（Overfitting）を防止する指標です。
$$\text{EBIC} = -2\log \hat{L} + j\log N + 2j\gamma\log P$$
- $P$: 変数の総数
- $\gamma \in [0, 1]$: ペナルティの強さ（通常 0.5）

### 実務的意味
- **スコアが正 ($> 0$)**: そのセルの偏りは、単なるサンプルサイズの大きさに由来する統計的ノイズを上回る「実質的なエビデンス」を持つと判断します。

---

## 参考文献
- Jeffreys, H. (1961). *Theory of Probability*. Oxford University Press.
- Kass, R. E., & Raftery, A. E. (1995). Bayes Factors. *Journal of the American Statistical Association*.
- Schwarz, G. (1978). Estimating the dimension of a model. *The Annals of Statistics*.
