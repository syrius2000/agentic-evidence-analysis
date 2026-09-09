---
name: vcd-bayesian-evidence-analysis
description: Use when analyzing large-sample two-way or three-way categorical tables with 4-axis cell diagnostics (Effect, Evidence, Influence, Stability), explicit BIC log-linear models, Dirichlet posterior inferences, and effect sizes.
license: MIT
metadata:
  version: "2.0"
---

**IRON LAW**: Pass 3（`dashboard.html`）は既定で Pass 2 産物（`executive_summary.md`）が無いと失敗する。プレビュー目的でのみ `require_pass2 = FALSE` を明示し、それ以外では Pass 1→2→3 の順序を崩さない。

大標本における「P値の罠」を克服し、4軸セル診断（Effect × Evidence × Influence × Stability）、Leverage補正局所Score統計量、総度数 $N$ 基準の明示式 BIC、および全体効果量（Cramér's V）を併用して「統計的有意性」と「実質的意義」を峻別するAI連携型分析パイプライン。

`mysql-create-query-support` などで検証済みになった抽出 SQL は、repo root の `sql/validated/` 配下を正本として参照する。分析用 CSV は、その SQL の粒度・除外条件・検証結果と対応するものを使う。

## 共通品質契約

本スキルは `.agents/shared/analysis_quality_contract.md` を参照する。Pass 0では分析スコープ、Pass 1では統計計算と主要JSON、Pass 2ではAIレビュー標準構成、Pass 2.5では品質確認、Pass 3ではHTMLと図表の読み取り確認を契約に沿って満たす。

## 統計的背景: 4軸セル診断フレームワーク

本スキルの **推論本体**は、(1) 標本数 $N$ に不変な実質的効果量 **Effect**、(2) セル指示変数追加に対する Rao のスコア統計量（自由度1のカイ二乗値）である **Evidence**（Leverage補正局所Score統計量 $T_i^{\rm score}$）、(3) モデル適合に対するセルの制約度 **Influence**（Leverage $h_{ii}$）、(4) ゼロセル（$O=0$）、疎セル（$E < 5.0$）、または過大レバレッジ（$h \ge 0.80$）を隔離する **Stability**、および (5) 全体効果量 **Cramér's V** です。

### 指標の粒度契約

- **Effect（実質的効果量: 標本数不変）**: `log_oe_ratio`（$\log(O/E)$）および `scaled_diff`（$e_i$）は、期待値に対する実質的な過剰・過少の強さを示し、標本サイズ $N$ に依存しない。大標本における主判定指標。
- **Evidence（証拠強度: 標本数比例）**: `score_stat`（$T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}$）は、セルが偶然変動を超えてモデルから逸脱している統計的確信度を示す。
- **全体効果量**: `Cramér's V` は、分割表全体の大域的な関連強度を表し、個々のセルに割り付ける局所指標ではない。
- **旧セルScoreの廃止**: 従来の $r^2 - k \log N$ は局所LRTとの乖離および大標本でのエビデンス飽和を引き起こすため、**完全廃止**されました。

### Leverage補正局所Score統計量

$$T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}} = \frac{(y_i - \hat{\mu}_i)^2}{\hat{\mu}_i (1 - h_{ii})}$$

- $r_{P,i}$: 基準モデル（相互独立 M1 または均一連関 M8）の標準化ピアソン残差
- $h_{ii}$: Hat 行列の対角成分（Leverage）。セルの構造的制約度を表す。
- 自由度 1 のカイ二乗分布に従い、ダミー再適合による局所尤度比検定統計量 $\Delta G_i^2$ の高精度な二次近似となる。

### 総度数 $N$ 基準の明示式 BIC

$$\mathrm{BIC}_{\mathrm{explicit}} = -2 \ln L + p \cdot \ln(N)$$

- 分割表の真の標本サイズである被験者総数 $N$ を用いる（ポアソン完全対数尤度基準。R既定の `stats::BIC` はセル数 $K$ を用いるため不採用）。
- 自由パラメータ数 $p$（切片を含むモデル推定パラメータ数）による厳密なペナルティ。

## 前提条件

- `R` (≥ 4.0) および Pass 1/3 で `pacman` によりロードされるパッケージ（手動導入する場合は `references/dependencies.md` を参照）：
  - `dplyr`, `tidyr`, `jsonlite`, `DT`, `htmlwidgets`, `htmltools`, `effectsize`, `knitr`, `rmarkdown`, `pacman`
- 入力データは UTF-8 エンコードの CSV または R 組み込みデータセット名を指定

## 実行前の必須ステップ: Pass 0 (Interactive Consultation)

新規分析では、Pass 1の前に **`vcd-pass0-consultation`** を実行し、分析スコープと由来付き `analysis_config.json` を確定します。`analysis.R` はPass 0由来を検証するため、`--config` なしでは統計計算を開始しません。

- **理由**: 変数が多すぎると「次元の呪い」により結果の解釈が困難になり、偽陽性のリスクも高まります。
- **手順**: `.agents/shared/inspect_data.R` でデータを検分し、AI と対話して重要な軸（次元）や層別解析の必要性を判断してください。
- **成果物**: Pass 0 を経ることで、Pass 1 でそのまま利用可能な `analysis_config.json` が得られます。正準仕様は `references/analysis_config.schema.json` です。

`analysis_config.json` は手書きせず、Pass 0 の `finalize_pass0_config.R` で確定します。これにより、設定内容に加えて検分JSONと入力CSVのハッシュ連鎖が保存されます。

`analysis.R --config` は、Pass 1 の統計計算前に `analysis_config.json`、Pass 0検分JSON、入力CSVのSHA-256を照合します。由来不一致、入力改変、必須キー不足は、正式run作成前に日本語エラーで停止します。

## 利用者向け出力導線

新しいプロジェクトでは、次の配置を標準例とします。

```text
output/<project>/
├── 00_consultation/
│   └── analysis_config.json
└── 10_bayesian/
    └── run_<first16>[_N]/
```

`analysis_config.json` の `output_dir` に `output/<project>/10_bayesian/` を指定すると、Pass 1 はその親ディレクトリ直下へ正式 run を原子的に予約します。Pass 1 の完了後は、run 内の `run_handover.json` に記載された `run_output_dir` を Pass 2・Pass 3 へ渡してください。`./skill_out/vcd_bayesian/` は、`output_dir` を指定しない既存利用の後方互換用既定値です。

## 共通 4-Pass 正式対応表

| 共通 4-Pass | Bayesian (`vcd-bayesian-evidence-analysis`) |
| :--- | :--- |
| **Pass 0** (Consultation) | `vcd-pass0-consultation` / `inspect_data.R` によるデータ検分と `analysis_config.json` 単一正本策定（正式 run 作成なし） |
| **Pass 1** (Statistical Compute) | `templates/analysis.R`（4軸セル診断計算、`results_manifest.json`、実 run 原子的予約隔離、`run_handover.json`） |
| **Pass 2** (Expert Narrative) | `executive_summary.md`（AI 専門家考察）または `pass2_stub.R`（プレビュー用スタブ）。staging 領域から `finalize_run_stage.R` による本番確定 |
| **Pass 3** (Dashboard / Report) | `templates/render_dashboard.R`。`--preview`（未封印）または本番確定（`finalize_pass3` 経由で `dashboard.html` 生成、`run_state = "sealed"` 封印） |

## 実行手順（4-Pass・順序厳守）

**必須の流れ:** Pass 0（設定策定）→ Pass 1（統計計算・run 予約隔離・マニフェスト出力）→ Pass 2（AI 考察ドラフトを staging に作成し `finalize_run_stage.R` で確定）→ Pass 3（`render_dashboard.R --run-dir <path>` で本番レンダリングし `sealed` 封印）。

### Pass 1: R Engine（統計計算）

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --config output/titanic/00_consultation/analysis_config.json
```

| オプション | 既定値 | 説明 |
| :--- | :--- | :--- |
| `--config` | 必須 | Pass 0で確定し、由来情報を持つ `analysis_config.json` パス |
| `--input` | - | Pass 0設定作成時の項目。Pass 1は設定ファイルの値を使用 |
| `--output_dir` | `./skill_out/vcd_bayesian/` | 出力親ディレクトリ（out_root） |
| `--run-id` | （なし） | 指定時は `<--output_dir>/run_<prefix>/` に隔離（`prefix` = 解決後 `run_id` の先頭16文字。未指定時は入力から算出したハッシュの先頭16文字）。同一秒重複時は `_2` 等のサフィックスで原子的分離 |
| `--vars` | （全変数） | 分析対象カテゴリ変数（2変数または3変数をカンマ区切りで指定） |
| `--freq` | `Freq` | 度数列名（存在しない場合は1行=1件としてカウント） |
| `--response_var` | （なし） | 3次元以上で Cramér's V を算出するための応答変数 |
| `--base_model` | `M1` | 局所セル診断の基準モデル（M1: 相互独立モデル 〜 M9: 飽和モデル） |
| `--top_k` | 10 | Top-K 表示件数（効果比またはScore統計量上位セル） |
| `--large_n_threshold` | 2000 | 大規模データモード切替閾値（N > 2,000 で Effect 優先 Dual-Filter を適用） |
| `--supersedes-run` | （なし） | 改定・再分析元となる確定済み実 run ディレクトリパス |
| `--allow-legacy-run-meta` | （なし） | レガシー run (v1.0) のメタデータ読み取りを許可するフラグ |
| `--help` | - | CLI ヘルプを表示 |
| `--help_stats` | - | 統計指標ガイドを表示 |

#### 成果物マニフェスト (`results_manifest.json`)
Pass 1 完了時に、実ファイルバイト列に対する SHA-256 ハッシュを記録した `results_manifest.json` が出力されます。
- **スキーマ制約**: `path` は実 run ディレクトリからの相対パス（POSIX 形式、一意）、`sha256` は 64 桁の 16 進小文字。
- **role allowlist**: `primary_results`, `diagnostic`, `intermediate`, `summary_table`, `figure`, `canonical_result`, `question_result` のみ許容。

#### データの hash_only 原則
設定ファイル（`analysis_config.json`）のスナップショットは run 内に保存されますが、巨大な外部元生データは無断で run 内にコピーされず、入力検証およびハッシュ値（SHA-256）のみが `run_meta.json` に安全に記録されます。

### Pass 2: AI 考察生成と本番確定プロトコル

Pass 1 が生成した `evidence_results.json` を読み込み、以下の **日本語エグゼクティブ・サマリー** を作成します。

#### プレビュースタブ生成（一回限り）
AI による本番執筆前に、プレビュー確認用のスタブを作成できます:
```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R \
  --run-dir <run_dir>
```
※ `executive_summary_preview.md` が生成され、`pass_status$pass2` は `stub_generated` に更新されます。同名プレビューの上書き再実行は拒絶されます。

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
- **排他ロック**: `<out_root>/.run_locks/<run_lock_id>/`（全64桁ハッシュ）にて信頼境界検証付き排他ロックを取得して保護されます。
- **stale ロック回復**: ロック保持プロセスが死滅し一定時間経過した場合は、`--recover-stale-lock` フラグで監査ログ (`audit.jsonl`) を残して安全に回復できます（生存 PID や他ホストのロックは拒絶）。
- **promotion**: 検証成功後に staging から本番配置（`executive_summary.md`）へ原子的に昇格され、メタデータが `completed` に更新されます。

**AI 執筆ガイドライン（4節構成・日本語厳守）**:
- `#### 節1: 全体的な関連性の評価（モデル選択BIC + 全体効果量）`
- `#### 節2: 局所セル診断の4軸評価（Effect / Evidence / Influence / Stability）`
- `#### 節3: 多次元交互作用の解釈（層別エビデンスと条件付き割合差）`
- `#### 節4: 結論と実務的示唆`

### Pass 2.5: 品質確認 (quality_check.md)

Pass 2 の後、必要に応じて `quality_check.md` を run ディレクトリに保存します。P値偏重や因果断定を避け、効果量、残差方向、スパースセル、集約による情報損失、解釈保留事項が適切に整理されていることを確認します。

### Pass 3: ダッシュボード生成と sealed 封印

ダッシュボード生成は必ず `--run-dir` で実 run ディレクトリを直接指定します（暗黙探索は完全廃止）。

#### プレビューダッシュボード生成（未封印）
```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R \
  --run-dir <run_dir> \
  --preview
```
※ `dashboard_preview.html` が生成されます。`run_state` は `active`（未封印）のまま保持され、後から本番確定が可能です。

#### 本番ダッシュボード確定と sealed 封印
```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R \
  --run-dir <run_dir>
```
- Pass 2 が確定済み（`completed`）であることを検証します。
- レンダリングされた HTML は staging 経由で検証され、`dashboard.html` として本番確定配置されます。
- `dashboard.Rmd` は `self_contained: true` に準拠し、生成された HTML はローカル一時ファイルに依存しない単一ファイル完結性を持ちます。
- 確定と同時に **`run_state = "sealed"`** に遷移し、run は完全に封印されます。**封印後の成果物追加・変更・上書きはすべて拒絶されます。**

### クラッシュ回復と冪等性
promotion 完了後、run_meta 更新前にクラッシュした場合でも、既存成果物の実ファイルバイト列ハッシュが期待値と一致していれば、finalizer の再実行によって安全かつ冪等にメタデータを同期・回復できます。

### 確定済み run の改定 (`--supersedes-run`)
`sealed` 封印済みの run に対して再分析やパラメータ変更を行う場合は、元 run を直接改ざんせず、Pass 1 に `--supersedes-run <old_run_dir>` を指定して新しい run を予約・作成します。元 run の実ファイルハッシュ再計算と系統記録（lineage）が安全に保持されます。

### パス・リンク表現基準
- **リポジトリ内ファイル**: 相対パス（例: `[dashboard.html](run_xxx/dashboard.html)`）で記述する。`file:///` 絶対 URL は禁止。
- **成果物メタデータ**: `path_schema_version: "1.0"` と `path_kind` を付与し、`repo_relative` または `run_relative` の POSIX 相対パスを保存する。
- **外部入力**: 既定では物理パスを保存せず、SHA-256 と論理ラベルだけを `external` として記録する。明示的な `--supersedes-run` の元 run は外部参照として絶対パスを許可する。
- **`run_handover.json`**: `cwd: "."` と `repo_root_marker` を使い、run 内ファイルは run 相対パスで記録する。legacy の絶対パスは読み取り互換に限定する。

### AI 完了報告の 4 大要素（必須）
分析完了をユーザーへ報告する際は、以下の 4 要素を必ず明記してください：
1. **ダッシュボードリンク**: `[dashboard.html](相対パス)`
2. **確定実 run パス**: 実際に生成・封印された `run_output_dir`
3. **設定・計算結果リンク**: `analysis_config.json`, `evidence_results.json`, `results_manifest.json` への相対リンク
4. **進行・封印状態**: `run_state` が `sealed` であること、および各 Pass の完了ステータス

## 生成ファイル一覧

| 出力ファイル | 役割 / タイミング | 説明 |
| :--- | :--- | :--- |
| `run_meta.json` | Pass 1〜3 | 実行メタデータ・成果物ハッシュ・状態管理（v2.0 形式） |
| `evidence_results.json` | Pass 1 | 4軸セル診断モジュール構造（一次計算結果） |
| `results_manifest.json` | Pass 1 | 実ファイルバイト列ハッシュを含む成果物マニフェスト |
| `run_handover.json` | Pass 1 | 後続 Pass への確定パス・引数引き継ぎ情報 |
| `analysis_config.json` | Pass 1 | 実行設定のスナップショット |
| `dt_table.html` | Pass 1 | インタラクティブ DT テーブル |
| `executive_summary_preview.md` | Pass 2 (Preview) | プレビュー用スタブ考察（一回限り） |
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
