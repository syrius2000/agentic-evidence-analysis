---
name: questionnaire-batch-analysis
description: Use when batch-analyzing multiple categorical questionnaire items from a question-config CSV and generating summary.csv plus per-question reports for nominal_2way, likert_2way, or nominal_3way analyses.
license: MIT
metadata:
  version: "1.1"
---

**IRON LAW**: `--question-config` の必須列が欠けている、または `var1/var2/var3` が入力データに存在しない状態では実行しない。まず設定不整合を修正してから再実行する。

設問設定 CSV に基づき、複数設問を同一ルールで処理して `summary.csv` と設問別レポートを出力する。

## 共通品質契約

本スキルは `.agents/shared/analysis_quality_contract.md` を参照する。実行前には入力品質と設問設定、実行後には設問別成果物、横断総括、解釈保留、完了報告を契約に沿って確認する。

## 実行前の必須ステップ: Pass 0 (Interactive Consultation)

新規分析では、**`vcd-pass0-consultation`** によりデータ検分、設問定義、分母、欠測、複数回答、層別を確認し、由来情報付き `analysis_config.json` を確定します。`batch_runner.R` は `--config` なしでは統計計算を開始しません。

## 利用者向け出力導線

新しいプロジェクトでは、Pass 0 の相談成果物を `output/<project>/00_consultation/` に保存し、`analysis_config.json` の `output_dir` に `output/<project>/10_questionnaire/` を指定します。正式成果物は必ず、その親ディレクトリ下の `runs/<id>[_N]/` に隔離されます。

```text
output/<project>/
├── 00_consultation/analysis_config.json
└── 10_questionnaire/
    └── runs/<id>[_N]/
```

Pass 1 完了後は、run 内の `run_handover.json` に記載された `run_output_dir` を後続工程へ渡してください。`./skill_out/questionnaire/` は `--out` または設定ファイルで別の親ディレクトリを指定しない場合の後方互換用既定値です。

## 実行チェックリスト

- [ ] **Pass 0確認（必須）**: `vcd-pass0-consultation` で検分・対話・設問定義を完了している
- [ ] **共通設定確認（必須）**: Pass 0で生成した `analysis_config.json` を `--config` で渡す
- [ ] **設定確認（必須）**: `references/config-schema.md` の必須列を満たす
- [ ] **品質契約確認**: `.agents/shared/analysis_quality_contract.md` に従い、欠損、過剰水準、セルスパース性、設問タイプ、集約・除外の必要性を確認する
- [ ] **確認ゲート**: `--out` が既存ディレクトリの場合、上書きしてよいかユーザー確認
- [ ] **確認ゲート**: 設問数が多い（目安: 50件超）場合、実行時間増大を案内して継続確認
- [ ] **実行**: `templates/batch_runner.R` を実行
- [ ] **完了判定**: `summary.csv` と `{output_slug}/report.html` が生成されている
- [ ] **横断総括**: 複数設問を扱う場合は `cross_question_summary.md` を生成し、重要設問、解釈保留、次アクションを整理する

### `output_slug` 公開契約

`output_slug` は出力root直下で使う**安全な単一slug成分**とし、次の条件をすべて満たすこと。

- 1〜100文字のASCII文字列で、先頭は英数字とする。
- 使用可能文字はASCII英数字・`.`・`_`・`-`、すなわち `[A-Za-z0-9._-]` のみとする。
- 末尾は英数字・`_`・`-` とし、末尾の `.` は禁止する。空白、非ASCII文字、パス区切り、Windows禁止記号も使用できない。
- 重複はcase-insensitiveで判定し、`Question1` と `question1` のような組み合わせを成果物生成前に拒否する。
- Windows予約名 `CON`、`PRN`、`AUX`、`NUL`、`COM1`〜`COM9`、`LPT1`〜`LPT9` は、`CON.txt` など拡張子付きの場合も禁止する。
- 設定CSVは全列を文字列として読み、`output_slug` のCSV文字列をそのまま保持して先頭ゼロを維持する。`output_slug` 以外の設定列ではliteral `NA` は欠損として扱い、空欄の欠損処理も維持する。一方、`output_slug` の `NA` は文字列として保持する。したがって `001` と `1`、`01` と `1` は別slugであり、文字列 `NA` も上記構文を満たす合法slugとなる。

## 共通 4-Pass 正式対応表

| 共通 4-Pass | Questionnaire (`questionnaire-batch-analysis`) |
| :--- | :--- |
| **Pass 0** (Consultation) | `question_config.csv` 策定・設問定義および `vcd-pass0-consultation` |
| **Pass 1** (Statistical Compute) | `templates/batch_runner.R`（全設問一括計算、`results_manifest.json`、`runs/<id>/` 強制隔離予約） |
| **Pass 2** (Expert Narrative) | 設問別解釈・`cross_question_summary.md`（横断総括）。staging 領域から `finalize_run_stage.R` による本番確定 |
| **Pass 3** (Dashboard / Report) | `templates/render_dashboard.R --run-dir <dir>`。`--preview`（未封印）または本番確定（`finalize_pass3` 経由で `dashboard.html` 生成、`run_state = "sealed"` 封印） |

## 移行ガイド: 親直下出力の完全廃止と `runs/<id>` 強制隔離

旧バージョンでは `--out` 直下に `summary.csv` や設問ディレクトリが出力される場合がありましたが、本バージョンより**親直下出力は完全廃止**されました。
- **強制隔離**: すべての実行成果物は必ず `<out>/runs/<run_id>/` 配下に隔離生成されます。
- **実行パスの引き継ぎ**: 自動化スクリプトや後続処理は、Pass 1 が出力する `run_handover.json` から確定した `run_output_dir` を取得して利用してください。

## 3 区分状態遷移と診断成果物保持契約

Questionnaire バッチ実行は、設問ごとの成否に応じて以下の 3 区分に遷移します：
1. **`completed` (全設問成功)**:
   - すべての設問が正常に分析された状態。
   - `summary.csv`, 各設問 `report.html`, `results_manifest.json`, `run_handover.json` が生成され、本番 Pass 2 / 3 確定へ進むことができます。
2. **`partial` (一部設問失敗)**:
   - 1 つ以上の設問が失敗したが、1 つ以上の設問が成功した状態。
   - 非ゼロ終了コードで停止し、成功設問の結果と `partial_failures` メタデータ、およびそれらを網羅した `results_manifest.json` が保持されます。
   - プレビュー確認（`--preview`）は可能ですが、**本番 Pass 2/3 確定（`dashboard.html` および sealed 封印）は安全のため遮断**されます。
   - 失敗原因の修正後、`--supersedes-run <partial_run_dir>` を指定して新しい run へ引き継ぎ可能です。
3. **`failed` (全設問失敗)**:
   - すべての設問が失敗した状態。非ゼロ終了コードで停止します。
   - `--supersedes-run` の元 run として指定することはできません。

## 実行手順（4-Pass・順序厳守）

### Pass 1: バッチ一括計算

```bash
Rscript .agents/skills/questionnaire-batch-analysis/templates/batch_runner.R \
  --config output/<project>/00_consultation/analysis_config.json
```

| オプション | 既定値 | 説明 |
| :--- | :--- | :--- |
| `--config` | 必須 | Pass 0で確定した入力・設問設定・由来情報を持つ設定ファイル |
| `--data` | - | Pass 0設定作成時の項目。Pass 1は設定ファイルの値を使用 |
| `--question-config` | - | Pass 0設定作成時の項目。Pass 1は設定ファイルの値を使用 |
| `--out` | `./skill_out/questionnaire/` | 出力親ディレクトリ（out_root）。新規プロジェクトでは `output/<project>/10_questionnaire/` を指定 |
| `--run-id` | （未指定時はJST時刻） | 指定時は `<out>/runs/<run_id>[_N]/`、未指定時はJST時刻で原子的予約隔離 |
| `--supersedes-run` | （なし） | 改定・再分析元となる確定済み実 run ディレクトリパス |
| `--allow-legacy-run-meta` | （なし） | レガシー run (v1.0) のメタデータ読み取りを許可するフラグ |

#### 成果物マニフェスト (`results_manifest.json`)
Pass 1 完了時に、実ファイルバイト列に対する SHA-256 ハッシュを記録した `results_manifest.json` が出力されます。
- `summary.csv`、各設問の `report.html`、`questionnaire_results.json` など全成果物が登録されます。
- 設定ファイルのスナップショットは保存されますが、元データはコピーせず `hash_only` で SHA-256 のみが安全に記録されます。

### Pass 2: 設問横断総括と本番確定プロトコル

`summary.csv` および各設問の計算結果に基づき、横断考察を作成します。

#### 横断総括（cross_question_summary.md）作成要領
複数設問を分析した場合は、`summary.csv` と設問別レポートを根拠に `cross_question_summary.md` を作成します。
- 重要設問、解釈保留、次アクションを明確にする。
- **禁止**: P値だけで設問を順位付けしない。`status=error` 行を結果解釈に混ぜない。
- 設問タイプ（`nominal_2way`、`likert_2way`、`nominal_3way`）に応じた適切な解釈を行う。

#### 本番 Pass 2 確定手順
1. AI は横断考察 Markdown を **run 内の staging 領域** (`<run_dir>/staging/cross_question_summary.md`) にドラフト保存します。
2. 共通 CLI ラッパーを用いて本番確定を実行します:
```bash
Rscript .agents/shared/finalize_run_stage.R \
  --stage pass2 \
  --run-dir <run_dir> \
  --source-artifact <run_dir>/staging/cross_question_summary.md \
  --target-name cross_question_summary.md \
  --expected-results-manifest-sha256 <sha256>
```
- `<out_root>/.run_locks/<run_lock_id>/` にて信頼境界検証付き排他ロックを取得して保護されます。
- 検証成功後に staging から本番配置へ原子的に昇格（promotion）されます。

### Pass 3: ダッシュボード生成と sealed 封印

新設された専用 CLI レンダラー `templates/render_dashboard.R` を用いて、`--run-dir` で実 run ディレクトリを直接指定します。

#### プレビューダッシュボード生成（未封印）
```bash
Rscript .agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R \
  --run-dir <run_dir> \
  --preview
```
※ `dashboard_preview.html` が生成されます。`partial` run に対してもプレビュー確認が可能です（未封印）。

#### 本番ダッシュボード確定と sealed 封印
```bash
Rscript .agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R \
  --run-dir <run_dir>
```
- `completed` run のみ実行可能です（`partial` / `failed` run は本番レンダリングが遮断されます）。
- Pass 2 が確定済みであることを検証します。
- `dashboard.Rmd` は `self_contained: true` に準拠し、ローカル一時ファイルに依存しない単一ファイル完結型 HTML として生成されます。
- 確定と同時に **`run_state = "sealed"`** に遷移し、run は完全に封印されます。**封印後の成果物追加・変更・上書きはすべて拒絶されます。**

### クラッシュ回復と supersedes-run
- promotion 完了後・run_meta 更新前に中断された場合でも、実ハッシュ照合により再実行で冪等に回復できます。
- 封印済み run または `partial` run を再分析・再計算する場合は、Pass 1 に `--supersedes-run <old_run_dir>` を渡して安全に新 run を予約します。

### パス・リンク表現基準と AI 完了報告 4 大要素
- リポジトリ内ファイルは相対リンク、リポジトリ外ファイルは正規化絶対パスで記述する。
- `run_meta.json` と `run_handover.json` の保存パスには `path_schema_version: "1.0"` と `path_kind` を付与し、リポジトリ内・run内は POSIX 相対パスで記録する。外部入力は既定で物理パスを保存せず、SHA-256 と論理ラベルだけを保存する。
- `summary.csv` の `report_path` も run 内相対パスとし、`cwd` は `"."` の repo root marker とする。legacy の絶対パスは明示的な読み取り互換時だけ解決する。
- 完了報告では、(1) ダッシュボードリンク、(2) 確定実 run パス、(3) 設定・結果リンク、(4) 進行・封印状態（`run_state = "sealed"`）を必ず提示する。

## 生成ファイル一覧

| 出力ファイル | 役割 / タイミング | 説明 |
| :--- | :--- | :--- |
| `run_meta.json` | Pass 1〜3 | 実行メタデータ・成果物ハッシュ・状態管理（v2.0 形式） |
| `summary.csv` | Pass 1 | 全設問の一括集計・検定・効果量サマリー |
| `{output_slug}/report.html` | Pass 1 | 設問ごとの個別詳細レポート |
| `results_manifest.json` | Pass 1 | 全設問成果物の実ファイルバイト列ハッシュを含む成果物マニフェスト |
| `run_handover.json` | Pass 1 | 後続 Pass への確定パス・引数引き継ぎ情報 |
| `cross_question_summary.md` | Pass 2 (本番) | AI 専門家による確定版横断総括考察 |
| `dashboard_preview.html` | Pass 3 (Preview) | プレビュー用ダッシュボード（未封印） |
| `dashboard.html` | Pass 3 (本番) | 単一ファイル完結型統合 HTML ダッシュボード（`sealed` 封印トリガー） |

## 確定・回復時の共通契約

- 本番確定とpreview公開は、共通 `run.lock` の下で状態を再読して実行する。既に封印されたrunや完了済み工程は再確定しない。
- Pass 2はmanifestの期待ハッシュを引き継ぐ。Pass 3は確定済み考察の記録ハッシュと由来manifestを描画前後に照合する。改定は新runで実施する。
- promotion中断時は、元の `--source-artifact` と期待ハッシュで確定CLIを再実行する。sourceが消失していても、run外の `transaction_<stage>.json` と公開先が一致するときに回復する。ロックが残った場合のみ `--recover-stale-lock` を明示する。証跡を削除・捏造しない。
- legacy previewは `--allow-legacy-run-meta --preview --preview-output-dir <元run外の出力先>` を指定する。元runは読み取り専用とし、同名previewは上書きしない。
- Questionnaireのpartial/failedは非ゼロ終了し、停止理由付きhandoverの本番next_actionsは空となる。診断成果物を確認して新しいrunへ進む。
- `run_handover.json` の `cwd` へ移動し、提示された `argv` を実行する。存在しないstubコマンドを推測して追加しない。
