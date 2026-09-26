---
name: comparative-design-analysis
description: "Use when performing design-aware comparative inference (matched pairs, matched sets, IPTW, and person-time incidence rates) with separated point estimation, uncertainty, and direction."
license: MIT
metadata:
  author: agentic-evidence-analysis
  version: "1.0"
---

# Comparative Design Analysis

比較デザインに応じて推論器を選択する。Pass 0 のルーティング結果と設計情報を確認し、独立群用の Beta-Binomial 推論器へ非独立データを渡してはならない。

## 1:1 Matched Pairs

- 入力は 1 行 1 ペアとし、`pair_id`、`target_outcome`、`reference_outcome` を含める。各アウトカムは 0/1 とする。
- `.agents/shared/matched_pair_dirichlet.R` の `run_matched_pair_dirichlet()` を使う。
- 4 セル $(n_{11}, n_{10}, n_{01}, n_{00})$ に対して Jeffreys 型事前分布 $(0.5, 0.5, 0.5, 0.5)$ の多項 Dirichlet 事後分布を用いる。
- RD は $p_{10}-p_{01}$、周辺リスクは $p_T=p_{11}+p_{10}$ と $p_R=p_{11}+p_{01}$ である。
- 主たるオッズ比 `odds_ratio` は不一致ペア比較（McNemar オッズ比）$OR_{\rm discordant}=p_{10}/p_{01}$ であり、観察研究マッチドペアにおいて無条件の因果的治療効果と解釈してはならない。
- ペア内の転帰一致連関は副次的な記述量 `intra_pair_association_or`（$OR_{\rm assoc}=p_{11}p_{00}/(p_{10}p_{01})$）として完全に分離して報告する。
- 有限時の事後期待値はモンテカルロ平均ではなく Dirichlet 解析的厳密期待値（$E[OR_{\rm discordant}]=(n_{10}+0.5)/(n_{01}-0.5)$）を用いる。
- 出力は `inferential_semantics="posterior"`、`estimate.source="posterior_median"`、`interval.method="posterior_eti"` とする。

## 1:k Matched Sets

- 入力は縦持ちデータフレーム（1 行 1 被験者）とし、`subject_id`、`set_id`、`treatment`（1/0）、`outcome`（1/0）、および任意の数値共変量列を含める。`subject_id` は全セット間で一意（重複なし）でなければならず、非復元マッチングを保証する。
- 各セットには処置群（treatment=1）が厳密に 1 名、対照群（treatment=0）が $k_j \ge 1$ 名含まれること（固定・可変比率、非復元マッチング）。
- `.agents/shared/matched_set_inference.R` の `run_matched_set_inference()` を使う。
- 標的推定量は ATT（Average Treatment Effect on the Treated、`estimand = "ATT"`）であり、観測標本から解析的に点推定値を算出する（$\hat{p}_{T,obs}=\frac{1}{J}\sum Y_{Tj}$、$\hat{p}_{R,obs}=\frac{1}{J}\sum \bar{Y}_{Rj}$、`estimate.source="observed_sample_estimate"`）。
- 生の記述的被験者数・イベント数は `matched_set.raw_target_counts` および `matched_set.raw_reference_counts` に保持し、対照群の推定量セマンティクスは `reference_cohort$estimate_semantics = "att_set_weighted_risk"`（`events`, `total` は `null`）として分離する。
- 不確実性評価はマッチドセット単位の原子的なクラスタブートストラップ（Atomic Cluster Bootstrap）により行い、`inferential_semantics="bootstrap"`、`interval.method="bootstrap_percentile"` とする。ブートストラップスコープは固定マッチドセット条件付き（`conditional_on_fixed_matched_sets`）であり、マッチング推定量自体の再抽出ではない（Abadie & Imbens 2008 は nearest-neighbor matching estimator に対して通常の bootstrap の妥当性を一般に仮定できないことを示している）。
- ゼロ除算 RR ポリシー：観測対照群リスクが 0 の場合は RR 推定値・区間・平均および RR 由来精度指標（`precision_metrics$log_rr_interval_width` 等）を完全に `null`（`diagnostic = "ZERO_REFERENCE_RISK"`）とする。観測対照群リスクが正であってもブートストラップ反復内に $p_R^* = 0$ が 1 回でも発生した場合は保守的ポリシーにより RR 区間および RR 精度指標を `null` とし、`rr_bootstrap_diagnostics`（`defined_replicates`, `undefined_replicates`, `defined_fraction`）を記録する（RD を主対比とする）。
- マッチ後共変量バランスは、ATT 重み（$w_{Tj}=1, w_{Rj\ell}=1/k_j$）に基づく第二中心モーメント分散による標準化平均差（SMD）として記録する。ゼロ分散時はスケール不変判定（$s_{pooled}=0$）により、平均差が 0 であれば `smd = 0.0`（`ZERO_VARIANCE_ZERO_DIFFERENCE`）、平均差が非ゼロ（完全分離等）であれば `smd = null`（`ZERO_VARIANCE_NONZERO_DIFFERENCE`）に分類する。事前（unmatched）SMD はマッチド専用推論器では報告しない。

## IPTW (Inverse Probability of Treatment Weighting)

- 入力は縦持ちデータフレーム（1 行 1 被験者）とし、`treatment`（1/0）、`outcome`（1/0）、およびプロペンシティスコア（PS）推定用の数値共変量列を指定する。
- `.agents/shared/iptw_inference.R` の `run_iptw_inference()` を使う。
- 標的エスティマンドは ATE（`estimand = "ATE"`）または ATT（`estimand = "ATT"`）を指定する。
- 重み計算式：
  - **ATE**: 非安定化 $w_i = \frac{A_i}{e_i} + \frac{1-A_i}{1-e_i}$、安定化 $sw_i = A_i \frac{\bar{A}}{e_i} + (1-A_i)\frac{1-\bar{A}}{1-e_i}$
  - **ATT**: 非安定化 $w_i = A_i + (1-A_i)\frac{e_i}{1-e_i}$、安定化（Marginal Odds Scaled）$sw_i = A_i + (1-A_i)\frac{e_i}{1-e_i}\frac{\bar{A}}{1-\bar{A}}$
- 処置群別のパーセンタイル刈り込み（既定: `truncation = c(0.01, 0.99)`）に対応し、極端な重みによる分散爆発を抑制する。
- 有効標本サイズは Kish の近似式（$ESS_g = (\sum_{i \in g} w_i)^2 / \sum_{i \in g} w_i^2$）により処置群・対照群の双方で算出し記録する。
- 不確実性評価は患者レベルの有復元抽出ブートストラップ（Patient-level Bootstrap）により行い、各反復内で PS モデル（ロジスティック回帰）を再推定（`iptw_mode = "refit_ps"`）して重み再計算と刈り込みを行うことで、PS 推定の確率的変動を統合する。
- 観測標本から算出した点推定値を `estimate.source = "observed_sample_estimate"` として報告し、`inferential_semantics = "bootstrap"`、`interval.method = "bootstrap_percentile"` を出力する。
- 重み付け前後の共変量バランス（加重平均・加重分散に基づく SMD）および PS 分布の重なり（Positivity / Overlap 診断）を記録する。
- PS は `ps_boundary = c(lower, upper)`（既定 `c(1e-6, 1 - 1e-6)`）で有効値を clamp する。raw/effective PS要約、境界、clipping件数を記録し、positivity overlap は raw PS から評価する。
- 入力は1行1被験者である。`subject_id_col` を指定した場合は欠損・重複IDを拒否する。反復測定データは本エンジンへ直接入力しない。
- `max_failure_rate` は公開引数（既定0.05）であり、0以上1未満を指定する。閾値は結果metadataにも保存する。
- evidenceとdraw metadataには同一の重み付け・PS・truncation・ATT scaling・bootstrap clipping・収束閾値の由来を保存する。bootstrap refitで生じたPS clippingは、発生反復数、上下clipping合計、最大反復内割合を記録する。
- ATT の `stabilization = TRUE` は `att_scaling_mode = "marginal_odds_scaled"` と組み合わせる。conventional ATT は `stabilization = FALSE` とする。
- raw events/total は `iptw.raw_patient_counts` にだけ保持し、weighted cohort riskにはraw numerator/denominatorを付与しない。レポートは bootstrap を percentile interval / bootstrap support fraction と表示し、posterior / ETI 用語を使用しない。
- design-aware report overrideではevidenceのraw countsを表示元とし、入力aggregate countsとの不一致は`EVIDENCE_REPORT_PROVENANCE_MISMATCH`で拒否する。ESSはRaw descriptive Nと分けて表示し、Fisher exact compatibilityは既定で出力しない。小セル抑制は本契約で採用していない。
- bootstrapの有復元抽出による同一subject再出現は仕様どおりであり、pseudo-replication警告として扱わない。
- **数理境界原則（Task 10.12）**: IPTW の加重計算によって得られる非整数擬似度数（pseudo-counts）を、独立群用の Beta-Binomial や多項 Dirichlet 事後推論器に渡してはならない（整数前提違反として即座に `NON_INTEGER_COUNT` で拒絶される）。

## Person-Time Incidence Rates (人年発症率)

- 入力は処置群および対照群のイベント数と観察人年/人月（`events`, `exposure`）とする。
- `.agents/shared/person_time_rate.R` の `run_person_time_rate()` を使う。
- Jeffreys 非正格事前分布 $p(\lambda) \propto \lambda^{-1/2}$ を用いた共役 Gamma-Poisson 率モデル（事後分布 $\text{Gamma}(x_g + 0.5, \text{rate}=T_g)$）により事後ドローを生成。
- 出力セマンティクスは `inferential_semantics = "posterior"`、`estimate.source = "posterior_median"`、`interval.method = "posterior_eti"`。
- 率差（IRD: Incidence Rate Difference）および率比（IRR: Incidence Rate Ratio）を共通コントラストエンジンより導出。
- 参照群イベントゼロ（$x_R = 0$）時は、事後中央値・ETIを報告しつつ `mean = null`、`mean_is_finite = false`、`incidence_rate_ratio$diagnostic = "ZERO_REFERENCE_EVENTS"` を確定。
- 単位は人年（person-years）または人月（person-months）を明記し、一定ハザード性および同一被験者内再発イベントの無クラスタ性を制限事項として付記する。

## 共通境界

- 結果を因果的優越や自動意思決定として解釈しない。
- 生のドローは既定でメモリ内のみとし、`persist_raw_draws=TRUE` を明示したときだけ返す。
- この共有推論器は run ディレクトリを直接作成しない。成果物を永続化する呼び出し側は `evidence-run-layout` の `run_<canonical_id>[_N]/` と shared `run_scope.R` を使用する。
- 実行中にパッケージを導入しない。不足した依存関係は明示的に停止する。
