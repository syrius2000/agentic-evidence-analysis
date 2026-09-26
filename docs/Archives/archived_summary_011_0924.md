# アーカイブ済みArtifactの要約 (Batch 011)

- **created**: 2026-09-24 01:18 (JST)
- **author**: Antigravity
- **対象期間**: 2026-09-23 00:00 (JST) 〜 2026-09-23 23:59 (JST)
- **archive_batch_id**: 20260924_011800_011
- **source_count**: 21

---

## 1. 対象と結論

本ドキュメントは、`docs/Artifacts/` に配備されていた `comparative-evidence-reporting-v3` 関連の完了済み文書21件（OpenSpec仕様策定レビュー4件、Phase 1実装計画・レビュー完了記録10件、Phase 2 Section 7〜9実装計画・修復レビュー記録7件）を精査・完了確認し、原本を [20260924_011800_011/sources/](20260924_011800_011/sources/) へ退避・集約したアーカイブです。

### アーカイブ対象文書一覧

1. `OpenSpec_review1_comparative_evidence_reporting_v3_20260923.md` 〜 `OpenSpec_review4_comparative_evidence_reporting_v3_20260923.md` (4件)
2. `Phase1_implementation_review1_20260923.md` 〜 `Phase1_implementation_review5_20260923.md` (5件)
3. `implementation_plan.md`
4. `implementation_plan_001_0923.md` 〜 `implementation_plan_004_0923.md` (4件)
5. `implementation_plan_005_0923.md` 〜 `implementation_plan_008_0923.md` (4件)
6. `Phase2_Section9_matched_sets_review_1_20260923.md`
7. `Phase2_Section9_repair_plan_review_1_20260923.md`
8. `Phase2_Section9_repair_plan_review_2_20260923.md`

### 結論

本期間において、本リポジトリは `comparative-evidence-reporting-v3` の仕様策定（OpenSpec Reviews 1〜4）、Phase 1（独立群 Jeffreys Beta-Binomial、1:1 マッチドペア等）の実装・レビューサイクル（Reviews 1〜5）、および Phase 2 Section 7〜9（マッチドペア推論、1:k マッチドセットのATT set-weighted推定量および原子単位セット・クラスターブートストラップ推論）の実装と QA 指摘修復を完全に完了・合意し、凍結（freeze）しました。現行作業は Section 10（IPTW）へ移行したため、これらの過去フェーズ文書は安全にアーカイブされます。

---

## 2. 確定した決定と理由

| 元文書 | 確定した決定事項 | 理由・背景 | 集約先の節 |
| :--- | :--- | :--- | :--- |
| `OpenSpec_review1..4_...md` | 比較エビデンス解析（二群比較）の数理モデル・契約を `agentic-evidence-analysis` の OpenSpec Change として一元管理。 | ドメイン（安全域・RWD等）とデザイン（独立群・マッチング・IPTW・人年）と推論（ベイズ・ブートストラップ）を明確分離するため。 | §3.1 |
| `Phase1_review1..5_...md`<br>`plan_001..004_...md` | 独立二群において Jeffreys 事後分布 $\text{Beta}(x+0.5, n-x+0.5)$ を主事前とし、Laplace 事前を感度分析として分離出力。RD, RR, OR のモンテカルロ事後標本を同時生成。 | ゼロセル発生時の一致性と正値性を担保し、不連続な連続性補正に依存しない統一事後分布を提供するため。 | §3.1 |
| `plan_005..006_...md` | 1:1 マッチドペア（Section 7-8）において、ペア間相関（intra-pair association OR）と条件付き治療効果（conditional treatment effect OR）の用語・セマンティクスを明確に分離。 | マッチングデザインにおける疫学的効果量と相関指標の混同を防止するため。 | §3.2 |
| `Phase2_Section9_...md`<br>`plan_007..008_...md` | 1:k マッチドセット（Section 9）において、原子単位セットブートストラップ（Atomic Set Bootstrap）を実装し、不均衡セット構造を崩さずにリサンプリング。 | 個体レベル抽出によるマッチング構造崩壊を防止し、クラスタリング相関を正しく保持するため。 | §3.3 |
| 同上 | 1:k マッチドセットにおいて、各セットの被験者 ID 一意性検証および重複排除ガードレールを導入。 | データ重複による過剰適合や非現実的な擬似反復を Fail-Fast で検知するため。 | §3.3 |
| 同上 | 1:k マッチドセットの推論・レポートをすべて PASS 判定とし、Section 9 を freeze（凍結）。 | 独立レビュアーによる第2回修復レビューで全指摘事項の解消が確認されたため。 | §3.3 |

---

## 3. 主要成果と検証の限界

### 3.1 仕様・実装成果

1. **OpenSpec Change 策定**: `openspec/changes/comparative-evidence-reporting-v3/` の仕様・タスク・設計を確立。
2. **Phase 1 エンジン完備**: `.agents/shared/independent_beta_binomial.R`, `vcd-categorical-reporting` スキルテンプレートの実装と検証。
3. **Phase 2 マッチング基盤**: `.agents/shared/matched_pair_dirichlet.R`, `.agents/shared/matched_set_inference.R` の実装と網羅的テスト。

### 3.2 検証エビデンス（アーカイブ時点）

- `tests/test_comparative_schemas.R`: PASS
- `tests/test_matched_pair_dirichlet.R`: PASS
- `tests/test_matched_set_inference.R`: PASS
- `tests/test_vcd_categorical_reporting.R`: PASS

### 3.3 検証の限界

- Section 9 までのテストは 1:1 ペアおよび 1:k セットの構造的検証に特化しており、連続体共変量調整（IPTW）や人年発生率（Gamma-Poisson）の推論は Phase 2 Section 10 以降の責務として分離されています。

---

## 4. 未解決事項と引継ぎ

1. **Phase 2 Section 10 (IPTW) — 完了・アーカイブ済**:
   - IPTW 修復（10.R1〜10.R22）および Section 11 初回実装は [archived_summary_012_0924.md](archived_summary_012_0924.md)（Batch `20260924_141100_012`）へ退避済み。
2. **現行引継ぎ（Artifacts 残置）**:
   - Section 11 受入後硬化〜Section 12 / QA-0001 は `docs/Artifacts/implementation_plan_013_0924.md` 以降を参照。

---

## 5. 元文書と復元情報

退避された元ファイルは [20260924_011800_011/sources/](20260924_011800_011/sources/) に完全保存されています。

| 元ファイル名 | 退避先相対パス | Git コミット (Baseline) |
| :--- | :--- | :--- |
| `OpenSpec_review1_comparative_evidence_reporting_v3_20260923.md` | [sources/OpenSpec_review1_...md](20260924_011800_011/sources/OpenSpec_review1_comparative_evidence_reporting_v3_20260923.md) | `cee26ff` |
| `OpenSpec_review2_comparative_evidence_reporting_v3_20260923.md` | [sources/OpenSpec_review2_...md](20260924_011800_011/sources/OpenSpec_review2_comparative_evidence_reporting_v3_20260923.md) | `cee26ff` |
| `OpenSpec_review3_comparative_evidence_reporting_v3_20260923.md` | [sources/OpenSpec_review3_...md](20260924_011800_011/sources/OpenSpec_review3_comparative_evidence_reporting_v3_20260923.md) | `cee26ff` |
| `OpenSpec_review4_comparative_evidence_reporting_v3_20260923.md` | [sources/OpenSpec_review4_...md](20260924_011800_011/sources/OpenSpec_review4_comparative_evidence_reporting_v3_20260923.md) | `cee26ff` |
| `Phase1_implementation_review1_20260923.md` | [sources/Phase1_review1_...md](20260924_011800_011/sources/Phase1_implementation_review1_20260923.md) | `cee26ff` |
| `Phase1_implementation_review2_20260923.md` | [sources/Phase1_review2_...md](20260924_011800_011/sources/Phase1_implementation_review2_20260923.md) | `cee26ff` |
| `Phase1_implementation_review3_20260923.md` | [sources/Phase1_review3_...md](20260924_011800_011/sources/Phase1_implementation_review3_20260923.md) | `cee26ff` |
| `Phase1_implementation_review4_20260923.md` | [sources/Phase1_review4_...md](20260924_011800_011/sources/Phase1_implementation_review4_20260923.md) | `cee26ff` |
| `Phase1_implementation_review5_20260923.md` | [sources/Phase1_review5_...md](20260924_011800_011/sources/Phase1_implementation_review5_20260923.md) | `cee26ff` |
| `implementation_plan.md` | [sources/implementation_plan.md](20260924_011800_011/sources/implementation_plan.md) | `cee26ff` |
| `implementation_plan_001_0923.md` | [sources/implementation_plan_001_0923.md](20260924_011800_011/sources/implementation_plan_001_0923.md) | `cee26ff` |
| `implementation_plan_002_0923.md` | [sources/implementation_plan_002_0923.md](20260924_011800_011/sources/implementation_plan_002_0923.md) | `cee26ff` |
| `implementation_plan_003_0923.md` | [sources/implementation_plan_003_0923.md](20260924_011800_011/sources/implementation_plan_003_0923.md) | `cee26ff` |
| `implementation_plan_004_0923.md` | [sources/implementation_plan_004_0923.md](20260924_011800_011/sources/implementation_plan_004_0923.md) | `cee26ff` |
| `implementation_plan_005_0923.md` | [sources/implementation_plan_005_0923.md](20260924_011800_011/sources/implementation_plan_005_0923.md) | `cee26ff` |
| `implementation_plan_006_0923.md` | [sources/implementation_plan_006_0923.md](20260924_011800_011/sources/implementation_plan_006_0923.md) | `cee26ff` |
| `implementation_plan_007_0923.md` | [sources/implementation_plan_007_0923.md](20260924_011800_011/sources/implementation_plan_007_0923.md) | `cee26ff` |
| `implementation_plan_008_0923.md` | [sources/implementation_plan_008_0923.md](20260924_011800_011/sources/implementation_plan_008_0923.md) | `cee26ff` |
| `Phase2_Section9_matched_sets_review_1_20260923.md` | [sources/Phase2_Section9_matched_sets_review_1_20260923.md](20260924_011800_011/sources/Phase2_Section9_matched_sets_review_1_20260923.md) | `cee26ff` |
| `Phase2_Section9_repair_plan_review_1_20260923.md` | [sources/Phase2_Section9_repair_plan_review_1_20260923.md](20260924_011800_011/sources/Phase2_Section9_repair_plan_review_1_20260923.md) | `cee26ff` |
| `Phase2_Section9_repair_plan_review_2_20260923.md` | [sources/Phase2_Section9_repair_plan_review_2_20260923.md](20260924_011800_011/sources/Phase2_Section9_repair_plan_review_2_20260923.md) | `cee26ff` |
