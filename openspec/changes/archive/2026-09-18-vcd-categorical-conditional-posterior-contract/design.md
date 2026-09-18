## Context

提案の背景は[proposal.md](proposal.md)を参照する。現行エンジンはDirichlet drawから両方向の条件付き確率を生成するが、出力は平均・標準偏差に限られる。既存Serializerは結合確率・成果物識別子の整合だけを検査し、JSON SchemaとDashboardのデータ契約は条件付きETIを表現しない。

## Goals / Non-Goals

**Goals:**

- 条件付き事後を丸め前drawから完全に要約し、数学的に妥当な不変量を実行時とテストで共有する。
- Interface 3.0を保った加法的JSON契約として、serializer、Schema、表形式出力へ一貫して伝播する。
- 主解析事前分布を多項 Jeffreys（$\alpha = 0.5$）、対照感度分析を一様事前（$\alpha = 1.0$）に固定入替えし、成果物内に自己記述的メタデータを保持する。
- 結合確率、対数乖離、感度分析の既存出力を回帰保護する。

**Non-Goals:**

- Canonical CLI・Pass 0 provenance 境界構造の変更。
- 任意の事前分布ファミリやハイパーパラメータを外部から動的指定する拡張（主 $\alpha=0.5$、対照 $\alpha=1.0$ の固定入替に限定）。
- draw数や実務差閾値の外部動的拡張。
- Dashboardのレイアウト・図表追加（Change 3で実施）。
- 生drawの保存または新規R依存関係の導入。

## Decisions

### 1. 実行モード境界の一意化（Serializer は Canonical 専用）

`serialize_interface_v3()` は canonical 成果物をディスクへ書き出す専用関数として扱い、`execution_mode = "canonical"` のみを受け入れる。`development` はインメモリ計算パスに限定し、JSON、CSV、`run_<signature>` ディレクトリ、Dashboard を作成せず、Serializer を呼び出さない。

さらに、canonical 専用化に伴い、`analysis_signature`、`input_sha256`、`config_sha256` のフォールバック代替生成（digest による自動補填）を廃止し、これらが 64 桁の有効な SHA-256 文字列として渡されていることを必須検証する（NULL や不正値は即時停止）。
ここで、JSON の `provenance.config_sha256` は Canonical Core で再検証済みの `canonical_config_sha256` を格納する互換フィールドである。Serializer は Core から渡された値の 64 桁 SHA 形式と非空を検証して記録し、Serializer 内部に自己比較用の第 2 引数は増設しない。Pass 0 承認ハッシュと最終生成 JSON の `provenance.config_sha256` の完全一致は、E2E / 回帰テストで検証する。

### 2. 主解析事前分布の変更と自己記述的メタデータ（統計的意味論の非後方互換性）


分割表の主解析（Primary Analysis）における事前分布として、従来の Bayes-Laplace 一様事前分布（$\alpha = 1.0$）に代わり、**多項 Jeffreys 事前分布（$\alpha = 0.5$）** を正本・既定値として採用する。対照となる事前感度分析（Sensitivity Analysis）には、一様事前分布（$\alpha = 1.0$）を採用する。

これはスキーマ構造上は加法的互換であるが、事後平均、中央値、ETI幅、局所乖離等のすべての数値的意味を変える「統計的意味論における非後方互換な変更」である。成果物が自己記述的に主解析事前を明示できるよう、`posterior.prior_specification` に以下を記録する：

```json
"prior_specification": {
  "family": "symmetric_dirichlet",
  "alpha": 0.5,
  "role": "primary",
  "name": "jeffreys"
}
```

感度分析側にも `sensitivity_alpha: 1.0` を保持する。主解析事前分布が異なる成果物同士を同一推定量として直接比較してはならない境界を Interface reference および Dashboard Consumer 契約に明記する。

#### 既存の canonical signature / canonical_config_sha256 仕様に従う整合

主事前を $\alpha = 1.0$ から $\alpha = 0.5$ に変更することに伴い、正本仕様（`canonical_config_sha256` に事前分布パラメータを含める）に従って、canonical 実行時テンプレート（`templates/analysis.R`）やテストでの設定ハッシュ・署名照合は `alpha = 0.5` を一貫して渡して算出・照合する。これは新たな境界追加ではなく、既存の canonical signature Requirement の実装トレーサビリティとして担保される。


#### 数学的・理論的根拠の適正な記述

1. **フィッシャー情報行列に基づくパラメータ変換不変性（Invariance under Reparameterization）**:
   多項分布 $y \sim \text{Multinomial}(N, \boldsymbol{\pi})$（$\sum_{k=1}^K \pi_k = 1$）において、フィッシャー情報行列 $I(\boldsymbol{\pi})$ の行列式は $|I(\boldsymbol{\pi})| \propto \prod_{k=1}^K \pi_k^{-1}$ となる。これより Jeffreys の客観事前分布は一意に導出される：
   $$p(\boldsymbol{\pi}) \propto |I(\boldsymbol{\pi})|^{1/2} = \prod_{k=1}^K \pi_k^{-1/2} = \text{Dirichlet}\left(\frac{1}{2}, \frac{1}{2}, \dots, \frac{1}{2}\right)$$
   単体上で平坦な一様分布（$\alpha = 1.0$）は非線形パラメータ変換により測度が歪むのに対し、Jeffreys 事前分布は情報幾何学的な体積要素（リーマン計量）として定義されるため、座標変換に関して不変な性質を持つ。

2. **疎セルにおける平滑化量の違い**:
   観測度数 0 または極小度数の疎セルにおいて、一様事前分布（$\alpha = 1.0$）は全セルに仮想度数 1 を均等配分するため平滑化量が大きくなる。対称 Dirichlet（$\alpha = 0.5$）はゼロ・疎セルへの仮想度数が一様事前より小さく、平滑化量の異なる比較可能な主解析を提供する。
   ※本Changeでは全 estimand における唯一最適性や、安全性評価での上方バイアス改善の一般的一律保証までは主張せず、客観的数理事実としての座標変換不変性と平滑化量の差異に根拠を限定する。

3. **感度分析の対照設定**:
   主解析を Jeffreys（$\alpha = 0.5$）とした上で、対照として一様事前分布（$\alpha = 1.0$）を比較することで、「平坦な事前分布を与えた場合に稀少セルや信用区間幅がどの程度引きずられるか」を客観的に評価する。

### 3. practical_delta の入力境界契約と数理的定義

実務差閾値超過確率 `prob_practical_delta` の estimand を、**「絶対結合確率乖離の閾値超過事後確率」** として一貫して定義する：
$$P\left(\left|\pi_{ij} - \pi_{i+}\pi_{+j}\right| > \delta \;\middle|\; \text{data}\right)$$

- **入力境界バリデーション**:
  - 設定で `practical_delta` が未指定（NULL）の場合: 計算を抑止し、`practical_delta` および `prob_practical_delta` は `null` を出力する。
  - 有効値: $0 < \delta < 1$ の数値。
  - 不正値: 0、負値、1以上、非数値、非有限値（NA/NaN/Inf）が渡された場合は、入力境界エラーとして **fail-fast** で即時停止する。`null` への暗黙フォールバックは禁止する。

### 4. 検証境界（Verification Seam）と許容差定数の二層分離

数値検証を「Engine 内部の数学的不変量検証」と「Serializer 出力直前の丸め後整合性検証」の2層に厳密に分離する。

1. **Engine 内部検証 (`dirichlet_posterior.R`)**:
   - モンテカルロ draw 用の生データから直接計算する。
   - 各 draw $s$ における条件付き確率和: $\left|\sum_j \pi_{j|i}^{(s)} - 1.0\right| < 10^{-12}$、$\left|\sum_i \pi_{i|j}^{(s)} - 1.0\right| < 10^{-12}$
   - 丸め前の条件付き事後平均の総和: $\left|\sum_j E[\pi_{j|i}] - 1.0\right| < 10^{-12}$、$\left|\sum_i E[\pi_{i|j}] - 1.0\right| < 10^{-12}$
   - 確率範囲・順序整合: $0 \le \text{q025} \le \text{median} \le \text{q975} \le 1$、$\text{eti\_width} = \text{q975} - \text{q025} \ge 0$
   - **非線形要約の除外**: 中央値（median）および分位点（q025, q975）は成分ごとの非線形要約であり、一般に総和 1 を保存しないため、総和 1 検証を要求しない。

2. **Serializer 出力検証 (`serializer_v3.R`)**:
   - JSON 出力直前に丸め済み数値（6桁等）の整合性を検証する。
   - 出力直前の丸め済み結合確率和: $\left|\sum_{i,j} \pi_{ij} - 1.0\right| \le (R \times C) \times 10^{-6}$
   - 出力直前の丸め済み条件付き事後平均和: $\left|\sum_j \text{cond\_row\_prob\_mean} - 1.0\right| \le C \times 10^{-6}$
   - 成果物間識別キー整合性（`analysis_signature`, `run_id`, 全セルキー集合）および `provenance$execution_mode == "canonical"` を検証し、違反時は `SCHEMA_INVARIANT_VIOLATION` で即時停止する。

#### 固定する丸め規則と許容差定数

| 対象フィールド | 出力桁数 | 丸め前許容差（Engine） | 丸め後許容差（Serializer） |
| :--- | :---: | :---: | :---: |
| 結合確率・条件付き確率要約 (`mean`, `sd`, `median`, `q025`, `q975`, `eti_width`) | **6桁** | $10^{-12}$ | 水準数 $K \times 10^{-6}$ |
| 局所対数乖離要約 (`log_divergence_*`) | **4桁** | $10^{-12}$ | 順序・有限値のみ（和の制約なし） |
| 方向確率・実務差確率 (`prob_dir_positive`, `prob_practical_delta`) | **4桁** | $10^{-12}$ | $[0, 1]$ 範囲のみ |

### 5. Departure from Independence / Uncertainty Ranking / Sensitivity Analysis の JSON 契約固定

下流の Dashboard が純粋な Consumer として動作できるよう、以下のデータ構造・型・ソート規則を機械可読契約として確定する：

1. **Posterior Departure from Independence (`posterior.cell_posteriors[*]`)**:
   - `log_divergence_mean` (number, 4桁): 局所対数乖離の事後平均
   - `log_divergence_median` (number, 4桁): 局所対数乖離の事後中央値
   - `log_divergence_q025` (number, 4桁): 95% ETI 下限
   - `log_divergence_q975` (number, 4桁): 95% ETI 上限
   - `log_divergence_eti_width` (number, 4桁): 信用区間幅
   - `prob_dir_positive` (number, 4桁, 0〜1): 正方向への事後確率 $P(D > 0)$
   - `prob_practical_delta` (number, 4桁 または null): 実務差閾値超過確率（未指定時は null）

2. **Uncertainty Ranking の決定論的契約**:
   - ランキング評価指標: `prob_eti_width`（結合確率の95% ETI幅）
   - ソート順序: `prob_eti_width` 降順 $\to$ タイ時は `observed` 昇順 $\to$ タイ時は `row_level` 昇順 $\to$ `col_level` 昇順

3. **Prior Sensitivity Analysis (`posterior.sensitivity_analysis`)**:
   - `primary_alpha` (number = 0.5, Jeffreys)
   - `sensitivity_alpha` (number = 1.0, Bayes-Laplace)
   - `max_absolute_mean_diff` (number)
   - `max_median_shift` (number)
   - `max_eti_width_diff` (number)
   - **二値判定・主観的警告の廃止**: 恣意的な閾値判定を排除するため、boolean フラグ `is_sensitive` および `0.05` 閾値による Serializer の自動警告ロジックは廃止し、客観的な数値要約のみを出力する。
   - `cell_comparisons[*]`: `row_level`, `col_level`, `primary_median`, `sensitivity_median`, `median_shift`（絶対値差）, `primary_eti_width`, `sensitivity_eti_width`, `eti_width_difference`（**符号付き**: 感度側幅 - 主側幅）

### 6. 計算資源に関する実測と検証記録

モンテカルロ draw は既定 10,000 回とする。代表的な小規模・中規模表で計算が問題なく完了することを確認し、観測した実行時間とメモリ上の注意を検証記録に残す。新しい実行時上限や fail-fast 機構の導入は本 Change の対象外とする。

## Risks / Trade-offs

- [主解析の Jeffreys 移行に伴う既存テスト期待値の変更] → Task 0 で既存テストの実測確認と基線整理を行い、主解析 $\alpha=0.5$ 基準の期待値へ計画的に移行する。
- [疎な表で分母が数値的に不安定] → 入力境界のゼロマージン拒否を前提に、有限値・確率範囲を検証して不正な値を出力しない。
- [丸め後の表示値が1から乖離] → 検証対象と表示対象を分離し、仕様とDashboard説明に丸めの扱いを記載する。
- [主事前が異なる過去成果物との誤比較] → `posterior.prior_specification` を新設し、Dashboard Consumer において異なる主事前の成果物の直接比較を禁止する境界を明記する。
- [同じ`two-way-evidence-analysis`仕様をDashboard changeも変更] → 条件付き事後changeを先に完了し、その後Dashboard changeのdeltaをrebase相当で再読して整合させる。

## Migration Plan

1. **Task 0 (改定前の基線実測確認)**: 既存のテストを個別Rプロセスで実測実行し、未実行のまま「赤状態」と決めつけず、失敗の原因（Change 1契約同期不足か期待値更新か）を実測ログでinventory化する。
2. **Task 1 (Change artifact の整合化)**: proposal、design、delta spec、tasks を本改定方針で整合させる。
3. **Task 2 (数理エンジンの契約実装)**: Jeffreys $\alpha=0.5$、感度 $\alpha=1.0$、条件付き完全要約、`practical_delta` 入力検証・計算、二層検証 Engine 側を実装。
4. **Task 3 (Serializer・Schema・Consumer 契約)**: canonical 専用 Serializer、`prior_specification`、丸め後許容差検証、警告廃止を実装。
5. **Task 4 (テストと性能境界)**: 固定 seed 再現性、疎セル比較、不正入力 fail-fast、Serializer 違反検知、ピークメモリ・時間実測。
6. **Task 5 (受入判定と引継ぎ)**: Schema validation、`git diff --check`、Dashboard Change への引継ぎ記録作成。
