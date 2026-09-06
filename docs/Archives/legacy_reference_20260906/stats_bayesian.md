# 共通統計リファレンス: ベイズ統計と4軸セル診断体系

このドキュメントは、対数線形モデル比較や、大規模データにおける局所セル診断（4軸フレームワーク: Effect × Evidence × Influence × Stability）の数理的背景をまとめたものです。

---

## 1. 対数線形モデル比較と明示式BIC (Total Sample Size N)

分割表データにおける要因間の独立性や交互作用構造を検証するため、ポアソン対数線形モデル（Poisson GLM）のモデル族（M1〜M9）を適合します。

### モデル選択基準（明示式BIC）
Rの標準 `BIC()` 関数は分割表の集約行数を標本サイズ $n$ として誤認しがちですが、本パイプラインでは真の総観測度数 $N$ を基準とした明示式BICを採用しています。
$$\mathrm{BIC} = \mathrm{Deviance} + \mathrm{df}_{\rm used} \cdot \ln(N)$$
- $\mathrm{Deviance} = 2 \sum_i O_i \ln(O_i / E_i)$
- $\mathrm{df}_{\rm used}$: モデルで使用されたパラメータ数
- $N = \sum_i O_i$: 分割表全体の総観測度数

BIC最小（$\Delta\mathrm{BIC} = 0$）のモデルが最良モデルとして選択されます。

### ベイズ因子近似 ($BF_{10}$)
2つの競合するモデル（例：独立モデル $M_0$ と 飽和・交互作用モデル $M_1$）の比較には、BIC差分によるベイズ因子近似が利用されます：
$$\ln BF_{10} \approx \frac{\mathrm{BIC}_{M_0} - \mathrm{BIC}_{M_1}}{2}$$
- **$BF_{10} > 100$**: 決定的エビデンス（Decisive）
- **$30 \sim 100$**: 非常に強いエビデンス（Very Strong）
- **$10 \sim 30$**: 強いエビデンス（Strong）

---

## 2. 4軸セル診断フレームワーク（局所セル評価）

大標本データ（$N > 2,000$）において、大域モデルの棄却や全体P値だけでは「どのサブグループ（セル）が乖離を引き起こしているか」を実務的・客観的に特定できません。本体系では以下の4軸で個別セルを多面的に診断します。

### 軸 1: Effect（効果量・乖離の大きさ）
標本規模 $N$ に依存しない本質的なシグナル強度です。
- **対数効果比 $\log(O_i / E_i)$**:
  観測度数 $O_i$ と基準モデルの期待度数 $E_i$ の対数比。正値は過剰（濃縮）、負値は過少（希薄化）を示す。標本数が100倍になっても値は不変（スケール不変性）。
- **全体効果量（Cramér's $V$）**:
  表全体の連関の強さ（$[0, 1]$）。大標本下での全体的スクリーニング指標。

### 軸 2: Evidence（統計的証拠・有意性）
標本抽出誤差（ノイズ）による偶然の偏りを退ける検定指標です。
- **Leverage補正Score統計量 $T_i^{\rm score}$（Raoの局所スコア検定）**:
  $$T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}$$
  ここで $r_{P,i} = \frac{O_i - E_i}{\sqrt{E_i}}$ はピアソン残差、$h_{ii}$ はポアソンGLMにおけるハット行列対角成分（Leverage）。
  特定セルにのみ局所特異効果パラメータ $\delta_i$ を付加した局所モデル比較（LRT $\Delta G_i^2$）の厳密なスコア検定統計量であり、モデル再推定なしに厳密な局所検定統計量と一致します。
- **局所P値**: $\chi^2(1)$ 分布に基づく検定P値。

> [!NOTE]
> **旧エビデンススコアの廃止について**:
> 従来の $r_i^2 - k \ln N$ という指標は、局所尤度比検定統計量と乖離し、また超大標本で全セルが正値化する「エビデンス飽和」を引き起こすため、廃止されました。新体系では Rao のスコア統計量 $T_i^{\rm score}$ と効果量 $\log(O/E)$ の併用（Dual-Filter）により、厳密かつ頑健な判定を行います。

### 軸 3: Influence（影響度・てこ比）
- **Leverage $h_{ii}$**:
  そのセルが対数線形モデルの適合値（期待値 $E_i$）に及ぼす影響度（$[0, 1]$）。$h_{ii}$ が大きいセルは期待値を自身に引き寄せるため、残差が過小評価されやすくなります（$T_i^{\rm score}$ はこれを数学的に補正します）。

### 軸 4: Stability（数値安定性・信頼性）
- **診断状態（Stability Status）**:
  - `REGULAR`: 期待値 $E \ge 5$ かつ $h < 0.8$。大標本漸近正規性・カイ二乗分布近似が成立する信頼性の高いセル。
  - `QUARANTINED`: 期待値が極小（$E < 5$）または過大レバレッジ（$h \ge 0.8$）のセル。統計量が数値的に不安定になるため、解釈保留・隔離フラグを付与。

---

## 3. 大標本モード（Dual-Filter 原則）

総度数 $N > 2,000$ のデータでは、検定統計量（$T_i$）やP値は微小な差でも過敏に極大化します。
したがって、以下の手順で解釈を組み立てます：
1. **第1フィルタ（Effect軸）**:
   まず効果比 $|\log(O/E)|$ および Cramér's $V$ に基づき、実務的・臨床的に意味のある大きさの乖離が存在するセルを絞り込む。
2. **第2フィルタ（Evidence軸）**:
   絞り込まれたセルについて、Score統計量 $T_i^{\rm score}$ および P値を確認し、偶然誤差でないことを裏付ける。

---

## 参考文献
- Agresti, A. (2013). *Categorical Data Analysis* (3rd ed.). John Wiley & Sons.
- Rao, C. R. (1948). Large sample tests of statistical hypotheses concerning several parameters with applications to problems of estimation. *Mathematical Proceedings of the Cambridge Philosophical Society*.
- Jeffreys, H. (1961). *Theory of Probability*. Oxford University Press.
- Schwarz, G. (1978). Estimating the dimension of a model. *The Annals of Statistics*.
