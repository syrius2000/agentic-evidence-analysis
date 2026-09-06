# 4軸セル診断フレームワークとRaoの局所スコア検定の数理

本ドキュメントは、大標本カテゴリカルデータにおいて局所サブグループ（個別セル）の特異シグナルを客観的に評価するための**4軸セル診断フレームワーク（Effect × Evidence × Influence × Stability）**、および **Leverage 補正 Score 統計量（Rao's Local Score Test）** の厳密な数理的導出と証明を記述する。

---

## 1. 4軸セル診断フレームワークの数理体系

全体モデルの適合（$\chi^2$ 検定や全体 BIC）は「表全体として関連があるか」を判定するが、「**どのセルが、どのような方向・大きさで、どれほどの信頼性をもって乖離しているか**」は示さない。
本フレームワークでは、分割表の各セル $i \in \{1, \dots, K\}$ の乖離を以下の 4 つの直交する軸で多面的に診断する。

```
              [ 4軸セル診断体系 (4-Axis Cell Diagnostics) ]
                     
         (1) Effect 軸            (2) Evidence 軸
     【局所効果比 log(O/E)】   【Score統計量 T = r^2/(1-h)】
      ・標本数 N に不変         ・標本抽出誤差 (ノイズ) 排除
      ・実質的乖離の大きさ      ・局所特異効果の厳密検定
                \                  /
                 \                /
                  \              /
                   \            /
                /                  \
               /                    \
              /                      \
             /                        \
        (3) Influence 軸          (4) Stability 軸
       【Leverage h_ii】        【REGULAR / QUARANTINED】
      ・モデル適合への影響度    ・小度数 E < 5, 高レバレッジ h >= 0.8
      ・自己引力による残差収縮  ・漸近正規近似の信頼性判定
```

---

## 2. 軸 1: Effect（効果量・乖離の大きさ）

### 2.1 局所対数効果比 $\log(O_i / E_i)$
基準モデル（例：相互独立モデル M1）の下でのセル $i$ の期待度数を $E_i = \hat{\mu}_i$、観測度数を $O_i = y_i$ とする。
局所対数効果比（Log Observed-to-Expected Ratio）は以下で定義される：

$$\mathrm{log\_oe\_ratio}_i = \ln\left( \frac{O_i}{E_i} \right) = \ln(O_i) - \ln(E_i)$$

#### 数学的性質（スケール不変性）
すべてのセルの度数が定数倍 $c > 0$（例：$c = 100$）された拡大分割表において、観測度数は $O_i^{(c)} = c O_i$ となり、ポアソン対数線形モデルの期待度数も同次性（Homogeneity）より $E_i^{(c)} = c E_i$ となる。したがって：

$$\ln\left( \frac{O_i^{(c)}}{E_i^{(c)}} \right) = \ln\left( \frac{c O_i}{c E_i} \right) = \ln\left( \frac{O_i}{E_i} \right)$$

対数効果比は**標本規模 $N$ に対して厳密に不変（Scale-Invariant）** である。
- $\log(O/E) > 0$：期待よりも過剰（濃縮・正の関連、$\exp(\log(O/E))$ 倍）
- $\log(O/E) < 0$：期待よりも過少（希薄化・負の関連）
- $\log(O/E) = 0$：期待値と完全一致

### 2.2 補助的局所効果指標
- **標準化差 (Scaled Difference)**:
  $$\mathrm{scaled\_diff}_i = \frac{O_i - E_i}{\sqrt{N}}$$
  サンプルサイズ $N$ で規格化した偏差。全セルの自乗和はピアソンカイ二乗統計量を $N$ で割った値（$\phi^2 = \chi^2 / N$）に等しい。
- **割合差 (Rate Difference)**:
  $$\mathrm{rate\_diff}_i = \frac{O_i - E_i}{N} = p_{O,i} - p_{E,i}$$
  全体に占める観測割合と期待割合の実質的な差分。

---

## 3. 軸 2: Evidence（統計的証拠・有意性）

### 3.1 ピアソン残差の限界
従来のピアソン残差（Pearson Residual）は：

$$r_{P,i} = \frac{O_i - E_i}{\sqrt{E_i}}$$

しかし、ポアソン対数線形回帰において $E_i = \hat{\mu}_i$ はパラメータ推定値 $\hat{\boldsymbol{\beta}}$ に依存しているため、残差ベクトル $\mathbf{r}_P$ の分散共分散行列は単位行列 $I$ ではなく、ハット行列 $H$ に依存する：

$$\mathrm{Var}(\mathbf{r}_P) \approx I - H$$

したがって、セル $i$ の残差の真の分散は $1 - h_{ii}$ であり、生残差の自乗 $r_{P,i}^2$ は $\chi^2(1)$ 統計量よりも常に過小となる（$h_{ii}$ が大きいほど過小評価が深刻化する）。

---

### 3.2 Rao の局所スコア検定統計量 $T_i^{\rm score}$ の数学的導出

#### 帰無モデルと局所代替モデル
- **帰無モデル $M_0$**: $\ln \mu_j = \mathbf{x}_j^T \boldsymbol{\beta}$ （パラメータ $\boldsymbol{\beta} \in \mathbb{R}^p$）
- **局所特異代替モデル $M_1^{(i)}$**: セル $i$ だけに特異効果パラメータ $\delta_i \in \mathbb{R}$ を追加したモデル：
  $$\ln \mu_j = \mathbf{x}_j^T \boldsymbol{\beta} + \mathbf{1}_{\{j = i\}} \delta_i$$
  ここで検定対象の仮説は $H_0: \delta_i = 0$ vs $H_1: \delta_i \neq 0$ である。

#### スコア関数の導出
モデル $M_1^{(i)}$ の全パラメータを $\boldsymbol{\theta} = (\boldsymbol{\beta}^T, \delta_i)^T$ とする。
対数尤度関数は：
$$\ell(\boldsymbol{\beta}, \delta_i) = \sum_{j \neq i} [y_j \mathbf{x}_j^T \boldsymbol{\beta} - e^{\mathbf{x}_j^T \boldsymbol{\beta}}] + [y_i (\mathbf{x}_i^T \boldsymbol{\beta} + \delta_i) - e^{\mathbf{x}_i^T \boldsymbol{\beta} + \delta_i}] - \sum_j \ln(y_j!)$$

帰無仮説 $H_0: \delta_i = 0$ の下で、最尤推定量 $\hat{\boldsymbol{\beta}}_0$ におけるスコア関数を計算する：
$$\left. \frac{\partial \ell}{\partial \delta_i} \right|_{\delta_i = 0, \boldsymbol{\beta} = \hat{\boldsymbol{\beta}}_0} = y_i - e^{\mathbf{x}_i^T \hat{\boldsymbol{\beta}}_0} = O_i - E_i$$

$$\left. \frac{\partial \ell}{\partial \boldsymbol{\beta}} \right|_{\delta_i = 0, \boldsymbol{\beta} = \hat{\boldsymbol{\beta}}_0} = X^T (\mathbf{y} - \hat{\boldsymbol{\mu}}_0) = \mathbf{0} \quad (\text{最尤推定量の定義より})$$

#### フィッシャー情報行列の分割
拡大パラメータ $\boldsymbol{\theta} = (\boldsymbol{\beta}^T, \delta_i)^T$ に対するフィッシャー情報行列 $\mathcal{I}$ は：

$$\mathcal{I} = \begin{pmatrix} \mathcal{I}_{\boldsymbol{\beta}\boldsymbol{\beta}} & \mathcal{I}_{\boldsymbol{\beta}\delta} \\ \mathcal{I}_{\delta\boldsymbol{\beta}} & \mathcal{I}_{\delta\delta} \end{pmatrix} = \begin{pmatrix} X^T W X & X^T W \mathbf{e}_i \\ \mathbf{e}_i^T W X & \mathbf{e}_i^T W \mathbf{e}_i \end{pmatrix}$$

ここで：
- $W = \mathrm{diag}(E_1, \dots, E_K)$
- $\mathbf{e}_i = (0, \dots, 1, \dots, 0)^T$ は第 $i$ 成分のみ 1 の単位ベクトル
- したがって $W \mathbf{e}_i = E_i \mathbf{e}_i$、$\mathbf{e}_i^T W \mathbf{e}_i = E_i$

#### 有効情報量（Effective Information）の計算
スコア検定（Rao, 1948）における局所パラメータ $\delta_i$ の有効情報量 $\mathcal{I}_{\delta \mid \boldsymbol{\beta}}$ は、シューア補元（Schur complement）により与えられる：

$$\mathcal{I}_{\delta \mid \boldsymbol{\beta}} = \mathcal{I}_{\delta\delta} - \mathcal{I}_{\delta\boldsymbol{\beta}} \mathcal{I}_{\boldsymbol{\beta}\boldsymbol{\beta}}^{-1} \mathcal{I}_{\boldsymbol{\beta}\delta} = E_i - (E_i \mathbf{x}_i^T) (X^T W X)^{-1} (E_i \mathbf{x}_i)$$

ここで、ポアソン回帰のハット行列 $H$ の定義：
$$H = W^{1/2} X (X^T W X)^{-1} X^T W^{1/2}$$
より、その第 $(i, i)$ 対角要素（Leverage $h_{ii}$）は：
$$h_{ii} = \mathbf{e}_i^T H \mathbf{e}_i = E_i^{1/2} \mathbf{x}_i^T (X^T W X)^{-1} \mathbf{x}_i E_i^{1/2} = E_i \mathbf{x}_i^T (X^T W X)^{-1} \mathbf{x}_i$$

これを代入すると、有効情報量は驚くほど簡潔な形に帰着される：

$$\mathcal{I}_{\delta \mid \boldsymbol{\beta}} = E_i - E_i \cdot h_{ii} = E_i (1 - h_{ii})$$

#### Rao スコア検定統計量の導出完了
スコア統計量 $T_i^{\rm score}$ は、スコアの二乗を有効情報量で除したものである：

$$T_i^{\rm score} = \frac{\left( \left. \frac{\partial \ell}{\partial \delta_i} \right|_{H_0} \right)^2}{\mathcal{I}_{\delta \mid \boldsymbol{\beta}}} = \frac{(O_i - E_i)^2}{E_i (1 - h_{ii})} = \frac{r_{P,i}^2}{1 - h_{ii}}$$

**［証明終了］**

#### 漸近分布と局所尤度比検定（LRT）との関係
帰無仮説 $H_0: \delta_i = 0$ の下で：

$$T_i^{\rm score} \overset{d}{\longrightarrow} \chi^2(1)$$

また、実際に特定セル $i$ にダミー変数を追加して再推定したモデルとの局所尤度比検定統計量（$\Delta G_i^2 = G^2(M_0) - G^2(M_1^{(i)})$）に対して、テイラー展開により：

$$\Delta G_i^2 = T_i^{\rm score} + O_p(N^{-1/2})$$

が成立する。すなわち、$T_i^{\rm score}$ は**モデル再推定を一切行うことなく、完全な局所尤度比検定の値を厳密に算出する解析公式**である。

---

## 4. 軸 3: Influence（影響度・てこ比）

### 4.1 ハット行列（Hat Matrix）の定義
ポアソン対数線形回帰におけるハット行列 $H \in \mathbb{R}^{K \times K}$ は：

$$H = W^{1/2} X (X^T W X)^{-1} X^T W^{1/2}$$

ハット行列は射影行列（巾等行列: $H^2 = H$）であり、そのトレースは推定パラメータ数 $p$ に等しい：

$$\mathrm{tr}(H) = \sum_{i=1}^K h_{ii} = p$$

各対角要素 $h_{ii}$ をセル $i$ の**レバレッジ（Leverage）** と呼ぶ（$0 \le h_{ii} \le 1$）。

### 4.2 レバレッジの実務的意味
- $h_{ii}$ は「セル $i$ の観測値 $O_i$ の微小変化が、モデルの予測期待値 $E_i$ をどれだけ自分自身に引き寄せるか」（$\partial \hat{\mu}_i / \partial y_i$）を表す感度係数である。
- **高レバレッジ（$h_{ii} \to 1$）の危険性**:
  $h_{ii}$ が大きいセルは、自身が期待値 $E_i$ を強力に引き寄せるため、見かけ上の残差 $O_i - E_i$ が極端に小さく縮退する。生のピアソン残差 $r_{P,i}$ はこの影響で著しく過小評価されるが、Score統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}$ は分母の $1 - h_{ii}$ によってこの縮退を数学的に正確に補正する。

---

## 5. 軸 4: Stability（数値安定性・信頼性）

### 5.1 漸近近似の破綻条件
カイ二乗分布および正規分布近似に基づく推論は、以下の極限において信頼性を失う：
1. **ゼロセル（観測度数ゼロ）**: 観測度数 $O_i = 0$ の場合、対数効果比 $\log(O_i / E_i)$ の直接計算が不可能となり（平滑化定数 $0.5$ 等の補正が必要）、局所漸近近似の信頼性が低下する。
2. **スパース性（極小期待度数）**: 期待度数 $E_i < 5.0$ の場合、ポアソン分布の離散性が顕著になり、連続分布近似（カイ二乗近似）が歪む。
3. **過大レバレッジ**: $h_{ii} \ge 0.80$ の場合、セルがモデル推定値の大部分を支配しており、有効情報量 $E_i (1 - h_{ii}) \to 0$ となり、推定分散が過大化・数値的に不安定化する。

### 5.2 診断状態（Stability Status）判定ルール

$$\mathrm{stability\_status}_i = \begin{cases} \mathbf{REGULAR} & (O_i > 0 \ \land \ E_i \ge 5.0 \ \land \ h_{ii} < 0.80) \\ \mathbf{QUARANTINED} & (O_i = 0 \ \lor \ E_i < 5.0 \ \lor \ h_{ii} \ge 0.80) \end{cases}$$

- **`REGULAR`**: 大標本漸近正規性・カイ二乗近似が完全に成立。統計的推論および P 値の信頼性が極めて高い。
- **`QUARANTINED`**: 隔離・注意セル（ゼロセル、疎セル、過大レバレッジセルのいずれか）。統計量が極端に振れる可能性があるため、解釈を保留するか、またはベイズ Dirichlet 事後推論による厳密な信用区間を参照する。

---

## 6. 旧エビデンススコア（$r^2 - k \ln N$）の数学的破綻と廃止理由

従来の分析パイプラインで使用されていた旧指標：
$$\mathrm{Evidence\_Score}_i = r_{P,i}^2 - k \cdot \ln(N)$$
は、以下の 2 つの致命的な数学的・実務的欠陥を抱えていたため、**完全廃止**された。

### 欠陥 1: Leverage 補正の欠如による局所 LRT からの乖離
旧式は生のピアソン残差 $r_{P,i}^2$ を用いていたため、分母の $1 - h_{ii}$ による補正が欠落していた。
特に高レバレッジセルにおいて、局所パラメータ追加による真の尤度比統計量 $\Delta G_i^2$ と大きく乖離し、重要な特異セルを見落とす欠陥があった。

### 欠陥 2: 大標本下での「エビデンス飽和」（全セル正値化現象）
ピアソン残差の自乗 $r_{P,i}^2 = \frac{(O_i - E_i)^2}{E_i}$ は、$N \to \infty$ において真の母集団分布との乖離がある場合、**サンプルサイズ $N$ に正比例して $O(N)$ で増大**する。
一方、ペナルティ項は対数オーダー $O(\ln N)$ でしか増大しない。
$$r_{P,i}^2 \sim O(N) \gg k \ln N \sim O(\ln N) \quad (N \to \infty)$$
このため、$N = 50,000 \sim 200,000$ のような大規模リアルワールドデータでは、**分割表のほぼすべてのセルで $r^2 - k \ln N > 0$（正値）となってエビデンスが飽和**し、「どのセルが特異的であるか」を識別するスクリーニング指標としての機能を完全に失っていた。

### 新体系による解決
新体系では、旧スコアのような無理な単一合成指標を排し：
1. 標本規模に不変な **Effect 軸（$\log(O/E)$）**
2. 厳密な局所スコア検定に基づく **Evidence 軸（$T_i^{\rm score}$）**
を明確に分離した **Dual-Filter 原則** を適用することで、大標本下でも破綻しない完璧な弁別力を実現した。

---

## 参考文献
- Agresti, A. (2013). *Categorical Data Analysis* (3rd ed.). John Wiley & Sons.
- Rao, C. R. (1948). Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation. *Proceedings of the Cambridge Philosophical Society*, 44(1), 50–57.
- Pregibon, D. (1981). Logistic regression diagnostics. *The Annals of Statistics*, 9(4), 705–724.
- Pierce, D. A., & Schafer, D. W. (1986). Residuals in generalized linear models. *Journal of the American Statistical Association*, 81(396), 977–986.
