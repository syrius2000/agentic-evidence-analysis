# ベイズDirichlet事後推論とモデル診断の数理

本ドキュメントは、多次元分割表における**ベイズ的多項・Dirichlet共役モデル（Multinomial-Dirichlet Conjugate Model）**、層別条件付き割合差の事後推論、および **Freeman-Tukey 統計量に基づく事後予測チェック（Posterior Predictive Checks: PPC）** の数理的基盤を詳述する。

---

## 1. 多項・Dirichlet 共役モデルの定式化

### 1.1 尤度関数（多項分布）
セル数 $K$ の分割表における総観測度数を $N = \sum_{i=1}^K y_i$ とする。観測度数ベクトル $\mathbf{y} = (y_1, \dots, y_K)^T$ は、セル生起確率ベクトル $\boldsymbol{\theta} = (\theta_1, \dots, \theta_K)^T$（ただし $\theta_i \ge 0, \sum_{i=1}^K \theta_i = 1$）をパラメータとする多項分布に従う：

$$p(\mathbf{y} \mid \boldsymbol{\theta}) = \frac{N!}{\prod_{i=1}^K y_i!} \prod_{i=1}^K \theta_i^{y_i}$$

### 1.2 事前分布（Dirichlet 分布）
生起確率ベクトル $\boldsymbol{\theta}$ に対する共役事前分布として、ハイパーパラメータ $\boldsymbol{\alpha} = (\alpha_1, \dots, \alpha_K)^T$（$\alpha_i > 0$）を持つ Dirichlet 分布を採用する：

$$p(\boldsymbol{\theta} \mid \boldsymbol{\alpha}) = \frac{1}{\mathrm{B}(\boldsymbol{\alpha})} \prod_{i=1}^K \theta_i^{\alpha_i - 1}$$

ここで多変量ベータ関数 $\mathrm{B}(\boldsymbol{\alpha})$ は：

$$\mathrm{B}(\boldsymbol{\alpha}) = \frac{\prod_{i=1}^K \Gamma(\alpha_i)}{\Gamma(\alpha_0)}, \quad \alpha_0 = \sum_{i=1}^K \alpha_i$$

標準分析パイプラインでは、情報を持たない対称事前分布（無情報事前分布）として Jeffreys 事前分布（$\alpha_i = 0.5$）または一様事前分布（$\alpha_i = 1.0$）を採用する。

### 1.3 事後分布
尤度と事前分布の積より、事後分布 $p(\boldsymbol{\theta} \mid \mathbf{y})$ も再び Dirichlet 分布となる（共役性）：

$$\boldsymbol{\theta} \mid \mathbf{y} \sim \mathrm{Dirichlet}(\boldsymbol{\alpha}^*), \quad \boldsymbol{\alpha}^* = \boldsymbol{\alpha} + \mathbf{y} = (\alpha_1 + y_1, \dots, \alpha_K + y_K)^T$$

更新された総パラメータを $\alpha_0^* = \sum_{i=1}^K \alpha_i^* = \alpha_0 + N$ とする。

---

## 2. 事後統計量の解析解

Dirichlet 事後分布の性質より、任意のセル $i, j$ の事後平均、分散、共分散は解析的に厳密に求まる：

### 2.1 事後平均
$$\mathbb{E}[\theta_i \mid \mathbf{y}] = \frac{\alpha_i^*}{\alpha_0^*} = \frac{\alpha_i + y_i}{\alpha_0 + N}$$
これは事前平均と最尤推定量 $\hat{\theta}_i = y_i / N$ の重み付き凸結合（Shrinkage 推定）である。

### 2.2 事後分散
$$\mathrm{Var}(\theta_i \mid \mathbf{y}] = \frac{\alpha_i^* (\alpha_0^* - \alpha_i^*)}{(\alpha_0^*)^2 (\alpha_0^* + 1)}$$

### 2.3 事後共分散
$$\mathrm{Cov}(\theta_i, \theta_j \mid \mathbf{y}] = -\frac{\alpha_i^* \alpha_j^*}{(\alpha_0^*)^2 (\alpha_0^* + 1)} \quad (i \neq j)$$

---

## 3. 層別条件付き割合と割合差の推論

### 3.1 条件付き確率の定義
要因 $A$（水準 $i$）、要因 $B$（水準 $j$）、応答要因 $Y$（水準 $k$）からなる 3元表において、サブグループ $(A=i, B=j)$ を与えたときの応答 $Y=k$ の条件付き生起確率は：

$$\theta_{k \mid i, j} = \frac{\theta_{ijk}}{\sum_{l} \theta_{ijl}}$$

### 3.2 2群間の条件付き割合差（Risk Difference）
2つのサブグループ（例：要因 $A$ の水準 $i_1$ と $i_2$、要因 $B$ は同一水準 $j$）における応答 $Y=k$（例：生存率など）の差分パラメータ $\Delta$ は：

$$\Delta = \theta_{k \mid i_1, j} - \theta_{k \mid i_2, j}$$

この差分パラメータ $\Delta$ の事後分布は、比率の差であるため閉形式の初等関数では表せないが、モンテカルロ法により極めて容易かつ厳密にサンプリング可能である。

### 3.3 モンテカルロ積分と較正基準
事後分布 $\boldsymbol{\theta}^{(s)} \sim \mathrm{Dirichlet}(\boldsymbol{\alpha}^*)$（$s = 1, \dots, S$、$S = 20,000$ ドロー）から各ドローにおいて条件付き確率と差分 $\Delta^{(s)}$ を計算する：

1. **事後平均推定量**:
   $$\hat{\mu}_\Delta = \frac{1}{S} \sum_{s=1}^S \Delta^{(s)}$$
2. **95% 等裾信用区間（Equal-Tailed Credible Interval）**:
   $$\left[ \Delta_{(0.025 \cdot S)}, \ \Delta_{(0.975 \cdot S)} \right]$$
3. **優越事後確率（Posterior Probability of Superiority）**:
   $$P(\Delta > 0 \mid \mathbf{y}) = \frac{1}{S} \sum_{s=1}^S \mathbf{1}_{\{ \Delta^{(s)} > 0 \}}$$

#### モンテカルロ標準誤差（MCSE）の較正ルール
$S = 20,000$ ドローにおける推定量平均のモンテカルロ標準誤差は：
$$\mathrm{MCSE}(\hat{\mu}_\Delta) = \frac{\mathrm{SD}(\Delta)}{\sqrt{S}} \le \frac{1}{2 \sqrt{20,000}} \approx 0.0035$$
本分析基盤の単体テスト（Section 5）では、$3 \times \mathrm{MCSE}$ 基準および二項カバレッジ標準誤差の $3\sigma$ 境界を用いた自動較正（Calibration）をパスすることを義務付けている。

---

## 4. Freeman-Tukey 統計量による事後予測チェック（PPC）

事後予測チェック（Posterior Predictive Check: Gelman et al., 2013）は、「当てはめたモデルが、観測されたデータと類似した複製データを生成できるか」を検証する総合的な適合度診断法である。

### 4.1 Freeman-Tukey 逸脱統計量
ポアソン・多項データにおいて、外れ値や小度数セルに対する頑健性に優れた Freeman-Tukey 変換統計量を採用する：

$$T(\mathbf{y}, \boldsymbol{\theta}) = \sum_{i=1}^K \left( \sqrt{y_i} - \sqrt{N \theta_i} \right)^2$$

### 4.2 複製データの生成と事後予測 P 値（PPP-value）
各事後ドロー $\boldsymbol{\theta}^{(s)}$ に対して、モデルから新たな観測データ（複製データ）$\mathbf{y}^{\rm rep,(s)}$ を生成する：

$$\mathbf{y}^{\rm rep,(s)} \sim \mathrm{Multinomial}(N, \boldsymbol{\theta}^{(s)})$$

そして、観測データに対する統計量 $T(\mathbf{y}, \boldsymbol{\theta}^{(s)})$ と複製データに対する統計量 $T(\mathbf{y}^{\rm rep,(s)}, \boldsymbol{\theta}^{(s)})$ を比較する。

事後予測 P 値（Posterior Predictive P-value: PPP）は以下で定義される：

$$\mathrm{PPP} = \frac{1}{S} \sum_{s=1}^S \mathbf{1}_{\left\{ T(\mathbf{y}^{\rm rep,(s)}, \boldsymbol{\theta}^{(s)}) \ge T(\mathbf{y}, \boldsymbol{\theta}^{(s)}) \right\}}$$

- $\mathrm{PPP} \approx 0.5$：モデルが観測データを理想的に説明している。
- $\mathrm{PPP} < 0.05$ または $\mathrm{PPP} > 0.95$：モデルが系統的な歪みや過剰分散を抱えている兆候。

---

## 5. Dirichlet-多項式モデルにおける厳密周辺尤度とベイズ因子

事前分布 $\boldsymbol{\theta} \sim \mathrm{Dirichlet}(\boldsymbol{\alpha})$ の下で、パラメータ $\boldsymbol{\theta}$ を積分消去したデータ $\mathbf{y}$ の厳密周辺尤度（Marginal Likelihood）は、ディリクレ多項分布（Dirichlet-Compound Multinomial）として閉形式で得られる：

$$p(\mathbf{y} \mid \boldsymbol{\alpha}) = \int_{\mathcal{S}_K} p(\mathbf{y} \mid \boldsymbol{\theta}) p(\boldsymbol{\theta} \mid \boldsymbol{\alpha}) d\boldsymbol{\theta} = \frac{N!}{\prod_{i=1}^K y_i!} \frac{\mathrm{B}(\boldsymbol{\alpha} + \mathbf{y})}{\mathrm{B}(\boldsymbol{\alpha})} = \frac{N!}{\prod_{i=1}^K y_i!} \frac{\Gamma(\alpha_0)}{\Gamma(\alpha_0 + N)} \prod_{i=1}^K \frac{\Gamma(\alpha_i + y_i)}{\Gamma(\alpha_i)}$$

対数周辺尤度は：

$$\ln p(\mathbf{y} \mid \boldsymbol{\alpha}) = \ln(N!) - \sum_{i=1}^K \ln(y_i!) + \ln\Gamma(\alpha_0) - \ln\Gamma(\alpha_0 + N) + \sum_{i=1}^K \left[ \ln\Gamma(\alpha_i + y_i) - \ln\Gamma(\alpha_i) \right]$$

この閉形式周辺尤度を用いることで、飽和ディリクレモデルと独立拘束モデルとの間の厳密ベイズ因子（Exact Bayes Factor）を、サンプリング誤差なしに決定論的に算出・検証することが可能である。

---

## 参考文献
- Gelman, A., Carlin, J. B., Stern, H. S., Dunson, D. B., Vehtari, A., & Rubin, D. B. (2013). *Bayesian Data Analysis* (3rd ed.). CRC Press.
- Bishop, C. M. (2006). *Pattern Recognition and Machine Learning*. Springer.
- Freeman, M. F., & Tukey, J. W. (1950). Transformations related to the angular and the square root. *The Annals of Mathematical Statistics*, 21(4), 607–611.
- Good, I. J. (1965). *The Estimation of Probabilities: An Essay on Modern Bayesian Methods*. MIT Press.
