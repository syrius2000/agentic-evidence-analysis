# 3次元カテゴリカル探索の数理リファレンス

created: 2026-09-06 23:48 (JST)
update: 2026-09-07 00:35 (JST)
author: Codex (GPT-5) / Antigravity

この文書は、集計済みの 3 変数カテゴリカル表を探索する現行経路の数理的正本リファレンスです。実装の入口は [vcd-bayesian-evidence-analysis](../../.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md)、統計契約および再現手順は [three_way_contract.md](../../.agents/skills/vcd-bayesian-evidence-analysis/references/three_way_contract.md) に定義されています。

---

## 1. 入力データの定義と事前固定（Pass 0 契約）

入力は、3 つのカテゴリ変数 $A, B, C$ と非負整数の観測度数 $n_{ijk}$ を持つ集計表（contingency table）です。個票へ展開せず、同一カテゴリ組合せの複数行は合算（集約）します。統計計算を開始する前に、以下を `analysis_config.json` および Pass 0 検分成果物に固定します：

- 変数名、水準順（辞書順または定義順）、度数列名、総度数 $N = \sum_{i,j,k} n_{ijk}$
- 欠測、未記載セル、標本ゼロ（sampling zeros: 偶然 $n_{ijk}=0$）、構造ゼロ（structural zeros: 定義上生じ得ないセル）の区別
- 標本単位、重複観測の有無、観測間の独立性仮定
- 目的変数を特定するか、3 変数を対称な関連として探索するか
- 抽出条件、解析対象集団の分母、実務上意味のある差の最小許容幅

> [!IMPORTANT]
> 集計度数表単体からは、患者や回答者の重複、クラスター構造、時系列相関を自動検知することは不可能です。観測の独立性が保証されない場合、計算上の数値は算出できても推論結果は保留（HOLD）とします。

---

## 2. 9 階層対数線形モデル（Hierarchical Log-Linear Models）

ポアソン GLM 表現において、各セルの観測度数を $n_{ijk} \sim \operatorname{Poisson}(\mu_{ijk})$ とし、対数期待度数 $\log \mu_{ijk}$ を線形結合でモデル化します：

\[
  \log \mu_{ijk} = \lambda + \lambda_i^A + \lambda_j^B + \lambda_k^C + \lambda_{ij}^{AB} + \lambda_{ik}^{AC} + \lambda_{jk}^{BC} + \lambda_{ijk}^{ABC}
\]

本ツールキットでは、全主効果を含む 9 つの階層モデル（M1〜M9）を固定候補として比較します。上位の交互作用項が含まれる場合、対応する下位の主効果・低次交互作用が必ず包含される階層性（hierarchy）を満たします。

| モデル ID | 最大項の配位（Generating Class） | 表現する統計的構造 | 自由度（$I,J,K$ 水準数） |
| :--- | :--- | :--- | :--- |
| **M1** | $[A][B][C]$ | 完全相互独立（Mutual Independence） | $IJK - 1 - (I-1) - (J-1) - (K-1)$ |
| **M2** | $[AB][C]$ | $AB$ 周辺関連、$C$ は $AB$ と独立 | $IJK - IJ - K + 1$ |
| **M3** | $[AC][B]$ | $AC$ 周辺関連、$B$ は $AC$ と独立 | $IJK - IK - J + 1$ |
| **M4** | $[BC][A]$ | $BC$ 周辺関連、$A$ は $BC$ と独立 | $IJK - JK - I + 1$ |
| **M5** | $[AB][AC]$ | $A$ の下で $B$ と $C$ が条件付き独立 ($B \perp C \mid A$) | $(I)(J-1)(K-1)$ |
| **M6** | $[AB][BC]$ | $B$ の下で $A$ と $C$ が条件付き独立 ($A \perp C \mid B$) | $(J)(I-1)(K-1)$ |
| **M7** | $[AC][BC]$ | $C$ の下で $A$ と $B$ が条件付き独立 ($A \perp B \mid C$) | $(K)(I-1)(J-1)$ |
| **M8** | $[AB][AC][BC]$ | 均一連関モデル（全 2 因子交互作用、3 次交互作用なし） | $(I-1)(J-1)(K-1)$ |
| **M9** | $[ABC]$ | 飽和モデル（Saturated Model、3 次交互作用を包含） | $0$（完全適合） |

目的変数を指定した場合であっても、大域的なモデル比較の枠組み（M1〜M9）は変更しません。目的変数の指定は、条件付き割合や層間リスク差を読み解く切り口として機能します。

---

## 3. 尤度・逸脱度と総度数 $N$ 基準の明示式 BIC

### 3.1 ポアソン対数尤度と多項対数尤度の関係

セルの総数を $K = I \times J \times K$、観測度数を $y_i$、モデル期待度数を $\mu_i$ と置きます。ポアソン完全対数尤度は次式で与えられます：

\[
  \ell_P(y; \mu) = \sum_{i=1}^K \left\{ y_i \log \mu_i - \mu_i - \log(y_i!) \right\}
\]

固定総度数 $N = \sum y_i$ を条件付けると、度数ベクトル $y$ は多項分布 $\operatorname{Multinomial}(N, \pi)$ に従います。多項対数尤度 $\ell_M$ はポアソン尤度から総度数のポアソン項を差し引くことで厳密に得られます：

\[
  \ell_M(y; \pi) = \ell_P(y; \mu) - \left\{ N \log N - N - \log(N!) \right\}
\]

ポアソン GLM で総度数を保存するモデル（主効果定数項を含む M1〜M9）では $\sum \mu_i = N$ が常に成立するため、モデル間の尤度差 $\Delta \ell = \ell_{M1} - \ell_{M0}$ はポアソン対数尤度の差と完全に一致します。

### 3.2 総度数 $N$ 基準の明示式 BIC の導出

Schwarz (1978) のベイズ情報量基準（BIC）は、多変量指数型分布族において独立な観測数 $N$ を標本サイズとして正則条件の下で導出されます：

\[
  \mathrm{BIC}_{\mathrm{explicit}} = -2 \ell_P + p \log N
\]

ここで $p$ はモデルの自由パラメータ数（ポアソン設計行列 $X$ の階数 $\operatorname{rank}(X)$）です。多項尤度に基づく比較では $p_M = p - 1$ かつ $\ell_M$ を用いますが、$-2\ell_M + (p-1)\log N$ は定数項を除いて同一のモデル間差 $\Delta \mathrm{BIC}$ を与えます。

> [!CAUTION]
> **R 既定 `stats::BIC()` および Deviance 式の落とし穴**:
> 1. R の `stats::BIC(glm_obj)` は標本サイズを行数 $K$（セルの個数）と見なして計算するため、総度数 $N$ を反映しません。
> 2. 単純な逸脱度式 $\mathrm{Deviance} + df \cdot \log N$ は、飽和モデル基準の相対値であり、完全尤度に基づくモデル比較やベイズ因子近似において定数項の不整合を招きます。
> 本リポジトリでは、総度数 $N$ 基準のポアソン明示式 $\mathrm{BIC}_{\mathrm{explicit}} = -2\ln L + p\ln N$ を唯一の正本として実装・記録しています。

---

## 4. 新 4 軸セル診断フレームワーク (Four-Axis Cell Diagnostics)

セル単位の局所的な偏りを評価する際、単一のスコアに縮約せず、以下の独立した 4 軸によって評価します。

```
                    【新 4 軸セル診断フレームワーク】
┌──────────────────────────────────────────────────────────────┐
│  1. Effect（効果量）: log(O/E), e_i, d_i                     │
│     → 標本サイズ N に依存しない「現象の大きさ」（不変尺度）    │
├──────────────────────────────────────────────────────────────┤
│  2. Evidence（証拠強度）: T_i^score, ln(P)                   │
│     → サンプルサイズ N に比例する統計的確信度（Rao Score検定） │
├──────────────────────────────────────────────────────────────┤
│  3. Influence（影響度）: Leverage h_ii                       │
│     → ハット行列対角成分。モデル適合に対するセルの自己牽引力   │
├──────────────────────────────────────────────────────────────┤
│  4. Stability（数値安定性）: QUARANTINED / REGULAR           │
│     → O_i=0, E_i<5.0, h_ii>=0.80 の論理和による隔離フラグ    │
└──────────────────────────────────────────────────────────────┘
```

### 4.1 軸 1: Effect（効果の大きさ / 標本数不変）
標本サイズ $N$ が数万・数十万に膨張しても値が一定に保たれる不変指標であり、大標本スクリーニングにおいて最優先されます。
- **局所対数効果比 (Log Relative Excess)**:
  \[
    \log(O_i / E_i)
  \]
  モデル期待度数に対する観測度数の乗法的な乖離を表します。
- **標準化差 (Standardized Difference)**:
  \[
    e_i = \frac{O_i - E_i}{\sqrt{E_i N}}
  \]
- **率差 (Rate Difference)**:
  \[
    d_i = \frac{O_i - E_i}{N}
  \]

### 4.2 軸 2: Evidence（証拠の強さ / 標本数比例）
帰無仮説（基準モデル）からの乖離を統計的に検定する指標であり、標本サイズ $N$ に比例して増大します。
- **Rao のスコア検定統計量（Leverage 補正 Score 統計量）**:
  セル $i$ に局所インジケータ（ダミー変数）を追加したモデルの局所スコア検定統計量は、基準モデル（Null fit）の重み付き設計行列 $X$ と対角重み行列 $W = \operatorname{diag}(\hat{\mu})$ から導出されます（Rao, 1948; Pregibon, 1981）：
  \[
    T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}
  \]
  ここで $r_{P,i} = \frac{O_i - E_i}{\sqrt{E_i}}$ はピアソン残差、$h_{ii}$ はハット行列 $H = W^{1/2} X (X^T W X)^{-1} X^T W^{1/2}$ の対角成分（Leverage）です。
- **自然対数 P 値**:
  \[
    \ln(P) = \log\left( \Pr(\chi_1^2 \ge T_i^{\rm score}) \right)
  \]
  大標本下での浮動小数点アンダーフロー（0 への丸め）を防止するため、対数スケールで厳密に保持します。

### 4.3 軸 3: Influence（影響度 / ハット行列 Leverage）
- **レバレッジ $h_{ii}$**:
  セル $i$ の観測値が自分自身のモデル予測値 $\hat{\mu}_i$ に及ぼす感度 $\frac{\partial \hat{\mu}_i}{\partial y_i}$ を表します。
  $h_{ii} \in [0, 1]$ であり、$h_{ii}$ が 1 に近いセルは、モデルのフィッティングそのものを自身に強く引き寄せるため、局所的な誤差や乖離が見かけ上小さく隠蔽されるリスク（過小残差）を持ちます。

### 4.4 軸 4: Stability（数値安定性と隔離判定）
統計的推定の妥当性を保証するため、以下の 3 条件の論理和（OR 条件）に基づく厳密なスクリーニングを行います：
1. **観測度数ゼロ**: $O_i = 0$（境界解、対数比発散）
2. **疎セル（小期待度数）**: $E_i < 5.0$（漸近カイ二乗分布近似の破綻、Cochran 1954 基準）
3. **過大レバレッジ**: $h_{ii} \ge 0.80$（モデル構造の特異性、Pregibon 1981 基準）

上記いずれか 1 つでも満たすセルは **`QUARANTINED`（隔離セル）** としてフラグ付けし、統計的推論・自動解釈を保留します。3 条件をすべてクリアしたセルのみを **`REGULAR`（通常セル）** として確定的な評価対象とします。

---

## 5. 大標本 Dual-Filter 原則（$N > 2,000$）

サンプルサイズ $N$ が大規模（$N > 2,000$）になると、実務的に無視できる極めて微小な偏りであっても、検定統計量 $T_i^{\rm score}$ は巨大化し、P 値は飽和（極小化）します。

```
【大標本 Dual-Filter スクリーニング手順】
Step 1: Effect スクリーニング（第一関門）
        |log(O/E)| >= 0.5 （実務的に意味のある偏りのみ通過）
             │ 通過
             ▼
Step 2: Evidence フィルタリング（第二関門: ノイズ排除）
        T_i^score >= 3.84 （偶然の標本誤差ではないことを確認）
             │ 通過
             ▼
        真に有用な偏り（Meaningful & Evident Cells）
```

> [!NOTE]
> **旧エビデンススコア（$r^2 - k\log N$）の破綻と監査列化**:
> 過去のプロトタイプで用いられた旧指標 $r^2 - k\log N$ は、度数が 100 倍（$N \to 100N$）になると、シグナル項 $r^2$ が 100 倍に膨張するのに対し、ペナルティ項は $\log(100N) = \log N + 4.6$ とわずかしか増加しないため、ほぼ全セルが正値化（エビデンス飽和）してフィルタ機能を喪失します。
> このため、現行システムでは旧スコアを監査専用列（audit-only）として隔離し、真の信号判定・セル合否判定には一切使用しません。

---

## 6. 局所モデル改善量 $\Delta G_i^2$ と 1 観測あたり逸脱度改善 $\Delta G_i^2 / N$

セル $i$ にダミー変数を追加して再適合したときの逸脱度改善量を $\Delta G_i^2$ とします。このとき、

\[
  \frac{\Delta G_i^2}{N} = 2 \left\{ D_{\mathrm{KL}}(\hat{p} \parallel p_0) - D_{\mathrm{KL}}(\hat{p} \parallel p_1) \right\}
\]

は、拡張モデルが観測分布 $\hat{p}$ との Kullback-Leibler (KL) 乖離を **1 観測あたりどれだけ縮小したか** を表す情報理論的尺度です。これは標準化効果量（Cramér's V 等）や局所ベイズ因子とは数学的に異なる概念であり、独立したモデル改善尺度として解釈します。

---

## 7. 参考文献（Primary Literature）

1. **Rao, C. R. (1948)**. "Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation." *Proceedings of the Cambridge Philosophical Society*, 44(1), 50–57. [DOI:10.1017/S0305004100024038](https://doi.org/10.1017/S0305004100024038)
2. **Pregibon, D. (1981)**. "Logistic regression diagnostics." *The Annals of Statistics*, 9(4), 705–724. [DOI:10.1214/aos/1176345513](https://doi.org/10.1214/aos/1176345513)
3. **Pierce, D. A., & Schafer, D. W. (1986)**. "Residuals in generalized linear models." *Journal of the American Statistical Association*, 81(396), 977–986. [DOI:10.1080/01621459.1986.10478361](https://doi.org/10.1080/01621459.1986.10478361)
4. **Schwarz, G. (1978)**. "Estimating the dimension of a model." *The Annals of Statistics*, 6(2), 461–464. [DOI:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)
5. **Agresti, A. (2013)**. *Categorical Data Analysis* (3rd ed.). John Wiley & Sons, Hoboken, New Jersey. [ISBN:978-0-470-46363-5](https://www.wiley.com/en-us/Categorical+Data+Analysis%2C+3rd+Edition-p-9780470463635)
6. **Bishop, Y. M. M., Fienberg, S. E., & Holland, P. W. (1975)**. *Discrete Multivariate Analysis: Theory and Practice*. MIT Press, Cambridge, Massachusetts. [ISBN:978-0-262-02113-5](https://mitpress.mit.edu/9780262524865/discrete-multivariate-analysis/)
7. **McCullagh, P., & Nelder, J. A. (1989)**. *Generalized Linear Models* (2nd ed.). Chapman and Hall/CRC, London. [DOI:10.1007/978-1-4899-3242-6](https://doi.org/10.1007/978-1-4899-3242-6)
8. **Cochran, W. G. (1954)**. "Some methods for strengthening the common $\chi^2$ tests." *Biometrics*, 10(4), 417–451. [DOI:10.2307/3001616](https://doi.org/10.2307/3001616)
9. **Kass, R. E., & Raftery, A. E. (1995)**. "Bayes factors." *Journal of the American Statistical Association*, 90(430), 773–795. [DOI:10.1080/01621459.1995.10476572](https://doi.org/10.1080/01621459.1995.10476572)
