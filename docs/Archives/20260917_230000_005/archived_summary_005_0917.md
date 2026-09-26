# アーカイブ済みArtifactの要約 (Batch 005)

created: 2026-09-17 23:00 (JST)
author: Antigravity
対象期間: 2026-09-15 18:20 (JST) 〜 2026-09-17 23:00 (JST)
archive_batch_id: 20260917_230000_005
source_count: 2

---

## 1. 対象と結論

本ドキュメントは、`docs/Artifacts/` に蓄積されていた名義2次元分割表解析スキル（`vcd-categorical-analysis`）のメジャーアップデートおよび契約修復に関する計画書 2 件を精査・統合し、監査可能な原本として `docs/Archives/sources/` に集約したアーカイブです。

この期間において、本リポジトリは以下の重要マイルストーンを完遂しました：

1. **vcd-categorical-analysis v4.0 の完成**: 従来の2次元 Pearson 残差分析から、統計的証拠・局所残差診断・多項 Dirichlet 事後不確実性を分離統合した科学的エビデンス分析エンジン（Interface 3.0）への全面刷新（commit `03d682c`）。
2. **vcd-categorical-analysis v4.1 の契約修復と安全化**: OpenSpec change `vcd-categorical-analysis-v4-1-repair` に基づき、残存していた3次元フォールバックの完全除去（2次元専任化）、Pass 0 来歴検証（`analysis_config.json` 必須化と SHA-256 照合）、構造的ゼロ・ゼロマージン・未指定 `input_mode` の即時フェイルファスト遮断を配備。
3. **Cross-Field Invariant と品質ループ（QMS）受入**: `categorical_results.json` と `evidence_profile.json` の同時生成と署名・セルキー照合、および独立レビュー（`QMS-VCD-V41-IMPLEMENTATION-001`）における F-001 / F-002 の完全是正（全 85 テスト PASS）を経て、Owner による正式承認・受入（`accepted`）を達成。

---

## 2. 確定した決定と理由

| 計画書 | 確定した決定事項 | 理由・背景 | 集約先の節 |
| :--- | :--- | :--- | :--- |
| `Implementation-plan-vcd-categorical-analysis-v4.0.md` | 5軸分離原則（Effect / Evidence / Influence / Stability / Uncertainty）の採用。構造的ゼロはサポート外とし、完全2次元名義分割表専用エンジンとして定義。 | P値や単一スコアへの過度の依存を排し、効果の大きさ・統計的証拠・推定量不確実性を混同せず評価できるようにするため。 | §3.1 |
| `Implementation-plan-vcd-categorical-analysis-v4.0.md` | Interface 3.0 成果物（`categorical_results.json`, `residuals_table.csv`, GT/DT HTML, Mosaic/Assoc PNG）の標準化と決定論的シード（Dirichlet事後推論）の導入。 | 監査再現性を担保し、インタラクティブ HTML と詳細 JSON を一貫したスキーマで提供するため。 | §3.1 |
| `Implementation-plan-vcd-categorical-analysis-v4.1 Repair & Contract Hardening.md` | `analysis.R` からの3次元レガシー分岐（HairEyeColorフォールバック等）の完全撤廃。Arity != 2 は `INVALID_INPUT_ARITY` で即時停止。 | 仕様（2次元専任）と実コードの乖離を解消し、3次元以上の解析は正本スキル `vcd-bayesian-evidence-analysis` へ明確に委譲するため。 | §3.2 |
| `Implementation-plan-vcd-categorical-analysis-v4.1 Repair & Contract Hardening.md` | Pass 0 設定（`analysis_config.json`）の必須化と、入力データおよび設定の SHA-256 改ざん検知（Pass 0 来歴契約の厳格化）。 | 事前相談なしでの直接起動や入力データの事後改変を防止し、科学的再現性を保証するため。 | §3.2 |
| `Implementation-plan-vcd-categorical-analysis-v4.1 Repair & Contract Hardening.md` | `input_mode` の暗黙 "aggregated" 既定投入の撤廃（未指定・未知値は `INVALID_INPUT_MODE` で停止）。 | 個別データが誤って集約データとして扱われる重大な誤集計・データ完全性リスクを排除するため。 | §3.2 |
| `Implementation-plan-vcd-categorical-analysis-v4.1 Repair & Contract Hardening.md` | 正本成果物名を `evidence_profile.json` に統一し、出力直前の Cross-Field Invariant（署名・run_id・セルキー・確率和・CI順序）検証と違反時 `SCHEMA_INVARIANT_VIOLATION` fail-fast を実装。 | 成果物間の整合性を機械的に保証し、下流の監査システムでのデータ不整合を遮断するため。 | §3.2 |

---

## 3. 主要成果と検証の限界

### 3.1 vcd-categorical-analysis v4.0（エビデンス分析エンジン）

- **成果**:
  - Cramér's V（バイアス補正区間付き）、調整残差、Rao スコア検定統計量 $T_i^{\rm score}$、対数P値、Leverage $h_{ii}$、Quarantine 3条件（ゼロセル・期待度数不足・高レバレッジ）を実装。
  - 大標本 Dual-Filter 原則（$N \ge 2000$ かつ効果量・証拠強度の両閾値超過セルのみを候補とする）を導入。
  - 多項 Dirichlet 事後推論（10,000 draws、決定論的シード）によるセル結合確率の信用区間および実務差確率（`prob_practical_delta`）算出基盤を確立。
  - 出力成果物（JSON/CSV/HTML/PNG）の Interface 3.0 標準化。
- **検証の限界**:
  - 完全な名義2次元分割表専用であり、順序尺度スコア付けや3次元以上の交互作用モデルは対象外。

### 3.2 vcd-categorical-analysis v4.1（契約修復と安全化・品質ループ）

- **成果**:
  - 7つの失敗モード（`INVALID_INPUT_MODE`, `MISSING_FREQUENCY_COLUMN`, `FREQUENCY_COLUMN_NOT_PERMITTED`, `ZERO_MARGIN_DETECTED`, `INVALID_INPUT_ARITY`, `STRUCTURAL_ZERO_NOT_SUPPORTED`, `MISSING_REQUIRED_CONFIG`）に対する即時遮断と `run_state.json: failed` 記録を網羅。
  - Quality Loop 監査案件 `QMS-VCD-V41-IMPLEMENTATION-001` において、`F-001`（`input_mode` 既定投入撤廃）および `F-002`（`evidence_profile.json` 整合性検証）を特定・是正。
  - 回帰テストスイート `verify_skill.sh`（Step 1: 15, Step 2: 50, Step 3: 20）全 85 テスト 100% PASS を達成。
  - `analysis.R` 実プロセス起動による E2E 遮断（`INVALID_INPUT_MODE`, `SCHEMA_INVARIANT_VIOLATION`）を独立実証。
  - OpenSpec change `vcd-categorical-analysis-v4-1-repair` の strict validation 合格。
- **検証の限界**:
  - テスト環境変数による失敗系注入はサブプロセス実行時のメモリ内プロファイル改ざんに限定されており、通常運用時における本番コードへの影響は完全ゼロ（不活性）。

---

## 4. 未解決事項と引継ぎ

- **マニュアル文書の維持**: `docs/Artifacts/quality_loop_manual_001_0912.md` は Quality Loop の恒久的な手順書であるため、アーカイブ対象から除外し、引き続き現行パスにて維持。
- **OpenSpec Change のアーカイブ**: 本品質ループの完了に伴い、OpenSpec change `vcd-categorical-analysis-v4-1-repair` の本流同期およびアーカイブ（`/opsx-archive`）を必要に応じて後続実施可能。

---

## 5. 元文書と復元情報

| 元ファイルパス | 判定 | 作成・更新日時 (JST) | 退避先原本パス | SHA-256 ハッシュ |
| :--- | :--- | :--- | :--- | :--- |
| `docs/Artifacts/Implementation-plan-vcd-categorical-analysis-v4.0.md` | 完了 | 2026-09-16 00:00 / 2026-09-16 12:00 | [`sources/Implementation-plan-vcd-categorical-analysis-v4.0.md`](sources/Implementation-plan-vcd-categorical-analysis-v4.0.md) | `a47f7507c83c3502805207a189ca9184f5c34c1593d20b55a87aeca8c2584ba3` |
| `docs/Artifacts/Implementation-plan-vcd-categorical-analysis-v4.1 Repair & Contract Hardening.md` | 完了 | 2026-09-17 00:00 / 2026-09-17 22:55 | [`sources/Implementation-plan-vcd-categorical-analysis-v4.1 Repair & Contract Hardening.md`](sources/Implementation-plan-vcd-categorical-analysis-v4.1%20Repair%20&%20Contract%20Hardening.md) | `e64827f4bfc30322dd1d336345043d36a76833bc651daee5d4f2cc48c220aae2` |

※ 原本を復元する場合は、上記 `sources/` 内のファイルを元のパスへ配置し、SHA-256 チェックサムを照合してください。
