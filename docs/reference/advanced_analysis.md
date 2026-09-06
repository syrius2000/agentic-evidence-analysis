# 探索的分析の設計と実務ワークフロー

created: 2026-09-06 23:51 (JST)
update: 2026-09-07 00:35 (JST)
author: Codex (GPT-5) / Antigravity

高度な実務統計分析において最も重要なのは、複雑な指標を機械的に増やすことではなく、「問い・母集団の分母・モデルの前提・統計的不確実性・意思決定基準」を明確に切り分けることです。

---

## 1. 4-Pass 体系における推奨ワークフロー

本ツールキットでは、以下の 6 段階の思考プロセスに従って分析を進行します：

1. **Pass 0 (Interactive Consultation)**:
   変数、離散水準、観測度数、欠測値、標本単位、観測の独立性、構造ゼロの有無、目的変数、および分母（適格基準）を確定する。
2. **全体構造の同定 (Global Structure)**:
   3 次元データであれば 9 つの階層対数線形モデル（M1〜M9）を適合・比較し、完全独立、条件付き独立、均一連関、3 次交互作用の有無をポアソン完全対数尤度による明示式 BIC（$\mathrm{BIC}_{\mathrm{explicit}} = -2\ln L + p\ln N$）で評価する。
3. **差の大きさの評価 (Effect Size)**:
   局所対数効果比 $\log(O_i / E_i)$、率差 $d_i = (O_i - E_i)/N$、標準化差 $e_i$ により、標本サイズに依存しない現象の大きさを把握する。
4. **証拠強度の診断 (Evidence Strength)**:
   Rao のスコア検定統計量（Leverage 補正 Score 統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1-h_{ii}}$）、自然対数 P 値 $\ln(P)$、および明示事前によるベイズ因子により、偶然の標本誤差である可能性を排除する。
5. **数値安定性と影響度の隔離 (Stability & Influence)**:
   観測ゼロ $O_i=0$、小期待度数 $E_i < 5.0$、過大レバレッジ $h_{ii} \ge 0.80$ の 3 条件を満たすセルを `QUARANTINED`（隔離）とし、数値的不安定性や構造的自己牽引による過大解釈を未然に防ぐ。
6. **実務的判断と次のアクション (Decision & Next Actions)**:
   意思決定に伴う費用やリスク、許容差を考慮し、層別解析、水準の再集約、追加データの収集、またはブートストラップ安定性評価などの後続計画を策定する。

---

## 2. 大標本データにおける Dual-Filter 探索プロトコル（$N > 2,000$）

RWD（リアルワールドデータ）、大規模臨床データ、Web アクセスログ、全数調査アンケートなど、$N$ が数千〜数十万を超えるビッグデータ環境では、「統計的有意性と実用的有意性の乖離（P 値の呪い）」が不可避的に発生します。

本ツールキットでは、大標本環境において以下の **Dual-Filter プロトコル** を厳格に適用します：

```
                    【大標本 Dual-Filter スクリーニング】
┌────────────────────────────────────────────────────────────────────────┐
│  Step 1: Effect Filter（第一スクリーニング: 現象の大きさ）               │
│          基準モデルに対する乗法的乖離 |log(O/E)| >= 0.50                 │
│          （または業務上の最小意味閾値）を満たすセルのみを抽出。         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ 通過したセル
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  Step 2: Evidence Filter（第二スクリーニング: ノイズ排除）              │
│          Leverage 補正 Score 統計量 T_i^score >= 3.84 (自由度1, α=0.05) │
│          により、偶然の標本誤差による見かけの乖離を排除。              │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ 通過したセル
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  Step 3: Stability Check（数値安定性の確認）                            │
│          Stability フラグが REGULAR であり、推論が安定していることを確認│
└────────────────────────────────────────────────────────────────────────┘
```

> [!NOTE]
> 旧エビデンススコア（$r^2 - k\ln N$）は大標本下で全セルが正値化（エビデンス飽和）してスクリーニング機能を失うため、現行システムでは監査専用列（audit-only）として隔離し、上記 Dual-Filter を真の抽出ロジックとして採用しています。

---

## 3. 高度な分析手法との境界と位置づけ

### 3.1 アソシエーションルール（Association Rule Mining: ARM）
ARM における Lift 値：
\[
  \operatorname{Lift}(A \to B) = \frac{P(B \mid A)}{P(B)} = \frac{P(A \cap B)}{P(A) P(B)}
\]
は、相互独立モデル M1 における局所効果比 $O / E$ と数学的に同値です。ただし、ARM の Lift 値は交絡因子（第 3 変数 $C$）の調整を行わないため、シンプソンのパラドックスに脆弱です。3 変数以上の解析では、条件付き独立（M5〜M7）や均一連関（M8）を明示的に統制できる階層対数線形モデルが優位性を持ちます。

### 3.2 疎な分割表（Sparse Tables）と構造ゼロ（Structural Zeros）
期待度数が極端に小さいセルが多数を占める疎な表や、医学的・論理的に存在し得ない組合せ（構造ゼロ）を含む表では、標準的な漸近理論（カイ二乗分布近似）が破綻します。
本ツールキットでは、Pass 0 検分および Stability 判定においてこれらを検知し、安全に推論を保留（QUARANTINED）する設計を採っています。

---

## 4. 参考文献（Primary Literature）

1. **Agresti, A. (2013)**. *Categorical Data Analysis* (3rd ed.). John Wiley & Sons, Hoboken, New Jersey. [ISBN:978-0-470-46363-5](https://www.wiley.com/en-us/Categorical+Data+Analysis%2C+3rd+Edition-p-9780470463635)
2. **Wasserstein, R. L., & Lazar, N. A. (2016)**. "The ASA statement on p-values: context, process, and purpose." *The American Statistician*, 70(2), 129–133. [DOI:10.1080/00031305.2016.1154108](https://doi.org/10.1080/00031305.2016.1154108)
3. **Rao, C. R. (1948)**. "Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation." *Proceedings of the Cambridge Philosophical Society*, 44(1), 50–57. [DOI:10.1017/S0305004100024038](https://doi.org/10.1017/S0305004100024038)
4. **Pregibon, D. (1981)**. "Logistic regression diagnostics." *The Annals of Statistics*, 9(4), 705–724. [DOI:10.1214/aos/1176345513](https://doi.org/10.1214/aos/1176345513)
5. **Schwarz, G. (1978)**. "Estimating the dimension of a model." *The Annals of Statistics*, 6(2), 461–464. [DOI:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)
6. **Cohen, J. (1988)**. *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum Associates, Hillsdale, New Jersey.
