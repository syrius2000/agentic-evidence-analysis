---
name: vcd-categorical-analysis
description: 名義カテゴリカル変数（クロス表 2-way/3-way）の独立性検定・残差分析を行う R パイプライン。Pass 1 で `data_profile.json`、Pass 2 で `summary_*.json`・残差CSV・HTML・PNGを生成し、後続の `vcd-categorical-reporting` へ接続する。
license: MIT
metadata:
  version: "2.1"
---

**IRON LAW**: Pass 2（`--render`）を実行する前に、必ず Pass 1 の `data_profile.json` を確認し、過大セル数や過剰水準に対する `render_config.json` を決める。

名義カテゴリカル変数（最大 3-way）の独立性検定（Poisson GLM）および残差の可視化を行うためのパイプライン。

> [!WARNING]
> `templates/report.Rmd` はレガシー版（v1.x）です。新規分析は `analysis.R` を用いた2パス方式（Pass 1 + Pass 2）が推奨されます。

## 前提条件
- `references/dependencies.md` の R パッケージが導入済みであること。
- 入力データは UTF-8 でエンコードされた CSV（集計・非集計問わず）を想定。非集計データの場合は、指定された変数を用いて自動集計される。

## 実行手順（2パス方式）

### Pass 1: プロファイリング
まずは軽量なプロファイルを実行し、次元数・水準数・セル数を `data_profile.json` として生成する。

```bash
Rscript .agent/skills/vcd-categorical-analysis/templates/analysis.R \
  --profile \
  --data your_data.csv \
  --vars "var1,var2" \
  --freq "Freq" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260417
```

- **`--run-id`（任意）**: 指定すると成果物は `<--out>/runs/<id>/` に隔離され、別データを続けて解析しても既定パスを上書きしません。`auto` を渡すと JST のタイムスタンプが ID になります。
- **`run_meta.json`**: Pass 1 時に `runs/<id>/` に出力される。`out_root` は `--out` および `--config` の `output_dir` で決まる出力ベース（`runs` のひとつ上）と一致する。

※ `--data` が無い場合は、内蔵の `HairEyeColor` データセットを使用する。
※ 非集計データ等で `--freq` の列が見つからない場合は自動集計し、`Freq` として扱われる。

### Pass 2: 本生成
`data_profile.json` を読んだ AI が `render_config.json` を生成したのち、本生成を実行する。

```bash
Rscript .agent/skills/vcd-categorical-analysis/templates/analysis.R \
  --render \
  --config render_config.json \
  --data your_data.csv \
  --vars "var1,var2" \
  --freq "Freq" \
  --label "mydata" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260417
```

## 確認ゲート

- 連続して別データを解析する場合は **`--run-id`** で出力サブフォルダを分ける（または `--out` をデータごとに変える）。`--out` の直下だけを使い続けると上書きされる。
- `--out` が既存ディレクトリの場合、既存成果物（HTML/PNG/CSV）を上書きしてよいか確認する。
- `render_config.json` で `collapse_below_n` や `max_levels_per_var` を適用する場合、情報損失の許容可否を確認する。

## 生成されるファイル

| 出力 | 説明 |
| :--- | :--- |
| `data_profile_post.json` | `config` の集約ルール適用後のプロファイル情報 |
| `summary_{label}.json` | モデル比較、逸脱度、層ごとの残差統計などのサマリー |
| `residuals_{label}.csv` | 全残差データ |
| `residuals_{label}_significant.csv` | 有意なセル上位（絶対値降順） |
| `matrix_*.html` | `gt` を用いた残差マトリックス表 |
| `dt_residuals_{label}.html` | `DT` によるソート可能・インタラクティブな残差テーブル |
| `mosaic_{label}.png` 等 | モザイクプロット等の静的画像（`plot_mode` による） |

## 連携スキル

- **後続**: `vcd-categorical-reporting` が本スキルの出力を読み取り、AI判断レポートを生成する。
- **契約**: `references/interface.md` を参照（interface version: 2.1）。
