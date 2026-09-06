# 統計基盤検証 レビュー指摘・修正課題コメント

- 受信日時: 2026-09-06 18:39 (JST)
- 対象ブランチ: `Angigravity`
- 関連文書:
  - 検証報告書: [statistical_validation_001_0906.md](statistical_validation_001_0906.md)
  - タスク一覧: [tasks.md](../../openspec/changes/validate-three-way-statistical-foundations/tasks.md)
  - 設計書: [design.md](../../openspec/changes/validate-three-way-statistical-foundations/design.md)

---

## 1. 確認した問題と次に必要なこと（指摘原本）

### (1) 合格基準が設計と異なる
- **問題**: MCSE基準ではなく、事後平均の絶対誤差0.01で判定しています。
- **対応**: 合意した誤差基準に戻して再判定する。基準変更が必要なら理由を記録する。
- **該当処理**: [calibrate_bayesian.R (line 72)](../../tests/statistical_foundations/calibrate_bayesian.R)

### (2) 検証失敗でも実行成功になる経路がある
- **問題**: 結果に `CHECK_FAILED` を設定しても、最後は `SUCCESS` を返します。
- **対応**: 検証失敗を終了コードと最終状態へ反映する。
- **該当処理**: [run_validation.R (line 218)](../../tests/statistical_foundations/run_validation.R)

### (3) 閉形式との照合結果が総合合否に含まれていない
- **問題**: 閉形式との一致判定 `cf_match` が総合判定 `is_ok` / `all_passed` に含まれていません。
- **対応**: 独立参照との不一致を確実に不合格にする。
- **該当処理**: [check_results.R (line 58)](../../tests/statistical_foundations/check_results.R)

### (4) ベイズ計算の検証範囲が完了表示より狭い
- **問題**: 厳密BFのテストは値を表示するだけで、独立した期待値との比較がありません。条件付き割合・層間差の事後計算も確認できませんでした。
- **対応**: 不足する照合・計算を追加し、対応タスクの完了状態を修正する。
- **該当テスト**: [test_section5_bayesian.R (line 44)](../../tests/statistical_foundations/test_section5_bayesian.R)

---

## 2. 数学的な説明・統計学的記述の調整（指摘原本）

### (1) 局所尤度比とベイズ因子の関係
- 局所尤度比へ置き換えれば、そのまま局所ベイズ因子になるわけではありません。
- また、尤度比統計量のカイ二乗分布による評価は、条件付きの漸近近似です。
- 参考解説: [Penn State STAT 504 - Lesson 3](https://online.stat.psu.edu/stat504/Lesson03)

### (2) RのBICと標本サイズの定義
- 「RのBICは統計学的に誤り」という過度の一般化ではなく、「今回想定した多項標本の総度数 $N$ と、Poisson GLM が観測数として扱うセル数 $K$ が異なる」と説明すべきです。

### (3) P値の数値計算と有意性の表現
- P値を `1 - pchisq(...)` で計算しており、小さい値の精度を失う実装です。`pchisq(..., lower.tail = FALSE, log.p = TRUE)` 等で上側確率・対数確率を直接求めます。
- 「すべて過剰有意」という表現を整理し、大標本下での漸近的検出力と効果量（実質的有意性）の観点から記述します。
- R公式仕様: [R chisq distribution reference](https://www.stat.math.ethz.ch/R-manual/R-devel/library/stats/html/Chisquare.html)
