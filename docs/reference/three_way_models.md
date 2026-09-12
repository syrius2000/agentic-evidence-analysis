# 3次元カテゴリカル探索の数理リファレンス

created: 2026-09-06 23:48 (JST)
update: 2026-09-12 21:48 (JST)
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

$$
\log \mu_{ijk} = \lambda + \lambda_i^A + \lambda_j^B + \lambda_k^C + \lambda_{ij}^{AB} + \lambda_{ik}^{AC} + \lambda_{jk}^{BC} + \lambda_{ijk}^{ABC}
$$

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

### 2.1 閉形式最尤推定量（Closed-Form MLE）と反復比例適合（IPF）の数理

9 階層モデルのうち、グラフィカルモデル（Chordal graph）に相当するモデルは陽な閉形式最尤推定量（Closed-form MLE）を持ちます（Bishop et al., 1975; Agresti, 2013）。
観測度数の周辺和を $n_{i\cdot\cdot} = \sum_{j,k} n_{ijk}$、2次元周辺和を $n_{ij\cdot} = \sum_k n_{ijk}$、総度数を $N$ と表すとき、各モデルの期待度数推定量 $\hat{\mu}_{ijk}$ は次式で直接計算されます：

| モデル ID | 構造 | 閉形式最尤推定量 $\hat{\mu}_{ijk}$ | 充足統計量（周辺和） |
| :--- | :--- | :--- | :--- |
| **M1** | $[A][B][C]$ | $\frac{n_{i\cdot\cdot} n_{\cdot j\cdot} n_{\cdot\cdot k}}{N^2}$ | $\{n_{i\cdot\cdot}\}, \{n_{\cdot j\cdot}\}, \{n_{\cdot\cdot k}\}$ |
| **M2** | $[AB][C]$ | $\frac{n_{ij\cdot} n_{\cdot\cdot k}}{N}$ | $\{n_{ij\cdot}\}, \{n_{\cdot\cdot k}\}$ |
| **M3** | $[AC][B]$ | $\frac{n_{i\cdot k} n_{\cdot j\cdot}}{N}$ | $\{n_{i\cdot k}\}, \{n_{\cdot j\cdot}\}$ |
| **M4** | $[BC][A]$ | $\frac{n_{\cdot jk} n_{i\cdot\cdot}}{N}$ | $\{n_{\cdot jk}\}, \{n_{i\cdot\cdot}\}$ |
| **M5** | $[AB][AC]$ | $\frac{n_{ij\cdot} n_{i\cdot k}}{n_{i\cdot\cdot}}$ | $\{n_{ij\cdot}\}, \{n_{i\cdot k}\}$ |
| **M6** | $[AB][BC]$ | $\frac{n_{ij\cdot} n_{\cdot jk}}{n_{\cdot j\cdot}}$ | $\{n_{ij\cdot}\}, \{n_{\cdot jk}\}$ |
| **M7** | $[AC][BC]$ | $\frac{n_{i\cdot k} n_{\cdot jk}}{n_{\cdot\cdot k}}$ | $\{n_{i\cdot k}\}, \{n_{\cdot jk}\}$ |
| **M8** | $[AB][AC][BC]$ | **閉形式解なし**（IPF または Newton-Raphson 法を要する） | $\{n_{ij\cdot}\}, \{n_{i\cdot k}\}, \{n_{\cdot jk}\}$ |
| **M9** | $[ABC]$ | $n_{ijk}$（観測値と完全一致） | $\{n_{ijk}\}$ |

#### M8 均一連関モデルにおける反復比例適合（IPF: Iterative Proportional Fitting）
M8 は全 2 因子交互作用を含み、対応するグラフは 3 頂点の閉路（Cycle）を成すため三角化（Chordal）されておらず、閉形式の解が存在しません。最尤推定量 $\hat{\mu}_{ijk}$ は、充足統計量である 3 つの 2 次元周辺和 $\{n_{ij\cdot}\}, \{n_{i\cdot k}\}, \{n_{\cdot jk}\}$ を逐次スケーリングする反復比例適合法（Deming & Stephan, 1940; Bishop et al., 1975）によって計算されます：

初期値 $\mu_{ijk}^{(0)} = 1.0$ から開始し、第 $m$ 反復サイクルにおいて以下の 3 ステップを収束するまで繰り返します：

$$
\begin{aligned}
  \mu_{ijk}^{(3m-2)} &= \mu_{ijk}^{(3m-3)} \times \frac{n_{ij\cdot}}{\sum_k \mu_{ijk}^{(3m-3)}} \quad (AB \text{ 周辺調整}) \\[8pt]
  \mu_{ijk}^{(3m-1)} &= \mu_{ijk}^{(3m-2)} \times \frac{n_{i\cdot k}}{\sum_j \mu_{ijk}^{(3m-2)}} \quad (AC \text{ 周辺調整}) \\[8pt]
  \mu_{ijk}^{(3m)} &= \mu_{ijk}^{(3m-1)} \times \frac{n_{\cdot jk}}{\sum_i \mu_{ijk}^{(3m-1)}} \quad (BC \text{ 周辺調整})
\end{aligned}
$$

このアルゴリズムは、多項尤度の凸最適化問題における Kullback-Leibler (KL) 情報量射影（I-projection / Csiszár, 1975）を解くものとして幾何学的に正当化されており、ポアソン GLM の Newton-Raphson（または Fisher スコア）アルゴリズムが到達する大域的最尤解と機械精度内で完全に一致します。本リポジトリの検証基盤（`tests/statistical_foundations/reference_values.R`）では、GLM 推定値とこの閉形式解・IPF の独立計算を二重照合することで、推定アルゴリズムの厳密性を担保しています。

### 2.2 ゼロセルの分類と最尤推定量の存在条件

分割表に度数 0 のセルが含まれる場合、対数線形モデルの推定と推論には特別な数理的注意が必要です：

1. **標本ゼロ（Sampling Zeros / Random Zeros）**:
   生起確率は正（$\pi_{ijk} > 0$）であるが、標本サイズ $N$ が有限であるために偶然 $n_{ijk} = 0$ となったセル。
2. **構造ゼロ（Structural Zeros / Fixed Zeros）**:
   医学的・論理的・物理的に生起確率がゼロ（$\pi_{ijk} \equiv 0$）であるセル（例: 男性における子宮頸癌の発生）。

#### 最尤推定量の有限存在条件（Haberman 1974; Fienberg 1970）
対数線形モデルにおいて最尤推定量 $\hat{\mu}_{ijk}$ がすべて有限かつ正（$0 < \hat{\mu}_{ijk} < \infty$）として一意に存在するための必要十分条件は、**周辺和がすべて正であること（必要条件）に加えて、観測充足統計量ベクトルがモデルの許容する周辺多面体（marginal polytope）の相対的内部（relative interior）に存在すること**です（Haberman, 1974; Fienberg, 1970; Eriksson et al., 2006）。

単に 1 次元・2 次元の周辺和が正であっても、特定のゼロ配置によって充足統計量が多面体の境界上（facet や boundary）に位置する場合、最尤推定量は境界解となり：
- パラメータ $\lambda$ の一部が $-\infty$ に発散し、推定量の一意性や数値的安定性が失われます。
- 局所効果比 $\log(O_i / E_i)$ は $O_i = 0$ のとき $-\infty$ となり、効果量として未定義（発散）となります。
- 漸近正規性・カイ二乗近似（Wilks の定理）の前提である「パラメータが内部点に存在すること」が崩壊します。

このため、本ツールキットでは $O_i = 0$ のセル、期待値 $E_i < 5.0$ の疎セル、および自己牽引により特異推定を招く過大レバレッジ $h_{ii} \ge 0.80$ のセルを **`QUARANTINED`（隔離セル）** としてフラグ付けし、モデル選択の順位付けや確証的判定から安全に隔離する契約を設けています。

---

## 3. 尤度・逸脱度と総度数 $N$ 基準の明示式 BIC

### 3.1 ポアソン対数尤度と多項対数尤度の関係

セルの総数を $K = I \times J \times K$、観測度数を $y_i$、モデル期待度数を $\mu_i$ と置きます。ポアソン完全対数尤度は次式で与えられます：

$$
\ell_P(y; \mu) = \sum_{i=1}^K \left\{ y_i \log \mu_i - \mu_i - \log(y_i!) \right\}
$$

固定総度数 $N = \sum y_i$ を条件付けると、度数ベクトル $y$ は多項分布 $\operatorname{Multinomial}(N, \pi)$ に従います。多項対数尤度 $\ell_M$ はポアソン尤度から総度数のポアソン項を差し引くことで厳密に得られます：

$$
\ell_M(y; \pi) = \ell_P(y; \mu) - \left\{ N \log N - N - \log(N!) \right\}
$$

切片項（および主効果基底）を含む標準的な正則ポアソン GLM（対数リンク・offset や非一様重みなし・正則適合）では、定数項に関するスコア方程式 $\sum (y_i - \mu_i) = 0$ より $\sum \mu_i = N$ が厳密に成立します。したがって、モデル間の尤度差 $\Delta \ell = \ell_{M1} - \ell_{M0}$ はポアソン対数尤度の差と完全に一致します（※ offset、標本重み、境界解が存在する場合は総度数保存が成り立たない点に留意）。

### 3.2 総度数 $N$ 基準の明示式 BIC の導出

Schwarz (1978) のベイズ情報量基準（BIC）は、多変量指数型分布族において独立な観測数 $N$ を標本サイズとして正則条件の下で導出されます：

$$
\mathrm{BIC}_{\mathrm{explicit}} = -2 \ell_P + p \log N
$$

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
標本サイズ $N$ が数万・数十万に膨張しても値が一定に保たれる不変指標（$\mathcal{O}(1)$）であり、大標本スクリーニングにおいて最優先されます。
- **局所対数効果比 (Log Relative Excess)**:

  $$
  \log(O_i / E_i)
  $$

  モデル期待度数に対する観測度数の乗法的な乖離を表します。
- **大標本規格化差 (Global Normalized Difference)**:

  $$
  e_i^{(\mathrm{global})} = \frac{O_i - E_i}{\sqrt{E_i N}}
  $$

  > [!NOTE]
  > **標準化残差 $r_{S,i}$ との数理的区別**:
  > 一般的なカテゴリカルデータ分析における「調整済み標準化残差（Standardized Pearson Residual）」$r_{S,i} = \frac{O_i - E_i}{\sqrt{E_i(1 - h_{ii})}}$ は、帰無仮説下で漸近標準正規分布 $\mathcal{N}(0, 1)$ に従い、標本サイズ $N$ に比例して二乗値が増大する **Evidence 軸の検定統計量**（$T_i^{\rm score} = r_{S,i}^2$、次数 $\mathcal{O}(N)$）です。
  > 一方、本ツールキットで定義する大標本規格化差 $e_i^{(\mathrm{global})}$ は、分母にさらに総度数 $\sqrt{N}$ を掛けて規格化することで、度数を $c$ 倍（$N \to cN$）にスケールしても値が厳密に変化しない（$\mathcal{O}(1)$）よう設計された **標本倍率不変の Effect 補助指標** です（コード上の変数名は後方互換性のため `std_diff` / `e_i` を用いますが、概念上は $r_{S,i}$ と峻別されます）。
- **率差 (Rate Difference)**:

  $$
  d_i = \frac{O_i - E_i}{N}
  $$

### 4.2 軸 2: Evidence（証拠の強さ / 標本数比例）
帰無仮説（基準モデル）からの乖離を統計的に検定する指標であり、標本サイズ $N$ に比例して増大します。
- **Rao のスコア検定統計量（Leverage 補正 Score 統計量）**:
  セル $i$ に局所インジケータ（ダミー変数）を追加したモデルの局所スコア検定統計量は、基準モデル（Null fit）の重み付き設計行列 $X$ と対角重み行列 $W = \operatorname{diag}(\hat{\mu})$ から導出されます（Rao, 1948; Pregibon, 1981）：

  $$
  T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}
  $$

  ここで $r_{P,i} = \frac{O_i - E_i}{\sqrt{E_i}}$ はピアソン残差、$h_{ii}$ はハット行列 $H = W^{1/2} X (X^T W X)^{-1} X^T W^{1/2}$ の対角成分（Leverage）です。
- **自然対数 P 値**:

  $$
  \ln(P) = \log\left( \Pr(\chi_1^2 \ge T_i^{\rm score}) \right)
  $$

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

### 4.5 マルチベースライン（M1 vs 選択モデル）セル診断の数理構造

本ツールキット（および仕様 `multi-baseline-cell-diagnostics`）では、各セルの診断指標を **単一の基準ではなく、2 つの異なる基準モデル（Baseline Models）の下で独立に計算・保持** します：

1. **M1 相互独立基準 ($E_i^{(M1)}$)**:

   $$
   H_0^{(M1)}: \text{全変数が完全相互独立} \quad (\log \mu_{ijk} = \lambda + \lambda_i^A + \lambda_j^B + \lambda_k^C)
   $$

   - **診断の問い**: 「このセルは、主効果（全体の構成比）だけから期待される値に対して、どれだけ全体的な連関（乖離）を持っているか？」
   - **役割**: 大局的な偏りや集積パターンの検出。
2. **選択モデル基準 ($E_i^{(M_{\text{best}})}$、例: M5 や M8)**:

   $$
   H_0^{(M_{\text{best}})}: \text{データ全体の連関構造が最良モデル } M_{\text{best}} \text{ で説明される}
   $$

   - **診断の問い**: 「全体モデル $M_{\text{best}}$ で共分散・条件付き独立・均一連関を説明した後に、**なお説明しきれず残った局所的な異常乖離（Residual Anomaly）** は存在するか？」
   - **役割**: モデルの局所的な適合不全や、特定の水準組合せにのみ生じている特殊な局所相互作用の検出。

```
                    【マルチベースライン診断の比較構造】
┌───────────────────────────────────────┬───────────────────────────────────────┐
│     基準 1: M1（相互独立モデル）      │    基準 2: M_best（選択最良モデル）   │
├───────────────────────────────────────┼───────────────────────────────────────┤
│ 期待度数: E_i^(M1)                    │ 期待度数: E_i^(M_best)                │
│ 残差: r_{P,i}^(M1)                    │ 残差: r_{P,i}^(M_best)                │
│ レバレッジ: h_{ii}^(M1)               │ レバレッジ: h_{ii}^(M_best)           │
│ スコア統計量: T_{i, M1}^score         │ スコア統計量: T_{i, M_best}^score     │
├───────────────────────────────────────┼───────────────────────────────────────┤
│ 意味: 全体的な集積・連関の大きさ      │ 意味: 全体モデルで説明不能な局所残差  │
└───────────────────────────────────────┴───────────────────────────────────────┘
```

> [!CAUTION]
> **基準モデル間の件数・率の合算禁止（Mathematical Fallacy）**:
> $E_i^{(M1)}$ と $E_i^{(M_{\text{best}})}$ は異なるパラメータ空間への射影であり、残差ベクトル $r_{P}^{(M1)}$ と $r_{P}^{(M_{\text{best}})}$ は数学的に異なる直交補空間に属します。
> したがって、M1 で検出された「探索候補数」と M_best で検出された「探索候補数」を足し合わせたり、「エビデンス率」として平均化することは数学的に無意味であり、仕様上厳格に禁止されています。

---

## 5. 大標本 Dual-Filter 原則（$N > 2,000$）

### 5.1 スクリーニング手順

サンプルサイズ $N$ が大規模（$N > 2,000$）になると、実務的に無視できる極めて微小な偏りであっても、検定統計量 $T_i^{\rm score}$ は巨大化し、P 値は飽和（極小化）します。

```
【大標本 Dual-Filter スクリーニング手順】
Step 1: Effect スクリーニング（第一関門）
        |log(O/E)| >= 0.5 （現象としての乗法的乖離の大きさでスクリーニング）
             │ 通過
             ▼
Step 2: Evidence フィルタリング（第二関門: 低検出力・微小セルへの探索的足切り）
        T_i^score >= 3.84 （未調整カイ二乗有意点 alpha=0.05 相当の探索閾値）
             │ 通過
             ▼
        探索的着目セル（Dual-Filtered Candidate Cells）
```

> [!WARNING]
> **Dual-Filter の統計的制約と解釈上の厳格な境界**:
> 1. **多重比較未調整（No FWER / FDR Guarantee）**: $T_i^{\rm score} \ge 3.84$ はセルごとの公称水準 $\alpha = 0.05$（自由度 1 のカイ二乗分布の上側 5% 点）に対応する単一セル基準の探索閾値です。表全体のファミリーワイズ誤差率（FWER）や偽発見率（FDR）を調整・保証するものではありません。
> 2. **漸近近似の成立限界**: 疎セル（$E_i < 5.0$）や境界推定、構造ゼロを含むセルでは漸近カイ二乗近似が破綻するため、事前に Stability 条件（Quarantine）で除外されていることが前提となります。
> 3. **実務的重要性・因果性の非保証**: 本フィルタの通過は「大標本下で実質的な効果量と基礎的な証拠強度の両基準を同時に満たす探索候補」であることを意味するに過ぎず、実務上の重要性、因果関係、外部妥当性、再現性を保証するものではありません。

> [!NOTE]
> **旧エビデンススコア（$r^2 - k\log N$）の破綻と監査列化**:
> 過去のプロトタイプで用いられた旧指標 $r^2 - k\log N$ は、度数が 100 倍（$N \to 100N$）になると、シグナル項 $r^2$ が 100 倍に膨張するのに対し、ペナルティ項は $\log(100N) = \log N + 4.6$ とわずかしか増加しないため、ほぼ全セルが正値化（エビデンス飽和）してフィルタ機能を喪失します。
> このため、現行システムでは旧スコアを監査専用列（audit-only）として隔離し、真の信号判定・セル合否判定には一切使用しません。

### 5.2 標本サイズ $c$ 倍拡張（100倍実験）における各統計量の漸近挙動

標本サイズ感度を数理的に検証するため、度数ベクトルを $c$ 倍（$n_{ijk}' = c \cdot n_{ijk}$、例えば $c=100$）に拡張した人工表を考えます。このとき各統計量の漸近オーダは厳密に次のように振る舞います：

| 指標分類 | 統計指標 | 定義式 | 標本サイズ $c$ 倍時の変換 | 漸近次数 | 統計的意味・解釈 |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Effect（効果量）** | 局所対数効果比 | $\log(O_i / E_i)$ | $\log(cO_i / cE_i) = \log(O_i / E_i)$ | $\mathcal{O}(1)$ | **厳密に不変**。現象の乗法的な偏りの大きさ |
| | 大標本規格化差 | $e_i^{(\mathrm{global})} = \frac{O_i - E_i}{\sqrt{E_i N}}$ | $\frac{c(O_i - E_i)}{\sqrt{cE_i \cdot cN}} = e_i^{(\mathrm{global})}$ | $\mathcal{O}(1)$ | **厳密に不変**。全体に対する規格化乖離（※ $r_{S,i}$ と区別） |
| | 率差 | $d_i = \frac{O_i - E_i}{N}$ | $\frac{c(O_i - E_i)}{cN} = d_i$ | $\mathcal{O}(1)$ | **厳密に不変**。総度数に対する差の割合 |
| **Evidence（証拠強度）** | ピアソン残差二乗 | $r_{P,i}^2 = \frac{(O_i - E_i)^2}{E_i}$ | $\frac{c^2(O_i - E_i)^2}{cE_i} = c \cdot r_{P,i}^2$ | $\mathcal{O}(N)$ | **標本サイズに正比例**して増大 |
| | Rao スコア検定統計量 | $T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}$ | $\frac{c \cdot r_{P,i}^2}{1 - h_{ii}} = c \cdot T_i^{\rm score}$ | $\mathcal{O}(N)$ | **標本サイズに正比例**して増大（$h_{ii}$ は不変、$= r_{S,i}^2$） |
| | 自然対数 P 値 | $\ln(P) \approx -\frac{1}{2} T_i^{\rm score}$ | $\ln(P') \approx c \cdot \ln(P)$ | $\mathcal{O}(N)$ | $-\infty$ へ線形に発散（※ 極端な右裾近似では $-\frac{1}{2}T - \frac{1}{2}\ln T + \mathcal{O}(1)$。有限の閾値判定式ではなく漸近挙動の説明） |
| **Model（モデル比較）** | 逸脱度差 / 対数尤度差 | $\Delta G^2 = -2 \Delta \ln L$ | $c \cdot \Delta G^2$ | $\mathcal{O}(N)$ | モデル間乖離の証拠強度が $c$ 倍に増大 |
| | 明示式 BIC 差分 | $\Delta \mathrm{BIC} = \Delta G^2 - \Delta p \ln(cN)$ | $c \Delta G^2 - \Delta p(\ln N + \ln c)$ | $\mathcal{O}(N)$ | 第 1 項（尤度比）が支配的となり線形増大 |
| **Bayesian（事後推論）** | Dirichlet 事後平均 | $\mathbb{E}[\pi_i \mid \boldsymbol{y}] = \frac{y_i + \alpha_i}{N + \alpha_0}$ | $\frac{c y_i + \alpha_i}{c N + \alpha_0} \to \frac{y_i}{N}$ | $\mathcal{O}(1)$ | 事前分布の影響が消滅し生比率へ収束 |
| | Dirichlet 事後分散 | $\operatorname{Var}(\pi_i \mid \boldsymbol{y}) \sim \frac{\pi_i(1-\pi_i)}{N}$ | $\frac{\pi_i(1-\pi_i)}{c N}$ | $\mathcal{O}(1/N)$ | **標本サイズに反比例**して事後分散が縮小 |
| | 等裾信用区間（95% ETI）幅 | $\mathrm{Width}_{95\%} \approx 3.92 \sqrt{\operatorname{Var}}$ | $\frac{1}{\sqrt{c}} \mathrm{Width}_{95\%}$ | $\mathcal{O}(1/\sqrt{N})$ | $c=100$ では漸近的に約 $1/10$ へ縮小（※ 有限標本では事前パラメータ $\boldsymbol{\alpha}$、境界、分位点非対称性により厳密な $1/10$ からずれる） |
| **Audit（旧指標）** | 旧エビデンススコア | $r_{P,i}^2 - k\ln N$ | $c \cdot r_{P,i}^2 - k(\ln N + \ln c)$ | $\mathcal{O}(N)$ | **シグナル項のみが $c$ 倍に膨張**し全セル正値化（飽和破綻） |

この対比表が示す通り、度数 100 倍化は「新しい被験者を独立に観測した証拠の追加」ではなく、**標本サイズ感度を可視化するための数理実験**です。効果量（Effect）が完全に保存される一方、証拠（Evidence）と不確実性の幅（Credible Interval）が標本サイズに応じてどのように収縮・増大するかを検証する目的で使用されます。

---

## 6. 局所モデル改善量 $\Delta G_i^2$ と 1 観測あたり逸脱度改善 $\Delta G_i^2 / N$

セル $i$ にダミー変数を追加して再適合したときの逸脱度改善量を $\Delta G_i^2$ とします。このとき、

$$
\frac{\Delta G_i^2}{N} = 2 \left\{ D_{\mathrm{KL}}(\hat{p} \parallel p_0) - D_{\mathrm{KL}}(\hat{p} \parallel p_1) \right\}
$$

は、拡張モデルが観測分布 $\hat{p}$ との Kullback-Leibler (KL) 乖離を **1 観測あたりどれだけ縮小したか** を表す情報理論的尺度です。これは標準化効果量（Cramér's V 等）や局所ベイズ因子とは数学的に異なる概念であり、独立したモデル改善尺度として解釈します。

---

## 7. 条件付きセル順位再現性（Conditional Rank Reproducibility: CRR）の数理

### 7.1 標本変動下における局所セル順位の脆弱性と反復再適合 Estimand

4 軸セル診断における局所効果比 $S_i = |\log(O_i / E_i)|$ の降順順位付けは、有限標本下において多項サンプリングの標本変動（sampling variability）に敏感です。特に、近接した効果比を持つセル同士や度数が小さいセルでは、サンプリング標本がわずかに変動するだけで順位が大きく逆転する現象が生じます。

本ツールキットでは、観測総度数 $N$ および経験割合ベクトル $\hat{\boldsymbol{p}} = \boldsymbol{n}/N$ を所与とする多項再標本化（Multinomial Resampling）に基づき、各セルの Top-$K$ 順位選択頻度を評価する **条件付きセル順位再現性（Conditional Rank Reproducibility: CRR）** を提供します。

#### 【重要】反復ごとの期待度数再推定（Model Refitting）の数理的必然性
素朴なブートストラップ法では、元データの固定期待度数 $\boldsymbol{E}^{(0)}$ を全反復で使い回す誤りが散見されます。しかし、$S_i^{(b)} = |\log(O_i^{(b)} / E_i^{(0)})|$ と評価すると、周辺度数の偶然の偏り（主効果や低次交互作用の標本変動）による歪みを「対象セルの固有の局所乖離」と誤認します。

したがって、各反復 $b$（$b = 1, \dots, B$）において生成された度数ベクトル $\boldsymbol{n}^{(b)} \sim \mathrm{Multinomial}(N, \hat{\boldsymbol{p}})$ に対し、指定された基準モデル（M1 または M5）の最尤期待度数 $\widehat{\boldsymbol{E}}^{(b)}$ を反復ごとに再適合（閉形式 MLE）して局所効果比を算出しなければなりません（SHALL）：

- **M1 相互独立モデル再適合 ($[A][B][C]$)**:
  $$\widehat{\mu}_{ijk}^{(b)} = \frac{n_{i++}^{(b)} n_{+j+}^{(b)} n_{++k}^{(b)}}{N^2}$$
- **M5 条件付き独立モデル再適合 ($[AB][AC]$: $B \perp C \mid A$)**:
  $$\widehat{\mu}_{ijk}^{(b)} = \frac{n_{ij+}^{(b)} n_{i+k}^{(b)}}{n_{i++}^{(b)}}$$

### 7.2 Estimand の条件付けと連続性補正

1. **元データ適格セル集合（$\mathcal{C}_{\mathrm{reg}}$）への条件付け**:
   順位付けの母集合は、元データ診断で `REGULAR` と判定された適格セル集合 $\mathcal{C}_{\mathrm{reg}}$（要素数 $C_{\mathrm{reg}}$）に固定します。元データで観測ゼロ（$O_i=0$）、疎セル（$E_i < 5.0$）、または過大レバレッジ（$h_{ii} \ge 0.80$）により `QUARANTINED` とされたセルは、順位付け競争から除外されます。
2. **反復中観測ゼロに対する 0.5 連続性補正**:
   反復 $b$ において適格セル $i \in \mathcal{C}_{\mathrm{reg}}$ の度数が偶然 $O_i^{(b)} = 0$ となった場合、局所効果比 $\log(0 / \widehat{E}_i^{(b)})$ が $-\infty$ に発散することを回避するため、標準的な 0.5 連続性補正（continuity correction）を適用して有限な順位付けを維持します：
   $$S_i^{(b)} = \begin{cases} \left|\log\left(\frac{O_i^{(b)}}{\widehat{E}_i^{(b)}}\right)\right| & (O_i^{(b)} > 0) \\ \left|\log\left(\frac{0.5}{\widehat{E}_i^{(b)}}\right)\right| & (O_i^{(b)} = 0) \end{cases}$$
3. **正準セルインデックスによる決定論的タイブレーク**:
   同一反復内で $S_i^{(b)} = S_j^{(b)}$ となるタイが発生した場合、因子水準の直積順序に基づいて付番された正準セルインデックス（`canonical_cell_index`）の昇順で厳格に順位を決定します。これにより、入力 CSV の行順や内部表示ソートに対する完全な順位不変性を保証します。

### 7.3 Top-K 選択頻度、MCSE、および運用品質ゲート

有効反復数 $B_{\mathrm{valid}}$ における適格セル $i$ の Top-$K$ 選択頻度 $\hat{\pi}_i^{(K)}$ およびそのモンテカルロ標準誤差（MCSE）は次式で計算され、対として出力されます：
$$\hat{\pi}_i^{(K)} = \frac{1}{B_{\mathrm{valid}}} \sum_{b=1}^{B_{\mathrm{valid}}} \mathbb{I}\left(\operatorname{rank}_i^{(b)} \le K\right), \quad \mathrm{MCSE}_i = \sqrt{\frac{\hat{\pi}_i^{(K)}(1 - \hat{\pi}_i^{(K)})}{B_{\mathrm{valid}}}}$$

#### 運用品質ゲート（Operational Quality Gate）
反復生成された分割表において層周辺度数が 0 となるなど、閉形式 MLE の分母ゼロ・階数落ちが生じた特異反復は無効反復として厳密にカウントされます。
有効反復率が運用基準値（既定 0.95、設定可能範囲 $0 < x \le 1.0$）を下回る場合（$\text{valid\_rate} < qg\_min\_rate$）：
- `status: "INSUFFICIENT_VALID_REPLICATES"`
- `quality_gate.passed: false`
- `cells: null`
として個別セルの選択頻度出力を安全に保留（HOLD）し、数値的に不安定な順位頻度の誤用を防止します。

### 7.4 統計的解釈境界と限界（製薬・臨床 RWD 分析における適用上の注意）

1. **標本抽出の独立性前提**:
   本手法は「各観測が同一の多項確率ベクトルから独立に抽出された」という仮定に依拠します。実臨床データ（RWD）において、同一患者の複数エピソード、施設間クラスタリング、時系列相関が存在する場合、本手法による選択頻度は過小評価された分散（過信）を反映するリスクがあります。
2. **因果性および真の重要性の非保証**:
   Top-$K$ 選択頻度が高いことは、「指定された対数線形モデルの残差構造において、標本変動に対して順位が保たれやすい」という統計的記述事実を示すに過ぎず、医学的・因果的な重要性や母集団における真の効果を直接証明するものではありません。

---

## 8. 参考文献（Primary Literature）

1. **Rao, C. R. (1948)**. "Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation." *Proceedings of the Cambridge Philosophical Society*, 44(1), 50–57. [DOI:10.1017/S0305004100024038](https://doi.org/10.1017/S0305004100024038)
2. **Pregibon, D. (1981)**. "Logistic regression diagnostics." *The Annals of Statistics*, 9(4), 705–724. [DOI:10.1214/aos/1176345513](https://doi.org/10.1214/aos/1176345513)
3. **Pierce, D. A., & Schafer, D. W. (1986)**. "Residuals in generalized linear models." *Journal of the American Statistical Association*, 81(396), 977–986. [DOI:10.1080/01621459.1986.10478361](https://doi.org/10.1080/01621459.1986.10478361)
4. **Schwarz, G. (1978)**. "Estimating the dimension of a model." *The Annals of Statistics*, 6(2), 461–464. [DOI:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)
5. **Agresti, A. (2013)**. *Categorical Data Analysis* (3rd ed.). John Wiley & Sons, Hoboken, New Jersey. [ISBN:978-0-470-46363-5](https://www.wiley.com/en-us/Categorical+Data+Analysis%2C+3rd+Edition-p-9780470463635)
6. **Bishop, Y. M. M., Fienberg, S. E., & Holland, P. W. (1975)**. *Discrete Multivariate Analysis: Theory and Practice*. MIT Press, Cambridge, Massachusetts. [ISBN:978-0-262-02113-5](https://mitpress.mit.edu/9780262524865/discrete-multivariate-analysis/)
7. **McCullagh, P., & Nelder, J. A. (1989)**. *Generalized Linear Models* (2nd ed.). Chapman and Hall/CRC, London. [DOI:10.1007/978-1-4899-3242-6](https://doi.org/10.1007/978-1-4899-3242-6)
8. **Cochran, W. G. (1954)**. "Some methods for strengthening the common $\chi^2$ tests." *Biometrics*, 10(4), 417–451. [DOI:10.2307/3001616](https://doi.org/10.2307/3001616)
9. **Deming, W. E., & Stephan, F. F. (1940)**. "On a least squares adjustment of a sampled frequency table when the expected marginal totals are known." *The Annals of Mathematical Statistics*, 11(4), 427–444. [DOI:10.1214/aoms/1177731829](https://doi.org/10.1214/aoms/1177731829)
10. **Fienberg, S. E. (1970)**. "The analysis of multidimensional contingency tables when some cells had missing data." *Journal of the American Statistical Association*, 65(330), 980–986. [DOI:10.1080/01621459.1970.10481138](https://doi.org/10.1080/01621459.1970.10481138)
11. **Csiszár, I. (1975)**. "$I$-divergence geometry of probability distributions and minimization problems." *The Annals of Probability*, 3(1), 146–158. [DOI:10.1214/aop/1176996454](https://doi.org/10.1214/aop/1176996454)
12. **Kass, R. E., & Raftery, A. E. (1995)**. "Bayes factors." *Journal of the American Statistical Association*, 90(430), 773–795. [DOI:10.1080/01621459.1995.10476572](https://doi.org/10.1080/01621459.1995.10476572)
13. **Efron, B., & Tibshirani, R. J. (1993)**. *An Introduction to the Bootstrap*. Chapman & Hall/CRC, New York. [ISBN:978-0-412-04231-7](https://www.routledge.com/An-Introduction-to-the-Bootstrap/Efron-Tibshirani/p/book/9780412042317)
    - *多項再標本化およびノンパラメトリック・ブートストラップ推論の基礎。*
