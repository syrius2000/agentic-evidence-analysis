# 実装計画書: Section 9 Design-Aware Inference Engine (1:k Matched Sets)

- **計画書番号**: `implementation_plan_005_0923`
- **作成日時**: 2026-09-23 16:15 (JST)
- **対象ブランチ**: `feat/comparative-evidence-reporting-v3`
- **基準コミット（HEAD）**: `7987cb6e1f46a999964c9faabb5a62b17ffec95d`
- **対象 OpenSpec**: `openspec/changes/comparative-evidence-reporting-v3/` (Section 9)

---

## 1. 概要と目的

本計画書は、OpenSpec `comparative-evidence-reporting-v3` の **Section 9: Design-Aware Inference Engine: 1:k Matched Sets** を実装するための詳細設計および検証計画である。

傾向スコアマッチング等の観察研究・RWD分析において広く用いられる 1:k（固定比率または可変比率、非復元抽出）マッチドセットデータに対し、**処置群における平均処置効果（ATT: Average Treatment Effect on the Treated）** を標的推定量（Estimand）とする推論器 `.agents/shared/matched_set_inference.R` を新規構築する。

本推論器は、観測標本から算出される正確な ATT 点推定値（`estimate.source = "observed_sample_estimate"`）と、マッチドセット単位の非復元ペア関係を保った原子的なクラスタブートストラップ（Atomic Cluster Bootstrap）による不確実性評価（`inferential_semantics = "bootstrap"`, `interval.method = "bootstrap_percentile"`）を厳密に分離・統合する。

---

## 2. 数理仕様と設計原則

### 2.1 データ構造と入力契約

- **入力形式**: 縦持ちデータフレーム（Long-format `data.frame`）。各行が 1 被験者に対応。
  - `set_id`: マッチドセット識別子（$j = 1, \dots, J$）
  - `treatment`: 処置群フラグ（1: Target / 処置群, 0: Reference / 対照群）
  - `outcome`: 二値アウトカム（0 または 1）
  - 共変量列（任意）: バランス評価対象の数値または二値変数
- **構造的制約（Fail-Fast 検証）**:
  1. 各セット $j$ に処置群被験者（Target, $A=1$）が**厳密に 1 名**存在すること。
  2. 各セット $j$ に対照群被験者（Reference, $A=0$）が **$k_j \ge 1$ 名**存在すること（$k_j$ は可変または固定）。
  3. 各セット内で処置群・対照群の重複や非二値アウトカム、欠測値（NA）が存在しないこと。

### 2.2 標的推定量（ATT）と観測標本点推定式（Task 9.2）

マッチドセット数（＝処置群患者数）を $J$、各セット $j$ の対照群被験者数を $k_j$ とする。
セット $j$ の処置群アウトカムを $Y_{Tj} \in \{0, 1\}$、対照群被験者 $\ell$ のアウトカムを $Y_{Rj\ell} \in \{0, 1\}$（$\ell = 1, \dots, k_j$）とする。

セット $j$ における対照群の平均アウトカムを $\bar{Y}_{Rj} = \frac{1}{k_j} \sum_{\ell=1}^{k_j} Y_{Rj\ell}$ と定義する。
観測標本における ATT 推定値は以下で算出される：

1. **処置群リスク**:
   $$\hat{p}_{T,obs} = \frac{1}{J} \sum_{j=1}^J Y_{Tj}$$
2. **対照群（セット加重）反事実リスク**:
   $$\hat{p}_{R,obs} = \frac{1}{J} \sum_{j=1}^J \bar{Y}_{Rj} = \frac{1}{J} \sum_{j=1}^J \left( \frac{1}{k_j} \sum_{\ell=1}^{k_j} Y_{Rj\ell} \right)$$
3. **リスク差（Risk Difference: RD）**:
   $$\hat{RD}_{obs} = \hat{p}_{T,obs} - \hat{p}_{R,obs}$$
4. **相対リスク（Relative Risk: RR）**:
   $$\hat{RR}_{obs} = \begin{cases} \frac{\hat{p}_{T,obs}}{\hat{p}_{R,obs}} & (\hat{p}_{R,obs} > 0) \\ \text{NA} & (\hat{p}_{R,obs} = 0) \end{cases}$$

これらの点推定値は、`estimate.source = "observed_sample_estimate"` として確定的に格納される。

### 2.3 原子的なクラスタブートストラップ（Atomic Cluster Bootstrap, Task 9.1）

マッチング構造（共変量がマッチした 1:k のセット関係）を保つため、被験者単位ではなく**マッチドセット単位**での復元抽出を行う。

1. 観測された $J$ 個のマッチドセットのインデックス集合 $\{1, 2, \dots, J\}$ に対し、復元抽出（with replacement）により $J$ 個のインデックス $j^{*(b)}_1, \dots, j^{*(b)}_J$ をサンプリングする。
2. ブートストラップ反復 $b$（$b = 1, \dots, B$）におけるリスク推定値：
   $$p_T^{*(b)} = \frac{1}{J} \sum_{m=1}^J Y_{T, j^{*(b)}_m}$$
   $$p_R^{*(b)} = \frac{1}{J} \sum_{m=1}^J \bar{Y}_{R, j^{*(b)}_m}$$
   $$RD^{*(b)} = p_T^{*(b)} - p_R^{*(b)}$$
   $$RR^{*(b)} = \frac{p_T^{*(b)}}{\max(p_R^{*(b)}, 10^{-15})}$$
3. 得られた $B$ 個のドロー $\{p_T^{*(b)}\}_{b=1}^B, \{p_R^{*(b)}\}_{b=1}^B$ から、ブートストラップ・パーセンタイル信頼区間（`interval.method = "bootstrap_percentile"`）、方向性支持率（`bootstrap_support_fraction_rd_gt_zero`）、および実用領域支持率（`practical_region_support`）を算出する。

### 2.4 マッチ後共変量バランス評価（SMD: Standardized Mean Difference, Task 9.4）

共変量 $X$（連続変数または二値変数）について、マッチ後のバランスを評価する。
セット $j$ の処置群共変量を $X_{Tj}$、対照群のセット平均を $\bar{X}_{Rj} = \frac{1}{k_j} \sum_{\ell=1}^{k_j} X_{Rj\ell}$ とする。

1. **処置群平均**: $\bar{X}_T = \frac{1}{J} \sum_{j=1}^J X_{Tj}$
2. **対照群加重平均**: $\bar{X}_{R,weighted} = \frac{1}{J} \sum_{j=1}^J \bar{X}_{Rj}$
3. **対照群非加重平均（マッチ前/単純平均）**: $\bar{X}_{R,raw} = \frac{1}{\sum k_j} \sum_{j=1}^J \sum_{\ell=1}^{k_j} X_{Rj\ell}$
4. **標準化分母（Pooled SD または 処置群 SD）**:
   - 処置群の標本標準偏差: $s_T = \sqrt{\frac{1}{J-1} \sum_{j=1}^J (X_{Tj} - \bar{X}_T)^2}$
   - 対照群の標本標準偏差: $s_R = \sqrt{\frac{1}{N_R-1} \sum_{i \in R} (X_{Ri} - \bar{X}_{R,raw})^2}$
   - 統合標準偏差: $s_{pooled} = \sqrt{\frac{s_T^2 + s_R^2}{2}}$
   - 本推論器では、疫学・RWDの標準慣例（Austin 2009）に準拠し、$s_{pooled}$（処置群・対照群の統合SD）を分母とした $SMD = \frac{\bar{X}_T - \bar{X}_{R,weighted}}{s_{pooled}}$ を算出する（分母が 0 の場合は 0.0）。マッチ前の単純 SMD も併記して改善度（Balance improvement）を可視化する。

### 2.5 マッチドセットメタデータ（Task 9.3）

- `matching_ratio`:
  - `type`: `"fixed"`（全セットで $k_j$ が同一）または `"variable"`（セット間で $k_j$ が変動）
  - `min_controls`: $\min(k_j)$
  - `max_controls`: $\max(k_j)$
  - `mean_controls`: $\frac{1}{J} \sum k_j$
- `caliper`: 設定値（数値）または `null`
- `replacement`: `false`（非復元マッチング）
- `patient_counts`:
  - `target_matched`: $J$
  - `reference_matched`: $\sum k_j$
  - `target_discarded`: 除外処置群数（入力時指定、既定 0）
  - `reference_discarded`: 除外対照群数（入力時指定、既定 0）

---

## 3. スキーマ拡張設計

### 3.1 `schemas/comparative-evidence-v1.json`

`properties` 内に `matched_set` オブジェクトを追加：

```json
"matched_set": {
  "type": "object",
  "required": [
    "set_count",
    "matching_ratio",
    "replacement",
    "patient_counts"
  ],
  "properties": {
    "set_count": { "type": "integer", "minimum": 1 },
    "matching_ratio": {
      "type": "object",
      "required": ["type", "min_controls", "max_controls", "mean_controls"],
      "properties": {
        "type": { "type": "string", "enum": ["fixed", "variable"] },
        "min_controls": { "type": "integer", "minimum": 1 },
        "max_controls": { "type": "integer", "minimum": 1 },
        "mean_controls": { "type": "number", "minimum": 1.0 }
      }
    },
    "caliper": { "type": ["number", "null"] },
    "replacement": { "type": "boolean" },
    "patient_counts": {
      "type": "object",
      "required": ["target_matched", "reference_matched"],
      "properties": {
        "target_matched": { "type": "integer", "minimum": 1 },
        "reference_matched": { "type": "integer", "minimum": 1 },
        "target_discarded": { "type": "integer", "minimum": 0 },
        "reference_discarded": { "type": "integer", "minimum": 0 }
      }
    },
    "covariate_balance": {
      "type": ["array", "null"],
      "items": {
        "type": "object",
        "required": ["covariate", "smd_matched"],
        "properties": {
          "covariate": { "type": "string" },
          "target_mean": { "type": "number" },
          "reference_weighted_mean": { "type": "number" },
          "smd_unmatched": { "type": ["number", "null"] },
          "smd_matched": { "type": "number" }
        }
      }
    }
  }
}
```

### 3.2 `schemas/comparative-draws-v1.json`

`properties` 内に `matched_set_metadata` オブジェクトを追加（任意項目）：

```json
"matched_set_metadata": {
  "type": ["object", "null"],
  "properties": {
    "set_count": { "type": "integer" },
    "matching_ratio_type": { "type": "string", "enum": ["fixed", "variable"] }
  }
}
```

---

## 4. 変更対象ファイル一覧

| 操作 | ファイルパス | 役割・変更内容 |
| :--- | :--- | :--- |
| **[NEW]** | `.agents/shared/matched_set_inference.R` | 1:k マッチドセット推論器の実装本体（検証、ATT 点推定、クラスタブートストラップ、SMD） |
| **[NEW]** | `tests/test_matched_set_inference.R` | 1:k マッチドセット推論器の包括的単体・境界・シード再現性テスト |
| **[MODIFY]** | `schemas/comparative-evidence-v1.json` | `matched_set` オブジェクト定義の追加 |
| **[MODIFY]** | `schemas/comparative-draws-v1.json` | `matched_set_metadata` の追加 |
| **[MODIFY]** | `.agents/skills/comparative-design-analysis/SKILL.md` | 1:k Matched Sets の仕様・利用指針・境界の追記 |
| **[MODIFY]** | `tests/test_comparative_schemas.R` | 1:k マッチドセット成果物の Draft-7 スキーマ検証および異常値拒絶テスト |
| **[MODIFY]** | `tests/run_regression_suite.R` | 公式回帰テストスイートへの `test_matched_set_inference.R` 登録 |
| **[MODIFY]** | `openspec/changes/comparative-evidence-reporting-v3/tasks.md` | Section 9 のタスク完了チェック |

---

## 5. 段階的実装手順

### フェーズ 1: スキーマ拡張とテスト先行準備（Contract First）

1. `schemas/comparative-evidence-v1.json` に `matched_set` 定義を追加。
2. `schemas/comparative-draws-v1.json` に `matched_set_metadata` 定義を追加。
3. `tests/test_comparative_schemas.R` に 1:k matched set のスキーマ検証と不正値拒絶テストを追加。

### フェーズ 2: 推論器コア実装（`.agents/shared/matched_set_inference.R`）

1. `validate_matched_set_data()`:
   - 縦持ちデータフレームの検証（`set_id`, `treatment`, `outcome` の存在、厳密に1名の処置群、$\ge 1$ 名の対照群、二値アウトカム、NA排除）。
2. `compute_matched_set_att_estimates()`:
   - 観測標本における $\hat{p}_{T,obs}, \hat{p}_{R,obs}, \hat{RD}_{obs}, \hat{RR}_{obs}$ の解析的計算。
3. `compute_covariate_balance()`:
   - マッチ前後の平均値および SMD（標準化平均差）の計算。
4. `sample_matched_set_bootstrap()`:
   - マッチドセット単位の原子的なクラスタブートストラップ復元抽出（行列集計による高速化）。
5. `run_matched_set_inference()`:
   - `compute_comparative_contrasts()` との統合。
   - `inferential_semantics = "bootstrap"`、`estimate.source = "observed_sample_estimate"`、`interval.method = "bootstrap_percentile"` の生成。
   - `evidence` および `draws` オブジェクトの構築。

### フェーズ 3: テストスイート構築（`tests/test_matched_set_inference.R`）

1. **入力バリデーション**:
   - 処置群が 0 名または 2 名以上のセットの拒絶。
   - 対照群が 0 名のセットの拒絶。
   - 非二値アウトカムの拒絶。
   - 欠測値の拒絶。
2. **数理的整合性**:
   - 固定比率（1:2, 1:3 等）および可変比率（1:1〜1:4 混在）での手計算値との完全一致。
   - $k=1$（1:1 マッチ）において、1:1 マッチドペア推論器の周辺リスク点推定値と完全一致することの検証。
   - クラスタブートストラップ反復における周辺リスク範囲が $[0, 1]$ 内に収まることの検証。
3. **共変量バランス（SMD）**:
   - 完全バランス時の SMD = 0.0 検証。
   - 既知の人工データにおける手計算 SMD との完全一致検証。
4. **シード再現性**:
   - 同一シードにおけるドローおよび分位数の完全一致検証。
   - 異シードにおける独立性検証。
5. **ゼロイベント・ゼロ参照群診断**:
   - 処置群 0 イベント、対照群 0 イベント時の安全な挙動確認。

### フェーズ 4: SKILL 文書更新と回帰スイート統合

1. `.agents/skills/comparative-design-analysis/SKILL.md` を更新。
2. `tests/run_regression_suite.R` にテストを登録し、全スイートを実行。
3. `tasks.md` の Section 9 を更新。

---

## 6. 検証手順

```bash
# 1. 1:k matched set 単体テストの実行
Rscript tests/test_matched_set_inference.R

# 2. スキーマ検証テストの実行（純R jsonlite Draft-7）
Rscript tests/test_comparative_schemas.R

# 3. 公式正規回帰テストスイートの全件実行
Rscript tests/run_regression_suite.R

# 4. OpenSpec バリデーション
openspec validate comparative-evidence-reporting-v3 --strict --json

# 5. Git diff 品質検査
git diff --check
```

---

## 7. リスクと対策

1. **計算パフォーマンス（クラスタブートストラップ $B=4000$）**:
   - 各反復でデータフレーム全体を再抽出・集計すると $O(B \cdot N)$ のオーバーヘッドが生じる。
   - **対策**: セット単位の $Y_{Tj}$（長さ $J$ のベクトル）と $\bar{Y}_{Rj}$（長さ $J$ のベクトル）を事前に前処理で事前計算し、ブートストラップ抽出時は `sample.int(J, J, replace = TRUE)` で得た添字ベクトルから `colMeans` または `matrixStats`（標準R `tabulate` 等）を用いて高速集計する。1秒以内で $B=4000$ を完了させる。
2. **対照群ゼロイベント時の RR 計算**:
   - ブートストラップ反復内で $p_R^{*(b)} = 0$ となる場合がある。
   - **対策**: `comparative_contrasts.R` の仕様に準拠し、分母に $10^{-15}$ の微小保護を適用し、パーセンタイル信頼区間が発散・NaN にならないよう保護する。観測標本で対照群が 0 イベントの場合は `rr$estimate$value = NA`、`mean_is_finite = FALSE` とする。

---

## 8. 承認ゲート

本計画書の内容（数理仕様、スキーマ設計、段階的実装手順、検証計画）についてユーザー（Owner）の承認を得た後、フェーズ 1 のスキーマ拡張および実装へ移行する（2026-09-23 16:14 JST 承認済）。

---

## 9. 実施結果

2026-09-23 16:20 (JST) に以下の全項目を実装・検証完了：

1. **Task 9.1**: `.agents/shared/matched_set_inference.R` にて、1:k マッチドセットに対する原子的なクラスタブートストラップ復元抽出（行列集計による高速化）を実装。
2. **Task 9.2**: 観測標本に基づく正確な ATT 点推定式（$\hat{p}_{T,obs}=\frac{1}{J}\sum Y_{Tj}$、$\hat{p}_{R,obs}=\frac{1}{J}\sum \bar{Y}_{Rj}$、$\hat{RD}_{obs}$、$\hat{RR}_{obs}$）を解析的に実装（`estimate.source = "observed_sample_estimate"`）。
3. **Task 9.3**: `matching_ratio`（fixed/variable, min/max/mean controls）、`replacement: false`、`patient_counts` 等のメタデータを `evidence$matched_set` に完全記録。
4. **Task 9.4**: Austin (2009) 準拠の $s_{pooled}$ によるマッチ後共変量バランス（標準化平均差: SMD）およびマッチ前 SMD を算出・記録。
5. **Task 9.5**: `comparative-draws-v1` および `comparative-evidence-v1` に準拠し、`inferential_semantics = "bootstrap"`、`interval.method = "bootstrap_percentile"`、`bootstrap_support_fraction_rd_gt_zero` を出力。
6. **Task 9.6**: `tests/test_matched_set_inference.R`（38/38 PASS）およびスキーマテスト `tests/test_comparative_schemas.R`（41/41 PASS）を完備。
7. **公式回帰スイート**: `tests/run_regression_suite.R` に登録（40/40 PASS）。
8. **SKILL**: `.agents/skills/comparative-design-analysis/SKILL.md` を更新。
9. **Tasks**: `openspec/changes/comparative-evidence-reporting-v3/tasks.md` の Section 9（Tasks 9.1〜9.6）を完了更新。
