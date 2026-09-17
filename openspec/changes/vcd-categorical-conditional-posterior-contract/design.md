## Context

提案の背景は[proposal.md](proposal.md)を参照する。現行エンジンはDirichlet drawから両方向の条件付き確率を生成するが、出力は平均・標準偏差に限られる。既存Serializerは結合確率・成果物識別子の整合だけを検査し、JSON SchemaとDashboardのデータ契約は条件付きETIを表現しない。

## Goals / Non-Goals

**Goals:**

- 条件付き事後を丸め前drawから完全に要約し、数学的に妥当な不変量を実行時とテストで共有する。
- Interface 3.0を保った加法的JSON契約として、serializer、Schema、表形式出力へ一貫して伝播する。
- 結合確率、対数乖離、感度分析の既存出力を回帰保護する。

**Non-Goals:**

- Canonical CLI・Pass 0 provenance境界の変更。
- 事前分布種類、draw数、実務差閾値の拡張。
- Dashboardのレイアウト・図表追加。
- 生drawの保存または新規R依存関係の導入。

## Decisions

### 丸め前のdrawを唯一の数理正本とする

条件付き確率、分位点、ETI幅および総和検証は、JSON用に丸める前のdraw・要約値から求める。表示値の総和は丸めのため厳密に1でない場合がある。

代替案としてJSON出力値から検証する方法は、丸め誤差を数理エラーとして誤検出するため採用しない。

### 総和検証をdrawと平均へ限定する

各drawとその線形要約である平均は条件付き分布として総和1を保つ。中央値・分位点は非線形な成分別要約であり、総和1を保つ保証がないため、範囲・順序・ETI幅のみを検証する。

中央値を正規化して総和を1に補正する案は、各セルの事後要約を改変し、ETIとの整合性を失うため採用しない。

### JSONは既存セル事後オブジェクトを加法的に拡張する

既存のcell posteriorに、行条件付き・列条件付きの要約フィールドを加法的に追加する。水準名は既存の`row_level`・`col_level`を正本とし、重複した識別子配列を設けない。

追加フィールドの命名規約：
- 行条件付き \(P(B \mid A)\): `cond_row_prob_mean`（既存）, `cond_row_prob_sd`, `cond_row_prob_median`, `cond_row_prob_q025`, `cond_row_prob_q975`, `cond_row_prob_eti_width`
- 列条件付き \(P(A \mid B)\): `cond_col_prob_mean`（既存）, `cond_col_prob_sd`, `cond_col_prob_median`, `cond_col_prob_q025`, `cond_col_prob_q975`, `cond_col_prob_eti_width`

### Departure from Independence / Uncertainty Ranking / Sensitivity Analysis の JSON 契約固定

下流の Dashboard が純粋な Consumer として動作できるよう、以下のデータ構造・型・ソート規則を機械可読契約として確定する：

1. **Posterior Departure from Independence (`posterior.cell_posteriors[*]`)**:
   - `log_divergence_mean` (number): 局所対数乖離の事後平均
   - `log_divergence_median` (number): 局所対数乖離の事後中央値
   - `log_divergence_q025` (number): 95% ETI 下限
   - `log_divergence_q975` (number): 95% ETI 上限
   - `log_divergence_eti_width` (number): 信用区間幅
   - `prob_dir_positive` (number, 0〜1): 正方向への事後確率 \(P(D > 0)\)
   - `prob_practical_delta` (number または null): 実務差閾値超過確率（未指定時は null）

2. **Uncertainty Ranking の決定論的契約**:
   - ランキング評価指標: `prob_eti_width`（結合確率の95% ETI幅）
   - ソート順序: `prob_eti_width` 降順 $\to$ タイ時は `observed` 昇順 $\to$ タイ時は `row_level` 昇順 $\to$ `col_level` 昇順

3. **Prior Sensitivity Analysis (`posterior.sensitivity_analysis`)**:
   - `primary_alpha` (number = 1.0)
   - `sensitivity_alpha` (number = 0.5)
   - `max_absolute_mean_diff` (number)
   - `max_median_shift` (number)
   - `max_eti_width_diff` (number)
   - ※恣意的な閾値による自動重要度判定を排除するため、booleanフラグ `is_sensitive` は廃止（数値要約のみ保持）
   - `cell_comparisons[*]`: `row_level`, `col_level`, `primary_median`, `sensitivity_median`, `median_shift`（絶対値差）, `primary_eti_width`, `sensitivity_eti_width`, `eti_width_difference`（感度側幅 - 主側幅）


### 先行Change 1の実行モード契約を成果物JSONへ同期する

Change 1（`vcd-categorical-provenance-boundary-hardening`）で規定された実行モード（`execution_mode: "canonical"`）を、`serializer_v3.R` の `provenance_block` に正式に追加し、JSON成果物にも実行モードを永続化する。


### Schema、serializer、テストを同一変更単位にする

Schemaで型・必須性・null表現を規定し、serializerでcross-field不変量を検証し、fixtureを通じてreader互換性を確認する。加法的更新が不可能と分かった場合は実装を停止し、Interface version変更を含む計画更新と再承認を求める。


## Risks / Trade-offs

- [疎な表で分母が数値的に不安定] → 入力境界のゼロマージン拒否を前提に、有限値・確率範囲を検証して不正な値を出力しない。
- [丸め後の表示値が1から乖離] → 検証対象と表示対象を分離し、仕様とDashboard説明に丸めの扱いを記載する。
- [既存readerが新しいフィールドを解釈しない] → 加法的拡張に留め、既存fixtureの回帰とSchema検証を実施する。
- [同じ`two-way-evidence-analysis`仕様をDashboard changeも変更] → 条件付き事後changeを先に完了し、その後Dashboard changeのdeltaをrebase相当で再読して整合させる。

## Migration Plan

1. 固定seedの小規模表・疎な表で新しい要約と不変量のテストを追加する。
2. エンジン、serializer、Schema、表形式出力を同一変更で更新する。
3. 既存のInterface・Dirichlet・入力境界テストを実行し、JSON fixtureを必要最小限更新する。
4. 失敗時は、このchangeで追加した条件付きフィールドとテストだけを戻し、既存の結合確率・対数乖離・感度分析を変更しない。
