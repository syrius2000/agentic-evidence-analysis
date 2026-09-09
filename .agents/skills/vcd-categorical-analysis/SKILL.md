---
name: vcd-categorical-analysis
description: "Use when performing nominal two-way or three-way categorical analysis through the profile, render, expert narrative, quality-check, and dashboard workflow."
license: MIT
metadata:
  author: vcd-categorical-analysis-skill
  version: "3.1"
---

名義カテゴリカル変数（クロス表 **2-way / 3-way**）の独立性検定（Poisson GLM）および残差の可視化を行う。共通 4-Pass パイプライン（Pass 0: Consultation / Profile → Pass 1: Render / Compute → Pass 2: AI Review → Pass 3: Dashboard / Report）に従い、集計・AI考察・レポート生成までを一貫して行う。

## 共通 4-Pass 正式対応表

| 共通 4-Pass | Categorical (`vcd-categorical-analysis`) |
| :--- | :--- |
| **Pass 0** (Consultation) | `vcd-pass0-consultation` ＋ 必要に応じ `analysis.R --profile`（データ構造プロファイル生成、正式 run 作成なし） |
| **Pass 1** (Statistical Compute) | `analysis.R --render --config ...`（集計・モデル適合・`results_manifest.json` 出力、正式 run 原子予約隔離） |
| **Pass 2** (Expert Narrative) | `executive_summary.md`（AI 考察）。staging 領域から `finalize_run_stage.R` による本番確定配置 |
| **Pass 3** (Dashboard / Report) | `templates/render_dashboard.R --run-dir <dir>`。`--preview`（未封印）または本番確定（`finalize_pass3` 経由で `dashboard.html` 生成、`run_state = "sealed"` 封印） |

## 共通品質契約

本スキルは `.agents/shared/analysis_quality_contract.md` を参照する。Pass 0では入力品質と出力生成、Pass 2ではAIレビュー標準構成、Pass 2.5では品質確認、Pass 3ではHTMLと図表の読み取り確認を契約に沿って満たす。

## スコープ

| 項目 | 内容 |
| :--- | :--- |
| **次元** | **3-way まで**。4-way 以上は対象外（Pass 0 で分割・集約を提案）。 |
| **出力先** | `<out>/run_<first16>[_N]/`（Pass 1 で確定予約。親直下出力は禁止）。 |
| **正本** | `.agents/skills/vcd-categorical-analysis/` です。 |

## Categorical claim 機構の完全廃止と Pass 1 唯一 run 作成原則

旧バージョンでは `requested_run_id` と `analysis_signature` の一致を検証し、`run_state`（`allocated` → `profile_complete` → `render_in_progress` → `render_complete`）を用いた claim 再開機構が存在していましたが、Pass 1 唯一 run 作成原則に伴い claim 機構は**完全廃止**されました。
- **Pass 0 (`--profile`)**: 正式 run ディレクトリを作成しません。`data_profile.json` を指定出力先または一時領域に出力し、ユーザーや AI が設定を検討するための参考情報を提供します。
- **Pass 1 (`--render`)**: 実 run ディレクトリを決定・作成する**唯一の主体**です。atomic reservation により秒単位 JST タイムスタンプ（重複時は `_2` 等）で原子的かつ安全に隔離予約されます。存在しない `--data` は実行前にエラー停止します。

## 実行手順（4-Pass・順序厳守）

### Pass 0: プロファイリング (任意)

```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --profile \
  --data your_data.csv \
  --vars "var1,var2" \
  --freq "Freq" \
  --out ./skill_out/vcd_categorical/
```
※ `data_profile.json` が出力されます（正式 run ディレクトリは作成されません）。過大セル数や過剰水準を確認し、集約や除外方針を `render_config.json`（または `analysis_config.json`）にまとめます。

### Pass 1: R Engine 本計算（成果物マニフェスト出力と run 予約）

```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --render \
  --config render_config.json \
  --data your_data.csv \
  --vars "var1,var2" \
  --freq "Freq" \
  --label "mydata" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260417
```

| オプション | 既定値 | 説明 |
| :--- | :--- | :--- |
| `--render` | - | 本計算モードを指定（必須） |
| `--config` | （なし） | 集約・表示ルール等を定義した設定ファイル |
| `--data` | （内蔵 `HairEyeColor`） | 入力 CSV ファイルパス |
| `--vars` | （全変数） | 分析対象カテゴリ変数（カンマ区切り） |
| `--freq` | `Freq` | 度数列名 |
| `--label` | `categorical` | 出力ファイル接尾辞ラベル |
| `--out` | `./skill_out/vcd_categorical/` | 出力親ディレクトリ（out_root） |
| `--run-id` | （なし） | 実行識別子。`<out>/run_<prefix>[_N]/` に原子的予約隔離 |
| `--supersedes-run` | （なし） | 改定元となる確定済み実 run ディレクトリパス |
| `--allow-legacy-run-meta` | （なし） | レガシー run (v1.0) のメタデータ読み取りを許可するフラグ |

#### 成果物マニフェスト (`results_manifest.json`)
Pass 1 完了時に、実ファイルバイト列に対する SHA-256 ハッシュを記録した `results_manifest.json` が出力されます。
- `categorical_results.json`, `data_profile_post.json`, `summary_{label}.json`, 各種プロット図表が登録されます。
- 設定ファイルのスナップショットは保存されますが、外部元データはコピーせず `hash_only` で SHA-256 のみが安全に記録されます。

### Pass 2: AI 考察生成と本番確定プロトコル

`categorical_results.json` および `summary_{label}.json` を読み、日本語エグゼクティブサマリーを作成します。

#### 本番 Pass 2 確定手順
1. AI は考察 Markdown を **run 内の staging 領域** (`<run_dir>/staging/executive_summary.md`) にドラフト保存します。
2. 共通 CLI ラッパーを用いて本番確定を実行します:
```bash
Rscript .agents/shared/finalize_run_stage.R \
  --stage pass2 \
  --run-dir <run_dir> \
  --source-artifact <run_dir>/staging/executive_summary.md \
  --target-name executive_summary.md \
  --expected-results-manifest-sha256 <sha256>
```
- `<out_root>/.run_locks/<run_lock_id>/` にて信頼境界検証付き排他ロックを取得して保護されます。
- 検証成功後に staging から本番配置へ原子的に昇格（promotion）されます。

### Pass 2.5: 品質確認 (quality_check.md)

Pass 2 の後、必要に応じて `quality_check.md` を run ディレクトリに保存します。P値偏重や因果断定を避け、効果量、残差方向、スパースセル、集約による情報損失、解釈保留事項が適切に整理されていることを確認します。

### Pass 3: ダッシュボード生成と sealed 封印

ダッシュボード生成は必ず新設された薄型 CLI レンダラー `templates/render_dashboard.R` を用いて、`--run-dir` で実 run ディレクトリを直接指定します。

#### プレビューダッシュボード生成（未封印）
```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/render_dashboard.R \
  --run-dir <run_dir> \
  --preview
```
※ `dashboard_preview.html` が生成されます。`run_state` は `active`（未封印）のまま保持されます。

#### 本番ダッシュボード確定と sealed 封印
```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/render_dashboard.R \
  --run-dir <run_dir>
```
- Pass 2 が確定済みであることを検証します。
- `dashboard.Rmd` は `self_contained: true` に準拠し、ローカル一時ファイルに依存しない単一ファイル完結型 HTML として生成されます。
- 確定と同時に **`run_state = "sealed"`** に遷移し、run は完全に封印されます。**封印後の成果物追加・変更・上書きはすべて拒絶されます。**

### クラッシュ回復と supersedes-run
- promotion 完了後・run_meta 更新前に中断された場合でも、実ハッシュ照合により再実行で冪等に回復できます。
- 封印済み run の再分析・再計算を行う場合は、Pass 1 に `--supersedes-run <old_run_dir>` を渡して安全に新 run を予約します。

### パス・リンク表現基準と AI 完了報告 4 大要素
- リポジトリ内ファイルは相対リンク、リポジトリ外ファイルは正規化絶対パスで記述する。
- `run_meta.json` と `run_handover.json` の保存パスには `path_schema_version: "1.0"` と `path_kind` を付与し、リポジトリ内・run内は POSIX 相対パスで記録する。外部入力は既定で物理パスを保存せず、SHA-256 と論理ラベルだけを保存する。
- `cwd` は `"."` の repo root marker とし、legacy の絶対パスは明示的な読み取り互換時だけ解決する。
- 完了報告では、(1) ダッシュボードリンク、(2) 確定実 run パス、(3) 設定・結果リンク、(4) 進行・封印状態（`run_state = "sealed"`）を必ず提示する。

## 生成ファイル一覧

| 出力ファイル | 役割 / タイミング | 説明 |
| :--- | :--- | :--- |
| `run_meta.json` | Pass 1〜3 | 実行メタデータ・成果物ハッシュ・状態管理（v2.0 形式） |
| `data_profile.json` | Pass 0 (任意) | 初期次元・水準・セル数プロファイル（run 外または一時領域） |
| `data_profile_post.json` | Pass 1 | 集約後プロファイル（実 run 内） |
| `summary_{label}.json` | Pass 1 | モデル比較・残差統計サマリー |
| `categorical_results.json` | Pass 1 | ダッシュボード連携用 JSON（一次計算結果） |
| `results_manifest.json` | Pass 1 | 実ファイルバイト列ハッシュを含む成果物マニフェスト |
| `run_handover.json` | Pass 1 | 後続 Pass への確定パス・引数引き継ぎ情報 |
| `executive_summary.md` | Pass 2 (本番) | AI 専門家による確定版日本語エグゼクティブサマリー |
| `dashboard_preview.html` | Pass 3 (Preview) | プレビュー用ダッシュボード（未封印） |
| `dashboard.html` | Pass 3 (本番) | 単一ファイル完結型統合 HTML ダッシュボード（`sealed` 封印トリガー） |

## 確定・回復時の共通契約

- 本番確定とpreview公開は、共通 `run.lock` の下で状態を再読して実行する。既に封印されたrunや完了済み工程は再確定しない。
- Pass 2はmanifestの期待ハッシュを引き継ぐ。Pass 3は確定済み考察の記録ハッシュと由来manifestを描画前後に照合する。改定は新runで実施する。
- promotion中断時は、元の `--source-artifact` と期待ハッシュで確定CLIを再実行する。sourceが消失していても、run外の `transaction_<stage>.json` と公開先が一致するときに回復する。ロックが残った場合のみ `--recover-stale-lock` を明示する。証跡を削除・捏造しない。
- legacy previewは `--allow-legacy-run-meta --preview --preview-output-dir <元run外の出力先>` を指定する。元runは読み取り専用とし、同名previewは上書きしない。
- Questionnaireのpartial/failedは非ゼロ終了し、停止理由付きhandoverの本番next_actionsは空となる。診断成果物を確認して新しいrunへ進む。
- `run_handover.json` の `cwd` へ移動し、提示された `argv` を実行する。存在しないstubコマンドを推測して追加しない。
