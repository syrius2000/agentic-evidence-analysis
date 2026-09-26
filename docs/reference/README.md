# 統計数理リファレンス・ポータル

created: 2026-09-06 23:52 (JST)
update: 2026-09-12 21:54 (JST)
author: Codex (GPT-5) / Antigravity

このディレクトリは、本リポジトリの分析スキルが計算・出力する統計指標の数学的定義、背後にある理論、適用条件、および一次文献（学術論文・標準教科書）を網羅した**統計数理的正本リファレンス**です。

---

## 1. 統計哲学の刷新：新 4 軸セル診断と大標本 Dual-Filter 原則

本ツールキットは、従来の「P 値の単一閾値（$p < 0.05$）依存」や「旧エビデンススコア（$r^2 - k\ln N$）による過度の縮約」を根底から脱却し、現代的な大標本統計学（ASA 2016 声明等）に準拠した以下の 5 つの柱を実装しています：

| 柱 | 領域 | 中核手法・指標 | 役割と数理的根拠 |
| :---: | :--- | :--- | :--- |
| **1** | **全体構造の階層比較**<br>(Global Model Hierarchy) | 9 階層対数線形モデル（M1〜M9）<br>総度数 $N$ 基準の明示式 BIC | $\mathrm{BIC}_{\mathrm{explicit}} = -2 \ln L + p \ln N$<br>ポアソン完全対数尤度に基づき、過大・過小ペナルティを排した決定論的モデル選択 |
| **2** | **新 4 軸セル診断フレームワーク**<br>(Four-Axis Cell Diagnostics) | ・Effect（効果量）<br>・Evidence（証拠強度）<br>・Influence（影響度）<br>・Stability（数値安定性） | ・Effect: 標本倍率不変 $\log(O/E)$、標準化差 $e_i^{(\mathrm{global})}$、率差 $d_i$<br>・Evidence: 標本数比例 Rao Score $T_i^{\mathrm{score}}$、対数 P 値 $\ln(P)$<br>・Influence: ハット行列 Leverage $h_{ii}$（Pregibon 1981）<br>・Stability: $O_i=0$、$E_i<5.0$、$h_{ii} \ge 0.80$ の論理和判定（`QUARANTINED` 隔離） |
| **3** | **探索的Dual-Filter原則** | 次元別の2段階スクリーニング | ・2次元: $N \ge 2,000$、REGULAR、$|\log(O/E)| \ge 0.50$、$T_i^{\mathrm{score}} \ge 3.84$<br>・3次元: REGULAR、Effect、Evidence（Nカットオフなし）<br>・いずれもFWER/FDR、実務的重要性、因果性を保証しない |
| **4** | **多項 Dirichlet 事後推論と不確実性評価** | 共役事前分布による事後標本化<br>事後予測チェック（PPC） | ・部分集合分子・分母による条件付き割合と 95% 等裾信用区間（ETI）<br>・全セル同時事後標本による層間差 $\Delta \theta$ の事後推論<br>・Freeman-Tukey 統計量による事後予測 P 値（PPP-value） |
| **5** | **標本変動下における条件付き順位再現性**<br>(Conditional Rank Reproducibility: CRR) | 多項再標本化と各反復でのモデル再適合（M1/M5）<br>運用品質ゲート（有効反復率 $\ge 0.95$） | ・元データ `REGULAR` 適格セル集合 $\mathcal{C}_{\mathrm{reg}}$ に限定した条件付き Top-$K$ 選択頻度 $\hat{\pi}_i^{(K)}$ と MCSE<br>・固定期待度数の誤謬を排除した反復閉形式 MLE 推定<br>・階数落ち・特異分割表に対する安全な解釈保留（HOLD）契約 |

---

## 2. ドキュメント構成と読解順序

| 順序 | リファレンス文書 | 主な解説内容・カバーする数理 |
| :--- | :--- | :--- |
| **1** | [カテゴリカル分析の基礎](stats_categorical.md) | 分割表の基礎（行数・セル数・総度数 $N$ の区別）、ピアソン残差と標準化残差、全体効果量 Cramér's V（Cohen 1988 基準と Bergsma 2013 バイアス補正）、旧スコア破綻の数理、ASA 2016 P値声明 |
| **2** | [3次元カテゴリカル探索の数理](three_way_models.md) | 9 階層対数線形モデル（M1〜M9）、閉形式最尤推定量と反復比例適合（IPF）、ゼロセル分類と最尤推定量存在条件（Fienberg 1970）、ポアソン完全対数尤度と明示式 BIC、新 4 軸セル診断（Effect/Evidence/Influence/Stability）、マルチベースライン診断構造、大標本 Dual-Filter 原則、標本サイズ $c$ 倍拡張（100倍実験）の漸近挙動体系、局所逸脱度改善量 $\Delta G_i^2/N$、条件付きセル順位再現性（CRR）の多項再標本化と反復再推定 |
| **3** | [ベイズ推定とモデル比較の基礎](stats_bayesian.md) | ベイズ因子（周辺尤度比）の定義、Schwarz BIC 近似の成立条件、多項 Dirichlet 事後推論、部分集合指定による一般化条件付き割合と層間差の同時事後推論、均一連関オッズ比不変性、シンプソンのパラドックス解消機構、独立対飽和の解析的厳密ベイズ因子、Freeman-Tukey 事後予測チェック |
| **4** | [探索的分析設計と実務ワークフロー](advanced_analysis.md) | 4-Pass 推奨思考プロセス、大標本 Dual-Filter スクリーニング手順、アソシエーションルール（ARM）や疎な表との境界 |
| **5** | [分析スキルの責務境界](skill_responsibilities.md) | 各スキル（Pass 0, vcd-bayesian 3次元正本, vcd-categorical 2次元, バッチ）の役割分担とインターフェース契約、CRRの解釈境界 |
| **補助** | [DB由来集計表の分析入力契約](DB_Best_Practices.md) | DB由来集計表のデータ型・文字コード・時刻意味論、総度数 $N$ 完全一致検証、サンプリングゼロの保持。DB/SQL 実装の正本は対象外。 |
| **運用** | [エージェント出力スタイル（ADHD配慮）](output_style_adhd.md) | 認知負荷を抑え、アクションに直結させるための出力・コミュニケーションスタイル規約 |

---

## 3. 旧指標の位置づけ（監査専用列）

過去のプロトタイプで用いられた旧Evidence Score（$r^2-k\ln N$）は、再適合した局所尤度比改善量（$\Delta G_i^2$）、局所BIC差、Rao scoreとは異なる式です。固定した非ゼロ乖離では大標本ほど正値になりやすいため候補判定に使わず、監査専用列として扱います。セル追加モデルの正当な局所比較は、基準モデル、追加項、尤度、パラメータ差、探索上の限界を明示して別に扱います。
このため、現行ツールキットでは旧スコアを**監査専用列（audit-only）**として隔離し、真の信号判定や合否判定には一切使用しません。

---

## 4. OpenSpec 仕様群（`openspec/specs/`）と数理リファレンスの対応マッピング

本リポジトリの分析スキルが準拠する正本仕様（`openspec/specs/` 配下の 7 仕様）と、本数理リファレンスの各セクションとの対応関係は以下の通りです：

| OpenSpec 仕様 (`openspec/specs/`) | 依拠する主な数理リファレンス | カバーされる数理的基礎・定理 |
| :--- | :--- | :--- |
| **[`cell-evidence-interpretation`](../../openspec/specs/cell-evidence-interpretation/spec.md)** | [3次元探索の数理](three_way_models.md) §4, §5<br>[ベイズ推定の基礎](stats_bayesian.md) §3 | ・Effect / Evidence / Influence / Stability の新 4 軸分離<br>・旧スコア監査列化と真の信号判定の分離<br>・多項 Dirichlet 事後信用区間と事前感度分析<br>・探索的セル候補と確証検定（多重比較）の非同値性 |
| **[`conditional-rank-reproducibility`](../../openspec/specs/conditional-rank-reproducibility/spec.md)** | [3次元探索の数理](three_way_models.md) §7 | ・反復モデル再適合（M1/M5 閉形式 MLE）による固定期待度数の誤謬解消<br>・元データ `REGULAR` 適格セル母集合への条件付けと 0.5 連続性補正<br>・因子水準直積順 `canonical_cell_index` による決定論的タイブレーク<br>・Top-$K$ 選択頻度 $\hat{\pi}_i^{(K)}$ とモンテカルロ標準誤差（MCSE）の定式化<br>・運用品質ゲート（有効反復率 $\ge 0.95$）による解釈保留（HOLD）契約<br>・未指定時における既存出力の完全な 1 ビット・SHA-256 不変性 |
| **[`conditional-rate-view`](../../openspec/specs/conditional-rate-view/spec.md)** | [ベイズ推定の基礎](stats_bayesian.md) §3.3, §3.4, §3.5 | ・部分集合分子・分母による一般化条件付き割合 $\theta_{A \mid B, g}$<br>・全セル同時 Dirichlet 事後標本による層間差 $\Delta \theta$ の推論<br>・分母ゼロ時の不確実性発散と部分 HOLD の数理条件<br>・均一連関オッズ比不変性とシンプソンのパラドックス解消 |
| **[`multi-baseline-cell-diagnostics`](../../openspec/specs/multi-baseline-cell-diagnostics/spec.md)** | [3次元探索の数理](three_way_models.md) §4.4, §4.5 | ・M1 相互独立基準（大局的連関）と M_best 選択モデル基準（残余乖離）の分離<br>・基準モデル依存の期待値・残差・Leverage の数学的直交性<br>・基準モデル間のセル件数合算・率平均化の数理的禁止<br>・Stability 3 条件（観測ゼロ、疎セル、過大レバレッジ）の論理和判定 |
| **[`three-way-model-assessment`](../../openspec/specs/three-way-model-assessment/spec.md)** | [3次元探索の数理](three_way_models.md) §2, §2.1, §2.2, §3 | ・9 階層対数線形モデル（M1〜M9）の配位と自由度<br>・M1〜M7 の閉形式最尤推定量公式と M8 の反復比例適合（IPF）<br>・サンプリングゼロと構造ゼロの区分、最尤推定量存在条件（Fienberg 1970）<br>・総度数 $N$ 基準のポアソン明示式 BIC（$-2\ln L + p\ln N$） |
| **[`three-way-validation-cases`](../../openspec/specs/three-way-validation-cases/spec.md)** | [3次元探索の数理](three_way_models.md) §2.1, §5.2<br>[カテゴリカル基礎](stats_categorical.md) §4 | ・標本サイズ $c$ 倍拡張（100倍実験）における統計量の漸近次数体系（$O(1)$ vs $O(N)$ vs $O(1/\sqrt{N})$）<br>・GLM と閉形式解・IPF の独立参照値二重照合<br>・人工既知構造表・異常系シナリオの挙動固定 |
| **[`three-way-dashboard-reporting`](../../openspec/specs/three-way-dashboard-reporting/spec.md)** | [3次元探索の数理](three_way_models.md) §2, §3<br>[実務ワークフロー](advanced_analysis.md) §1<br>[責務境界](skill_responsibilities.md) §3 | ・BIC 最小モデルの「相対的評価」原則（真のモデルの証明ではない限界明示）<br>・完全オフライン契約（外部 CDN / Ajax / フォント取得ゼロ）<br>・Pass 2.5 主張ゲート（JSON Pointer / 数値 / SHA-256）の照合保証 |

---

## 5. 一次文献マスターインデックス（Primary Literature）

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
   - *有限標本における Cramér's V のバイアス低減補正の導出。*
10. **Wasserstein, R. L., & Lazar, N. A. (2016)**. "The ASA statement on p-values: context, process, and purpose." *The American Statistician*, 70(2), 129–133. [DOI:10.1080/00031305.2016.1154108](https://doi.org/10.1080/00031305.2016.1154108)
    - *アメリカ統計学会（ASA）による P 値の誤用警告と有意性・効果量の峻別原則。*
11. **Bishop, Y. M. M., Fienberg, S. E., & Holland, P. W. (1975)**. *Discrete Multivariate Analysis: Theory and Practice*. MIT Press, Cambridge, Massachusetts.
    - *離散多変量データ分析と対数線形モデルの古典的名著。*
12. **Kass, R. E., & Raftery, A. E. (1995)**. "Bayes factors." *Journal of the American Statistical Association*, 90(430), 773–795. [DOI:10.1080/01621459.1995.10476572](https://doi.org/10.1080/01621459.1995.10476572)
    - *ベイズ因子の包括的レビュー、BIC 近似の評価、Jeffreys スケールの整理。*
13. **Deming, W. E., & Stephan, F. F. (1940)**. "On a least squares adjustment of a sampled frequency table when the expected marginal totals are known." *The Annals of Mathematical Statistics*, 11(4), 427–444. [DOI:10.1214/aoms/1177731829](https://doi.org/10.1214/aoms/1177731829)
    - *反復比例適合法（IPF）の原著論文。*
14. **Fienberg, S. E. (1970)**. "The analysis of multidimensional contingency tables when some cells had missing data." *Journal of the American Statistical Association*, 65(330), 980–986. [DOI:10.1080/01621459.1970.10481138](https://doi.org/10.1080/01621459.1970.10481138)
    - *分割表における最尤推定量の存在条件とゼロセル解析の基礎。*
15. **Csiszár, I. (1975)**. "$I$-divergence geometry of probability distributions and minimization problems." *The Annals of Probability*, 3(1), 146–158. [DOI:10.1214/aop/1176996454](https://doi.org/10.1214/aop/1176996454)
    - *情報量幾何学における $I$-射影と IPF の幾何学的正当化。*
16. **Yule, G. U. (1903)**. "Notes on the theory of association of attributes in statistics." *Biometrika*, 2(2), 121–134. [DOI:10.1093/biomet/2.2.121](https://doi.org/10.1093/biomet/2.2.121)
    - *層別による関連の逆転（シンプソンのパラドックス）の定式化。*
17. **Simpson, E. H. (1951)**. "The interpretation of interaction in contingency tables." *Journal of the Royal Statistical Society: Series B (Methodological)*, 13(2), 238–241. [DOI:10.1111/j.2517-6161.1951.tb00088.x](https://doi.org/10.1111/j.2517-6161.1951.tb00088.x)
    - *分割表における高次交互作用と交絡の解釈。*
18. **Efron, B., & Tibshirani, R. J. (1993)**. *An Introduction to the Bootstrap*. Chapman and Hall/CRC, New York. [ISBN:978-0-412-04231-7](https://www.routledge.com/An-Introduction-to-the-Bootstrap/Efron-Tibshirani/p/book/9780412042317)
    - *多項再標本化（リサンプリング）、モンテカルロ標準誤差（MCSE）、および順位変動評価の統計理論。*
