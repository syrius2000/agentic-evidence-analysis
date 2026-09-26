# Implementation Plan 008 — Phase 2 Section 10: IPTW Inference Engine & Governance

**作成日**: 2026-09-23 (JST)
**対象ブランチ**: `feat/comparative-evidence-reporting-v3`
**親文書**: [design.md](../../openspec/changes/comparative-evidence-reporting-v3/design.md), [spec.md](../../openspec/changes/comparative-evidence-reporting-v3/specs/comparative-design-inference/spec.md), [tasks.md](../../openspec/changes/comparative-evidence-reporting-v3/tasks.md)
**対象スコープ**: Phase 2 Section 10（IPTW 推論エンジン、反復内 PS 再推定、ATE/ATT 重み、ESS、SMD バランス、Positivity 診断）

---

## 1. 概要と背景

Owner 裁定に基づき、Section 9（1:k matched sets inference engine）は **FREEZE / ACCEPT** として確定した。
残余の schema/range hardening（enum/bounds の微細調整）は Section 9 を再 HOLD とせず、Phase 2 の共通 schema hardening タスクとして別管理する。

本計画書は、**Phase 2 Section 10: IPTW (Inverse Probability of Treatment Weighting) 推論エンジン** の設計および実装手順を定義する。

---

## 2. 数理仕様とアーキテクチャ設計

### 2.1 標的エスティマンドと重み計算式 (Tasks 10.3, 10.5)

処置変数を $A_i \in \{0, 1\}$、プロペンシティスコア（PS）を $e_i = P(A_i = 1 \mid \mathbf{X}_i)$ とする。
ロジスティック回帰モデル $\text{logit}(e_i) = \mathbf{X}_i^\top \boldsymbol{\beta}$ により推定する。

1. **ATE (Average Treatment Effect)**:
   - 非安定化: $w_i^{ATE} = \frac{A_i}{e_i} + \frac{1-A_i}{1-e_i}$
   - 安定化: $sw_i^{ATE} = A_i \frac{\bar{A}}{e_i} + (1-A_i)\frac{1-\bar{A}}{1-e_i}$ （$\bar{A} = P(A=1)$ の標本割合）
2. **ATT (Average Treatment Effect on the Treated)**:
   - 非安定化: $w_i^{ATT} = A_i + (1-A_i)\frac{e_i}{1-e_i}$
   - 安定化（Marginal Odds Scaled）: $sw_i^{ATT} = A_i + (1-A_i)\frac{e_i}{1-e_i}\frac{\bar{A}}{1-\bar{A}}$

### 2.2 重み刈り込み (Truncation) (Task 10.4)

極端な重みによる分散爆発を抑制するため、処置群別（$A=1$ と $A=0$ 別）に指定パーセンタイル（既定値: 下限 1%, 上限 99% 等、または指定なし）でトリミング/トランケーションを実施する。

### 2.3 有効標本サイズ (Effective Sample Size: ESS) (Task 10.7)

Kish の近似式に基づき、群別有効標本サイズを算出：
\[
ESS_g = \frac{\left(\sum_{i \in g} w_i\right)^2}{\sum_{i \in g} w_i^2}, \quad g \in \{T, R\}
\]

### 2.4 重み付け周辺リスクと点推定量 (Task 10.5, 10.6)

観測標本上の加重平均リスク：
\[
\hat{p}_T = \frac{\sum_{i: A_i=1} w_i Y_i}{\sum_{i: A_i=1} w_i}, \quad \hat{p}_R = \frac{\sum_{i: A_i=0} w_i Y_i}{\sum_{i: A_i=0} w_i}
\]

- $\hat{RD} = \hat{p}_T - \hat{p}_R$
- $\hat{RR} = \hat{p}_T / \hat{p}_R$ （$\hat{p}_R > 0$ の場合）
- 点推定値の出典: `estimate.source = "observed_sample_estimate"`
- セマンティクス: `inferential_semantics = "bootstrap"`

### 2.5 反復内モデル再推定ブートストラップ (In-Replicate Refitting) (Tasks 10.1, 10.2, 10.11)

- 標本抽出不確実性と PS 推定の不確実性を統合するため、患者レベルで非復元ではなく **有復元抽出（Patient-level Bootstrap）** を $B$ 回実行。
- 各ブートストラップ標本において、**PS モデルのロジスティック回帰を再推定（`iptw_mode = "refit_ps"`）** し、重みを再計算、刈り込みを再適用して $\hat{p}_T^{*(b)}, \hat{p}_R^{*(b)}$ を導出。
- 収束モニタリング: 完全分離や数値的不安定性により `glm` が非収束となった反復をカウント。失敗率が許容閾値（例: 5%）を超えた場合は governed error（`[IPTW_CONVERGENCE_FAILURE]`）で fail-fast。

### 2.6 重み付け前後共変量バランス (SMD) & Positivity 診断 (Tasks 10.8, 10.9, 10.10)

- **SMD (Before & After)**:
  各共変量 $X$ について、重み付け前（unweighted）および重み付け後（weighted）の加重平均と加重分散を求め、スケール不変な式で SMD を計算。
- **Positivity / Overlap 診断**:
  処置群・対照群における推定 PS の分布要約（min, 1st qu, median, mean, 3rd qu, max）および重なり共通サポート区間 $[\max(\min e_T, \min e_R), \min(\max e_T, \max e_R)]$ を記録。

---

## 3. 実装対象ファイルと責務

| 区分 | ファイルパス | 変更種別 | 責務 |
|---|---|---|---|
| **コア計算** | `.agents/shared/iptw_inference.R` | **[NEW]** | IPTW 推論エンジン（PSモデル推定、重み計算、刈り込み、反復内 refit ブートストラップ、ESS、SMD、診断） |
| **スキーマ** | `schemas/comparative-evidence-v1.json` | **[MODIFY]** | `iptw` プロパティの追加（ESS, 重み要約, バランス, Positivity） |
| **スキーマ** | `schemas/comparative-draws-v1.json` | **[MODIFY]** | `iptw_metadata` プロパティの追加 |
| **スキル** | `.agents/skills/comparative-design-analysis/SKILL.md` | **[MODIFY]** | IPTW 解析のガイドライン・制約・実行例を追加 |
| **テスト** | `tests/test_iptw_inference.R` | **[NEW]** | 単体・数理検証テスト（重み公式、ESS、SMD、refit PS、非整数擬似度数拒絶、再現性） |
| **テスト** | `tests/test_comparative_schemas.R` | **[MODIFY]** | IPTW 出力のスキーマ妥当性検証を追加 |
| **スイート** | `tests/run_regression_suite.R` | **[MODIFY]** | `test_iptw_inference.R` を全回帰スイートに登録 |
| **仕様・タスク** | `openspec/.../tasks.md` | **[MODIFY]** | Section 10 タスク（10.1〜10.13）の進捗管理 |

---

## 4. 検証手順

1. **数理・単体検証**:
   - `Rscript tests/test_iptw_inference.R` (100% PASS)
   - ATE / ATT 重み計算が数式と完全一致することの検証
   - 反復内 refit により PS 不確実性が反映されることの検証
   - 独立 Beta-Binomial が非整数重み付き擬似度数を拒絶することの検証 (Task 10.12)
2. **スキーマ検証**:
   - `Rscript tests/test_comparative_schemas.R` (100% PASS)
3. **全正規回帰テスト**:
   - `Rscript tests/run_regression_suite.R` (41本すべて PASS)
4. **OpenSpec 厳格検証**:
   - `openspec validate comparative-evidence-reporting-v3 --strict --json` (0 errors)
5. **Git クリーンネス**:
   - `git diff --check`
