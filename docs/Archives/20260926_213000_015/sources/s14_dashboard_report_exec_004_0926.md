# Execution Record: Section 14 Visual Acceptance Battery with Verified U3 Row (14.R3c)

## 1. 概要
- **対象タスク**: Section 14 Visual QA Acceptance (Residual Finding M14-01 / 14.R3c)
- **対応方針**: `primary_delta = 0.01` を用いて、6条件（TargetExcess, RefExcess, Neutral, U3_Uncertain, TargetU2, ZeroRef）を包含する決定論的テストバッテリーを実行し、第4行 `T4_U3_Uncertain` にて真の `resolution_grade == "U3"`（実務判定 `target_excess`、低確信度）を発現。
- **視覚監査結果**:
  - `T4_U3_Uncertain` 実務セルが `class='col-practical practical-u3 practical-target-excess'` かつ `style='background-color: rgba(148, 163, 184, 0.12);'`（彩度抑制スレートグレー）として描画されたことを確認。
  - アラート色（赤/青）の抑制、単一セル限定着色（行全体着色の排除）、警告コールアウト2件の正常表示を確認。
  - Google Chrome (headless=new, 1280x800) によるスクリーンショット取得および寸法・アセット検証をパス。

---

## 2. 成果物一覧及び SHA-256 チェックサム

実行ディレクトリ: `evidence_runs/visual_qa_s14/run_20260926_041047/`

| 成果物ファイル | SHA-256 チェックサム | 役割 |
| :--- | :--- | :--- |
| `dashboard.html` | `f4bba2665f08da77c356c66725705e964dafabb88f01660b1365bee7bfa7d41b` | 自己完結HTMLダッシュボード（U3行含む） |
| `dashboard_1280x800.png` | `d18993a998f63aa9d7a8a5946e7b3c738fbc056df67f110f0a8811ba67a4fcd8` | Headless Chrome 1280x800 実測スクリーンショット |
| `comparative_summary.csv` | `53398dbc1228dc558b6e0711c57ca41fbab467bc81d6599267c7bc7d062d2f6a` | 解析サマリーCSV（全来歴列・U3グレード保持） |
| `comparative_evidence.json` | `926e1ddebd606e1d40d188ac4351cd8eaa7fe38dbef71251e41e93c57ef76fe4` | 一次エビデンスJSON |
| `comparative_report.md` | `3f9b7befa59d97e9cf739e4d1dcc663528eaa40ccc95bf9d4e420079582866d0` | 要約Markdownレポート |
| `results_manifest.json` | `3a0a2d22d8adfa68bb94ad4e36ca9fc5256bd4f97ad12b89273153590de1704b` | 成果物マニフェスト |
| `run_meta.json` | `a363c4a5893832f7f817fb8675e3ea5d546970fb8814e6a9a0820ad67c5d674b` | 実行メタデータ |

---

## 3. 表データ検証（`comparative_summary.csv` 抜粋）

| 行 | テーマ (theme) | N (T / R) | Events (T / R) | RD [95% CI] | RR [95% CI] | u_grade | dominant_region | 方向支持 | バッジ |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| 1 | T1_TargetExcess | 100 / 100 | 45 / 5 | 0.397 [0.288, 0.502] | 8.73 [4.05, 23.79] | **U0** | target_excess | 1.000 | (none) |
| 2 | T2_RefExcess | 100 / 100 | 5 / 45 | -0.395 [-0.501, -0.288] | 0.12 [0.04, 0.25] | **U0** | reference_excess | 0.000 | (none) |
| 3 | T3_Neutral | 1000 / 1000 | 50 / 50 | 0.000 [-0.019, 0.019] | 1.01 [0.68, 1.46] | **U2** | practical_neutral | 0.514 | (none) |
| 4 | **T4_U3_Uncertain** | 100 / 100 | 10 / 10 | 0.001 [-0.084, 0.085] | 1.01 [0.43, 2.34] | **U3** | target_excess | 0.512 | (none) |
| 5 | T5_TargetU2 | 100 / 100 | 12 / 8 | 0.039 [-0.046, 0.123] | 1.48 [0.65, 3.58] | **U2** | target_excess | 0.827 | (none) |
| 6 | T6_ZeroRef | 100 / 100 | 10 / 0 | 0.097 [0.046, 0.167] | 45.51 [3.80, 17480.30] | **U0** | target_excess | 1.000 | ZERO_REFERENCE, UNSTABLE_RR_INTERVAL |

---

## 4. DOM & スタイル実測検証

1. **U3 実務セルスタイル**:
   - `Tag`: `<td class='col-practical practical-u3 practical-target-excess' style='background-color: rgba(148, 163, 184, 0.12);'>`
   - `Content`: `<span class='ugrade'>U3</span><br><small>target_excess</small>`
   - `Styling Contract`: 彩度抑制・低コントラスト（スレートグレー 12% 透過）。過剰な警告赤色（`rgba(239, 68, 68, ...)`）の非適用を確認。
2. **コールアウト配置**:
   - Callout 1 (`#guidance-callout`): 解釈上の契約・免責事項（同等性誤認禁止、因果的優越禁止、スクリーニング免責）。
   - Callout 2 (`#numerical-instability-warning`): T6_ZeroRef に伴う相対リスク不安定性警告。
3. **ブラウザ表示整合性 (1280x800)**:
   - レンダリング画像寸法: 1280 x 800 (PNG)
   - テーブル崩れ、不自然な折り返し、見切れなし。

---

## 5. 自動回帰テスト検証結果

- 実行コマンド: `Rscript tests/test_comparative_dashboard_qa.R`
- 結果: **68 Passed, 0 Failed** (100% Pass)
- 網羅項目:
  - 14.1: 6大概念列分離と来歴列保持
  - 14.2 & 14.3: セル限定着色および U3 彩度抑制オーバーライド
  - 14.4: 診断列分離バッジ
  - 14.5: 数値不安定性警告コールアウト
  - 14.6: Zero External Asset (外部通信0件)
  - 14.7: Zero Local Path (OS固有絶対パス0件)
  - 14.8: アクセシビリティ・DOM一意性
  - 14.R1 & 14.R4: ガバナンスによる RR 区間抑制とブートストラップ来歴
  - 14.R2: 悪意あるラベルの HTML エスケープ
  - 14.R5: Markdown レポートにおける `1.33 [N/A]` 統一
