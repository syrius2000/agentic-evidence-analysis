# VCD Analysis ↔ Reporting インターフェース契約

interface_version: "2.1"

## 出力ディレクトリ

常に `<out>/run_<first16>[_N]/`。`first16` は要求run IDの先頭16文字、`_N` は既存runとのcollision suffix。

## run_meta.json と2-pass再開identity

| フィールド | 型 | 説明 |
| :--- | :--- | :--- |
| `run_id` | string | collision suffixを反映した実run ID |
| `requested_run_id` | string | collision前の元の明示run ID（サニタイズ後） |
| `analysis_signature` | string | 入力内容SHA-256、vars順序、freqから決定的に算出するSHA-256 |
| `run_state` | string | `allocated`、`profile_complete`、`render_in_progress`、`render_complete` で進捗を表す |

Pass 2は、`requested_run_id` と `analysis_signature` が要求値と完全一致し、`run_state` が `profile_complete` で、`data_profile.json` があり `categorical_results.json` がないprofile-only runだけを継続する。候補内の隠しclaim directoryを原子的に取得した後、同じ条件を再検証し、成立時だけrender開始前に `render_in_progress` へ更新する。全成果物の生成成功後だけ `render_complete` へ更新する。claim失敗・残置、再検証失敗、途中render、既存 `run_meta.json` にidentity fieldやstateがないrun、不明stateは安全側で再開しない。入力内容、vars順序、freqのいずれかが異なる場合も再開せず、collision suffix付きの新runへ出力する。`render_config.json` はPass 1後に決める入力なのでsignatureには含めない。

run directoryの確保はatomic reservationとする。out rootを先に作り、候補directoryは `dir.create(..., recursive = FALSE)` が成功した時だけ予約済みとし、既存または同時実行による衝突時は次のsuffix候補を確保する。

`--data` 省略時だけ内蔵 `HairEyeColor` を使う。存在しない `--data` を明示した場合は、signature計算とout root・run directory作成より前にエラー停止する。

## Pass 1 出力: data_profile.json
## Pass 2 出力: data_profile_post.json

| フィールド | 型 | 説明 |
| :--- | :--- | :--- |
| n_dimensions | int | 変数の数（2 or 3） |
| variables | object | 変数名をキー、{n_levels, levels} を値 |
| total_cells | int | 全セル数 |
| total_cells_2way_marginal | int | 2-way 周辺表のセル数 |
| n_nonzero_cells | int | Freq > 0 のセル数 |
| sparsity_ratio | float | n_nonzero_cells / total_cells |
| warning | string | ゼロセル等の警告メッセージ（無ければ null） |

## Pass 2 入力: render_config.json

| フィールド | 型 | 既定値 | 説明 |
| :--- | :--- | :--- | :--- |
| collapse_below_n | int | 0 | この Freq 以下のセルを集約（0=集約しない） |
| max_levels_per_var | int | 999 | 各変数の最大水準数（超過分は集約） |
| strata_to_render | array(string) | [] | gt マトリックスを生成する層（空=全層） |
| gt_matrix_vars | array(int) | [1, 2] | マトリックスの行・列に使う変数インデックス |
| plot_mode | string | "auto" | "auto" / "always" / "residual_only" |

※ R側は未知のキーを無視し、不正な型は既定値にフォールバックする（`validate_config`）。

## Pass 2 出力ファイル規約

| ファイル名パターン | 形式 | 生成元 | 消費先 |
| :--- | :--- | :--- | :--- |
| `data_profile.json` | JSON | analysis (Pass 1) | reporting |
| `data_profile_post.json` | JSON | analysis (Pass 2) | reporting |
| `summary_{data}.json` | JSON | analysis (Pass 2) | reporting |
| `residuals_{data}.csv` | CSV | analysis (Pass 2) | reporting |
| `residuals_{data}_significant.csv` | CSV | analysis (Pass 2) | reporting |
| `matrix_marginal_{data}.html` | gt HTML | analysis (Pass 2) | reporting |
| `matrix_{data}_{layer}.html` | gt HTML | analysis (Pass 2) | reporting |
| `dt_residuals_{data}.html` | DT HTML | analysis (Pass 2) | reporting |
| `mosaic_{data}.png` | PNG | analysis (Pass 2) | reporting |
| `assoc_{data}.png` | PNG | analysis (Pass 2) | reporting |
| `cotab_{data}.png` | PNG | analysis (Pass 2) | reporting |

## summary_*.json スキーマ

```json
{
  "interface_version": "2.1",
  "test_used": "string",
  "models_tested": ["string"],
  "deviance_main": "number",
  "df_main": "integer",
  "deviance_2way": "number",
  "df_2way": "integer",
  "p_value_main_vs_2way": "number",
  "cramers_v_marginal": "number",
  "top_residuals_main": [{"cell": "string", "res": "number"}],
  "top_residuals_2way": [{"cell": "string", "res": "number"}],
  "strata_summary": {
    "strata_var": "string",
    "n_strata": "integer",
    "max_abs_res_per_stratum": {"layer_name": "number"},
    "cramers_v_per_stratum": {"layer_name": "number"},
    "n_significant_cells_5pct": "integer",
    "n_significant_cells_1pct": "integer",
    "total_cells": "integer"
  }
}
```

## 変更ルール

- analysis 側が出力フォーマットを変更する場合、interface_version をインクリメントすること。
- reporting 側は interface_version を確認し、非互換の場合はユーザーに警告すること。
