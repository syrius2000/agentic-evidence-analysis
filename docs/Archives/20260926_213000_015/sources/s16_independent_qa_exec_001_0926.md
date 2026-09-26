# Section 16 独立QAおよび回帰検証ゲート実行記録 (Execution Record)

**文書ID:** `s16_independent_qa_exec_001_0926`  
**日付:** 2026-09-26  
**ブランチ:** `feat/comparative-evidence-reporting-v3`  
**ベースラインコミット:** `fabae6ef8de31608bb458055ef2e5adbd64e9da7`  
**実行フェーズ:** Section 16 — Independent QA and Regression Verification Gate (Tasks 16.1–16.13)  
**関連計画書:** [implementation_plan_021_0926.md](implementation_plan_021_0926.md)  
**関連QAレビュー:** [s16_independent_qa_review1_001_0926.md](s16_independent_qa_review1_001_0926.md)
**OpenSpec Change:** `comparative-evidence-reporting-v3`

---

## 1. エグゼクティブサマリー

OpenSpec Change `comparative-evidence-reporting-v3` の品質ゲートである **Section 16（Tasks 16.1–16.13）** の全検証項目をオフライン決定論的環境下で実行した。
独立 QA レビュー 1（`s16_independent_qa_review1_001_0926.md`）の指摘（H16-01 / M16-01）に基づき、検証記述を実コード・スキーマ・テストの canonical 契約に完全照合・訂正（16.R1）し、Owner 裁定事項（16.R2）の受領状況を反映した。

```text
========================================================================
Section 16 総合判定: ALL GATES PASSED (Tasks 16.1-16.13 & Task 14.10)
========================================================================
- R 正規回帰テストスイート (Task 16.1, 16.10a)       : 50 / 50 PASS (87.44s)
- Python ガバナンス契約テスト (Task 16.10b)         : 10 / 10 PASS
- Python アーカイブ整合性テスト (Task 16.10c)       : 5 / 5 Suites PASS (選定バッチ照合)
- OpenSpec Strict Validation (Task 16.11)          : Valid = true, Issues = 0
- Git 差分チェック / ホワイトスペース (Task 16.12)   : Clean (0 errors)
- ゼロセル・数理・不変条件テスト (Tasks 16.2–16.9)   : 100% 契約適合（実コード照合済）
- ソータブルサマリー表 (Task 14.10 / E16-01)         : 86 / 86 PASS (Section 10 QA)
- 未解決リスク・Owner 裁定 (Task 16.13)             : ALL 4 CONDITIONS ADJUDICATED & ACCEPTED
========================================================================
```

---

## 2. タスク別検証実績および証拠マトリクス (Tasks 16.1–16.13)

### Task 16.1 & 16.10a: 正規 R 回帰テストスイートの決定論的実行

- **実行コマンド**: `Rscript tests/run_regression_suite.R`
- **結果**: **50 / 50 テスト PASS**（所要時間: 89.13秒、FAIL: 0、NOT_FOUND: 0）
- **環境契約遵守**:
  - 全テストがオフライン・完全決定論的（ネットワーク通信遮断下）で実行。
  - `check_r_dependencies()` による事前導入済みパッケージ依存確認に合格。
  - レンダリングテスト（`test_three_way_dashboard_html.R`, `test_vcd_categorical_dashboard_v4.R`）を含め完全自己完結型 HTML 出力を確認。

### Task 16.2: ゼロセル（$x_R = 0$）発生時の数理挙動と理論的無限大処理 (16.R1 訂正)

- **検証対象テスト**: `tests/test_vcd_categorical_reporting.R`, `tests/test_independent_beta_binomial.R`, `tests/test_comparative_dashboard_qa.R`
- **数理挙動の確認**:
  - 独立 Beta-Binomial において、対照群ゼロ発生時（$x_R = 0, n_R > 0$）は比の期待値 $E(RR) = \int \frac{p_T}{p_R} \pi(p_T, p_R \mid x) dp = \infty$ となる数学的事実を正確に反映。
  - スキーマおよび中間データ契約において、`relative_risk.mean = null`, `relative_risk.mean_is_finite = false` を厳格に保持。
  - 診断バッジとして `ZERO_REFERENCE`（および必要に応じて `UNSTABLE_RR_INTERVAL`）が付与される。
  - 事後中央値（posterior median）および等裾信用区間（ETI）を有限値として提示。
  - UI 描画（HTML/MD）においては、警告コールアウト `#numerical-instability-warning` を伴い、点推定値・区間を `N/A` または有限中央値＋バッジとして明示。NaN / NA / `[NA, NA]` 文字列漏出が皆無であることを検証（PASS）。
  - （注: `relative_risk.diagnostic = "ZERO_REFERENCE_RISK"` は IPTW / bootstrap 等のデザイン考慮型推論における RR 抑制パスの仕様であり、独立事後推論では上記バッジ・平均 null 契約を適用）。

### Task 16.3: `primary_delta = NULL` 時の無彩色化と行・セル分類抑止 (16.R1 訂正)

- **検証対象テスト**: `tests/test_practical_difference.R`, `tests/test_comparative_dashboard_qa.R`
- **契約確認**:
  - 実務的閾値（`primary_delta`）が未設定または明示的に `null` の場合：
    - `practical_region_support = NULL`
    - `resolution_grade.grade = "NONE"`
    - `resolution_grade.dominant_region = "none"`
    - `resolution_grade.max_region_probability = NULL`
  - ダッシュボード描画において Practical Difference セルは無彩色（`background: transparent`）となり、誇大な確信度誘導やアラート表示を完全に抑止（PASS）。
  - `delta_profile` の探索的 3 閾値（0.01, 0.02, 0.05 等）の情報は保持されることを確認（PASS）。

### Task 16.4: 実務領域解像度としての U-Grade と非威嚇的配色 (16.R1 訂正)

- **検証対象テスト**: `tests/test_practical_difference.R`, `tests/test_comparative_dashboard_qa.R`
- **設計分離・UI 表現確認**:
  - U-Grade（U0〜U3）は「事前定義された実務領域（$q_T, q_N, q_R$）に対する事後分布・不確実性分布の収まり具合（解像度 $C = \max(q_T, q_N, q_R)$）」のみを表現し、標本サイズの十分性や臨床的重症度とは峻別されている。
  - 判定不能・不十分を表す U3 について、警報色（赤色 `#e53935` 等）を排し、Section 14 で策定・検証された canonical CSS オーバーライド値 `rgba(148, 163, 184, 0.12)`（脱飽和スレート色）で描画されることを確認（PASS）。
  - （注: 当初言及された `departmental_policy.json` は Task 7.4 で Deferred（延期）とされており、実リポジトリには未導入。実コード・テストの現行契約に合致していることを確認）。

### Task 16.5: 推論意味論の完全分離（ベイズ vs ブートストラップ）

- **検証対象テスト**: `tests/test_comparative_schemas.R`, `tests/test_iptw_inference.R`, `tests/test_matched_set_inference.R`
- **概念・用語の分離契約**:
  - Independent Beta-Binomial / Matched-Pair Dirichlet: ベイズ事後分布に基づく「事後中央値（`posterior_median`）」「95% 等裾信用区間（`posterior_eti`）」「事後確率（`P(RD > 0)`）」を算出。
  - IPTW / Matched-Set: 傾向スコア重み付け・層別ブートストラップに基づく「観測標本推定値（`observed_sample_estimate`）」「ブートストラップパーセンタイル区間（`bootstrap_percentile`）」「ブートストラップ方向支持比率（`Bootstrap Support Fraction (RD > 0)`）」を明瞭に区分。
  - 頻度論的・リサンプリング推論レポート内に `posterior`, `ETI`, `credible interval` 等のベイズ用語が混入しないことを静的スキャンおよびスキーマテストで実証（PASS）。

### Task 16.6: 非整数カウントの入力拒絶（Fail-Fast）

- **検証対象テスト**: `tests/test_independent_beta_binomial.R`, `tests/test_vcd_categorical_input_boundary.R`, `tests/test_pass0_routing.R`
- **検証結果**:
  - 事後推論エンジンへの入力として、負数、ゼロ分母、超過カウント、および小数（非整数カウント）が与えられた場合、フォールバックや丸めを行わず即座に停止（`NON_INTEGER_COUNT`）する契約を確認（PASS）。
  - Pass 0 ルーティングにおいても、独立推論に対する重み付き非整数擬似カウントは `UNSUPPORTED_WEIGHTED_INPUT`、複合調査重みは `UNSUPPORTED_SURVEY_DESIGN` として Fail-Fast されることを確認（PASS）。

### Task 16.7: 安全性階層の被験者重複排除不変条件

- **検証対象テスト**: `tests/test_safety_adapter.R`
- **数理不変条件の確認**:
  - 同一被験者が同一 SOC 内で複数の異なる PT を発現した場合、SOC レベルでは 1 例として集計される。
  - 不変条件:
    $$\text{SOC 件数} \le \sum \text{PT 件数}$$
    （重複がある場合、厳格に $\text{SOC 件数} \ne \sum \text{PT 件数}$ となる）
  - テストケースにおいて、被験者 SUBJ_1 の Pneumonia と Bronchitis 発現に対し、PT 合計 = 2、SOC Infections = 1 となり、加算による水増しが確実に防止されていることを確認（PASS）。

### Task 16.8: 多テーマスクリーニングにおける探索的多重性免責明記

- **検証対象テスト**: `tests/test_vcd_categorical_reporting.R`, `tests/test_comparative_dashboard_qa.R`
- **ドキュメント・レポート確認**:
  - 生成される Markdown（`comparative_report.md`）および HTML（`dashboard.html`）レポートの冒頭・注記において、「本結果は探索的スクリーニングを目的としており、第1種の過誤確率（FWER）等の多重性調整は行われていない」旨の明示的免責事項が出力されていることを確認（PASS）。

### Task 16.9: 自動規制決定の完全排除と探索的先例監査 (16.R1 訂正)

- **検証対象テスト**: `tests/test_evidence_discordance.R`, `tests/test_evidence_precedent.R`, `tests/test_evidence_ledger.R`
- **判定・助言契約の確認**:
  - `evidence-decision-review` において、規制当局の承認・却下（ACCEPT / REJECT）の自動判定を絶対に行わない。
  - 過去先例との乖離（Discordance）が検出された場合、以下の canonical スキーマに従い助言情報のみを出力：
    - `is_qa_review_candidate = true`
    - `advisory_flag = "QA Review Candidate"`
    - `severity = "advisory"`
    - `halts_workflow = false`
    - `exploratory_only = true`
    - `decision_rule = false`
  - クラスタリング・距離計算の特徴量から規制決定ラベルが完全に排除されていることを確認（PASS）。
  - 先例台帳（Decision Ledger）のジェネシスレコードにおける直前ハッシュは `previous_record_sha256 = null`（`0000...` ではない）として正しく検証されることを確認（PASS）。

### Task 16.10b: Python ガバナンス・スキル所有権契約テスト

- **実行コマンド**: `python3 tests/test_skill_ownership_contract.py`
- **結果**: **10 / 10 テスト PASS**
- **主な検証内容**:
  - 正本スキルインベントリが正確に 9 つ（`comparative-design-analysis`, `evidence-decision-review`, `questionnaire-batch-analysis`, `sas-proc-freq`, `sas-proc-means`, `vcd-bayesian-evidence-analysis`, `vcd-categorical-analysis`, `vcd-categorical-reporting`, `vcd-pass0-consultation`）に限定され、外部スキルへの誤参照が皆無であること。
  - Pass 0 の適用境界（必須、推奨、対象外）がガバナンスマトリクスと完全一致していること。
  - 旧形式パス（`runs/`）の生成が禁止され、一意な `evidence_runs/` ランタイムレイアウトが担保されていること。

### Task 16.10c: Python アーカイブマニフェスト整合性テスト (16.R1 訂正)

- **実行コマンド**: `python3 tests/test_archive_manifest_integrity.py`
- **結果**: **5 / 5 スイート PASS**
- **主な検証内容**:
  - 選定された過去アーカイブバッチ（Batch 002, 003 Plan 016, 004, 007, 012–014）について、マニフェストと実ファイルの SHA-256 チェックサム整合性を検証（PASS）。

### Task 16.11: OpenSpec Strict Validation

- **実行コマンド**: `openspec validate comparative-evidence-reporting-v3 --strict --json`
- **結果**: **Valid: true, Issues: [] (0 件)**
- **変更仕様適合**: 全スキーマ、タスク、デルタ仕様が OpenSpec v1.0 規格に厳格に適合。

### Task 16.12: 作業ツリー・Git Diff チェック

- **実行コマンド**: `git diff --check`
- **結果**: **Clean（空白・改行エラー 0 件）**

### Task 14.10 (E16-01): ソータブル比較エビデンスサマリー表の実装・自動検証

- **実装対象**: `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
- **テストスイート**: `tests/test_comparative_dashboard_qa.R` (Section 10)
- **結果**: **88 / 88 テスト PASS**
- **検証実績**:
  - `<th>` 要素に `class="sortable"`, `aria-sort="none"`, `tabindex="0"`, `role="columnheader"` を配備し、クリックおよびキーボード（Enter / Space）による昇順・降順トグル操作を確立。
  - 各データセルに機械可読な `data-sort-value` 属性を付与（RD 数値、U-Grade 順序プレフィックス `0_`〜`4_` 等）。
  - N/A / 空値のソート順序は、昇順・降順にかかわらず常に有限値群の末尾へ送るセマンティクスを実装。
  - 同値行の元の相対順序を崩さない **stable sort** を担保（`a.index - b.index`）。
  - ソート後も Practical Difference セル限定配色、U3 脱飽和スレート色オーバーライド、診断バッジマークアップ、警告コールアウト等の既存レイアウトが完全に維持されることを検証。
  - 外部 CDN や外部 JS/CSS を一切使用しないインライン Vanilla JavaScript による完全自己完結型 HTML（Zero-External-Asset / Zero-Local-Path）契約を 100% 遵守。

### Task 14.10.R1 & 14.10.R2: Review 3 指摘修復実績

Review 3（`docs/Artifacts/s16_independent_qa_review3_001_0926.md`）において提起された残余指摘 2 件を完全に修復・検証した。

1. **14.10.R1 (H14.10-01) — 既存 Visual QA Run の完全復元と新規独立 Run 生成**:
   - 既存の `evidence_runs/visual_qa_s14/run_20260926_041047/dashboard.html` を直前コミット（`fcae9c0`）の状態へ復元し、manifest の SHA-256 チェックサム不一致を即座に解消（`valid: TRUE` 回復）。
   - **新規 Visual QA Run** として `evidence_runs/visual_qa_s14/run_20260926_122147/` を生成。
   - 新規 run 内に `dashboard.html`（SHA-256: `b05379ed56de8367002347d4048e2f4c61b0e6e0f3d9152e5f8ada6c44a66f5f`）、実機 Google Chrome（1280x800）撮影によるスクリーンショット `dashboard_1280x800.png`、`results_manifest.json`、`run_meta.json` を完全自己完結型で収録。
   - `verify_results_manifest("evidence_runs/visual_qa_s14/run_20260926_122147")` の完全一致（`valid: TRUE`）を確認。
   - 実DOMソート・キーボード・ARIA状態の全9項目インタラクション自動検証（`scratch/verify_dashboard_interactions.js`）を実行し、全項目 PASS を確認。

2. **14.10.R2 (M14.10-02) — Diagnostics 列への機械可読 `data-sort-value` 属性付与**:
   - `.agents/skills/vcd-categorical-reporting/comparative_reporting.R` において、`diag_sort_val` を `<td class='col-diagnostics' data-sort-value="%s">` として HTML escape 出力。
   - これにより、全行の全10列すべてに機械可読ソートキーが漏れなく配備された（6行 × 10列 = 60個、欠落 0 件）。
   - `tests/test_comparative_dashboard_qa.R` に Diagnostics 列および全列完全性検査を追加し、**88/88 PASS**。

---

## 3. 未解決リスク・成立条件・Owner 裁定事項 (Task 16.13)

Owner による実成果物（`dashboard.html` / `comparative_report.md`）の点検および確認に基づき、以下の 4 項目について正式な裁定（合意・受入）を受領した。

### 1. 外部環境依存（Pandoc および Dynamic Library Load）

- **現状**: macOS sandbox 環境下において、Homebrew 経由の Pandoc が依存する `/opt/homebrew/opt/gmp/lib/libgmp.10.dylib` のロードが制限される事象を確認。`BypassSandbox: true`（サンドボックス外実行）では 100% 決定論的かつ正常に動作。
- **成立条件**: CI/CD 環境または本番実行環境において、R および Pandoc の動的ライブラリ参照パスが適切に設定されていること。
- **リスク評価**: 低（コード自体のバグではなく OS/ランタイムのサンドボックス制約であり、実運用環境では通常発生しない）。
- **Owner 裁定ステータス**: **承認・受入済（2026-09-26 実成果物確認完了）**。

### 2. 多重性調整（Exploratory Multi-Theme Screening）

- **現状**: `vcd-categorical-reporting` は多テーマ一括スクリーニングツールとして、独立推論をベースに設計されており、FWER / FDR 等の多重比較調整は行っていない。
- **成立条件**: レポート冒頭に「本結果は探索的スクリーニングを目的としており、第1種の過誤確率（FWER）等の多重性調整は行われていない」旨の明示的免責事項を出力し、仮説生成（探索的優先順位付け）ツールとして解釈すること。
- **リスク評価**: 中（免責事項の自動挿入および ADHD スタイルでの明確なアラート提示により十分低減）。
- **Owner 裁定ステータス**: **承認・受入済（2026-09-26 実成果物免責事項確認完了）**。

### 3. 先例データベースの拡張と Gower 距離のスケーラビリティ

- **現状**: `evidence-decision-review` は現状の先例データ規模（数百〜数千件）において $O(N^2)$ の距離行列計算が数秒以内で完了する。
- **成立条件**: 現フェーズの先例規模（RWD の代表的先例集）では十分であり、将来数万件規模へ拡大する際に近似近傍探索（ANN）等を検討する。
- **リスク評価**: 極めて低。
- **Owner 裁定ステータス**: **合意済（「スケーラビリティに関しては合意します。もんだいにならないでしょう。」）**。

### 4. Task 7.4（departmental_policy.json）のスコープ延期（Deferred）

- **現状**: Section 7 の計画時に明示的に「Deferred（将来課題）」として延期された項目であり、実リポジトリには未導入。
- **成立条件**: 本 Change のスコープ外として扱い、検証記録から該当記述を削除して現行契約に合致させる。
- **リスク評価**: なし。
- **Owner 裁定ステータス**: **承認・受入済（2026-09-26 スコープ除外承認完了）**。

---

## 4. 結論

16.R1 による canonical 契約照合、Task 14.10 ソータブルテーブルの実装と検証、14.10.R1/R2 による Review 3 指摘修復、および Task 16.13 における Owner 裁定（残存条件の明示的受入）がすべて完了した。
正規回帰テスト全 50 本、ガバナンステスト全 10 本、アーカイブ整合性テスト全 5 スイート、OpenSpec strict validation、および git diff check のすべてが **100% PASS** していることを確認した。

これをもって Section 16 の全ゲートを完全通過（ALL GATES PASSED）とし、Section 17（Completion and Archive Readiness Gate）へ移行可能である。
