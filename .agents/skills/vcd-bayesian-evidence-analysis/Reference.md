# DEPRECATED: vcd-bayesian-evidence-analysis 旧リファレンス（履歴資料）

> [!WARNING]
> **この文書は旧プロトタイプの互換・履歴資料です。**
>
> 過去のプロトタイプで用いられた `Evidence Score = r² − k \log(N)` は、度数を 100 倍にした大標本環境においてほぼ全セルが正値化（エビデンス飽和）してフィルタ機能を喪失すること、および局所尤度比改善量（LRT）と数学的に乖離することが判明したため、現行システムでは**監査専用列（audit-only）**として隔離されています。
>
> 新規の 3 次元カテゴリカル分析および正規の統計解釈においては、必ず以下の現行正本を参照してください：
> - [現行スキル契約 (SKILL.md)](SKILL.md)
> - [3次元分析契約 (three_way_contract.md)](references/three_way_contract.md)
> - [3次元カテゴリカル探索の数理](../../../docs/reference/three_way_models.md)
> - [統計数理リファレンス・ポータル](../../../docs/reference/README.md)

---

## 1. 旧指標: Evidence Score（監査専用列）の歴史的定義と限界

過去の実装において、大標本下でのノイズ除外を試みる探索的プロトタイプとして以下の独自式が検討されました：

\[
  \text{Evidence Score}_i = r_{P,i}^2 - k \cdot \log(N)
\]

- $r_{P,i}$: ピアソン残差 $\frac{O_i - E_i}{\sqrt{E_i}}$
- $k \cdot \log(N)$: サンプルサイズ対数に基づく簡易ペナルティ（$k=1$ または $k=2$）

### 【数学的破綻と現行での扱い】
度数を 100 倍（$N \to 100N$）にするシミュレーション実験において、シグナル項 $r^2$ が 100 倍に膨張するのに対し、ペナルティ項は $\log(100N) = \log N + 4.61$ と線形にしか増加せず、全セルの 90% 以上が正値化（エビデンス飽和）してスクリーニング機能を喪失しました。
そのため、現行ツールキットでは本指標を真の信号判定やセル合否判定から完全撤廃し、過去ログ照合用の**監査専用列**としてのみ保持しています。

---

## 2. 現行の正規診断体系：新 4 軸セル診断フレームワーク

現行の `three-way-results-v1` 経路では、セル単位の診断を以下の 4 つの独立した軸に完全統一しています：

1. **Effect（効果量: $N$ 不変）**: 局所対数効果比 $\log(O_i / E_i)$、標準化差 $e_i$、率差 $d_i$
2. **Evidence（証拠強度: $N$ 比例）**: Rao (1948) の局所スコア検定統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1-h_{ii}}$、対数 P 値 $\ln(P)$
3. **Influence（影響度）**: ハット行列対角成分 Leverage $h_{ii}$（Pregibon, 1981）
4. **Stability（数値安定性）**: 観測ゼロ $O_i=0$、疎セル $E_i < 5.0$、過大 Leverage $h_{ii} \ge 0.80$ の 3 条件論理和による `QUARANTINED`（隔離）判定

大標本環境（$N > 2,000$）では、**Effect（$|\log(O/E)| \ge 0.50$）** を第一スクリーニングとし、通過セルのみ **Evidence（$T_i^{\rm score} \ge 3.84$）** によるノイズ排除を行う **Dual-Filter 原則** を採用しています。

---

## 3. 一次情報・参考文献（Primary Literature）

1. **Rao, C. R. (1948)**. "Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation." *Proceedings of the Cambridge Philosophical Society*, 44(1), 50–57. [DOI:10.1017/S0305004100024038](https://doi.org/10.1017/S0305004100024038)
2. **Pregibon, D. (1981)**. "Logistic regression diagnostics." *The Annals of Statistics*, 9(4), 705–724. [DOI:10.1214/aos/1176345513](https://doi.org/10.1214/aos/1176345513)
3. **Agresti, A. (2013)**. *Categorical Data Analysis* (3rd ed.). John Wiley & Sons.
4. **Schwarz, G. (1978)**. "Estimating the dimension of a model." *The Annals of Statistics*, 6(2), 461–464. [DOI:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)
