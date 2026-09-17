# リファレンス: vcd-categorical-analysis

本ファイルは、`vcd-categorical-analysis` の補足リファレンスです。実行条件、入力契約、成果物、品質ゲートの正本は [SKILL.md](SKILL.md) と `references/` 配下の文書です。

## 1. スコープ

本スキルは、名義カテゴリカル変数2つの分割表を対象とする2次元専用の分析経路です。3次元以上の集計表、層別を含む多次元構造、階層対数線形モデルの分析は、正本スキル [vcd-bayesian-evidence-analysis](../vcd-bayesian-evidence-analysis/SKILL.md) に委譲します。

## 2. 主な統計量と可視化

- 独立性検定と適合度の確認
- Cramér's V（必要に応じたバイアス補正および信頼区間）
- Pearson残差・標準化残差によるセル診断
- モザイク図、関連図、セル診断表

モザイク図ではセル面積が観測度数を表し、色は期待度数からの偏りの方向と大きさを表します。P値、効果量、局所診断、不確実性は別々の情報として解釈します。

## 3. 詳細リファレンス

- [分析契約と入出力](references/interface.md)
- [実行フロー](references/workflow.md)
- [アーキテクチャ](references/architecture.md)
- [GLM/GNMと適合度](references/glm-gnm-goodness.md)
- [残差から考察へ変換する手順](references/ai-narrative-workflow.md)
- [順序尺度・Likertの補足](references/ordinal-likert-advanced.md)
- [統計数理リファレンス](../../../docs/reference/stats_categorical.md)
