# 統計数理リファレンス・ポータル

created: 2026-09-06 23:52 (JST)
update: 2026-09-07 00:35 (JST)
author: Codex (GPT-5) / Antigravity

このディレクトリは、本リポジトリの分析スキルが計算・出力する統計指標の数学的定義、背後にある理論、適用条件、および一次文献（学術論文・標準教科書）を網羅した**統計数理的正本リファレンス**です。

---

## 1. 統計哲学の刷新：新 4 軸セル診断と大標本 Dual-Filter 原則

本ツールキットは、従来の「P 値の単一閾値（$p < 0.05$）依存」や「旧エビデンススコア（$r^2 - k\ln N$）による過度の縮約」を根底から脱却し、現代的な大標本統計学（ASA 2016 声明等）に準拠した以下の 4 つの柱を実装しています：

```
                    【分析パイプラインの 4 つの柱】
┌────────────────────────────────────────────────────────────────────────┐
│  1. 全体構造の階層比較（Global Model Hierarchy）                       │
│     → 9 階層対数線形モデル（M1〜M9）と総度数 N 基準の明示式 BIC        │
│       BIC_explicit = -2 ln L + p ln N                                  │
├────────────────────────────────────────────────────────────────────────┤
│  2. 新 4 軸セル診断フレームワーク（Four-Axis Cell Diagnostics）          │
│     → Effect（効果量: 標本数不変 log(O/E), e_i, d_i）                   │
│     → Evidence（証拠強度: 標本数比例 Rao Score T_i^score, ln P）        │
│     → Influence（影響度: ハット行列 Leverage h_ii）                    │
│     → Stability（数値安定性: O_i=0, E_i<5.0, h_ii>=0.80 の隔離判定）   │
├────────────────────────────────────────────────────────────────────────┤
│  3. 大標本 Dual-Filter 原則（N > 2,000）                               │
│     → Step 1: Effect スクリーニング（|log(O/E)| >= 0.50）              │
│     → Step 2: Evidence フィルタリング（T_i^score >= 3.84, ノイズ排除） │
├────────────────────────────────────────────────────────────────────────┤
│  4. 多項 Dirichlet 事後推論と不確実性評価                               │
│     → 共役事前分布による事後平均、点ごとの 95% 信用区間（HDI/ETI）     │
│     → Freeman-Tukey 統計量による事後予測チェック（PPP-value）           │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. ドキュメント構成と読解順序

| 順序 | リファレンス文書 | 主な解説内容・カバーする数理 |
| :---: | :--- | :--- |
| **1** | [カテゴリカル分析の基礎](stats_categorical.md) | 分割表の基礎（行数・セル数・総度数 $N$ の区別）、ピアソン残差と標準化残差、全体効果量 Cramér's V（Cohen 1988 基準と Bergsma 2013 バイアス補正）、旧スコア破綻の数理、ASA 2016 P値声明 |
| **2** | [3次元カテゴリカル探索の数理](three_way_models.md) | 9 階層対数線形モデル（M1〜M9）、ポアソン完全対数尤度と明示式 BIC、新 4 軸セル診断（Effect/Evidence/Influence/Stability）、大標本 Dual-Filter 原則、局所逸脱度改善量 $\Delta G_i^2/N$ |
| **3** | [ベイズ推定とモデル比較の基礎](stats_bayesian.md) | ベイズ因子（周辺尤度比）の定義、Schwarz BIC 近似の成立条件、多項 Dirichlet 事後推論、条件付き割合の同時事後サンプリング、独立対飽和の解析的厳密ベイズ因子、Freeman-Tukey 事後予測チェック |
| **4** | [探索的分析設計と実務ワークフロー](advanced_analysis.md) | 4-Pass 推奨思考プロセス、大標本 Dual-Filter スクリーニング手順、アソシエーションルール（ARM）や疎な表との境界 |
| **5** | [分析スキルの責務境界](skill_responsibilities.md) | 各スキル（Pass 0, vcd-bayesian 3次元正本, vcd-categorical 2次元, バッチ）の役割分担とインターフェース契約 |
| **補助** | [DB設計とデータ整合性](DB_Best_Practices.md) | データ型選定、文字コード（UTF-8/utf8mb4）、総度数 $N$ 完全一致検証、サンプリングゼロの保持 |

---

## 3. 旧指標の位置づけ（監査専用列）

過去のプロトタイプで用いられた旧エビデンススコア（$r^2 - k\ln N$）は、サンプルサイズ $N$ が大規模（数万〜数十万）になると全セルが正値化（エビデンス飽和）してスクリーニング機能を失います。また、局所尤度比改善量（$\Delta G_i^2$）とも数学的に乖離します。
このため、現行ツールキットでは旧スコアを**監査専用列（audit-only）**として隔離し、真の信号判定や合否判定には一切使用しません。

---

## 4. 一次文献マスターインデックス（Primary Literature）

本リポジトリで採用されている統計数理手法の原著論文および標準教科書の一覧です：

1. **Rao, C. R. (1948)**. "Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation." *Proceedings of the Cambridge Philosophical Society*, 44(1), 50–57. [DOI:10.1017/S0305004100024038](https://doi.org/10.1017/S0305004100024038)
   - *Leverage 補正 Score 検定統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1-h_{ii}}$ の基礎となる局所スコア検定理論。*
2. **Pregibon, D. (1981)**. "Logistic regression diagnostics." *The Annals of Statistics*, 9(4), 705–724. [DOI:10.1214/aos/1176345513](https://doi.org/10.1214/aos/1176345513)
   - *一般化線形モデル（GLM）におけるハット行列 $H$、Leverage $h_{ii}$、および過大レバレッジ（$h_{ii} \ge 0.80$）の診断理論。*
3. **Pierce, D. A., & Schafer, D. W. (1986)**. "Residuals in generalized linear models." *Journal of the American Statistical Association*, 81(396), 977–986. [DOI:10.1080/01621459.1986.10478361](https://doi.org/10.1080/01621459.1986.10478361)
   - *GLM における残差の漸近分散と標準化ピアソン残差の定式化。*
4. **Schwarz, G. (1978)**. "Estimating the dimension of a model." *The Annals of Statistics*, 6(2), 461–464. [DOI:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)
   - *多変量指数型分布族におけるベイズ情報量基準（BIC）の漸近導出。*
5. **Agresti, A. (2013)**. *Categorical Data Analysis* (3rd ed.). John Wiley & Sons, Hoboken, New Jersey. [ISBN:978-0-470-46363-5](https://www.wiley.com/en-us/Categorical+Data+Analysis%2C+3rd+Edition-p-9780470463635)
   - *対数線形モデル、標準化残差、逸脱度、条件付き独立性の世界的標準教科書。*
6. **Good, I. J. (1965)**. *The Estimation of Probabilities: An Essay on Modern Bayesian Methods*. Research Monograph No. 30, The M.I.T. Press, Cambridge, Massachusetts.
   - *多項度数分布に対する Dirichlet 共役事前分布と事後平滑化の先駆的著作。*
7. **Gelman, A., Carlin, J. B., Stern, H. S., Dunson, D. B., Vehtari, A., & Rubin, D. B. (2013)**. *Bayesian Data Analysis* (3rd ed.). Chapman and Hall/CRC, Boca Raton, Florida. [ISBN:978-1-4398-4095-5](https://www.routledge.com/Bayesian-Data-Analysis/Gelman-Carlin-Stern-Dunson-Vehtari-Rubin/p/book/9781439840955)
   - *事後予測チェック（PPC）、事後予測 P 値（PPP-value）、階層ベイズ推論の基礎。*
8. **Cohen, J. (1988)**. *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum Associates, Hillsdale, New Jersey.
   - *Cramér's V を含む効果量の標準的解釈基準（Small / Medium / Large）。*
9. **Bergsma, W. (2013)**. "A bias-correction for Cramér’s $V$ and Tschuprow’s $T$." *Journal of the Korean Statistical Society*, 42(3), 323–328. [DOI:10.1016/j.jkss.2012.10.002](https://doi.org/10.1016/j.jkss.2012.10.002)
   - *有限標本における Cramér's V の不偏推定量導出。*
10. **Wasserstein, R. L., & Lazar, N. A. (2016)**. "The ASA statement on p-values: context, process, and purpose." *The American Statistician*, 70(2), 129–133. [DOI:10.1080/00031305.2016.1154108](https://doi.org/10.1080/00031305.2016.1154108)
    - *アメリカ統計学会（ASA）による P 値の誤用警告と有意性・効果量の峻別原則。*
11. **Bishop, Y. M. M., Fienberg, S. E., & Holland, P. W. (1975)**. *Discrete Multivariate Analysis: Theory and Practice*. MIT Press, Cambridge, Massachusetts.
    - *離散多変量データ分析と対数線形モデルの古典的名著。*
12. **Kass, R. E., & Raftery, A. E. (1995)**. "Bayes factors." *Journal of the American Statistical Association*, 90(430), 773–795. [DOI:10.1080/01621459.1995.10476572](https://doi.org/10.1080/01621459.1995.10476572)
    - *ベイズ因子の包括的レビュー、BIC 近似の評価、Jeffreys スケールの整理。*
