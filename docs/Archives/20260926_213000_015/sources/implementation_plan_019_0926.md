# 実装計画書: Section 14 最終 Re-QA 指摘修復および完全受入（14.R3c）

- 文書番号: `docs/Artifacts/implementation_plan_019_0926.md`
- 作成日時: 2026-09-26 JST
- 対象ブランチ: `feat/comparative-evidence-reporting-v3`
- 基準コミット: `75e79c601333b535b29dfbe801a711e43e07cd06` (QA: add Section 14 final visual Re-QA review3)
- 根拠QAレビュー: [`docs/Artifacts/s14_dashboard_report_qa_review3_001_0926.md`](s14_dashboard_report_qa_review3_001_0926.md)
- 目的: Section 14 の Re-QA Review 3 で指摘された唯一の残余課題（M14-01 / 14.R3c: 確定的な U3 行を含む exact visual QA artifact の生成・ブラウザ実測・Git 追跡）を完遂し、Section 14 を完全な PASS / ACCEPT へ昇格させる。

---

## 1. 現状分析と課題の特定（Gap Analysis）

Re-QA Review 3 において、以下の状況が確認された：

- **14.R5 (M14-03)**: Markdown レポートでの `1.33 [N/A]` 統一と `[NA, NA]` 排除が確認され、**CLOSED**。
- **14.R3b**: Exact artifact の Git 追跡、ハッシュ整合性（`1cc08d9fa5ff...`）、1280x800 スクリーンショット（`3dbba0f84d...`）の客観的検証が確認され、大幅に進捗。
- **残余課題 (M14-01 / 14.R3c)**:
  - 前回コミットされた `evidence_runs/visual_qa_s14/.../dashboard.html` 内の行 `T4_U3_Uncertain` は、`primary_delta = 0.05` で実行されたため、実際には `U2 / practical_neutral` と判定されており、U3 行が存在していなかった。
  - そのため、実行記録に記載された「U3 の muted slate 背景色（`rgba(148, 163, 184, 0.12)`）の視覚的検証」が exact artifact の実体と乖離していた。

---

## 2. 確定的な U3 を含むデータ契約とフィクスチャ設計（14.R3c）

### 2.1 パラメータ契約（`primary_delta = 0.02`）

`independent_beta_binomial` モデルにおいて、各実務領域への事後質量がすべて決定閾値（0.60）未満となる確実な U3 行を含む 6 テーマのフィクスチャを構成する：

| テーマ名 | 標本サイズ (T / R) | イベント数 (T / R) | 期待される判定 (delta=0.02) | 視覚エンコーディング契約 |
| :--- | :--- | :--- | :--- | :--- |
| **`T1_TargetExcess`** | 100 / 100 | 45 / 5 | **`U0` / `target_excess`** | Coral / Red (`rgba(239, 68, 68, 0.20)`) |
| **`T2_RefExcess`** | 100 / 100 | 5 / 45 | **`U0` / `reference_excess`** | Indigo / Blue (`rgba(59, 130, 246, 0.20)`) |
| **`T3_Neutral`** | 1000 / 1000 | 50 / 50 | **`U0` / `practical_neutral`** | Slate (`rgba(100, 116, 139, 0.20)`) |
| **`T4_U3_Uncertain`** | 100 / 100 | 10 / 10 | **`U3` / `practical_neutral`** (max_p=0.368) | **Muted Slate Override (`rgba(148, 163, 184, 0.12)`)** |
| **`T5_TargetU2`** | 100 / 100 | 12 / 8 | **`U2` / `target_excess`** (max_p=0.683) | Light Coral / Red (`rgba(239, 68, 68, 0.08)`) |
| **`T6_ZeroRef`** | 100 / 100 | 10 / 0 | **`U0` / `target_excess` (ZERO_REF)** | Coral / Red + `#numerical-instability-warning` |

### 2.2 実機ブラウザ測定と証跡記録契約

1. 新規 run ディレクトリ（例: `evidence_runs/visual_qa_s14/run_20260926_041500/`）に exact artifact を生成。
2. `dashboard.html` 内の `T4_U3_Uncertain` 行が以下を具備することをアサート：
   - `<span class='ugrade'>U3</span>`
   - `class="col-practical practical-u3 ..."`
   - `style="background-color: rgba(148, 163, 184, 0.12);"`
3. 実機 Google Chrome（macOS arm64 headless, 1280×800）によりスクリーンショット（`screenshot_1280x800.png`）を撮影。
4. Chrome DOM 計算値（`innerWidth`, `scrollWidth`, `tableWidth`, コールアウト視認性, 各 Practical セル色）をプローブ実行して実測。
5. 生成されたディレクトリ全体を Git 管理対象としてステージング・コミット。

---

## 3. 具体的テストマトリクス（Test Matrix）

| テスト項目 | 検証対象 | Checks / 検証内容 | 期待結果 (Expected Result) |
| :--- | :--- | :--- | :--- |
| **14.R3c (U3 HTML契約)** | `dashboard.html` | U3 行の存在、クラス名、スタイル属性 | `practical-u3` クラスおよび `rgba(148, 163, 184, 0.12)` が実在する。 |
| **14.R3c (U3 CSV契約)** | `comparative_summary.csv` | `T4_U3_Uncertain` の `u_grade` | `"U3"` と完全一致。 |
| **14.R3c (画像実測)** | `screenshot_1280x800.png` | 画像寸法 (sips) および U3 行の視覚的存在 | 1280×800 px。U3 セルが muted slate で描画されている。 |
| **14.R3c (レイアウト)** | Headless Chrome 1280x800 | `scrollWidth <= innerWidth` | 横スクロール 0 (1265 <= 1280)。 |
| **自動回帰テスト** | `tests/test_comparative_dashboard_qa.R` | 全テストスイート実行 | 68/68 PASS。 |

---

## 4. 変更対象ファイル一覧

1. **`evidence_runs/visual_qa_s14/`**:
   - 新規確定 run ディレクトリ（`dashboard.html`, `screenshot_1280x800.png`, CSV, JSON等）の追加
   - 旧 run ディレクトリ（U3 未含有の旧成果物）の置換
2. **`docs/Artifacts/s14_dashboard_report_exec_004_0926.md`**:
   - U3 行を実機検証した完全な Re-QA 3 修復実施記録
3. **`tests/test_comparative_dashboard_qa.R`**:
   - 変更なし（既に 68/68 PASS 達成済み）

---

## 5. 実行ステップ

1. 計画書の作成（本計画書）
2. `delta = 0.02` による確定的な U3 含有 Visual QA アーティファクトの生成
3. 実機 Google Chrome（1280x800）によるスクリーンショット撮影および DOM 計算値実測
4. 旧アーティファクトのクリーンアップと新アーティファクトの Git 追加
5. 実施記録 `s14_dashboard_report_exec_004_0926.md` の作成
6. 作業コミット（`Yip: finalize Section 14 visual QA artifact with verified U3 row (14.R3c)`）の作成
