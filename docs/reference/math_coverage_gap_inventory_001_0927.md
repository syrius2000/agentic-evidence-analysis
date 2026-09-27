# 数理リファレンス・カバレッジ監査と記載すべき情報

created: 2026-09-27 02:56 (JST)
update: 2026-09-27 02:56 (JST)
author: Cursor (Composer)

本文書は、現行 9 スキルおよび `openspec/specs/`（17 capability）に対し、`docs/reference/` の数理解説が十分かを監査した結果である。
**結論:** 3 次元／2 次元カテゴリカル探索（対数線形・4 軸診断・Dirichlet・CRR）は厚い一方、比較エビデンス・デザイン考慮推論・決定監査・SAS 互換の**専用数理解説が欠落または責務文書への一行要約に留まる**。以下に不足と、新規文書へ記載すべき情報の正本アウトラインを定義する。

> [!NOTE]
> 本ファイルは「これから書くべき数理正本」の受入契約である。実装コードの変更指示ではない。規範的挙動の正本は引き続き `openspec/specs/`。

---

## 1. 監査サマリー

| 判定 | 内容 |
| :--- | :--- |
| **充足** | `vcd-bayesian-evidence-analysis`、`vcd-categorical-analysis`（全体効果量・4 軸・多項 Jeffreys／Dirichlet）、`vcd-categorical-reporting`（`comparative_evidence_math.md`）、`comparative-design-analysis`（`design_aware_inference_math.md`）、Pass 0 の設計境界（責務文書） |
| **部分充足** | `evidence-decision-review`（`skill_responsibilities.md` §3 に原則のみ。式・シナリオ・一次文献なし） |
| **計画中** | Gower／HAC 監査数理（P1）、SAS PROC 互換の許容誤差・未定義契約（P2） |
| **ポータル同期** | `docs/reference/README.md` §4（OpenSpec 17 capability マッピング、P0 反映完了） |

---

## 2. スキル × 数理トピック × 現行カバレッジ

凡例: **C** = 専用章あり / **P** = 責務・ポータルに原則のみ / **M** = 欠落（要新設） / **N** = 数理正本対象外（運用・SAS 構文互換）

| スキル | 中核数理トピック | 現状 | 依拠 Spec（主要） | 現行参照ドキュメント |
| :--- | :--- | :---: | :--- | :--- |
| `vcd-pass0-consultation` | 入力品質・デザイン・ルーティング境界 | P | `pass0-analysis-routing` | `skill_responsibilities.md` §1–2 |
| `vcd-bayesian-evidence-analysis` | M1–M9、明示 BIC、4 軸、Dirichlet、PPC、CRR | C | `three-way-*`, `cell-evidence-*`, `conditional-*`, `multi-baseline-*` | `three_way_models.md`, `stats_bayesian.md`, `stats_categorical.md` |
| `vcd-categorical-analysis` | Cramér's V、Haberman 残差、2D Dual-Filter、多項 Jeffreys | C | `two-way-evidence-analysis` | `stats_categorical.md`, `stats_bayesian.md` |
| `vcd-categorical-reporting` | 独立 Jeffreys Beta-Binomial、RD/RR/E100、reciprocal RD、方向支持、実務領域・U-Grade、ゼロ参照 RR 契約、提示階層 | **C** | `comparative-evidence-reporting` | `comparative_evidence_math.md`（**P0 作成完了**） |
| `comparative-design-analysis` | マッチドペア Dirichlet、マッチドセット bootstrap、IPTW、Gamma-Poisson 人年 | **C** | `comparative-design-inference` | `design_aware_inference_math.md`（**P0 作成完了**） |
| `evidence-decision-review` | 決定ラベル非含有特徴量、Gower、HAC、先例検索、Ledger | **M** | `evidence-decision-consistency` | `skill_responsibilities.md` §3 のみ |
| `questionnaire-batch-analysis` | バッチオーケストレーション（数理は下流スキル依存） | N/P | （実行契約中心） | 責務表のみ |
| `sas-proc-freq` | Pearson / LRT / Fisher / OR・RR・二項 CI、MC（Patefield） | **M**/N | `sas-proc-freq` | なし（スキル文書のみ） |
| `sas-proc-means` | VARDEF、QNTLDEF 1–5、CLASS/FREQ/WEIGHT | **M**/N | `sas-proc-means` | なし（スキル文書のみ） |

横断契約（レイアウト・依存・テーマ）:

| Spec | 数理解説の要否 | 現状 |
| :--- | :--- | :--- |
| `evidence-run-layout` | 低（運用） | ポータル未記載で可。AGENTS 鉄則 3 と重複 |
| `deterministic-r-dependencies` | 低（運用） | 鉄則 1 で十分 |
| `shared-dashboard-presentation` | 中（Zero-External・用語） | README / AGENTS 鉄則 6。数式不要 |
| `pass0-analysis-routing` | 中（デザイン境界） | 責務文書。数式より判定木 |

---

## 3. 欠落の優先度と推奨新規文書

| 優先度 | 推奨ファイル | 主スキル | 状態 | 目的 |
| :---: | :--- | :--- | :---: | :--- |
| **P0** | [`comparative_evidence_math.md`](comparative_evidence_math.md) | `vcd-categorical-reporting` | **完了** | 独立群比較の推定・対比・実務領域・提示階層の正本 |
| **P0** | [`design_aware_inference_math.md`](design_aware_inference_math.md) | `comparative-design-analysis` | **完了** | 非独立デザイン 4 系統の推論契約 |
| **P1** | `evidence_decision_audit_math.md` | `evidence-decision-review` | 未作成 | ラベル非含有距離・クラスタ・先例監査 |
| **P2** | `sas_compatible_summaries.md` | `sas-proc-freq` / `sas-proc-means` | 未作成 | 古典検定・記述統計の互換境界と未定義契約（導出の百科事典化はしない） |
| **P2** | （既存追記）`stats_bayesian.md` に「独立 Beta-Binomial vs 多項 Dirichlet」対照節 | reporting / 2D / 3D | 未着手 | 事前の混同防止 |

ポータル更新（本監査と同時実施）:

- `docs/reference/README.md` — 読解順序・OpenSpec 17 対応・スキル×文書マトリクス・本監査へのリンク
- `AGENTS.md` / リポジトリ `README.md` — 比較・デザイン・監査への導線と不足明示

---

## 4. 記載すべき情報（文書別アウトライン）

### 4.1 `comparative_evidence_math.md`（P0・必須）

#### A. 独立 Jeffreys Beta-Binomial

- 群 $g \in \{T, R\}$: $x_g \sim \mathrm{Binomial}(n_g, p_g)$、主事前 $p_g \sim \mathrm{Beta}(0.5, 0.5)$（Jeffreys）、事後 $\mathrm{Beta}(x_g+0.5, n_g-x_g+0.5)$
- 事前感度: $\mathrm{Beta}(1,1)$、`prior_sensitivity.mode ∈ {zero_cell, off, explicit}`
- **禁止:** IPTW 擬似度数など非整数を本推論器へ投入すること（`NON_INTEGER_COUNT`）
- 多項 Dirichlet（分割表セル同時）との峻別表

#### B. 対比（Contrast）の定義と点推定ソース

| 量 | 定義 | 点推定ソース契約 |
| :--- | :--- | :--- |
| RD | $p_T - p_R$ | Bayes: `posterior_median` / Bootstrap: `observed_sample_estimate` |
| E100 | $100 \times \mathrm{RD}$（`excess_per_100`） | RD から派生。表示再計算禁止 |
| reciprocal RD | $1/|\mathrm{RD}|$（`reciprocal_absolute_rd`） | **二次解釈**。RD 点推定由来。変換ドロー要約ではない |
| RR | $p_T / p_R$ | ゼロ参照時の無限大契約（下記） |
| 方向支持 | $P(\mathrm{RD}>0)$ または bootstrap 支持比率 | 因果優越の禁止 |

- `inferential_semantics` / `interval.method`（`posterior_eti` vs `bootstrap_percentile`）
- 生ドローは ephemeral（`persist_raw_draws = false` 既定）

#### C. reciprocal 状態機械

| `reciprocal_status` | 条件 | 表示契約 |
| :--- | :--- | :--- |
| `STABLE_DIRECTION` | 区間が 0 を跨がない等、安定方向 | Safety: `target_excess→NNH-like` / `reference_excess→NNT-like`；非 Safety: `1/\|RD\|` のみ |
| `SIGN_AMBIGUOUS` | RD 区間が 0 を跨ぐ | 方向ラベル抑制、`— (SIGN_AMBIGUOUS)` 等 |
| `RD_NEAR_ZERO` | 点推定が数値的ゼロ | `reciprocal_absolute_rd = null`、`reciprocal_direction = none` |
| `NOT_INTERPRETABLE` | 解釈不能 | 方向ラベル抑制 |

- **禁止:** 0 跨ぎ RD 区間から contiguous な reciprocal 区間を捏造すること
- **提示階層:** E100（自然単位翻訳）と NNT/NNH-like（reciprocal）は**別列**。結合列「100人あたり差 / NNT」は廃止済み契約

#### D. 実務領域・U-Grade（独立章必須）

- 領域確率 $q_T, q_N, q_R$（`target_excess`, `practical_neutral`, `reference_excess`）、$\sum q = 1$
- $C = \max(q_T, q_N, q_R)$ → U0–U3；`primary_delta = null` なら U-Grade `NONE`、着色無効
- **直交性:** U-Grade ≠ ESS/区間幅 ≠ 臨床重症度 ≠ 方向支持
- 着色は実務領域セル限定（行全体・RD/E100/RR への伝播禁止）— presentation 契約だが概念分離の一部

#### E. ゼロ参照 RR

- $x_R = 0, x_T > 0$ ⇒ 理論 $E(\mathrm{RR})=\infty$；中央値・分位は報告可、`mean = null`, `mean_is_finite = false`、`ZERO_REFERENCE`

#### F. 多重性・探索的免責

- バッチ PT スクリーニングで FWER/FDR 制御を主張しない
- 非有意 ≠ 同等

#### G. 一次文献（追記候補）

- Jeffreys prior / Beta-Binomial 共役
- Newcombe / リスク差区間の文脈（実装が ETI か bootstrap かを明示）
- Cook & Sackett 系 NNT の**因果前提**と本リポジトリの「like」ラベル方針
- ASA 2016（既存インデックスと相互リンク）

#### H. Spec シナリオとのトレーサビリティ

`openspec/specs/comparative-evidence-reporting/spec.md` の各 Requirement / Scenario を節末に対応表で列挙すること。

---

### 4.2 `design_aware_inference_math.md`（P0・必須）

#### A. 共通インターフェース

- Draw / Evidence 標準化（`comparative-draws-v1` 等）
- Domain ≠ Design ≠ Inference の再掲と、独立群エンジンへの依存データ投入禁止

#### B. 1:1 マッチドペア（Dirichlet）

- 不一致セル $(n_{11}, n_{10}, n_{01}, n_{00})$、Jeffreys 型 $(0.5)^4$
- $\mathrm{RD} = p_{10}-p_{01}$、周辺 $p_T=p_{11}+p_{10}$, $p_R=p_{11}+p_{01}$
- 不一致 OR の **Dirichlet 解析的厳密期待値**（モンテカルロ平均禁止の契約）
- ゼロ除算 RR ポリシー（観測 / bootstrap 反復）

#### C. 1:k マッチドセット

- セット単位クラスタブートストラップ
- セット重み付き ATT 推定量
- `inferential_semantics = bootstrap`

#### D. IPTW

- 再現内 PS 再適合、腕別重み打ち切り
- **擬似度数を Beta-Binomial / Dirichlet に渡さない**（`NON_INTEGER_COUNT`）

#### E. 人年発症率（Gamma-Poisson）

- Jeffreys 非正格 $p(\lambda)\propto\lambda^{-1/2}$、事後 $\mathrm{Gamma}(x_g+0.5,\ \mathrm{rate}=T_g)$
- IRD / IRR と共通コントラストエンジン

#### F. 一次文献候補

- Breslow & Day / matched case-control
- Rosenbaum & Rubin（PS）、IPTW 標準文献
- Gamma-Poisson / person-time 疫学標準（Rothman 等）

---

### 4.3 `evidence_decision_audit_math.md`（P1）

- 特徴量: `core` vs `delta_dependent`；決定ラベル非含有の定義
- Gower 非類似度、凍結スケール範囲、overflow / `NOT_COMPARABLE`
- HAC・クラスタ安定性（patient-level bootstrap co-clustering の `ASSESSED` / `NOT_ASSESSED`）
- 先例検索は助言のみ；自動規制決定の禁止
- Append-only Ledger の監査意味（暗号詳細は附属で可）
- 一次文献: Gower (1971)、Kaufman & Rousseeuw 等

---

### 4.4 `sas_compatible_summaries.md`（P2）

- **目的:** 互換対象と非対象の境界、未定義理由コード（`status_reason`）、許容誤差
- PROC FREQ: Pearson / LRT / 連続性補正、Fisher（2×2 vs RxC）、Patefield MC、WEIGHT ZEROS 非対応の明示
- PROC MEANS: VARDEF、QNTLDEF 1–5
- **書かないこと:** SAS 全構文の再実装百科、CMH 等対象外機能の擬似解説

---

### 4.5 既存文書への最小追記（P2）

| 既存ファイル | 追記内容 |
| :--- | :--- |
| `stats_bayesian.md` | 「分割表多項 Dirichlet」vs「独立 2 群 Beta-Binomial」vs「人年 Gamma-Poisson」対照表 |
| `skill_responsibilities.md` | §3 末に本監査・将来の P0 文書へのリンク；提示階層（12 列）の一行契約 |
| `spec_supersession_map.md` | `2026-09-27-comparative-dashboard-metric-hierarchy-v1` → `comparative-evidence-reporting` |

---

## 5. OpenSpec 17 capability と数理文書の目標マッピング

| OpenSpec capability | 目標リファレンス（現状 → 目標） |
| :--- | :--- |
| `cell-evidence-interpretation` | `three_way_models.md` / `stats_bayesian.md`（充足） |
| `conditional-rank-reproducibility` | `three_way_models.md` §7（充足） |
| `conditional-rate-view` | `stats_bayesian.md`（充足） |
| `multi-baseline-cell-diagnostics` | `three_way_models.md`（充足） |
| `three-way-model-assessment` | `three_way_models.md`（充足） |
| `three-way-validation-cases` | `three_way_models.md` / `stats_categorical.md`（充足） |
| `three-way-dashboard-reporting` | `advanced_analysis.md` / `skill_responsibilities.md`（充足） |
| `two-way-evidence-analysis` | `stats_categorical.md` / `stats_bayesian.md`（充足） |
| `comparative-evidence-reporting` | **欠 → `comparative_evidence_math.md`** |
| `comparative-design-inference` | **欠 → `design_aware_inference_math.md`** |
| `evidence-decision-consistency` | **欠 → `evidence_decision_audit_math.md`** |
| `pass0-analysis-routing` | `skill_responsibilities.md`（原則充足） |
| `shared-dashboard-presentation` | 運用・AGENTS 鉄則 6（数式不要） |
| `evidence-run-layout` | AGENTS 鉄則 3（数式不要） |
| `deterministic-r-dependencies` | AGENTS 鉄則 1（数式不要） |
| `sas-proc-freq` | **欠 → `sas_compatible_summaries.md`（境界中心）** |
| `sas-proc-means` | **欠 → `sas_compatible_summaries.md`（境界中心）** |

---

## 6. 受入チェックリスト（将来の数理文書執筆時）

1. **Data / Provenance First:** 表示層で再導出禁止の量は canonical フィールド名で固定する
2. **概念分離:** Domain / Design / Inference / Contrast / Region / Precision / Decision を節見出しに反映する
3. **Zero-Guesswork:** 状態コード・列名・バッジはコード／Spec から転記する
4. **Test Matrix:** 各主要 Scenario に対応する回帰テスト ID（例: `test_comparative_dashboard_qa.R` Q1–Q24）を脚注または表で紐付ける
5. **一次文献:** DOI/ISBN 付きで `docs/reference/README.md` §5 インデックスへ追記する
6. **非目標:** 因果 NNT の臨床適応拡大、自動規制決定、FWER 保証の主張を書かない

---

## 7. 本監査の非対象

- 実装バグ修正、ダッシュボード CSS、OpenSpec archive 操作
- `quality_loop_manual_*` / `markdownlint_usage_*` 等の運用マニュアル（数理正本ではない）
- 外部エコシステム（`Productivity-Skill`, `rwd-mysql-skill-toolkit`）の SQL／DB 数理

---

## 8. 次アクション（推奨順）

1. ~~ポータル整備（本監査リンク・17 Spec 対応・AGENTS/README 導線）~~ ← 2026-09-27 実施済み
2. `implementation_plan` 承認後に P0 2 文書（`comparative_evidence_math.md`, `design_aware_inference_math.md`）を執筆
3. P1 `evidence_decision_audit_math.md`
4. P2 SAS 境界文書 + `stats_bayesian.md` 対照節 + supersession map 追記（supersession の hierarchy 行はポータル整備時に追記済み）
