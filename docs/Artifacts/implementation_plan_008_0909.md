# Pass 0 コンサルテーション必須化の実装計画

created: 2026-09-09 09:25 (JST)
update: 2026-09-09 09:25 (JST)
author: Codex (GPT-6)

## 背景

`vcd-pass0-consultation` はリポジトリの分析鉄則であるにもかかわらず、Bayesian、Categorical、Questionnaire の各スキルでは「推奨」「任意」「設定がある場合」と記載され、Pass 1 の実行経路も設定なしの直接実行を許しています。そのため、AI のスキル選択と R 実行の双方で Pass 0 が省略されます。

## 目的

すべての新規カテゴリカル分析で、`vcd-pass0-consultation` による検分・対話・`analysis_config.json` 確定を Pass 1 の前提にします。既存の統計計算、モデル式、閾値、乱数、出力数値は変更しません。

## 対象範囲

- 3つの分析スキルの frontmatter と本文を「必須依存」「順序厳守」に改定する。
- Bayesian、Categorical、Questionnaire の Pass 1 エントリーポイントで、`--config` と有効な Pass 0 設定を検証し、未指定時は FAIL-FAST で停止する。
- `analysis_config.json` に Pass 0 の生成元を識別できる最小メタデータ（`pass0_completed` または既存スキーマに適合する marker）を追加する。既存の正規スキーマと互換性を保つ。
- テストに「Pass 0 なしの拒否」「Pass 0 設定ありの成功」「3スキルの説明・依存参照」を追加する。
- README と共通品質契約の記述を、推奨ではなく必須の順序へ統一する。

## 非対象

- Pass 0 スキルの対話内容、統計手法、モデル式、閾値、乱数、既存結果の一括再計算。
- 既存の legacy run の書き換え、commit、push、外部システムへの書き込み。

## 受入条件

- 3スキルの `SKILL.md` が `vcd-pass0-consultation` を必須の最初のステップとして明記する。
- Pass 1 を `--config` なしで起動した場合、正式 run や統計成果物を作成せず非ゼロ終了する。
- Pass 0 で生成した有効な `analysis_config.json` を渡した場合、既存の Pass 1 出力契約が成立する。
- 無効な設定、入力・変数不一致、Pass 0 marker 欠落は、計算開始前に拒否する。
- 既存ライフサイクル、可搬パス、数値不変性テストが通過する。

## 検証

- Pass 0 未実行の拒否を各スキルで確認する。
- Pass 0 設定を使った3スキルのスモーク実行を確認する。
- `tests/test_run_scope_lifecycle.R`、`tests/test_run_scope_guards.R`、`tests/test_relocatable_run_lifecycle.R`、統計基盤テスト、Python契約テストを再実行する。
- `git diff --check` と新規成果物の個人パス漏洩スキャンを実施する。
