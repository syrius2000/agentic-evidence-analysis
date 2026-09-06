# リファレンス: vcd-bayesian-evidence-analysis (新4軸統計基盤)

このスキルで使用されている固有の理論背景および統計指標の定義ガイドです。

## 1. 4軸セル診断体系 (Effect x Evidence x Influence x Stability)

大標本データセットにおいて、「統計的確信度（Evidence）」と「実務的意義（Effect）」を峻別し、分割表の構造的影響（Influence）と数値的安定性（Stability）を同時に評価するための独立4軸フレームワークです。

### 1.1 Effect（実質的効果量: 標本数 $N$ に不変）
- **局所効果比**: $\log(O_i / E_i) = \ln(y_i / \hat{\mu}_i)$
  - 基準モデル期待値に対する観測値の実質的な倍率（過剰 $>0$、過少 $<0$）。
  - 標本サイズ $N$ が 100倍、10,000倍になっても完全不変であり、大標本分析における主たる意思決定根拠となります。
- **標準化差**: $e_i = \frac{y_i - \hat{\mu}_i}{\sqrt{\hat{\mu}_i \cdot N}}$
  - 標本サイズに依存しない正規化残差指標。
- **全体効果量**: **Cramér's V**
  - 分割表全体の大域的な関連強度（Cohen基準: $>0.1$ 小, $>0.3$ 中, $>0.5$ 大）。

### 1.2 Evidence（証拠強度: 標本数 $N$ に正比例）
- **Leverage補正局所Score統計量**:
  $$T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}} = \frac{(y_i - \hat{\mu}_i)^2}{\hat{\mu}_i (1 - h_{ii})}$$
  - 各セルに指示変数（ダミー）を追加したモデルに対する **Raoのスコア検定統計量（efficient score statistic）**。
  - モデル再適合なしに局所尤度比検定統計量 $\Delta G_i^2$ の高精度な二次近似となります。自由度 1 のカイ二乗分布に従います。
- **局所対数P値**: $\ln p = \text{pchisq}(T_i^{\rm score}, df = 1, \text{lower.tail} = \text{FALSE}, \text{log.p} = \text{TRUE})$
  - 大標本下での数値的アンダーフロー（P値が0に潰れる現象）を防止し、正確な有意性を保持します。

### 1.3 Influence（構造影響度: 標本数 $N$ に不変）
- **Leverage (梃子力)**: $h_{ii} = \text{hatvalues}(fit)$
  - モデル適合に対するセルの拘束度・影響度（$0 \le h_{ii} \le 1$）。
  - 周辺和や表の構造で定まり、標本サイズ拡大に影響されません。

### 1.4 Stability（数値的安定性）
- **ステータス判定**:
  - `REGULAR`: 正常な推定セル（$y_i > 0 \land \hat{\mu}_i \ge 5.0 \land h_{ii} < 0.80$）。
  - `QUARANTINED`: ゼロセル（$y_i = 0$）、小期待度数（$\hat{\mu}_i < 5.0$）、または過大レバレッジ（$h_{ii} \ge 0.80$）により、通常の順位付けから隔離・要慎重解釈とすべきセル。

> [!NOTE]
> **旧セルScore（$r_i^2 - k \log N$）の廃止について**:  
> 従来の $r^2 - k \log N$ は局所LRT統計量 $\Delta G_i^2$ と大きく乖離し、また大標本下で全セルが正値化する「エビデンス飽和」を引き起こすため**非推奨・廃止**としました。

---

## 2. 対数線形モデル選択とベイズ事後推論

### 2.1 総度数 $N$ 基準の明示式 BIC
3元表に対しては 9候補モデル（相互独立 M1 〜 飽和 M9）を適合し、総度数 $N$ に基づく明示式 BIC でモデル選択を行います：
$$\mathrm{BIC}_{\mathrm{explicit}} = -2 \ln L + p \cdot \ln(N)$$
※ $p$ はモデルの自由パラメータ数（切片を含む）。ポアソン完全対数尤度基準。R既定の `stats::BIC` はセル数 $K$ をペナルティに用いるため不採用としました。

### 2.2 多項Dirichlet推論
一様事前分布 $a = 1.0$ のもとで多項Dirichlet事後分布（20,000ドロー）を生成し、層別条件付き割合および層間差（生存率差等）の不確実性を相関構造を保ったまま推論します。

---

## 参考文献
- 採否報告書: `docs/Artifacts/statistical_validation_001_0906.md`
- 局所セル診断再設計: `HairEyeColor_local_cell_diagnostics_redesign.md`
- Agresti, A. (2013). *Categorical Data Analysis* (3rd ed.). Wiley.
- Rao, C. R. (1948). Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation. *Proc. Cambridge Philos. Soc.*
