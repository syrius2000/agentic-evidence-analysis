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

本スキルの **推論本体**は、(1) 標本数 $N$ に不変な実質的効果量 **Effect**、(2) セル指示変数追加に対する Rao のスコア統計量（自由度1のカイ二乗値）である **Evidence**（Leverage補正局所Score統計量 $T_i^{\rm score}$）、(3) モデル適合に対するセルの制約度 **Influence**（Leverage $h_{ii}$）、(4) ゼロセルや過大レバレッジを隔離する **Stability**、および (5) 全体効果量 **Cramér's V** です。

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

$$\mathrm{BIC} = -2 \ln L + k \cdot \ln(N) \quad (\text{または } G^2 - df \cdot \ln N)$$

- 分割表の真の標本サイズである被験者総数 $N$ を用いる（R既定の `stats::BIC` はセル数 $K$ を用いるため不採用）。

## 前提条件

- `R` (≥ 4.0) および Pass 1/3 で `pacman` によりロードされるパッケージ（手動導入する場合は `references/dependencies.md` を参照）：
  - `dplyr`, `tidyr`, `jsonlite`, `DT`, `htmlwidgets`, `htmltools`, `effectsize`, `knitr`, `rmarkdown`, `pacman`
- 入力データは UTF-8 エンコードの CSV または R 組み込みデータセット名を指定

## 実行前の推奨ステップ: Pass 0 (Interactive Consultation)

大規模・多次元データを分析する場合、いきなり Pass 1 を実行する前に **`vcd-pass0-consultation`** スキルを使用して分析のスコープを確定させることを強く推奨します。

- **理由**: 変数が多すぎると「次元の呪い」により結果の解釈が困難になり、偽陽性のリスクも高まります。
- **手順**: `.agents/shared/inspect_data.R` でデータを検分し、AI と対話して重要な軸（次元）や層別解析の必要性を判断してください。
- **成果物**: Pass 0 を経ることで、Pass 1 でそのまま利用可能な `analysis_config.json` が得られます。正準仕様は `references/analysis_config.schema.json` です。

`analysis_config.json` の最小例:

```json
{
  "input": "examples/titanic.csv",
  "vars": ["Class", "Sex", "Survived"],
  "freq": "Freq",
  "response_var": "Survived",
  "output_dir": "output/titanic",
  "run_id": "titanic_v1"
}
```

`analysis.R --config` は、Pass 1 の統計計算前に `analysis_config.json` を検証します。必須キー、`vars` / `freq` の入力CSV列との一致、数値パラメータの型が不正な場合は日本語エラーで停止します。未知キーは警告を出しつつ読み込みます。

## 実行手順（3-Pass・順序厳守）

**必須の流れ:** Pass 1 完了 → Pass 2 で `executive_summary.md` を `output_dir` に保存 → 必要に応じて Pass 2.5 で `quality_check.md` を保存 → Pass 3 で `dashboard.html` を生成。Pass 3 は既定で `executive_summary.md` が無いと **エラーで停止**する（`dashboard.Rmd` の `params$require_pass2`、既定 `TRUE`）。プレビュー専用で Pass 2 を省略する場合のみ `require_pass2 = FALSE` を指定する。

### Pass 1: R Engine（統計計算）

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --input your_data.csv \
  --vars FactorA,FactorB,FactorC \
  --freq Freq \
  --output_dir ./skill_out/vcd_bayesian/ \
  --run-id datasetA_20260417 \
  --response_var FactorC \
  --top_k 10 \
  --large_n_threshold 2000
```

Pass 0 が生成した config を使う場合:

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --config output/titanic/run_v1/analysis_config.json
```

| オプション | 既定値 | 説明 |
| :--- | :--- | :--- |
| `--run-id` | （なし） | 指定時は `<--output_dir>/run_<prefix>/` に隔離（`prefix` = 解決後 `run_id` の先頭16文字。未指定時は入力から算出したハッシュの先頭16文字）。`auto` は JST タイムスタンプに展開される |
| `--vars` | （全変数） | 分析対象カテゴリ変数（2変数または3変数をカンマ区切りで指定） |
| `--freq` | `Freq` | 度数列名（存在しない場合は1行=1件としてカウント） |
| `--response_var` | （なし） | 3次元以上でCramér's Vを算出するための応答変数。指定時は「予測側水準の組み合わせ × 応答変数」の2次元表へ畳み込んで全体効果量を算出する |
| `--base_model` | `M1` | 局所セル診断の基準モデル（M1: 相互独立モデル 〜 M9: 飽和モデル） |
| `--top_k` | 10 | Top-K 表示件数（効果比またはScore統計量上位セル） |
| `--large_n_threshold` | 2000 | 大規模データモード切替閾値（N > 2,000 で Effect 優先 Dual-Filter を適用） |
| `--config` | （なし） | Pass 0 で生成された `analysis_config.json` パス |
| `--help` | - | CLI ヘルプを表示 |
| `--help_stats` | - | 統計指標ガイドを表示 |

※ `--input` が無い場合は R 組み込みの `HairEyeColor` データセットを使用する。
※ 本スキルは **2元表または3元表（2変数または3変数）** を対象とします。4変数以上を分析する場合は、Pass 0 にて次元削減・層別化・3変数への絞り込みを行ってください。
※ `--response_var` は `--vars` に含める。未指定または算出不可の場合、Cramér's Vは未算出理由付きで記録される。

### Pass 2: AI 考察生成（本スキル）

Pass 1 が生成した `evidence_results.json` を読み込み、以下の **日本語エグゼクティブ・サマリー** を `executive_summary.md` として生成する。

**AI プロンプト指示**:

あなたは **計量薬理学・医療統計の専門家** です。`evidence_results.json` を入力として受け取り、以下の4節構成で日本語考察を執筆してください。

#### 節1: 全体的な関連性の評価（モデル選択BIC + 全体効果量）

- **重要: 見出しには必ず `####` (H4) を使用してください。**
- 冒頭で主要結論、実務上の意味、解釈保留の有無を先に記述
- 最良モデル（`models.best_model_id`、例: 均一連関M8、飽和M9）と相互独立M1との明示式BICの差を明示
- `effects.primary_metric`（Cramér's V）の数値を明示し、Cohen基準（>0.1小, >0.3中, >0.5大）で実質的意義を評価
- Cramér's V は全体効果量であり、個々のセルへ割り付ける指標ではないことを明示
- 対象次元数と変数名を明記

#### 節2: 局所セル診断の4軸評価（Effect / Evidence / Influence / Stability）

- **重要: 見出しには必ず `####` (H4) を使用してください。**
- 旧セルScore（$r^2 - k \ln N$）が大標本でのエビデンス飽和や局所LRT乖離により廃止された背景に言及
- 4軸フレームワークの定義を解説：
  - **Effect（実質的効果量）**: 標本数 $N$ に不変な局所効果比 $\log(O/E)$ および標準化差 $e_i$。大標本における最優先の意思決定根拠。
  - **Evidence（証拠強度）**: 標本数 $N$ に比例して増大する検定統計量（Leverage補正Score統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}$）および局所対数P値。
  - **Influence（構造影響度）**: モデル適合に対するセルの梃子力（Hat行列対角成分 $h_{ii}$）。
  - **Stability（数値的安定性）**: ゼロセルや過大レバレッジを隔離（`REGULAR` vs `QUARANTINED`）。
- 正常セル（REGULAR）の比率を記載

#### 節3: 多次元交互作用の解釈（層別エビデンスと条件付き割合差）

- **重要: 見出しには必ず `####` (H4) を使用してください。**
- `cells.top_k_data` に含まれる **上位セル**（局所効果比 $\log(O/E)$ または Score統計量順）を具体的数値付きで記述
- **レイアウト**: セル一覧は長文の連続を避け、読みやすい **Markdown表**（`| 変数 | 観測 | 期待 | log(O/E) | Score統計量 | Leverage | 診断状態 |`）で整列させる
- 応答変数 `response_var` がある場合、`posterior.conditional_differences` から層別の条件付き生存率や層間差（平均、95%信用区間、優位確率）を比較・考察

#### 節4: 結論と実務的示唆

- **重要: 見出しには必ず `####` (H4) を変えずに使用してください。**
- 分析全体の要約（2〜3文）
- 実務・学術的に重要な発見の強調
- 欠損、スパースセル、過剰水準、集約、サンプルサイズに由来する限界
- 次アクション（再分類、層別、追加確認、報告上の注意点）

**禁止事項**:

- 英語での考察出力（数式・変数名を除く）
- 旧エビデンススコア（$r^2 - k \ln N$）を主たる根拠として使用すること
- P値のみを根拠として効果の大きさを論じること
- 2次元データとして3次元データを解釈すること
- 時間順序や介入情報がない結果から因果を断定すること

#### 大規模データモード（N > 1,000 の場合）
`large_sample_mode` が `true` の場合、以下を必ず考察に含めること：

- Cramér's V の値と Cohen 基準による評価を冒頭に明示
- 検定統計量（Score統計量やP値）の肥大化に惑わされず、**標本数不変の Effect 軸（$\log(O/E)$、割合差）を最優先として実質的意義を判断する Dual-Filter ルール**を明記
- 100倍拡大等で検定統計量が巨大化しても、効果量が同一であることを対比

### Pass 2.5: 品質確認

Pass 2 の後、必要に応じて `quality_check.md` を `executive_summary.md` と同じ run 出力ディレクトリに保存する。

**確認項目**:

- `executive_summary.md` が結論、根拠、限界、解釈保留、次アクションを含む。
- 効果量（Effect）、検定統計量（Evidence）、構造影響度（Influence）、安定性（Stability）を読み分けている。
- 旧エビデンススコアを根拠としていない。
- 大標本効果、スパースセル、過剰水準、集約による情報損失を必要に応じて明示している。
- `evidence_results.json`、Top-K表、`dt_table.html`、`dashboard.html`予定の図表と本文が矛盾していない。
- 重大な未解決事項がある場合は完了扱いにせず、ブロッカーまたは解釈保留として報告する。

### Pass 3: ダッシュボード生成

`dashboard.html` は **`evidence_results.json` と同じ `run_<prefix>/` ディレクトリ**（`run_output_dir_from_root` と同じ規則）に出力する。Pass 1 と同じ **out_root** を `--output_dir` に渡す（Rmd の `params$output_dir` は out_root のまま、HTML の保存先だけが `run_<prefix>/` 配下になる）。

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R \
  --output_dir ./skill_out/vcd_bayesian/
```

プレビュー専用（Pass 2 省略）:

```bash
Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R \
  --output_dir ./skill_out/vcd_bayesian/ \
  --no-require-pass2
```

| フラグ / `dashboard.Rmd` パラメータ | 既定 | 説明 |
| :--- | :--- | :--- |
| `--no-require-pass2` | （指定しない） | 指定時のみ `executive_summary.md` なしでレンダー（プレビュー専用） |
| `require_pass2`（Rmd） | `TRUE` | `render_dashboard.R` では既定で `TRUE`。上記フラグで `FALSE` になる |

## 確認ゲート

- 別データの解析を続ける場合は **`--run-id`** で `run_<prefix>/` を分けるか、`--output_dir` 自体を変えて上書きを避ける。`vcd-categorical-analysis` の成果物を参照する場合は、同スキルの現行レイアウト `<out>/run_<first16>[_N]/` を使う。
- `output_dir` に既存の `evidence_results.json` / `dashboard.html` がある場合、上書き実行の可否を確認する。
- `require_pass2 = FALSE` で Pass 3 を先行する場合、プレビュー目的であることを確認し、本番成果物に使わないことを明示する。

## 生成されるファイル

| 出力 | 説明 |
| :--- | :--- |
| `run_meta.json` | Pass 1 時に `run_<prefix>/` に出力。`out_root` は `--output_dir`、`run_output_dir` は当該 `run_<prefix>/`（`.agents/shared/run_scope.R` の `write_run_meta`） |
| `evidence_results.json` | `provenance/input_summary/models/effects/cells/posterior` の4軸セル診断モジュール構造（Pass 1） |
| `dt_table.html` | 列フィルタ付きインタラクティブDTテーブル（+青/−赤色分け）（Pass 1）。`evidence_results.json` と同じ **`run_<prefix>/` 成果ディレクトリ**に保存される（`selfcontained` 時は同隣に補助ファイルが増える場合あり） |
| `executive_summary.md` | AI日本語エグゼクティブサマリー（Pass 2） |
| `quality_check.md` | AIレビュー・指標解釈・図表整合・解釈保留の品質確認（Pass 2.5） |
| `dashboard.html` | Top-K＋折りたたみ全テーブル＋用語解説統合HTMLダッシュボード（Pass 3）。**`run_<prefix>/` 直下**（`dt_table.html` と同階層） |

## アンチパターン対策

| # | アンチパターン | 対策 |
|---|-------------|------|
| A | 2次元への固執 | 次元数を `dim(table)` で自動判定、常に Poisson GLM を使用 |
| B | レンダリングパス失敗 | Pass 3 は `render_dashboard.R` を使い、リポジトリルートを `knit_root_dir` に固定する |
| C | 英語のみ出力 | すべての出力（ラベル・UI・考察）を日本語にデフォルト設定 |
| D | Pass 2 を飛ばして Pass 3 のみ実行 | 既定 `require_pass2 = TRUE` で `executive_summary.md` 必須。意図的プレビューのみ `FALSE` |
| E | レビュー過剰主張 | `quality_check.md` でP値・検定統計量偏重、因果断定、効果比と検定統計量の混同、図表矛盾を確認 |

## 連携スキル

- **前処理**: `vcd-categorical-analysis` （残差分析・モザイクプロット）
- **レポート**: `vcd-categorical-reporting` （AI判断レポート生成）
