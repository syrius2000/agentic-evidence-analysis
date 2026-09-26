# 比較エビデンス解析レポート (Comparative Evidence Report)

## 1. 重要な解釈上の注意と免責事項

> [!WARNING]
> **同等性の誤認禁止**: 不確実性区間が 0 を跨ぐこと（差が非有意であること）は、二群間の「同等性」や「差がないこと」を証明しません。
> **因果的優越の禁止**: 方向支持指標は、観察研究や未調整交絡の存在下で治療の因果的優越性を単独で証明するものではありません。
> **多重比較の探索的スクリーニング免責**: 複数テーマの一括スクリーニング解析では、家族ワイズ第1種過誤率（FWER）は制御されていません。本結果は仮説生成のための探索的スクリーニングとして解釈してください。

## 2. 解析結果要約

| テーマ | 比較 | 生データ記述N (T / R) | 生データ記述イベント数 (T / R) | 有効標本サイズ ESS (T / R) | RD 推定値 [区間] | RR 推定値 [区間] | 方向支持指標 | 推論方式 | U-Grade | 領域 | 診断バッジ |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| T1_TargetExcess | Active vs Control | 100 / 100 | 45 / 5 | N/A | 0.397 [0.288, 0.502] | 8.73 [4.05, 23.79] | 1.000 (P(RD > 0)) | posterior; ETI | U0 | target_excess |  |
| T2_RefExcess | Active vs Control | 100 / 100 | 5 / 45 | N/A | -0.395 [-0.501, -0.288] | 0.12 [0.04, 0.25] | 0.000 (P(RD > 0)) | posterior; ETI | U0 | reference_excess |  |
| T3_Neutral | Active vs Control | 1000 / 1000 | 50 / 50 | N/A | 0.000 [-0.019, 0.019] | 1.01 [0.68, 1.46] | 0.514 (P(RD > 0)) | posterior; ETI | U2 | practical_neutral |  |
| T4_U3_Uncertain | Active vs Control | 100 / 100 | 10 / 10 | N/A | 0.001 [-0.084, 0.085] | 1.01 [0.43, 2.34] | 0.512 (P(RD > 0)) | posterior; ETI | U3 | target_excess |  |
| T5_TargetU2 | Active vs Control | 100 / 100 | 12 / 8 | N/A | 0.039 [-0.046, 0.123] | 1.48 [0.65, 3.58] | 0.827 (P(RD > 0)) | posterior; ETI | U2 | target_excess |  |
| T6_ZeroRef | Active vs Control | 100 / 100 | 10 / 0 | N/A | 0.097 [0.046, 0.167] | 45.51 [3.80, 17480.30] | 1.000 (P(RD > 0)) | posterior; ETI | U0 | target_excess | ZERO_REFERENCE;UNSTABLE_RR_INTERVAL |

## 3. 統計指標の解説と利用ガイド (Statistical Metric Guide)

### 1. リスク・発症割合 (Risk / incidence proportion)
- **生の記述割合 (raw descriptive proportion)**: $p_{T,\text{raw}} = x_T / n_T$, $p_{R,\text{raw}} = x_R / n_R$
- **推論的点推定値 (inferential point estimate)**: 独立 Jeffreys 事前分布 $\text{Beta}(0.5, 0.5)$ に基づく事後中央値（posterior median）を使用。生の記述割合とは明確に区別されます。

### 2. リスク差 (Risk Difference: RD)
- **定義**: $RD = p_T - p_R$（一次対比）。絶対的な過剰負担や治療効果の規模を直接評価します。
- **重要禁止解釈**: 区間が 0 を跨ぐことは二群間の「同等性」や「差がないこと」を証明しません。

### 3. 相対リスク (Relative Risk: RR)
- **定義**: $RR = p_T / p_R$。対照群に対する相対的な発生リスクの対比を評価します。
- **ゼロセル挙動**: 対照群イベント数ゼロ ($x_R = 0$) の場合、理論的期待値 $E(RR) = \infty$ となり、平均値契約は `mean = null`, `mean_is_finite = false` となります。主対比として RD を併用してください。

### 4. 不確実性区間 (Uncertainty Interval)
- **Bayesian 95% ETI**: モデル・事前分布・観測データを条件として、パラメータの事後確率質量の 95% を含む等裾区間（下側 2.5% 点と上側 97.5% 点）。

### 5. 方向支持指標 (Direction Support)
- **定義**: $P(RD > 0 \mid \text{data})$（ベイズ事後方向支持確率）。
- **重要禁止解釈**: 方向確率単独で治療の因果的優越性を主張してはなりません。

### 6. 実務領域と一次対比閾値 (Practical Difference Regions & primary_delta)
- **3 領域確率**: $q_T = P(RD > \delta)$, $q_N = P(-\delta \le RD \le \delta)$, $q_R = P(RD < -\delta)$ ($q_T + q_N + q_R = 1$)。
- **無効化契約**: `primary_delta = null` の場合、実務領域分類は無効化（`none`）され、無彩色化されます。

### 7. 実務領域解像度グレード (U-Grade)
- **定義**: 最大領域確率 $C = \max(q_T, q_N, q_R)$ に基づく解像度等級（U0 $\ge$ 0.95, U1 $\ge$ 0.80, U2 $\ge$ 0.60, U3 < 0.60）。
- **重要禁止解釈**: 不確実性分布の実務領域への収まり具合（解像度）であり、標本サイズ（精度）や有害事象の臨床的重症度を意味しません。

### 8. 連続精度指標と有効標本サイズ (Precision Metrics & ESS)
- **定義**: 区間幅 ($RD_{\text{width}} = RD_{\text{upper}} - RD_{\text{lower}}$) および IPTW デザイン等の有効標本サイズ (ESS)。

### 9. 診断バッジ (Diagnostic Badges)
- **主なバッジ**: `ZERO_REFERENCE`, `ZERO_BOTH`, `SPARSE_EVENTS`, `UNSTABLE_RR_INTERVAL`。比率指標の数値不安定性を警告し、RD の併用を促します。

### 10. 多重比較・探索的スクリーニング指針 (Multiplicity & Exploratory Use)
- **探索的位置付け**: 家族ワイズ第1種過誤率（FWER）は制御されておらず、シグナル検出・仮説生成のためのスクリーニングです。自動規制決定や薬事承認の決定的根拠としてはなりません。
