# 統計基盤本番統合および旧エビデンススコア完全撤廃 完了報告書

- **文書ID**: `STAT-REPORT-001-0906`
- **作成日時**: 2026年09月06日 22:35 JST
- **作業環境**: Mac mini M2 Pro (Apple Silicon), メモリ 32 GB, R 4.6.1, macOS
- **対象ブランチ**: `Angigravity`
- **関連計画書**: [statistical_foundation_skill_migration_plan_001_0906.md](./statistical_foundation_skill_migration_plan_001_0906.md)

---

## 1. エグゼクティブ・サマリー

`tests/statistical_foundations/` において実証された最新の統計数理基盤を、本番分析スキル `vcd-bayesian-evidence-analysis`、規範文書（`README.md`, `AGENTS.md`）、品質契約（`analysis_quality_contract.md`）、および可視化ダッシュボード（`dashboard.Rmd`）へ完全統合した。

あわせて、大標本下で全セルが正値化し過剰適合を招いていた従来の「旧エビデンススコア（$r^2 - k \ln N$）」をリポジトリ全体から完全に廃止・一掃した。タイタニック通常標本（$N = 2,201$）および 100 倍拡大標本（$N = 220,100$）を用いた統合受入検証を実施し、新体系である **「4軸セル診断フレームワーク（Effect × Evidence × Influence × Stability）」**、**「総度数 $N$ 基準の明示式 BIC」**、および **「大標本 Dual-Filter 原則」** が極めて高精度に機能し、標本規模に対するスケール不変性が成立することを数理的・定量的に実証した。

---

## 2. 背景と課題（先祖返りの真因と解決）

### 2.1 発生していた課題
- 実証テスト（`tests/` 配下）では新統計仕様（4軸診断・明示式BIC）が確立されていたものの、本番スキル（`.agents/skills/vcd-bayesian-evidence-analysis/`）内の計算エンジンおよびダッシュボードテンプレートが未改修のまま残存していた。
- そのため、スキル実行時に旧エビデンススコア（$r^2 - k \ln N$）が出力され、AI エグゼクティブ・サマリーでも旧スコアに基づいた解釈が再生成されるという「先祖返り」が発生していた。

### 2.2 解決方針
1. **旧エビデンススコアの完全撤廃**: 計算コード、データ構造、ダッシュボード、解説文から $r^2 - k \ln N$ を排除。
2. **4軸セル診断体系の完全統合**:
   - **Effect（効果量）**: 対数効果比 $\log(O/E)$（局所尺度）、Cramér's $V$（大域尺度）
   - **Evidence（統計的証拠）**: Leverage補正Score統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}$（Raoの局所スコア検定統計量）
   - **Influence（影響度）**: ポアソンGLMハット行列対角成分（Leverage $h_{ii}$）
   - **Stability（数値安定性）**: 期待値 $E < 5$ または $h \ge 0.8$ の隔離判定（`REGULAR` vs `QUARANTINED`）
3. **総度数 $N$ 基準の明示式BICの適用**: 観測行数ではなく総度数 $N$ を基準とした明示式 BIC（$\mathrm{BIC}_{\mathrm{explicit}} = -2\ln L + p \cdot \ln(N)$、$p$ はモデル自由パラメータ数）による 9 候補対数線形モデル比較（M1〜M9）。ポアソン完全対数尤度に基づき、M1（独立モデル）の BIC は 1160.1817 と検証仕様と完全に整合。

---

## 3. 実施内容と改修ファイル

計画書（[statistical_foundation_skill_migration_plan_001_0906.md](./statistical_foundation_skill_migration_plan_001_0906.md)）および QA 指摘（Cycle 1/2）に沿って改修を完了した。

### 改修ファイル一覧

| No | 改修ファイル | 主な改修内容 |
| :---: | :--- | :--- |
| 1 | `README.md` | エビデンス判定基準テーブルを 4 軸セル診断および明示式 BIC へ刷新。旧スコア廃止を明記。 |
| 2 | `AGENTS.md` | 行動規範（Evidence Judgment Criteria）を 4 軸体系へ改訂。旧式の使用を禁止。 |
| 3 | `.agents/shared/analysis_quality_contract.md` | AI 考察の品質契約から旧スコアを完全除外。大標本下での Dual-Filter（Effect 優先）を義務化。 |
| 4 | `docs/reference/loglinear_models_bic.md` | 数理解説を新設（ポアソン対数尤度基準の明示式 BIC、逸脱度との厳密な関係式、モデル選択理論）。 |
| 5 | `docs/reference/four_axis_cell_diagnostics.md` | 4 軸診断体系（Effect, Evidence, Influence, Stability）の数理的定義（ゼロセル、疎セル、過大レバレッジ $h \ge 0.80$）。 |
| 6 | `docs/reference/README.md` | 統計リファレンス目録を新 4 軸体系へ整合（旧文書は Archives へ退避）。 |
| 7 | `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R` | 9 モデル適合、明示式 BIC 算出、4 軸セル診断算出（$O=0 \lor E<5 \lor h \ge 0.80$ で QUARANTINED）、Dirichlet 事後推論関数を実装。2/3元表ガード追加。 |
| 8 | `.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R` | 旧スコア算出を全廃。4 軸診断構造（`cells`）、モデル選択（`models`）を出力。実在 CLI オプションを厳密に定義。 |
| 9 | `.agents/skills/vcd-bayesian-evidence-analysis/Reference.md` | 4 軸および明示式 BIC の数理的定義へ更新。Stability 閾値（$h \ge 0.80$, ゼロセル）を完全整合。 |
| 10 | `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R` | スタブ出力を新 JSON スキーマ（`input_summary`, `effects`, `models`）へ完全対応。 |
| 11 | `.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md` | 旧 CLI オプション・旧スキーマを完全削除し新 4 軸オプションへ改訂。Stability 3 条件を明記。 |
| 12 | `.agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd` | 統計カード、モデル比較表、Top-K 4軸表（自然対数P値 $\ln P$ 追加・ソートキー整合）、全セルDT表、新用語解説へ全面刷新。 |
| 13 | `.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R` | 旧キー（`threshold_k`, `ebic_*`, `arm_*` 等）を非推奨化（`[DEPRECATED]` 警告）、新キー `base_model` を追加。 |
| 14 | `.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json` | 旧キーをスキーマから全廃（Drop）、新キー `base_model` を追加。 |
| 15 | `tests/fixtures/statistical_foundations/stability_leverage_fixture_3way.csv` | $h \ge 0.80$ 越えセル、ゼロセル、疎セル、正常セルの 4 状態を完全網羅する 3 元表フィクスチャ。 |
| 16 | `tests/test_vcd_bayesian_stability_leverage.R` | Stability 判定（過大レバレッジ・ゼロ・疎・正常）の自動検証テスト（全アサーション合格）。 |
| 17 | `tests/test_vcd_bayesian_config_validation.R` | 設定検証（新キー受理・旧キー非推奨警告・必須キー検証）の単体テスト。 |

---

## 4. 統合受入検証結果

タイタニック号の乗客・乗員データを用い、通常標本（$N = 2,201$）と 100 倍拡大標本（$N = 220,100$）において、Pass 1（計算）→ Pass 2（AIサマリー）→ Pass 3（ダッシュボード描画）の完全フローを実行した。

### 4.1 定量比較結果

| 評価指標 | 通常標本（$N = 2,201$） | 100倍拡大標本（$N = 220,100$） | 数理的検証評価 |
| :--- | :--- | :--- | :--- |
| **全体効果量 (Cramér's $V$)** | 0.5178［95% CI: 0.4798, 1.0000］ | 0.5208［95% CI: 0.5172, 1.0000］ | **実務的連関判定の一貫性**（$V \ge 0.5$ の大効果判定が完全一致、CI がシャープに収縮）※注1 |
| **最良モデル (明示式BIC)** | **M9（飽和モデル / 3元交互作用）** | **M9（飽和モデル / 3元交互作用）** | 完全一致（構造の同一性） |
| **安定セル率** | 16 / 16（100% REGULAR） | 16 / 16（100% REGULAR） | 数値的不安定セルなし（$O > 0, E \ge 5.0, h < 0.80$） |
| **1等女性生存 効果比 $\log(O/E)$** | **+1.8389**（期待比 $\approx 6.3$ 倍） | **+1.8389**（期待比 $\approx 6.3$ 倍） | **完全一致（スケール不変性の実証）** |
| **乗員女性死亡 効果比 $\log(O/E)$** | **-3.7529**（極度の希薄化） | **-3.7529**（極度の希薄化） | **完全一致（スケール不変性の実証）** |
| **3等男性死亡 効果比 $\log(O/E)$** | **+0.1157** | **+0.1157** | **完全一致（実測 JSON とサマリー完全整合）** |
| **1等女性生存 Leverage $h$** | 0.1278 | 0.1278 | **完全一致** |
| **3等男性死亡 Leverage $h$** | 0.6603 | 0.6603 | **完全一致** |
| **1等女性生存 Score統計量 $T$** | 719.16 | 71,915.98 | **厳密に 100 倍スケール** |
| **3等男性死亡 Score統計量 $T$** | 16.66 | 1,665.76 | **厳密に 100 倍スケール** |
| **旧エビデンススコアの出力** | **一切なし（完全排除）** | **一切なし（完全排除）** | 健全性を確認 |

※注1: `effectsize::cramers_v` の有限標本バイアス補正および度数加算・丸めにより、標本拡大に伴い $V$ は 0.5178 から 0.5208 へ約 0.003 変動する。大標本下での点推定値の微小変動は理論的限界であるが、実務的連関区分（大効果: $V \ge 0.5$）は頑健に維持され、信頼区間の幅は大幅に収縮して推論の安定性が確認された。
※注2: セル診断テーブルの `log_p` は、自由度 1 のカイ二乗分布に対する検定 P 値の **自然対数 $\ln(P)$** である（有意な乖離ほど負に大きな値をとる。例: $T=719.16$ に対し $\ln P \approx -157$）。一部で $-\log_{10}(P)$ と混同された記述は是正された。

### 4.2 数理的検証の核心（Dual-Filter の妥当性立証）
1. **Effect 軸の局所スケール不変性**:
   - 標本数が 100 倍に拡大しても、局所対数効果比 $\log(O/E)$ は全 16 セルで厳密に同一の値を維持した（3rd Male No: 0.1157, 1st Female Yes: 1.8389 等）。
   - これにより、標本サイズに影響されずに「真に実務的意味のある乖離」をスクリーニングする第1フィルタとしての機能が証明された。
2. **Evidence 軸の厳密なスケール特性**:
   - Rao のスコア統計量 $T_i^{\rm score}$ は、通常標本の値から厳密に 100 倍（1st Female Yes: 719.16 → 71,915.98、3rd Male No: 16.66 → 1,665.76）に膨張した。
   - これは大標本下で検定統計量（または P 値）単独に頼ると「些細な差でも過大視される」現象を明瞭に示しており、**Effect 軸を第一義とし、Evidence 軸を標本抽出誤差の排除（第2フィルタ）として用いる Dual-Filter 原則の不可欠性** が実証された。

---

## 5. テストスイート検証結果

新統計基盤テスト群（`tests/statistical_foundations/`）および移行後 CLI テストを実行し、合格を確認した。なお、旧仕様（ARM や旧 EBIC スキーマ等）を前提としていたレガシーテスト群は `tests/legacy_quarantine/` へ隔離した。

```
=== Section 3: 対数線形モデル適合・閉形式照合 ===
  - syn_independent: [PASS]
  - syn_ab_associated: [PASS]
  - syn_interaction_shifted: [PASS]
  - titanic_aggregated_3way: [PASS]
  -> 全 9 モデル適合、13 の入れ子比較、参照計算照合 全件合格

=== Section 4: 明示式BIC・Score統計量多軸診断 ===
  - 総度数 N 基準 BIC と stats::BIC のペナルティ乖離監査: 正常
  - 多軸診断（Effect, Evidence, Influence, Stability）算出: 正常
  -> 全件合格

=== Section 5: ベイズDirichlet事後推定・モンテカルロ校正 ===
  - 20,000 MC ドロー較正（MCSE 3-sigma、二項SE 3-sigma 範囲内）: TRUE
  - Freeman-Tukey 事後予測チェック（PPP-value = 0.544）: 正常
  - 厳密周辺尤度・ベイズ因子検証: [PASS]
  -> 全件合格

=== 新仕様 CLI、Pass 2 スタブ、および契約検証 ===
  - tests/test_vcd_bayesian_help.R: 新4軸CLIオプション [PASS]
  - tests/test_vcd_bayesian_run_id.R: 出力ディレクトリ・CLI契約 [PASS]
  - tests/test_vcd_bayesian_pass2_stub.R: 6件 [PASS]
  - tests/test_vcd_bayesian_stability_leverage.R: Stability 4状態（h>=0.80越え、ゼロ、疎、正常）[PASS]
  - tests/test_vcd_bayesian_config_validation.R: 新キー受理・旧キー非推奨警告 [PASS]
  - test_validate_config.R: 全 9 ケース [PASS]
  - test_reproducibility.R: 決定論的再現性および出力隔離性 [PASS]

=== レガシーテストの隔離 ===
  - tests/legacy_quarantine/: 旧仕様（ARM, 旧EBIC等）依存テスト 12 件を隔離
```

---

## 6. 成果物一覧

以下の成果物が生成・配置されていることを確認した。

1. **通常標本検証成果物（$N = 2,201$）**:
   - ダッシュボード HTML: `skill_out/titanic_std_v2/run_run_std_v2/dashboard.html`
   - エグゼクティブ・サマリー: `skill_out/titanic_std_v2/run_run_std_v2/executive_summary.md`
   - 計算結果 JSON: `skill_out/titanic_std_v2/run_run_std_v2/evidence_results.json`
   - 4軸セル診断テーブル HTML: `skill_out/titanic_std_v2/run_run_std_v2/dt_table.html`
   - ※ git追跡用フィクスチャ: `tests/fixtures/vcd_bayesian_dashboard/run_380de762db267d31/` 配下にも完全同値の計算結果を配置済み。
2. **100倍拡大標本検証成果物（$N = 220,100$）**:
   - ダッシュボード HTML: `skill_out/titanic_100x_v2/run_run_100x_v2/dashboard.html`
   - エグゼクティブ・サマリー: `skill_out/titanic_100x_v2/run_run_100x_v2/executive_summary.md`
   - 計算結果 JSON: `skill_out/titanic_100x_v2/run_run_100x_v2/evidence_results.json`
   - 4軸セル診断テーブル HTML: `skill_out/titanic_100x_v2/run_run_100x_v2/dt_table.html`
3. **Stability & Leverage 検証成果物**:
   - フィクスチャ CSV: `tests/fixtures/statistical_foundations/stability_leverage_fixture_3way.csv`
   - 単体検証テスト: `tests/test_vcd_bayesian_stability_leverage.R`
4. **計画・記録文書**:
   - 本格刷新計画書: [statistical_foundation_skill_migration_plan_001_0906.md](./statistical_foundation_skill_migration_plan_001_0906.md)
   - 完了報告書（本文書）: `docs/Artifacts/statistical_foundation_skill_migration_report_001_0906.md`

---

## 7. 結論

本対応により、テストベッドと本番スキルの乖離が完全に解消され、先祖返りの原因であった「旧エビデンススコア」はリポジトリ内から一掃された。
今後は、大標本リアルワールドデータ（RWD）の多次元クロス集計分析において、**標本数不変の Effect 軸（効果比・Cramér's $V$）を主軸とし、Leverage補正Score統計量 $T_i^{\rm score}$ と明示式 BIC で厳密に裏付ける、極めて堅牢で解釈性の高い分析パイプライン** として運用することが可能である。
