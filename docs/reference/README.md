# 統計数理リファレンス体系 (Mathematical Reference Documentation)

本ディレクトリは、多次元カテゴリカル・リアルワールドデータ（RWD）分析パイプラインを支える**統計数理基盤、推定理論、局所診断フレームワーク、およびデータ整合性原則**に関する公式リファレンス群を格納している。

大標本データ（$N > 2,000$）において古典的仮説検定が直面する「P値飽和問題（大標本の呪い）」を数理的に克服し、**「統計的有意性（Evidence）」と「実務的意義（Effect）」を厳格に峻別・統合する理論体系**を記述する。

---

## 1. ドキュメント体系目録

| ドキュメント | 主要テーマ・対象数理 | 主な適用スキル |
| :--- | :--- | :--- |
| **[four_axis_cell_diagnostics.md](./four_axis_cell_diagnostics.md)** | **4軸セル診断体系とRaoスコア検定**<br>・局所対数効果比 $\log(O/E)$ のスケール不変性<br>・Raoの局所スコア検定統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1-h_{ii}}$ の導出証明<br>・ハット行列 $H$ とレバレッジ $h_{ii}$ の実務的解釈<br>・REGULAR vs QUARANTINED 判定基準<br>・旧エビデンススコア（$r^2 - k\ln N$）破綻の数学的理由 | `vcd-bayesian-evidence-analysis`<br>`vcd-categorical-analysis` |
| **[loglinear_models_bic.md](./loglinear_models_bic.md)** | **ポアソン対数線形モデル族と明示式BIC**<br>・ポアソン対数線形回帰の定式化と IRLS 推定<br>・3元表における 9 候補モデル族（M1〜M9）の階層構造<br>・逸脱度（Deviance $G^2$）の漸近分布<br>・総度数 $N$ 基準の明示式 BIC（$\mathrm{BIC} = G^2 + p \ln N$）<br>・ベイズ因子近似 $\ln \mathrm{BF}_{10}$ と Jeffreys スケール | `vcd-bayesian-evidence-analysis` |
| **[bayesian_dirichlet_inference.md](./bayesian_dirichlet_inference.md)** | **ベイズDirichlet事後推論とモデル診断**<br>・多項・Dirichlet 共役モデルの事後平均・分散・共分散<br>・層別条件付き生起割合および割合差（Risk Difference）<br>・20,000 ドローのモンテカルロ積分と MCSE 較正基準<br>・Freeman-Tukey 統計量による事後予測チェック（PPC / PPP-value）<br>・ディリクレ多項式厳密周辺尤度と厳密ベイズ因子 | `vcd-bayesian-evidence-analysis` |
| **[effect_sizes_and_large_samples.md](./effect_sizes_and_large_samples.md)** | **効果量体系と大標本Dual-Filter原則**<br>・P値飽和問題（$\chi^2 = N \phi^2 \to \infty$）の数学的機序<br>・2元表および多次元畳み込み Cramér's $V$ の定式化<br>・適合度検定の最新効果量 Fei ($\text{פ}$)<br>・大標本 Dual-Filter（Effect優先 $\to$ Evidence検証）の運用フロー | 全分析スキル (Pass 0〜Pass 3) |
| **[database_and_pipeline_integrity.md](./database_and_pipeline_integrity.md)** | **データ整合性とパイプライン運用の技術基盤**<br>・型安全性制約（度数非負性、JSTタイムゾーン統一）<br>・サンプリング・ゼロ vs 構造的ゼロの分類と数学的処置<br>・run_id 決定論的ハッシュ規約と出力ディレクトリ隔離設計 | システム統合・共通基盤 |

---

## 2. コア理論体系の概念図

```
========================================================================================
                      【大標本多次元データ分析の階層的推論構造】
========================================================================================

  [ 入力データ ] 多次元クロス集計表 (Total Sample Size N, Cells K)
       │
       ├─────────────────────────────────────────────────────────────┐
       ▼                                                             ▼
  【大域的モデル評価】 (Global Structure)                     【大域的効果量】 (Global Effect)
   ・ポアソン対数線形モデル族 (M1〜M9)                         ・Cramér's V (2元表 / 畳み込み)
   ・総度数 N 基準の明示式 BIC                                 ・Fei (פ) (適合度検定)
   ・ベイズ因子 BF10 (モデル比較)                             ・標本規模 N に依存しない連関強度
   [loglinear_models_bic.md]                                   [effect_sizes_and_large_samples.md]
       │                                                             │
       └──────────────────────────────┬──────────────────────────────┘
                                      │
                                      ▼
             【大標本 Dual-Filter 原則】 (大規模 N > 2,000 時の必須規律)
              第 1 フィルタ: Effect 軸 (|log(O/E)|, Cramér's V) で実質的乖離を抽出
              第 2 フィルタ: Evidence 軸 (Rao Score 統計量 T) でサンプリングノイズを排除
              [effect_sizes_and_large_samples.md]
                                      │
                                      ▼
  【局所セル診断フレームワーク】 (Local Cell Diagnostics: 4-Axis Framework)
       ┌───────────────────────┬───────────────────────┬───────────────────────┐
       ▼                       ▼                       ▼                       ▼
   (1) Effect 軸           (2) Evidence 軸         (3) Influence 軸        (4) Stability 軸
  【対数効果比 log(O/E)】 【Raoスコア統計量 T】   【Leverage h_ii】       【数値安定性判定】
  ・標本数 N に完全不変    ・T = r_P^2 / (1 - h)   ・ポアソンハット行列    ・REGULAR: E>=5, h<0.8
  ・実質的濃縮・希薄化     ・モデル再推定不要      ・自己引力による残差    ・QUARANTINED: 隔離・
  ・スケール不変性の保証   ・局所LRT統計量と一致     収縮を数学的に補正      ベイズDirichlet参照
  [four_axis_cell_diagnostics.md]
                                      │
                                      ▼
  【ベイズ事後推論・モデル診断】 (Bayesian Posterior & PPC)
   ・Dirichlet 共役事後分布による厳密なパラメータ不確実性評価
   ・層別条件付き割合差（Risk Difference）の事後平均・95% 信用区間
   ・Freeman-Tukey 統計量による事後予測チェック（PPP-value）
   [bayesian_dirichlet_inference.md]
========================================================================================
```

---

## 3. 過去ドキュメントのアーカイブについて

旧バージョンのドキュメント群（旧エビデンススコア $r^2 - k\ln N$ を含んでいた歴史的文書）は、トレーサビリティおよび過去の経緯確認のため、以下のアーカイブディレクトリへ完全保存されています：
- **旧リファレンス退避先**: `docs/Archives/legacy_reference_20260906/`
- 本ディレクトリ（`docs/reference/`）内のすべてのドキュメントは、**旧スコアを完全に排除し、新数理基盤に基づいて再設計・統一**されています。

---

## 参考文献（主要原典）
1. **Agresti, A.** (2013). *Categorical Data Analysis* (3rd ed.). John Wiley & Sons.
2. **Rao, C. R.** (1948). Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation. *Proceedings of the Cambridge Philosophical Society*, 44(1), 50–57.
3. **Schwarz, G.** (1978). Estimating the dimension of a model. *The Annals of Statistics*, 6(2), 461–464.
4. **Gelman, A., et al.** (2013). *Bayesian Data Analysis* (3rd ed.). CRC Press.
5. **Ben-Shachar, M. S., et al.** (2023). Phi, Fei, Fo, Fum: Effect Sizes for Categorical Data That Use the Chi-Squared Statistic. *Mathematics*, 11(9), 1982.
