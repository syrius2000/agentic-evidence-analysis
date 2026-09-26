# Implementation Plan 007 — Phase 2 Section 9 Repair #2: Matched Sets Contract Hardening

**作成日**: 2026-09-23 (JST)
**対象ブランチ**: `feat/comparative-evidence-reporting-v3`
**親文書 / 根拠**: [Phase2_Section9_repair_plan_review_2_20260923.md](Phase2_Section9_repair_plan_review_2_20260923.md)
**対象スコープ**: Phase 2 Section 9 (1:k Matched Sets Inference Engine) の Review 2 指摘事項（B-01, H-01, H-02, H-03, M-01, M-02）の完全修復

---

## 1. 概要と背景

`Phase2_Section9_repair_plan_review_2_20260923.md` による独立レビュー（Review 2）において、ATT 点推定量、atomic set bootstrap、ATT 重み付き SMD、raw counts 分離、被験者 ID 一意性等の基本構造は PASS と評価されたものの、以下の 1 件の Blocker、3 件の High、2 件の Medium 指摘により判定が **HOLD** となった。

1. **B-01 (BLOCKER)**: RR suppression 後も共通 contrast engine 内の `1e-15` floor に起因する `precision_metrics$log_rr_interval_width` 等が残存し、意味論的矛盾が生じる。
2. **H-01 (HIGH)**: `num_draws` の最小値契約が runtime (>=1), shared engine (>=10), schema (>=1) で不整合。また数値引数の `is.finite()` 検証が不足。
3. **H-02 (HIGH)**: SMD zero-variance 判定の絶対閾値 `1e-12` がスケール不変性（単位変換不変性）を破壊している。
4. **H-03 (HIGH)**: JSON Schema において `raw_target_counts`, `raw_reference_counts`, `matched_set_metadata` の主要メタデータが required 化されておらず、enum 制約も不足。
5. **M-01 (MEDIUM)**: 前回コミット時に Baseline の seed reproducibility test が脱落。
6. **M-02 (MEDIUM)**: Abadie & Imbens (2008) の引用表現が fixed-set bootstrap を正当化しているように読める。

本計画書は、上記 6 点を過不足なく確実に解決するための設計と実装手順を定義する。

---

## 2. 変更対象コンポーネントと詳細設計

### 2.1 [BLOCKER B-01] RR Suppression 時の Precision Metrics 整合化

- **対象ファイル**: `.agents/shared/matched_set_inference.R`
- **設計内容**:
  - `att$p_reference <= 0` または `boot$rr_diagnostics$undefined_replicates > 0L` の場合、RR 区間・平均の suppression に連動して、RR 由来の精度指標も atomic に suppress（`NULL` 化）する：

    ```r
    evidence$precision_metrics["log_rr_interval_width"] <- list(NULL)
    evidence$precision_metrics["rr_interval_fold_range"] <- list(NULL)
    ```

  - 未使用の `clean_rr_draws`, `effective_rr_draws` を整理（dead code 排除）。
  - テスト `tests/test_matched_set_inference.R` に T10 を追加し、`p_R = 0` の場合に `log_rr_interval_width` が `NULL` であることを assert。

### 2.2 [HIGH H-01] `num_draws` 最小値契約統一と有限値 (`is.finite`) 検証

- **対象ファイル**:
  - `.agents/shared/matched_set_inference.R`
  - `schemas/comparative-draws-v1.json`
- **設計内容**:
  - `num_draws` の契約を最小値 10L に統一し、有限整数を厳格に検証：

    ```r
    if (!is.numeric(num_draws) || length(num_draws) != 1L || !is.finite(num_draws) || num_draws < 10L || num_draws != floor(num_draws)) {
      stop("[INVALID_ARGUMENT] num_draws は 10 以上の有限な単一整数である必要があります")
    }
    ```

  - その他数値引数（`caliper`, `discarded_target`, `discarded_reference`, `seed`, `level`）にも `!is.finite(...)` 検証を追加し、`Inf`, `-Inf`, `NaN` を governed error で reject。
  - スキーマ `schemas/comparative-draws-v1.json` の `num_draws` の `minimum` を 10 に更新。
  - テストに `num_draws = 9`, `num_draws = Inf`, `seed = Inf`, `caliper = Inf` 等の fail-fast テストケースを追加。

### 2.3 [HIGH H-02] スケール不変な SMD Zero-Variance 判定

- **対象ファイル**: `.agents/shared/matched_set_inference.R`
- **設計内容**:
  - 絶対閾値 `1e-12` を廃止し、exact zero または有限数値保証下でのスケール不変判定に刷新：

    ```r
    if (s_pooled == 0) {
      if (mean_diff == 0) {
        smd_matched <- 0.0
        status <- "ZERO_VARIANCE_ZERO_DIFFERENCE"
      } else {
        smd_matched <- NULL
        status <- "ZERO_VARIANCE_NONZERO_DIFFERENCE"
      }
    } else {
      smd_matched <- mean_diff / s_pooled
      status <- "OK"
    }
    ```

  - テストに $c = 10^{-13}, 1, 10^{13}$ 等のスケール変換で SMD が不変（`smd(cX) == smd(X)`）であることを検証するテストを追加。

### 2.4 [HIGH H-03] Schema Enforcement 強化と Negative Tests

- **対象ファイル**:
  - `schemas/comparative-evidence-v1.json`
  - `schemas/comparative-draws-v1.json`
  - `tests/test_comparative_schemas.R`
- **設計内容**:
  - `schemas/comparative-evidence-v1.json`:
    - `matched_set.required` に `raw_target_counts`, `raw_reference_counts` を追加。
  - `schemas/comparative-draws-v1.json`:
    - `matched_set_metadata` の `required` に `set_count`, `matching_ratio_type`, `estimand`, `bootstrap_scope`, `rr_bootstrap_diagnostics` を指定。
    - `bootstrap_scope.properties.type` に `enum: ["conditional_on_fixed_matched_sets"]` を設定。
    - `rr_bootstrap_diagnostics` の定義（minimum, maximum）を evidence 側と完全同期。
  - `tests/test_comparative_schemas.R`:
    - negative tests（必須項目欠落、不正な bootstrap scope type、num_draws < 10 等）を追加。

### 2.5 [MEDIUM M-01] Seed 再現性回帰テストの復活

- **対象ファイル**: `tests/test_matched_set_inference.R`
- **設計内容**:
  - 同一 seed で実行した際に `draws$target_draws`, `draws$reference_draws`, `evidence$risk_difference$interval` が完全一致（`identical`）することを検証するテストを復元・強化。

### 2.6 [MEDIUM M-02] 文献引用・理論説明の修正

- **対象ファイル**:
  - `openspec/changes/comparative-evidence-reporting-v3/design.md`
  - `openspec/changes/comparative-evidence-reporting-v3/specs/comparative-design-inference/spec.md`
  - `.agents/skills/comparative-design-analysis/SKILL.md`
- **設計内容**:
  - Abadie & Imbens (2008) について、「本手法は観測された matched sets を固定した条件付き resampling であり、matching estimator 自体を bootstrap するものではない。Abadie & Imbens (2008) は nearest-neighbor matching estimator に対して通常の bootstrap の妥当性を一般に仮定できないことを示している」旨の正確な理論的位置づけへ改訂。

### 2.7 OpenSpec タスク追跡の更新

- **対象ファイル**: `openspec/changes/comparative-evidence-reporting-v3/tasks.md`
- **設計内容**:
  - Section 9 に修復タスク（Tasks 9.13〜9.20）を追加し、実装進捗を追跡。

---

## 3. ファイル変更一覧

| 変更種別 | ファイルパス | 変更内容 |
|---|---|---|
| **[MODIFY]** | `.agents/shared/matched_set_inference.R` | B-01 (precision metrics suppression), H-01 (num_draws >= 10 & finite validation), H-02 (scale-invariant SMD) |
| **[MODIFY]** | `schemas/comparative-evidence-v1.json` | H-03 (raw_counts required 化) |
| **[MODIFY]** | `schemas/comparative-draws-v1.json` | H-01 (num_draws minimum: 10), H-03 (metadata required & enum 化) |
| **[MODIFY]** | `tests/test_matched_set_inference.R` | B-01, H-01, H-02, M-01 のテスト追加（zero-ref precision, finite arg, scale inv, seed identical） |
| **[MODIFY]** | `tests/test_comparative_schemas.R` | H-03 の negative schema validation tests 追加 |
| **[MODIFY]** | `openspec/changes/comparative-evidence-reporting-v3/design.md` | H-02 (SMD 式), M-02 (Abadie & Imbens 引用表現) の修正 |
| **[MODIFY]** | `openspec/changes/comparative-evidence-reporting-v3/specs/comparative-design-inference/spec.md` | H-01, H-02, M-02 仕様の反映 |
| **[MODIFY]** | `.agents/skills/comparative-design-analysis/SKILL.md` | M-02 説明の整合化 |
| **[MODIFY]** | `openspec/changes/comparative-evidence-reporting-v3/tasks.md` | Tasks 9.13〜9.20 の追加と完了チェック |

---

## 4. 検証計画

1. **単体・回帰テスト**:
   - `Rscript tests/test_matched_set_inference.R` (100% PASS)
   - `Rscript tests/test_comparative_schemas.R` (100% PASS)
   - `Rscript tests/run_regression_suite.R` (全スイート PASS)
2. **OpenSpec 厳格検証**:
   - `openspec validate comparative-evidence-reporting-v3 --strict --json` (0 errors)
3. **差分・構文確認**:
   - `git diff --check`
