# カテゴリカルデータ分析の基礎と解釈リファレンス

created: 2026-09-06 23:49 (JST)
update: 2026-09-07 00:35 (JST)
author: Codex (GPT-5) / Antigravity

この文書は、名義・順序カテゴリの分割表（contingency table）を正しく読み解くための統計数理リファレンスです。3 変数以上の多次元構造解析については [3次元カテゴリカル探索の数理](three_way_models.md) を参照してください。

---

## 1. 分割表の基礎：行数、セル数、総度数 $N$ の厳格な区別

カテゴリカルデータ分析において、以下の 3 つの量は全く異なる統計的意味を持ちます：
- **行数 / レコード数**: 生データ（個票）または集計表の行数
- **セル数 ($K$)**: 離散水準の組合せ総数（例: $I \times J$）
- **総度数 ($N = \sum O_i$)**: 観測された標本サイズの総和

集計済み CSV の 1 行が 1 被験者を意味するとは限らず、度数列の合計値が標本サイズ $N$ です。解析に先立ち、変数、水準、分母、欠測値の扱い、標本単位、観測間の独立性を確定することが必須です。

観測度数を $O_i$、帰無仮説モデル（独立モデル等）に基づく期待度数を $E_i$ と置きます。期待度数の数値と意味は、選択した基準モデル（相互独立、条件付き独立等）によって変動します。

---

## 2. 残差分析（Residual Analysis）の数理

### 2.1 ピアソン残差（Pearson Residual）
\[
  r_{P,i} = \frac{O_i - E_i}{\sqrt{E_i}}
\]
観測度数と期待度数の乖離をポアソン分散の平方根で割った標準化量です。二乗和 $\sum r_{P,i}^2 = X^2$ はピアソンのカイ二乗統計量に一致します。

### 2.2 標準化残差 / 調整済み残差（Standardized Pearson Residual）
ピアソン残差の分散は 1 ではなく、モデルの設計行列に依存して $1 - h_{ii}$ に縮小します（Haberman, 1973; Agresti, 2013）。したがって、漸近標準正規分布 $\mathcal{N}(0, 1)$ に従う厳密な残差は次式で与えられます：
\[
  r_{S,i} = \frac{O_i - E_i}{\sqrt{E_i (1 - h_{ii})}}
\]
ここで $h_{ii}$ はポアソン GLM におけるハット行列 $H$ の対角成分（Leverage）です。この残差の二乗が、セルごとの局所スコア検定統計量 $T_i^{\rm score} = r_{S,i}^2 = \frac{r_{P,i}^2}{1 - h_{ii}}$ と厳密に一致します（Rao, 1948; Pregibon, 1981）。

### 2.3 残差解釈上の注意
- 正の残差は「基準モデルの予測よりも観測が多い（過剰）」、負の残差は「少ない（過小）」を示します。
- 残差の絶対値だけで実質的重要性を判定してはなりません。大標本下では、実務上無意味な僅かなずれであっても残差は巨大化します。
- 機械的な一律閾値（$|r| > 1.96$ や $2.58$）を全セルに適用することは、多重比較（Family-Wise Error Rate）の観点からも誤りです。

---

## 3. 全体効果量：Cramér's V（Cohen 1988 基準と Bergsma 2013 補正）

### 3.1 古典的 Cramér's V
2 元分割表（$R \times C$、総度数 $N$）におけるピアソンカイ二乗統計量を $X^2$ とするとき、Cramér's V は次式で定義されます（Cramér, 1946）：
\[
  V = \sqrt{\frac{X^2}{N \min(R - 1, C - 1)}}
\]
この指標は $0 \le V \le 1$ の範囲をとり、標本サイズ $N$ のスケーリングを受けない不変の関連度尺度です。

### 3.2 Jacob Cohen (1988) の効果量判定基準
Cohen (1988) は、分割表の自由度 $df^* = \min(R - 1, C - 1)$ に応じた効果量の目安を以下のように提示しています：

| 自由度 $df^*$ | 小さい効果 (Small) | 中程度の効果 (Medium) | 大きい効果 (Large) |
| :---: | :---: | :---: | :---: |
| **1** | $0.10$ | $0.30$ | $0.50$ |
| **2** | $0.07$ | $0.21$ | $0.35$ |
| **3** | $0.06$ | $0.17$ | $0.29$ |
| **4** | $0.05$ | $0.15$ | $0.25$ |
| **5** | $0.04$ | $0.13$ | $0.22$ |

### 3.3 有限標本バイアス補正（Bergsma, 2013）
小標本やセル数が多い分割表では、標本 Cramér's V は上方にバイアス（過大評価）を持ちます。Bergsma (2013) はカイ二乗統計量の期待値 $df = (R - 1)(C - 1)$ を差し引いた不偏推定量 $\tilde{V}$ を提案しています：
\[
  \tilde{\phi}^2 = \max\left(0, \; \frac{X^2}{N} - \frac{(R - 1)(C - 1)}{N - 1}\right)
\]
\[
  \tilde{R} = R - \frac{(R - 1)^2}{N - 1}, \qquad \tilde{C} = C - \frac{(C - 1)^2}{N - 1}
\]
\[
  \tilde{V} = \sqrt{\frac{\tilde{\phi}^2}{\min(\tilde{R} - 1, \tilde{C} - 1)}}
\]

> [!IMPORTANT]
> **2元効果量と3元モデル探索の境界**:
> Cramér's V は表全体のグローバルな関連度を要約する指標であり、3 次元分割表の各セルに個別に割り当てる効果量ではありません。3 次元表のセル単位の偏りは、局所対数効果比 $\log(O_i / E_i)$ や標準化差 $e_i$ などのセル診断指標で評価します。

---

## 4. 旧エビデンススコア（$r^2 - k\log N$）の破綻と監査専用列化

過去のプロトタイプ実装において、局所ペナルティとして $r^2 - k\log N$（$k=1$ または $k=2$）が検討された経緯があります。しかし、度数を 100 倍（$N \to 100N$）にするシミュレーション実験において以下の数学的破綻が判明しました：

1. **エビデンス飽和現象（Filter Collapse）**:
   度数を 100 倍にすると、観測度数・期待度数が 100 倍となるため、残差二乗 $r_{P,i}^2$ は正確に 100 倍に膨張します。一方、対数ペナルティ項は $\log(100N) = \log N + \log 100 \approx \log N + 4.61$ と線形（対数的）にしか増加しません。
   結果として、$N$ が数万〜数十万規模になると、ほぼすべてのセルで $r^2 \gg k\log N$ となり、全セルが「正のスコア（エビデンスあり）」と判定され、フィルタリング機能が完全に崩壊します。
2. **局所尤度比検定（LRT）との乖離**:
   $r^2 - k\log N$ は、セルダミーを追加した対数線形モデルの再適合による逸脱度改善量 $\Delta G_i^2$ や局所 BIC 差分 $\Delta G_i^2 - \Delta p\log N$ と厳密に一致しません。

このため、現行ツールキットでは旧スコアを**監査専用列（audit-only）**としてのみ保持し、真の信号判定・セル合否判定・セル Bayes Factor の代用としては一切使用しません。

---

## 5. P 値の限界と実務的有意性（ASA 2016 声明）

アメリカ統計学会（ASA）の「統計的有意性と P 値に関する声明」（Wasserstein & Lazar, 2016）に準拠し、本分析基盤では以下の原則を徹底します：

1. **P 値は仮説とデータの矛盾度を示す指標に過ぎず、効果の大きさや実務的重要性を示さない。**
2. **$p < 0.05$ という恣意的な境界に基づく「有意 / 非有意」の二元論的断定を廃止する。**
3. **大標本下では、検定統計量は $N$ に比例して増大し P 値は 0 に収縮するため、以下の 5 要素を明確に切り分けて報告する：**
   - **構造 (Structure)**: 9 階層モデルのどれが現象の連関構造を最もよく説明しているか。
   - **効果 (Effect Size)**: 局所対数効果比 $\log(O/E)$、Cramér's V、率差など、標本数に依存しない現象の大きさ。
   - **証拠 (Evidence Strength)**: Rao のスコア検定統計量 $T_i^{\rm score}$、対数 P 値 $\ln(P)$、明示事前によるベイズ因子。
   - **数値安定性・影響度 (Stability & Influence)**: ゼロセル、小期待度数、過大レバレッジ（$h_{ii} \ge 0.80$）の隔離判定。
   - **実務判断 (Practical Decision)**: 意思決定に伴うリスク、費用、臨床的・ビジネス的許容幅。

---

## 6. 参考文献（Primary Literature）

1. **Agresti, A. (2013)**. *Categorical Data Analysis* (3rd ed.). John Wiley & Sons, Hoboken, New Jersey. [ISBN:978-0-470-46363-5](https://www.wiley.com/en-us/Categorical+Data+Analysis%2C+3rd+Edition-p-9780470463635)
2. **Cohen, J. (1988)**. *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum Associates, Hillsdale, New Jersey. [ISBN:978-0-805-80283-2](https://www.utstat.toronto.edu/~brunner/oldclass/378f16/readings/CohenPower.pdf)
3. **Bergsma, W. (2013)**. "A bias-correction for Cramér’s $V$ and Tschuprow’s $T$." *Journal of the Korean Statistical Society*, 42(3), 323–328. [DOI:10.1016/j.jkss.2012.10.002](https://doi.org/10.1016/j.jkss.2012.10.002)
4. **Haberman, S. J. (1973)**. "The analysis of residuals in cross-classified tables." *Biometrics*, 29(1), 205–220. [DOI:10.2307/2529686](https://doi.org/10.2307/2529686)
5. **Rao, C. R. (1948)**. "Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation." *Proceedings of the Cambridge Philosophical Society*, 44(1), 50–57. [DOI:10.1017/S0305004100024038](https://doi.org/10.1017/S0305004100024038)
6. **Pregibon, D. (1981)**. "Logistic regression diagnostics." *The Annals of Statistics*, 9(4), 705–724. [DOI:10.1214/aos/1176345513](https://doi.org/10.1214/aos/1176345513)
7. **Wasserstein, R. L., & Lazar, N. A. (2016)**. "The ASA statement on p-values: context, process, and purpose." *The American Statistician*, 70(2), 129–133. [DOI:10.1080/00031305.2016.1154108](https://doi.org/10.1080/00031305.2016.1154108)
8. **Cramér, H. (1946)**. *Mathematical Methods of Statistics*. Princeton University Press, Princeton, New Jersey.
