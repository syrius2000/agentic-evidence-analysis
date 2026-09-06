# 統計リファレンス (Reference Documentation)

このディレクトリには、本プロジェクトの分析パイプラインで使用されている統計的手法、数理的背景、および解釈基準に関する詳細なドキュメントが格納されています。

## ドキュメント一覧

| ファイル名 | 内容 | 対象スキル |
| :--- | :--- | :--- |
| **[stats_categorical.md](./stats_categorical.md)** | **カテゴリカル分析の基礎**: ピアソン残差、効果量 (Cramér's V / Fei)、大標本におけるP値の飽和問題について。 | 全スキル |
| **[stats_bayesian.md](./stats_bayesian.md)** | **ベイズ的エビデンス評価**: ベイズ因子 ($BF_{10}$)、Evidence Score ($r^2 - k\log N$)、EBIC の数理的背景について。 | `vcd-bayesian-evidence-analysis` |
| **[advanced_analysis.md](./advanced_analysis.md)** | **高度な分析ワークフロー**: Dual-Filter フレームワーク、アソシエーション分析 (ARM)、Top-K ランキング手法について。 | 全スキル (Pass 0/2/3) |

## 基本コンセプト

本プロジェクトは、大規模データ ($N > 5,000$) において「すべてが有意になってしまう」従来の検定の限界を克服することを目的としています。各ドキュメントを参照することで、単なる計算結果の読み方だけでなく、**「統計的有意性」と「実務的意義」をいかに峻別するか**の理論的根拠を確認できます。

---

# Reference Documentation (English)

This directory contains technical documentation regarding the statistical methods, mathematical backgrounds, and interpretation criteria used in this project.

## Documents

- **[stats_categorical.md](./stats_categorical.md)**: Fundamentals of categorical analysis, including Pearson residuals, effect sizes (Cramér's V / Fei), and the P-value saturation problem.
- **[stats_bayesian.md](./stats_bayesian.md)**: Bayesian evidence evaluation, covering Bayes Factors ($BF_{10}$), Evidence Scores, and Extended BIC (EBIC).
- **[advanced_analysis.md](./advanced_analysis.md)**: Advanced workflows such as the Dual-Filter framework, Association Rule Mining (ARM), and Top-K ranking strategies.

## Core Philosophy

This toolkit is designed to overcome the limitations of classical hypothesis testing in large-scale datasets, where trivial deviations often become statistically significant. These references provide the theoretical foundation for distinguishing **"Statistical Significance"** from **"Practical Significance."**
