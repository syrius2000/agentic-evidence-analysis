# 探索的分析の設計と実務ワークフロー

created: 2026-09-06 23:51 (JST)
update: 2026-09-12 21:54 (JST)
author: Codex (GPT-5) / Antigravity

高度な実務統計分析において最も重要なのは、複雑な指標を機械的に増やすことではなく、「問い・母集団の分母・モデルの前提・統計的不確実性・意思決定基準」を明確に切り分けることです。

---

## 1. 4-Pass 分析体系における 6 次元の判断フレームワーク

本ツールキットの 4-Pass パイプライン（Pass 0: 対話検分 $\to$ Pass 1: R エンジン計算 $\to$ Pass 2: AI 統計レビュー $\to$ Pass 3: レポート統合）では、統計的推論において以下の **6 つの次元を独立に分離して評価** します（AGENTS 統計原則）：

1. **前提の検分と契約 (Pass 0: Interactive Consultation)**:
   変数、離散水準、観測度数、欠測値、標本単位、観測の独立性、構造ゼロの有無、目的変数、および分母（適格基準）を確定し、`analysis_config.json` を正本として固定する。
2. **全体構造の同定 (Dimension 1: Global Structure)**:
   3 次元データであれば 9 つの階層対数線形モデル（M1〜M9）を適合・比較し、完全相互独立、条件付き独立、均一連関、3 次交互作用の有無を総度数 $N$ 基準のポアソン完全対数尤度明示式 BIC（$\mathrm{BIC}_{\mathrm{explicit}} = -2\ln L + p\ln N$）で評価する。
3. **差の大きさの評価 (Dimension 2: Effect Size / 標本数不変)**:
   局所対数効果比 $\log(O_i / E_i)$、率差 $d_i = (O_i - E_i)/N$、大標本規格化差 $e_i^{(\mathrm{global})}$ により、標本サイズ $N$ に依存しない現象自体の乗法的・加法的大きさを把握する。
4. **証拠強度の診断 (Dimension 3: Evidence Strength / 標本数比例)**:
   Rao のスコア検定統計量（Leverage 補正 Score 統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1-h_{ii}}$）および自然対数 P 値 $\ln(P)$ により、帰無モデルからの局所的乖離の統計的証拠を評価する。
5. **数値安定性と影響度の隔離 (Dimension 4: Stability & Influence)**:
   観測ゼロ $O_i=0$、疎セル $E_i < 5.0$、過大レバレッジ $h_{ii} \ge 0.80$ の 3 条件論理和を満たすセルを `QUARANTINED`（隔離）とし、漸近近似破綻や構造的自己牽引による過大解釈を未然に防ぐ。
6. **不確実性評価と実務的判断 (Dimension 5 & 6: Uncertainty & Decision)**:
   多項 Dirichlet 事後推論による点ごとの 95% 等裾信用区間（ETI）で不確実性を可視化し、意思決定に伴う費用やリスク、許容差を考慮して、層別解析、水準再集約、追加調査などの実務アクションを策定する。

---

## 2. 次元別のDual-Filter探索プロトコル

RWD（リアルワールドデータ）、大規模臨床観察データ、Web アクセスログ、大規模アンケートなど、$N$ が数千〜数十万を超える環境では、「統計的有意性と実質的意味の乖離（P 値の呪い）」が不可避的に発生します。

2次元では$N \ge 2,000$を含む探索的条件として以下のDual-Filterを適用します。3次元の現行候補条件はREGULAR、Effect、Evidenceであり、2次元のNカットオフを流用しません。どちらも実務的重要性、因果性、FWER/FDRを保証しません。

```
                    【大標本 Dual-Filter スクリーニング】
┌────────────────────────────────────────────────────────────────────────┐
│  Step 1: Effect Filter（第一スクリーニング: 現象の大きさ）               │
│          基準モデルに対する乗法的乖離 |log(O/E)| >= 0.50                 │
│          （実質的な偏りを持つセルのみを通過）                            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ 通過したセル
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  Step 2: Evidence Filter（第二スクリーニング: ノイズ・低検出力排除）     │
│          Leverage 補正 Score 統計量 T_i^score >= 3.84                    │
│          （未調整カイ二乗有意点 alpha=0.05 相当の探索閾値）             │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ 通過したセル
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  Step 3: Stability Check（数値安定性の確認）                            │
│          Stability フラグが REGULAR であり、漸近近似が成立していること  │
└────────────────────────────────────────────────────────────────────────┘
```

> [!WARNING]
> **Dual-Filter の統計的制約と解釈上の厳格な境界**:
>
> 1. **多重比較未調整（No FWER / FDR Guarantee）**: $T_i^{\rm score} \ge 3.84$ はセルごとの公称水準 $\alpha = 0.05$（自由度 1 のカイ二乗分布の上側 5% 点）に基づく単一セル基準の探索的足切りです。表全体のファミリーワイズ誤差率（FWER）や偽発見率（FDR）を調整・保証するものではありません。
> 2. **漸近近似の成立限界**: 疎セル（$E_i < 5.0$）や境界解では漸近カイ二乗近似が成立しないため、事前の Stability 条件（Quarantine）による除外が不可欠です。
> 3. **実務的重要性・因果性の非保証**: 本フィルタの通過は「大標本下で実質的な効果量と基礎的な証拠強度の両基準を同時に満たす探索候補」であることを意味するに過ぎず、実務上の重要性、因果関係、外部妥当性、再現性を保証するものではありません。

**旧Evidence Score（$r^2-k\ln N$）の監査列化**:
旧式は、再適合したセル追加モデルの局所尤度比または局所BIC差から導かれていないため、候補判定には使いません。固定した非ゼロ乖離では大標本ほど正値になりやすい一方、全セルの正値化を一般則とはしません。局所モデル改善は基準モデル、追加項、尤度、パラメータ差、境界条件を明示して別に評価します。

---

## 3. 高度な分析手法との境界と位置づけ

### 3.1 アソシエーションルール（Association Rule Mining: ARM）

ARM における 2 元周辺表 $(A, B)$ の Lift 値：

$$
\operatorname{Lift}(A \to B) = \frac{P(B \mid A)}{P(B)} = \frac{P(A \cap B)}{P(A) P(B)}
$$

は、同じ 2 元周辺表で相互独立を基準にしたセル別比 $O_{ab}/E_{ab}$ と対応します。ただし、3 元表の M1 におけるセル別比は $O_{abc}/E_{abc}$（確率表示では $P(A,B,C)/(P(A)P(B)P(C))$）であり、周辺化した $A \to B$ の Lift と一般には同値ではありません。

したがって、第 3 変数 $C$ を含む分析では、次の量を異なる estimand として分離して扱います。

- **周辺 Lift**: $C$ を周辺化した 2 元表における $A$ と $B$ の関連。
- **層別 Lift**: 各 $C=c$ の 2 元表における $A$ と $B$ の関連。
- **3 元セル診断**: M1、条件付き独立（M5〜M7）、または均一連関（M8）など、明示した基準モデルに対するセル別乖離。

ARM の周辺 Lift は交絡因子を自動調整しないため、シンプソンのパラドックスに脆弱です。3 変数以上では、周辺・層別・モデル基準セル診断のいずれを報告するかを Pass 0 で固定し、互いの値を同一尺度として比較・合算しません。

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
