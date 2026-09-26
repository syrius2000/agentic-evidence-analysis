## 1. 設定スキーマと入力検証の実装

- [x] 1.1 `.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json` に `factor_levels_order` および `conditional_rank_reproducibility` のスキーマ定義を追加し、スキーマ構文テストで検証する
- [x] 1.2 `.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R` に一次入力境界チェック（モデルID: M1/M5, metric: abs_log_oe, top_k >= 1, iterations >= 2, seed, 3変数, `factor_levels_order` の存在と全水準完全一致, 完全セル格子, 有限非負整数度数, N>0）を実装し、テスト実行で検証する

## 2. コア計算エンジンと品質ゲートの実装

- [x] 2.1 `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R` に `factor_levels_order` からの正準セルID（`Key=Value/...`）および `canonical_cell_index` 生成、M1/M5 閉形式モデル再推定サブルーチンを実装し、GLM 最尤解との同値性を検証する
- [x] 2.2 適格セル集合（元データ `REGULAR`）の固定、反復中観測ゼロへの 0.5 連続性補正、正準インデックス昇順による決定論的タイブレーク、無効反復内訳カウントを実装する
- [x] 2.3 運用品質ゲート（`valid_rate < 0.95` で保留）および元データ診断後の二段階検証（$K \le \text{eligible\_cell\_count}$ 違反でエラー、適格数0で保留）を実装する
- [x] 2.4 `.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R` に設定の受け渡しと `evidence_results.json` への構造化出力（`estimand_conditioning`、監査メタデータ、警告文、MCSE対）を配管する

## 3. 単体テストと受入テストの作成・検証

- [x] 3.1 `tests/test_conditional_rank_reproducibility.R` を作成し、TC-01（UCB Admissions におけるシード固定完全一致および M5 実測セル数 eligible=13 / quarantined=11）を検証する
- [x] 3.2 TC-02（閉形式と GLM の同値性、および直接入力による 0.5 補正の有限性）を単体テストで検証する
- [x] 3.3 TC-03（不完全格子・2変数・重複セル・非整数度数・`factor_levels_order` 不整合の計算前拒否、および $K > \text{eligible}$ の診断後実行エラー）を検証する
- [x] 3.4 固定疎 fixture `tests/fixtures/sparse_rank_gate_test.csv` を作成し、TC-04（多項リサンプルで層1度数0が約34%発生し、`status: "INSUFFICIENT_VALID_REPLICATES"`, `cells: null` で保留されること）を検証する
- [x] 3.5 TC-05（入力 CSV の行順を変更しても、`factor_levels_order` に基づく正準順序により同一シードで元順位・選択頻度・順位要約が完全一致し、特殊文字を含む水準でも `cell_id` が衝突しないこと）を検証する
- [x] 3.6 TC-06（`conditional_rank_reproducibility` 未指定時に既存の `evidence_results.json` が 1 bit も変化しない後方互換性）を検証する

## 4. 全体回帰テストと品質確認

- [x] 4.1 `python3 tests/test_analysis_quality_contract_docs.py` および `Rscript tests/test_three_way_computation_engine.R` を実行し、既存の全契約・回帰テストが PASS することを確認する
