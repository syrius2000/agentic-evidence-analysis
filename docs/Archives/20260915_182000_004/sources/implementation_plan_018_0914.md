# R 実行環境の決定論的依存関係管理と Fail-Fast 化 実施計画書

created: 2026-09-14 18:25 (JST)
update: 2026-09-14 21:50 (JST)
author: Antigravity (Advanced Agentic Coding)
status: 実装完了・検証済み
target_change: `openspec/changes/enforce-deterministic-r-dependencies`
related_docs:
- [OpenSpec 変更提案 (proposal.md)](../../openspec/changes/enforce-deterministic-r-dependencies/proposal.md)
- [OpenSpec 能力仕様 (spec.md)](../../openspec/changes/enforce-deterministic-r-dependencies/specs/deterministic-r-dependencies/spec.md)
- [OpenSpec 設計書 (design.md)](../../openspec/changes/enforce-deterministic-r-dependencies/design.md)
- [OpenSpec タスク一覧 (tasks.md)](../../openspec/changes/enforce-deterministic-r-dependencies/tasks.md)

---

## 1. 目的・背景

現在の R 実行基盤には、`pacman::p_load()` による実行時の CRAN からの暗黙的な自動パッケージインストール、共有モジュール `.agents/shared/run_scope.R` における `install.packages()`、およびテストコード内でのパッケージ自動取得処理が混在している。
これにより、サンドボックス環境、イントラネット環境、書き込み権限が制限された環境において、ネットワーク遮断（403 エラー）やパーミッションエラーでスクリプトが異常終了し、実行時における再現性（Reproducibility）や監査証跡が損なわれる原因となっている。

本計画は、以下の3段階の設計原則に基づき、暗黙の外部取得を根絶し、不足時は親切な案内を出して即時停止（Fail-Fast）する決定論的実行基盤を整備することを目的とする。

1. **実行時の自動インストールを全面禁止する**（`pacman`, `run_scope.R`, テストコード、Rmd等）
2. **依存関係を実行経路ごとに明示・分離し、不足時は共有モジュールで Fail-Fast する**
3. **正本リポジトリとして README.md / AGENTS.md による環境要件の明確化とオフライン検証環境を確立する**

---

## 2. アーキテクチャと基本設計

### 2.1 共有依存性検査モジュール `.agents/shared/dependency_check.R` の新設
各スクリプトに重複してチェック処理を埋め込まず、共通関数 `check_r_dependencies()` を提供する。

```r
check_r_dependencies <- function(required, context = "実行") {
  missing <- required[
    !vapply(required, requireNamespace, logical(1L), quietly = TRUE)
  ]

  if (length(missing) > 0L) {
    install_hint <- sprintf(
      'install.packages(c(%s))',
      paste(sprintf('"%s"', missing), collapse = ", ")
    )

    stop(
      sprintf(
        paste0(
          "[ERROR] %sに必要なRパッケージが不足しています: %s\n",
          "セキュリティおよび再現性確保のため、実行時の自動インストールは行いません。\n",
          "事前に次を実行してください:\n  %s\n"
        ),
        context,
        paste(missing, collapse = ", "),
        install_hint
      ),
      call. = FALSE
    )
  }
}
```

### 2.2 実行経路別の依存関係分離
統計計算処理（Pass 1）と HTML レポート・可視化処理（Pass 3）の依存関係を分離し、表示系パッケージの不足が統計計算をブロックしない構造とする。

| 実行工程 | 必須パッケージ | 検査コンテキスト名 | 備考 |
| :--- | :--- | :--- | :--- |
| **Pass 0 事前検分** | `jsonlite`, `readr`, `dplyr`, `digest` | `"Pass 0 事前検分"` | データ構造と SHA-256 検分 |
| **Run 隔離管理** | `jsonlite`, `digest` | `"Run隔離管理"` | `.agents/shared/run_scope.R` |
| **Pass 1 統計計算** | `jsonlite`, `digest`, `dplyr`, `tidyr`, `effectsize` | `"Pass 1 統計計算"` | 対数線形モデル・4軸セル診断 |
| **Pass 2 AI考察・検査** | `jsonlite`, `digest` | `"Pass 2/2.5 考察検査"` | 数値主張ゲート照合 |
| **Pass 3 ダッシュボード** | `rmarkdown`, `knitr`, `DT`, `htmltools`, `htmlwidgets`, `katex`, `ggplot2` | `"Pass 3 ダッシュボード生成"` | Pandoc を伴う HTML 可視化 |

---

## 3. 実装タスク一覧（OpenSpec tasks.md と完全同期）

### Phase 1: 共有依存性検査モジュールの新設と共有基盤の改修
- [x] **Task 1.1**: `.agents/shared/dependency_check.R` を新設し、`check_r_dependencies()` 関数を実装。単体テストを R コマンドで検証。
- [x] **Task 1.2**: `.agents/shared/run_scope.R` から `install.packages("digest")` および `install.packages("jsonlite")` を削除し、`check_r_dependencies()` による事前検査へ置換。
- [x] **Task 1.3**: `.agents/shared/inspect_data.R` の依存読み込み部を `check_r_dependencies()` に改修。`tests/test_inspect_data_out_dir.R` で動作検証。

### Phase 2: スキルテンプレート（R / Rmd）からの実行時自動インストール排除と依存分離
- [x] **Task 2.1**: `vcd-bayesian-evidence-analysis` の `templates/analysis.R` から `pacman::p_load` および UI 依存（`DT`, `htmlwidgets`, `htmltools`）の計算時強制ロードを削除し、計算用依存を `check_r_dependencies()` で検査。
- [x] **Task 2.2**: `vcd-bayesian-evidence-analysis` の `templates/render_dashboard.R` および `templates/dashboard.Rmd` から `pacman` 自動インストールと `p_load` を削除し、表示用依存を分離検査するよう改修。
- [x] **Task 2.3**: `vcd-categorical-analysis` の `templates/analysis.R`, `templates/dashboard.Rmd`, `templates/report.Rmd`, `tests/test_logic.R` から `pacman` 自動インストールと `p_load` を削除し、`check_r_dependencies()` に置換。
- [x] **Task 2.4**: `questionnaire-batch-analysis` の `templates/batch_runner.R`, `templates/dashboard.Rmd`, `templates/report.Rmd` から `pacman` 自動インストールと `p_load` を削除し、`check_r_dependencies()` に置換。

### Phase 3: テストコードの安全化とオフライン検証
- [x] **Task 3.1**: `tests/` 配下のスクリプトから `install.packages` / `pacman` 処理を削除。
- [x] **Task 3.2**: 共有依存検査モジュールの回帰テスト（正常通過および不足時の Fail-Fast 出力確認）を新設。
- [x] **Task 3.3**: 全 R / Rmd スクリプトおよびテストコードに対する静的走査（grep）を実施し、実行時自動インストール（`install.packages`, `p_load`）が 0 件であることを検証。
- [x] **Task 3.4**: 回帰テストスイートをサンドボックス内で実行し、外部通信なしで決定論的に通過することを検証。

### Phase 4: ドキュメントおよび事前セットアップ手順の整備
- [x] **Task 4.1**: ルート `README.md` の「動作環境要件」を更新し、用途別の必要 R パッケージ一覧と一括事前導入ワンライナーを明記。
- [x] **Task 4.2**: `AGENTS.md` に「R 依存関係・実行時インストール禁止原則」を追加し、AI エージェント向けの行動規範と `README.md` 参照規則を定義。
- [x] **Task 4.3**: 各スキルの `references/dependencies.md` を手動セットアップ前提に改訂。

### 3.1 回帰テストスイートの構成と既存テストの分類・因果帰属

本変更において決定論的オフライン実行を保証する正規回帰テストスイート（`tests/run_regression_suite.R`）は、現行の正本仕様（依存性検査、Pass 0 契約、3-way 対数線形計算、新 4 軸セル診断、questionnaire バッチ、SAS パリティ）に合致する **23 本** で構成され、100% 成功（23/23 PASS）を達成している。Pass 1 の主要解析保証は正規スイート内の `tests/test_dependency_isolation_pass1.R` が担う。

リポジトリ内の全テスト関連ファイル（全59件）は、公式台帳（`tests/test_inventory_manifest.csv`）において機械的に一意定義され、正規回帰スイート（23本）と除外テスト（36本）として分類・記録されている：

| カテゴリ | 本数 | 代表スクリプト | 除外理由と因果帰属・追跡先 |
| :--- | :--- | :--- | :--- |
| **A. 過去の数理エンジン刷新によるレガシーテスト** | 18本 | `test_vcd_bayesian_arm_weighted.R`, `test_vcd_bayesian_help.R`, `test_vcd_bayesian_levels.R`, `test_vcd_bayesian_topk.R` 等 | 新4軸診断フレームワークへの刷新により ARM 機能（`res$extensions$arm`）や旧エビデンス閾値（`--threshold_k`）が廃止されたこと、および Pass 0 義務化以前の旧 CLI 呼び出しに依存していることによる既知の失敗。本変更（依存管理）起因ではない。将来のテスト現代化案件で整理。 |
| **B. Pandoc・環境依存描画テスト** | 4本 | `test_three_way_dashboard_html.R`, `test_vcd_dashboard_display_formats.R`, `test_vcd_dashboard_layout_core.R`, `test_vcd_dashboard_layout_foundation.R` | システム Pandoc および macOS Sandbox での動的ライブラリ（libgmp）制約を伴う結合描画テスト。 |
| **C. 特殊リソース・境界ストレステスト** | 8本 | `test_sas_proc_freq_numerical_parity.R`（OOM境界試験）, `test_ggplot2_jp_font.R` 等 | 大規模メモリ上限、OSフォントキャッシュ、または長時間プロセス分離を検証する特殊境界テスト。 |
| **D. Python 契約検証スクリプト** | 2本 | `test_analysis_quality_contract_docs.py`, `test_skill_ownership_contract.py` | Python ベースの文書品質およびスキル所有権契約検証スクリプト（pytest 実行）。 |
| **E. サンプルデータ生成ヘルパー** | 1本 | `gen_sample_survey.R` | 単体テストではなく、テスト用サンプルアンケートデータ生成スクリプト。 |
| **F. 数理基盤専用受入テストサブシステム** | 3本 | `tests/statistical_foundations/test_contract.R`, `test_acceptance.py`, `test_report.py` | 固定参照データ（`output/statistical_foundations/verified_0906`）を前提とする数理検証専用スイートであり、前提条件が異なるため通常回帰から除外。追跡先は `tests/statistical_foundations/run_validation.R`。 |

> **検算式**: 公式スイート23本（tests直下22本 + agents配下1本）＋ 除外36本（A:18 + B:4 + C:8 + D:2 + E:1 + F:3）＝ **全59件**（重複0・漏れ0・計数差0）。

---

## 4. 承認ゲートと完了基準

1. **非外部依存性**: スクリプトのいかなる実行時にも CRAN への無断アクセスやダウンロードが発生しないこと（静的走査 0 件達成）。
2. **Fail-Fast の明瞭性**: パッケージ不足環境で実行された場合、即座に適切な日本語エラーと導入用コマンドを出力して終了すること（単体テスト 6/6 PASS）。
3. **回帰健全性**: サンドボックス内で関連する回帰テストスイートがすべて通過すること。
