## 1. 条件付き事後の数理契約

- [ ] 1.1 `P(B|A)` と `P(A|B)` の丸め前drawから平均、標準偏差、中央値、q025、q975、ETI幅を算出し、固定seedの小規模表で期待値と分位点順序を検証する
- [ ] 1.2 各drawと丸め前の条件付き事後平均の総和、確率範囲、ETI幅を検証し、中央値・分位点の総和を要求しない回帰テストを追加する
- [ ] 1.3 疎な表を用いて有限値・ゼロマージン境界・既存の結合確率、対数乖離、感度分析の回帰を検証する

## 2. Interface 3.0 の加法的拡張

- [ ] 2.1 既存cell posteriorへ両方向の条件付き事後フィールド（`mean`, `sd`, `median`, `q025`, `q975`, `eti_width`）を加え、`categorical_results_v3.json` の型・必須性・null表現を更新してSchema検証を通す
- [ ] 2.2 `cell_posteriors[*]` の局所対数乖離（`log_divergence_*`, `prob_dir_positive`）および `sensitivity_analysis`（`cell_comparisons[*]`）のJSON Schema定義を更新し、加法的検証テストを追加する
- [ ] 2.3 Uncertainty Ranking の決定論的ソート規則（`prob_eti_width` 降順 $\to$ `observed` 昇順 $\to$ 水準名昇順）に従った順序整合テストを追加する
- [ ] 2.4 serializerと必要な表形式出力を更新し、行・列水準、丸め規則、セル識別子がJSON・CSV間で一致するテストを追加する
- [ ] 2.5 serializerへ条件付き確率のcross-field不変量を追加し、不一致時に `SCHEMA_INVARIANT_VIOLATION` で停止するテストを追加する
- [ ] 2.6 先行Change 1から引き継いだ `execution_mode`（`"canonical"`）を `serializer_v3.R` の `provenance_block` へ追加し、成果物JSONのprovenance完全性を検証する


## 3. 回帰検証と引継ぎ

- [ ] 3.1 `tests/test_vcd_categorical_dirichlet_v4.R`、`tests/test_vcd_categorical_interface_v3.R`、関連する入力境界テストを個別Rプロセスで実行し、依存関係不足時に自動インストールしないことを確認する
- [ ] 3.2 既存fixtureと新規fixtureの変更範囲を確認し、Interface 3.0互換性、固定seed再現性、`git diff --check` を検証する
- [ ] 3.3 Dashboard changeへ渡す条件付き事後のJSONフィールド、丸め規則、表示上の注意を実行証跡とともに記録する

