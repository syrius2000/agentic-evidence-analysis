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
