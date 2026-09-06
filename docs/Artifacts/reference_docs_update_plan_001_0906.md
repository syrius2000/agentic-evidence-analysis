# 数理リファレンスと入口文書の更新計画

created: 2026-09-06 23:47 (JST)
update: 2026-09-06 23:47 (JST)
author: Codex (GPT-5)

## 目的

現行の3次元探索経路が採用する階層対数線形モデル、固定総度数の多項BIC、局所セル診断、Dirichlet事後推定を、`docs/reference/`で講座の受講者が学べる形に整理する。旧 `Evidence Score`、EBIC、Cramér's V / Feiの説明が現行実装の保証範囲を超えないようにし、README・AGENTS・スキル入口から正しい正本へ誘導する。

## 対象

- `docs/reference/README.md`
- `docs/reference/stats_categorical.md`
- `docs/reference/stats_bayesian.md`
- `docs/reference/advanced_analysis.md`
- 新規 `docs/reference/three_way_models.md`
- `README.md`、`AGENTS.md`、`TODO.md`

## 実施内容

1. 現行実装の9モデルと、Poisson表現から固定総度数の多項尤度へ移る式を正本化する。
2. Pearson/deviance残差、leverage補正score、局所ΔG²、log(O/E)、`d/√N`、`ΔG²/N`を、証拠・効果・診断の別軸として説明する。
3. Dirichlet事後、条件付き割合、同時事後標本による層間差、明示事前に依存する独立対飽和の厳密log BFを説明する。
4. BIC近似と厳密BF、全体指標とセル指標、人工100倍と独立標本を明確に区別する。
5. R公式マニュアル、ASA声明、Schwarz、Kass & Raftery、Agresti、Bergsma等を参照文献として記録する。
6. 古い一律閾値・自動勝者判定・未実装指標を入口文書から除去し、後続TODOを更新する。

## 完了条件

- 参照文書の式・用語・適用条件が新経路の `three_way_contract.md` と一致する。
- 現行実装で算出しない指標を「実装済みの合否基準」として記載しない。
- 各文献に著者、年、題名、媒体またはDOI、URLを付す。
- README・AGENTSから旧説明へ到達する導線がなく、相対リンクが解決する。
- `git diff --check` とMarkdownリンク検査が通る。
