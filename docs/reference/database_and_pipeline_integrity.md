# データ整合性とパイプライン運用の技術基盤

本ドキュメントは、リアルワールドデータ（RWD）およびデータベース（MySQL / PostgreSQL / BigQuery 等）と統計分析パイプラインを結合する際の**データ整合性原則（Data Integrity）**、ゼロ度数の取り扱い、および決定論的再現性（Reproducibility）の技術基準を記述する。

---

## 1. データ型と制約の基本原則

統計分析における誤った型変換や暗黙の欠損値補完は、モデル推定の歪みや計算停止を引き起こす。以下のデータ型原則を厳格に適用する。

| データ種別 | DB 推奨型 | R 推奨型 | 制約・バリデーション規則 |
| :--- | :--- | :--- | :--- |
| **カテゴリ変数** | `VARCHAR(64)` / `ENUM` | `factor` | 欠損値は明示的コード化（`"Unknown"` 等）、前後の空白文字トリム |
| **度数・カウント** | `INT UNSIGNED` / `BIGINT` | `integer` / `numeric` | **非負整数制約**（$\mathrm{Freq} \ge 0$）、`NA` 不可 |
| **タイムスタンプ** | `DATETIME(6)` / `TIMESTAMP` | `POSIXct` | **日本標準時（JST: Asia/Tokyo）** に明示的統一 |
| **識別子・ハッシュ** | `CHAR(64)` / `VARCHAR(64)` | `character` | 小文字英数字（SHA-256 等） |

---

## 2. ゼロ度数の分類と数学的処理

多次元クロス集計表において度数 0 のセルが出現した場合、その発生原因によって推論上の取り扱いを厳格に区別する。

```
                       [ ゼロ度数セルの分類 ]
                                 │
                 ┌───────────────┴───────────────┐
                 ▼                               ▼
     【サンプリング・ゼロ】              【構造的ゼロ】
     (Sampling Zero)                 (Structural Zero)
   ・標本サイズの制約による偶然の 0    ・物理的・医学的に発生不能な 0
   ・真の期待度数 mu > 0             ・真の期待度数 mu = 0 (生起確率 0)
   ・対数線形回帰で通常推定可能        ・該当セルを除外または制約付加
   ・ベイズ Dirichlet 事後推論で補正   ・自由度 (df) の明示的削減
```

### 2.1 サンプリング・ゼロ（Sampling Zeros）
- **定義**: 生起確率 $\theta_i > 0$ であるが、抽出標本のサイズ $N$ が有限であるために偶然 $y_i = 0$ となったセル。
- **処理**:
  - 対数線形モデルの反復推定（IRLS）において、周辺合計が正であれば最尤推定量 $\hat{\mu}_i > 0$ が一意に存在する。
  - 局所対数効果比 $\log(O_i / E_i)$ では、観測値 $O_i = 0$ の対数は未定義となるため、ラプラス・スムージング（Laplace Smoothing: $O_i + 0.5$ 等）を適用するか、または **ベイズ Dirichlet 事後推論の事後平均 $\mathbb{E}[\theta_i \mid \mathbf{y}] = \frac{\alpha_i}{\alpha_0 + N} > 0$** を用いて比率を評価する。
  - Stability 軸では $E_i < 5.0$ と判定され、自動的に `QUARANTINED`（隔離・参考値）としてマークされる。

### 2.2 構造的ゼロ（Structural Zeros）
- **定義**: 物理的、生物学的、または制度的に生起確率が厳密に 0 であるセル（例：「男性の妊娠・分娩」「小児の前立腺癌」など）。
- **処理**:
  - 構造的ゼロセルは、ポアソン対数線形モデルの推定対象から完全に除外する（不完全分割表の対数線形モデル）。
  - 分割表の総セル数 $K$ およびモデル残差自由度 $\nu$ から該当セル数を明示的に減算し、BIC の複雑度ペナルティを再計算する。
  - 構造的ゼロが未定義のまま放置されている場合、Pass 0（コンサルテーション）において分析保留（HOLD）とする。

---

## 3. 出力隔離と決定論的再現性（Deterministic Isolation）

分析結果の追跡可能性（Provenance）と再現性（Reproducibility）を担保するため、実行環境は以下の隔離アーキテクチャに従う。

### 3.1 run_id 規約と決定論的ハッシュ
すべての分析実行は、一意の `run_id` によって管理される：
1. **明示的指定**: `--run-id <slug>` が与えられた場合は、サニタイズされた文字列を採用。
2. **自動ハッシュ生成**: 入力 CSV ファイルの SHA-256 チェックサム値の先頭 16 文字を抽出し、`run_<hash16>` を自動生成する。
   同一入力データに対しては常に決定論的に同一の `run_id` が割り当てられ、異なるデータセット間で出力ファイルの上書き衝突が防止される。

### 3.2 ディレクトリ階層規約
分析成果物は、親ディレクトリ `<output_dir>` の直下に `run_<run_id>/` の形で厳密に隔離・出力される：

```
skill_out/vcd_analysis/
└── run_a1b2c3d4e5f67890/
    ├── run_meta.json              # 実行メタ情報（日時、スクリプト、Git SHA）
    ├── evidence_results.json      # 構造化計算結果
    ├── dt_table.html              # インタラクティブ4軸診断テーブル
    ├── executive_summary.md       # AI 専門的考察サマリー (Pass 2)
    └── dashboard.html             # 統合 HTML ダッシュボード (Pass 3)
```

---

## 4. タイムゾーンとロケールの一貫性

医療・リアルワールドデータ分析において、タイムスタンプの曖昧性は監査上の重大な不適合となる。
- すべての日時記録は **日本標準時（JST / Asia/Tokyo, UTC+9）** に統一し、ISO 8601 拡張形式（例：`2026-09-06T22:30:00+09:00`）で出力する。
- 数値出力における桁区切り（カンマ）や小数点（ピリオド）は、システムロケールに依存しないよう明示的フォーマット関数（`sprintf`, `format(big.mark=",")`）を介して処理する。

---

## 参考文献
- Agresti, A. (2013). *Categorical Data Analysis* (3rd ed.). John Wiley & Sons. (Chapter 10: Models for Matched Pairs and Incomplete Tables).
- Bishop, Y. M., Fienberg, S. E., & Holland, P. W. (1975). *Discrete Multivariate Analysis: Theory and Practice*. MIT Press.
- ISO 8601: Data elements and interchange formats – Information interchange – Representation of dates and times.
