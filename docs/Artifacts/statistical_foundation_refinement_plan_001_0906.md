# 統計基盤の改定・再検証計画書（HairEyeColor 局所セル診断の知見を統合）

- 作成日時: 2026-09-06 18:55 (JST)
- 対象ブランチ: `Angigravity` (Worktree: `agentic-evidence-analysis-antigravity`)
- 参照資料:
  - レビュー指摘: [review_feedback_001_0906.md](review_feedback_001_0906.md)
  - HairEyeColor 局所セル診断再設計文書: `HairEyeColor_local_cell_diagnostics_redesign.md`
  - 検証報告書: [statistical_validation_001_0906.md](statistical_validation_001_0906.md)
  - 設計書: [design.md](../../openspec/changes/validate-three-way-statistical-foundations/design.md)

---

## 1. 改定の基本方針

ユーザーレビューにおける 5 つの是正指摘（MCSE基準の復帰、検証失敗の終了コード反映、閉形式総合照合、ベイズ条件付き事後・厳密BF検証、数学的説明の厳密化）に、`HairEyeColor` 解析再設計文書の卓越した統計的知見（**leverage補正 score 統計量、Evidence/Effect/Influence/Stability の4軸分離、$N$ 不変効果量**）を統合し、強固で学術的・実務的に最高水準の統計基盤を完成させる。

---

## 2. 課題別 改定設計

### (1) モンテカルロ校正基準の「MCSE基準」復帰
- **現状**: 固定値 `abs(mean - analytical) <= 0.01` で判定。
- **改定**:
  - 各セルのモンテカルロ標準誤差 $\text{MCSE}(\bar{p}_i) = \text{sd}(p_{i, \cdot}) / \sqrt{D}$ を算出（$D = 20,000$）。
  - 合格基準: 全セルで $|\bar{p}_i - \mathbb{E}[p_i]| \le 3 \times \text{MCSE}(\bar{p}_i)$（99.7% 信頼区間基準）。
  - カバレッジ率基準: 95% 等裾区間の包含率について、二項標準誤差 $\text{SE}(\hat{c}) = \sqrt{0.95 \times 0.05 / D} \approx 0.00154$ に基づき、$|\hat{c}_i - 0.95| \le 3 \times \text{SE}(\hat{c}) \approx 0.0046$ で判定。

### (2) 検証失敗時の終了コード・最終状態への完全反映
- **現状**: `evaluation_status = "CHECK_FAILED"` でも `status = "SUCCESS"` が返り、終了コード 0 で正常終了する。
- **改定**:
  - `evaluation_status != "VERIFIED"` の場合、戻り値ステータスを `"CHECK_FAILED"` とする。
  - `main()` において検証失敗時は終了コード `1`（非ゼロ）で exit し、自動パイプラインや CI で確実に検知可能とする。

### (3) 閉形式照合（`cf_match`）の総合合否への完全組み込み
- **現状**: `check_results.R` で `cf_match` が `is_ok` に含まれていない。
- **改定**:
  - 閉形式が存在するモデル（M1〜M7, M9）において、`if (r_m$has_closed_form) is_ok <- is_ok && isTRUE(cf_match)` を組み込む。
  - 閉形式・IPF解（`stats::loglin`）・GLM解（`fit_models.R`）の 3 者完全一致を合格条件とする。

### (4) ベイズ計算の検証範囲拡充
- **厳密BFの独立期待値照合**:
  - 人工独立表 `syn_independent` で $\ln BF_{\text{sat}, \text{ind}} < 0$（独立モデル支持）となること、および既知の小規模表での手計算期待値との完全一致をアサート。
- **条件付き割合・層間差の事後推定**:
  - `calibrate_bayesian.R` に `compute_conditional_posterior_differences()` を実装。
  - 同一の同時事後標本 $p^{(d)}$ から、目的変数の条件付き確率 $\theta_{Y|X}^{(d)}$ および層間差 $\Delta \theta^{(d)}$ の事後平均、周辺 95% 等裾区間、事後確率 $P(\Delta > 0)$ を導出し、テストを追加。

### (5) 局所セル診断の体系的再設計（HairEyeColor の知見統合）
旧Score $r_i^2 - k \ln N$ から、以下の多軸診断体系へと移行する：

1. **Leverage 補正 Score 統計量**:
   $$\boxed{T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}}$$
   - $h_{ii} = \text{hatvalues}(M_0)$（GLMのHat行列対角成分 = Leverage）。
   - 1セルダミー追加に対する efficient score statistic であり、$T_i^{\rm score} \approx \Delta G_i^2$ の漸近関係を持つ。
2. **Exact 局所尤度比（Local LRT）**:
   $$\Delta G_i^2 = \text{deviance}(M_0) - \text{deviance}(M_{0 + \{i\}})$$
3. **$N$ 不変効果量（Sample-Size Invariant Effects）**:
   - 対称的相対効果: $\log(O_i / E_i)$
   - 正規化逸脱度残差: $e_i = d_i / \sqrt{N}$
   - 局所モデル改善度（正規化）: $\Delta G_i^2 / N$
4. **4軸によるセル診断出力**:
   - **Effect（効果量）**: $\log(O_i / E_i)$, $d_i / \sqrt{N}$, $\Delta G_i^2 / N$
   - **Evidence（証拠量）**: $\Delta G_i^2$, $T_i^{\rm score}$, 漸近P値（対数P値含む）
   - **Influence（影響度）**: $h_{ii}$ (Leverage)
   - **Stability（安定性）**: 境界推定・列従属のフラグ

### (6) 数学的記述・学術的説明の修正
- **局所尤度比とベイズ因子**: 局所 $\Delta G_i^2$ はカイ二乗漸近近似に基づく尤度比統計量であり、そのままベイズ因子ではない。ベイズ因子とするには $\Delta \text{BIC}_i = \Delta G_i^2 - \ln N$ のような漸近情報量規準近似を介す必要がある。
- **Rの `stats::BIC`**: 「RのBICは誤り」ではなく、「多項標本の固定総度数 $N$ と、Poisson GLM が観測行数として扱うセル数 $K$ の定義の乖離」と正確に解説。
- **P値の数値計算**: `1 - pchisq(...)` を `pchisq(..., lower.tail = FALSE)` に修正し、対数P値 `log.p = TRUE` も保持してアンダーフローを防止。「すべて過剰有意」を「大標本下での漸近的検出力増大に伴う微小効果の有意化」と整理。

---

## 3. 実装・検証のステップ

| フェーズ | 対象ファイル | 主な作業内容 |
| :--- | :--- | :--- |
| **Phase 1: 統計・校正エンジンの改定** | `calibrate_bayesian.R`<br>`check_results.R`<br>`audit_information_criteria.R` | - MCSE基準判定（$3 \times \text{MCSE}$）の実装<br>- 条件付き割合・層間差の事後推定関数の実装<br>- 閉形式 `cf_match` の総合合否組み込み<br>- `pchisq(lower.tail=FALSE, log.p=TRUE)` への修正<br>- Leverage $h_{ii}$ および $T_i^{\rm score} = r_i^2 / (1-h_{ii})$、$N$不変効果量（$\log(O/E)$, $d/\sqrt{N}$, $\Delta G^2/N$）の追加 |
| **Phase 2: パイプラインとテストの強化** | `run_validation.R`<br>`test_section5_bayesian.R`<br>`test_intentional_mismatch.R` | - 検証失敗時の非ゼロ終了コード反映<br>- 厳密BFの独立期待値アサーションの追加<br>- 条件付き割合・層間差の事後推定テストの追加<br>- 陰性対照テスト（閉形式不一致、検証失敗の非ゼロ終了）の拡充 |
| **Phase 3: 結合検証と結果再生成** | 全7ケースの再実行<br>`output/statistical_foundations/` | - 7ケースのパイプライン再実行（新セル診断フィールドおよびMCSE校正を含む `validation_results.json` の更新）<br>- 全単体テストの合格確認 |
| **Phase 4: 採否報告書の全面改訂** | `docs/Artifacts/statistical_validation_001_0906.md`<br>`tasks.md` | - HairEyeColor の知見（4軸分離、Score統計量）を盛り込んだレポート改訂<br>- 数学的説明の厳密化<br>- tasks.md の完了証拠の更新 |
