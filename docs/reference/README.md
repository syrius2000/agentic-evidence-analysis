# 統計リファレンス

created: 2026-09-06 23:52 (JST)
update: 2026-09-06 23:52 (JST)
author: Codex (GPT-5)

このディレクトリは、分析スキルが計算する量の定義、前提、解釈、参考文献を学ぶための正本です。実装の挙動はスキルと [新しい3次元統計契約](../../.agents/skills/vcd-bayesian-evidence-analysis/references/three_way_contract.md)で確認し、ここでは数理的な意味を確認します。

## 読む順序

| 順序 | 文書 | 学ぶ内容 |
| --- | --- | --- |
| 1 | [stats_categorical.md](stats_categorical.md) | 度数、期待値、残差、Cramér's V、P値の読み方 |
| 2 | [three_way_models.md](three_way_models.md) | 9階層モデル、固定Nの多項BIC、セル診断、100倍実験 |
| 3 | [stats_bayesian.md](stats_bayesian.md) | BIC近似と厳密BF、Dirichlet事後、条件付き割合、事前感度 |
| 4 | [advanced_analysis.md](advanced_analysis.md) | Pass 0からの探索設計、Top-K、ARM、疎な表の次の選択 |
| 補助 | [DB_Best_Practices.md](DB_Best_Practices.md) | CSV・DBの型、文字コード、件数整合性 |

## 現行経路の要点

- 3次元経路は、集計度数の9つの階層対数線形モデルを比較します。
- 構造、効果の大きさ、証拠量、不確実性、実務判断を別々に報告します。
- `r² − k log N` は旧監査列で、局所BFや実質的重要性の自動判定ではありません。
- Cramér's VとFeiは背景知識として説明しますが、現行3次元経路の合否指標ではありません。
- BIC差の半分は正則な大標本条件での近似log BFにすぎず、明示事前による厳密BFと区別します。
- 全体BFをセル単位へ転用しません。条件付き割合の信用区間も点ごとの区間です。
- 度数100倍は独立標本の追加ではなく、標本サイズ感度の教材です。

## 参照文献の選び方

標準的な理論はAgresti、Schwarz、Kass & Rafteryを軸にし、実装仕様はR公式マニュアルを一次参照とします。P値の表現についてはASA声明を参照します。有限標本のCramér's V補正はBergsmaを参照します。各文書末尾に著者、年、題名、媒体またはDOI、リンクを記載しています。

## 文書の使い分け

`docs/reference`は講座・利用者向けの数理説明です。実行順序や保留条件はスキル、入力契約は `three_way_contract.md`、回帰検証の証拠は [統計検証報告](../Artifacts/statistical_validation_001_0906.md)を参照します。未実装の方式を、参考文献があるという理由だけで現行機能と扱いません。
