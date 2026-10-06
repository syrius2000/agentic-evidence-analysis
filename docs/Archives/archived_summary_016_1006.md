# アーカイブサマリー 016：比較ダッシュボード指標解説・稀な有害事象既定閾値方針の実装完了

created: 2026-10-06 23:30 (JST)  
author: Antigravity  
対象期間: 2026-10-01 〜 2026-10-02  
対象ブランチ / PR: `codex/reporting_metric_guides` → `main` (PR #5, commit `84f83f3`)

---

## 1. 対象と結論

本アーカイブは、`vcd-categorical-reporting`（比較ダッシュボードおよびレポート生成）における指標解説・未評価表示の改善（計画001）と、稀な有害事象における実務閾値（既定0.001）・感度分析設定（計画002）の実装・検証完了に伴い、関連する計画書群を `./docs/Archives/` へ統合・退避した記録である。

両計画はトピックブランチ `codex/reporting_metric_guides` にて実装され、回帰テスト群の全件通過を経て `main`（PR #5、コミット `84f83f3`）へ集約・完了した。

---

## 2. 確定した決定と理由

| 計画ID | 決定事項 | 決定の理由・背景 |
|---|---|---|
| **001** | E100（100人あたり差）および逆数RD（NNT/NNH-like）の独立ガイド項目追加と表ヘッダーからのリンク導線新設 | 従来RDの解説文中に埋もれていた自然頻度換算・規模感を直感的に参照可能とし、ソート操作と解説リンクを両立させるため。 |
| **001** | 実務領域・U-Gradeの未評価（`primary_delta` 未設定）行における理由搬送と表示層での制御 | `NONE / none` をU3や中立と混同せず、かつ表示層での再推定を禁止するデータ契約を保ちつつ、未評価理由（`primary_delta_not_set`）を明示するため。 |
| **002** | `domain = "safety"` における引数省略時の実務閾値 0.001（1,000人あたり1人）および感度候補（0.0001, 0.0005, 0.001, 0.005）の自動適用方針（`rare_ae_exploratory_v1`） | 毎回の閾値確認の手間を省きつつ、探索的スクリーニングの標準基準を提供するため。ただし普遍的な臨床重要性や安全性の保証ではなく、重篤事象は別途レビューする規約を明記。 |
| **002** | 有害事象での未評価（`primary_delta = NULL`）を許容するための明示フラグ `allow_unevaluated = TRUE` の導入 | 意図しない未設定による探索漏れを防ぎ、利用者が意図的に省略する場合のみ明示合意を要求するため。 |

---

## 3. 主要成果と検証の限界

### 主要成果
1. **データ契約の厳格化**:
   - `excess_per_100`、`reciprocal_absolute_rd`、`practical_evaluation_status`、`practical_evaluation_reason`、`effective_primary_delta`、`practical_threshold_source` 等の要約列を追加。
   - 表示層での再計算・再判定を完全に排除し、上流の canonical 状態から一意に搬送。
2. **回帰テスト合格実績**:
   - `tests/test_comparative_dashboard_qa.R`（239 assertions passed）
   - `tests/test_vcd_categorical_reporting.R`（40 assertions passed）
   - `tests/test_comparative_schemas.R`（139 assertions passed）
   - `tests/test_dashboard_theme_contract.R`（88 assertions passed）
3. **オフライン・自己完結性保証**:
   - 生成HTMLダッシュボードにおいて、外部CDN/CSS/JS依存ゼロ、OS絶対パス依存ゼロを実証。

### 検証の限界
- 外部Pythonライブラリ `jsonschema` が環境に未導入であったため、Draft-07 スキーマ照合テストは自動スキップ（内部R検証のみ成功）。
- 重篤性情報のないCSVデータ（例: `Drug-Safty-example.csv`）に対しては、PT名称からの重篤性の推測・自動判定は行わず、別途医学的レビューを要する注記にとどめている。

---

## 4. 未解決事項と引継ぎ

- **未解決事項**: なし（計画001・002の全実装項目は完了し、`main` に統合済み）。
- **後続への引継ぎ**:
  - `vcd-categorical-reporting` の出力ルートは、その後の Change `standardize-evidence-run-output-contract`（計画005・006）により `evidence_runs/vcd_categorical_reporting/run_<id>/` へ標準化された。

---

## 5. 元文書と復元情報

| 元文書パス（退避前） | 退避先パス（アーカイブ内） | 作成日 | 復元用コミット |
|---|---|---|---|
| `docs/Artifacts/plans/implementation_plan_001_1001.md` | [20261006_233000_016/plans/implementation_plan_001_1001.md](20261006_233000_016/plans/implementation_plan_001_1001.md) | 2026-10-01 | `84f83f3` |
| `docs/Artifacts/plans/implementation_plan_002_1001.md` | [20261006_233000_016/plans/implementation_plan_002_1001.md](20261006_233000_016/plans/implementation_plan_002_1001.md) | 2026-10-01 | `84f83f3` |
