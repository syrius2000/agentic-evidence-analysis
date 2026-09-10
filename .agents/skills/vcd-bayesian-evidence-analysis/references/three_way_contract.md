# 新しい3次元経路の統計契約

## 構造と入力

内部A/B/Cは設定varsの順。度数は非負整数、正の総和、上限2^53。最大512セル。重複する組合せは合算し、個票展開しない。水準は全て明示する。標本ゼロは扱うが構造ゼロ・依存性未解決は保留。等値・集合包含の抽出のみ対応。総集中度1、感度0.1・10は教材用の初期設定であり普遍的推奨ではない。

9モデルは [A][B][C]、[AB][C]、[AC][B]、[BC][A]、[AB][AC]、[AB][BC]、[AC][BC]、[AB][AC][BC]、[ABC]。M5は`B ⟂ C | A`、M6は`A ⟂ C | B`、M7は`A ⟂ B | C`を表す。目的変数の指定で集合は変えない。初期版は有限パラメータのPoisson GLMであり、分離判定は数値的な保守的検出。非正則性の完全な解析的判定ではない。

## 指標と保留

- 多項対数尤度は Poisson対数尤度 − {N log N − N − log(N!)}。多項パラメータ数はPoissonの階数−1。BICの標本サイズは総度数N。stats::BICの行数K版は監査列に保存する。R一般の誤りとはしない。
- 局所診断基準はM1・M7・M8。局所ΔG²はダミー再適合による逸脱度減少。score統計量はPearson²/(1−h)。Pearson残差/√N、符号付き逸脱残差/√N、逸脱残差²/Nを別fieldとして保持し、残差二乗と再適合量を同一視しない。
- `ΔG²/N` は「効果量」ではなく、入れ子モデル間の1観測あたりの逸脱度改善。固定総度数の多項表では `2{D_KL(p̂||p_0)−D_KL(p̂||p_1)}` と解釈する。Cramér's V、セル確率、セルBF、実務上の重要性とは別軸である。
- 局所BIC差はΔG²−Δrank log N。その半分は正則な大標本近似log BFであり、厳密BFではない。EBICは採用しない。
- ゼロ観測セルのダミー、階数差不足、leverage≈1、非収束・境界は保留。カイ二乗推論では、比較する両モデルの期待度数が全て5以上の場合だけ漸近P値を表示する。この期待度数条件は保守的な運用heuristicであり、BICの数学的定義ではない。BIC/Laplace型近似のstatusはchi-square inference statusと分離する。
- P値は上側確率・対数尺度で保存する。アンダーフローはnullと対数P値を併記。ゼロ観測のlog(O/E)はnullと負の無限大を表す状態を保存する。
- 固定モデルで度数全体を定数倍すると、O/E、log(O/E)、Pearson残差/√N、符号付き逸脱残差/√N、逸脱残差²/N、ΔG²/N、leverage、odds ratioは不変。一方、G²、ΔG²、残差絶対値、P値、BIC/BF証拠、事後区間幅は変化する。人工コピーは`SCALED_SENSITIVITY_NOT_INDEPENDENT_NEW_OBSERVATIONS`であり、科学的な独立情報の増加ではない。
- セル順位は基準モデル・指標・上位Kを固定して探索的に表示する。leverageや境界フラグは順位安定性の証拠ではない。bootstrap・再標本化による包含率、順位分布、適合成功率は別計画で評価し、現行初版では未実装である。
- 結果JSONは`computation_status`、`model_fit_status`、`chi_square_inference_status`、`bic_approximation_status`、`diagnostic_status`を分離する。bootstrap・perturbationによるStabilityは未実装であり、`stability_status=NOT_EVALUATED`とする。
- `metric_ontology`は少なくとも`metric_class`、`sample_size_behavior`、`inferential_status`を持ち、structure、magnitude、evidence、uncertainty、influence、stability、practical relevanceの問いを混同させない。

## ベイズ推定

飽和多項のDirichlet(y+a/K)を解析・独立乱数で計算する。セル確率の平均と区間はBeta周辺、条件付き割合は条件群内のDirichlet再正規化。差は同じ同時標本から計算する。全区間は点ごとの95%等裾信用区間で、多重性未調整。独立対飽和の厳密BFのみ解析計算し、独立側は3変数の周辺に独立な総集中度aのDirichletを置く。他7モデルの厳密BFやモデル事後確率は未算出。

MC平均は5MCSE＋絶対1e-8＋相対1e-6、分位点はBetaのCDFがq±{5√(q(1−q)/S)+1e-4}を満たすか確認。PPCは固定NでFreeman–Tukey。飽和モデルのPPCを構造モデルの保証に使わない。

## 再現手順

```bash
Rscript tests/statistical_foundations/prepare_cases.R output/statistical_foundations/my_acceptance
Rscript tests/statistical_foundations/run_cases.R output/statistical_foundations/my_acceptance
```

prepareは記述的検分と事前合意済み教材設定の生成。実務データでは相談を省略するために流用しない。テスト出力はGit管理外。既存ディレクトリを上書きせず、検証記録を保持する。
