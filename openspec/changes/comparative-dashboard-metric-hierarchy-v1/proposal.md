## Why

比較エビデンス・ダッシュボードの主表では、`E100 = 100 × RD` と `1/|RD|`（NNT/NNH-like）が 1 列に結合されており、絶対効果の自然単位換算と二次的な逆数解釈が視覚的に混同される。統計概念の分離（Effect ≠ Natural-unit translation ≠ Reciprocal translation ≠ Direction ≠ Region resolution ≠ Precision）を UI 上でも保持するため、表示階層と列順序を再編する。

## What Changes

- HTML / Markdown 主表を **11 列 → 12 列**へ再編し、結合列「100人あたり差 / NNT・NNH-like」を **「100人あたり差 (E100)」** と **「NNT・NNH-like」** の 2 列に分離する。
- 正本の表示順を確定する:
  `識別 → 生データ → RD → E100 → NNT/NNH-like → RR → Direction Support → Practical Region / U-Grade → Precision → Diagnostics`。
- U-Grade / Practical Region 列は削除せず維持する。実務領域色は当該セルのみに限定する。
- Metric Guide の Risk Difference セクションで、RD（一次対比）・E100（自然単位）・reciprocal RD（二次解釈）を明示分離する。
- `reciprocal_sort_val` を presentation layer で分離管理する（表示文字列の再数値化禁止）。
- Safety reciprocal 方向マッピングを正本固定する: `target_excess → NNH-like`、`reference_excess → NNT-like`。非 Safety は `1/|RD|` のみ（NNT/NNH 断定禁止）。
- **非変更（契約分離）**:
  - `comparative_evidence.json` / `comparative-evidence-v1` nested evidence contract は変更しない。
  - `summary_df` および dashboard CSV export は引き続き exactly 40 canonical summary fields。
  - presentation-only フィールドをいずれの canonical contract にも追加しない。
  - Gower / PCoA / HAC 特徴量契約、RD/RR 推論、U-Grade 閾値、schema version は変更しない。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `comparative-evidence-reporting`: 比較エビデンス要約表の presentation hierarchy（列順序・E100/reciprocal 列分離・U-Grade 維持・HTML/Markdown 同期・Guide 階層化）を要件として追加・更新する。canonical data contract と幾何特徴量契約は変更しない。

## Impact

- **コード**: `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`（HTML / Markdown / Metric Guide）
- **テスト**: `tests/test_comparative_dashboard_qa.R`（列順・分離・suppression・U-Grade・sort/export 不変性）
- **正本 spec**: `openspec/specs/comparative-evidence-reporting/spec.md`
- **非影響**: `schemas/comparative-evidence-v1.json`、`comparative_contrasts.R`、`evidence_gower.R`、`evidence_feature_extract.R`
- **参照計画**: `docs/Artifacts/implementation_plan_024_0927.md`
