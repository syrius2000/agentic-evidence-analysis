# Implementation Plan 020: Section 15 — Documentation and Ecosystem Synchronization

## 1. 概要と目標
- **Change**: `comparative-evidence-reporting-v3`
- **対象フェーズ**: **Section 15: Documentation and Ecosystem Synchronization** (Tasks 15.1 - 15.9)
- **前提条件**: Section 14 QA Review 4 にて **PASS / ACCEPT** 判定（M14-01 / 14.R3c CLOSED, Blocker 0, High 0, Medium 0）を受領し、HOLD が完全解除された状態。
- **目標**: 本 Change で新規実装・改修された 3 つのスキル（`vcd-categorical-reporting`, `comparative-design-analysis`, `evidence-decision-review`）、共有基盤（`person_time_rate`, `independent_beta_binomial`, `comparative_contrasts`, `iptw_inference`, `matched_pair_dirichlet`, `matched_set_inference`）、および Pass 0 ルーティング契約をリポジトリ全体のドキュメント・スキルガイド・リファレンスマトリクスと完全同期させ、相対パスリンクの整合性を担保する。

---

## 2. タスク分解と対象ファイルマッピング

| タスク ID | 概要 | 主な対象ファイル | 変更内容・受入基準 |
| :---: | :--- | :--- | :--- |
| **15.1** | `AGENTS.md` の更新 | `AGENTS.md` | 新規スキルディスパッチ指針（`vcd-categorical-reporting`, `comparative-design-analysis`, `evidence-decision-review`）、`evidence_runs/<skill_slug>/` 規約、統計 6 次元の分離原則（実務領域・U-Grade と標本精度・臨床重症度の峻別）、多重比較スクリーニング免責規約を明記。 |
| **15.2** | `README.md` の更新 | `README.md` | 新規比較エビデンス解析（独立 Jeffreys Beta-Binomial、デザイン考慮型 IPTW/マッチドペア/人年発症率、エビデンス決定監査）の機能紹介、実行例、アーキテクチャ境界を追加。 |
| **15.3** | 責任境界マトリクスの更新 | `docs/reference/skill_responsibilities.md` | 既存 5 スキルに加え、`vcd-categorical-reporting`, `comparative-design-analysis`, `evidence-decision-review` の入力・出力・責任・非責任・越境禁止境界（GLMM/GEE 排除、規制自動裁定排除）をマトリクスに追加。 |
| **15.4** | Pass 0 スキルガイド更新 | `.agents/skills/vcd-pass0-consultation/SKILL.md` | 新規ルーティング質問（2群比較、マッチドペア、IPTW、人年発症率、反復測定の集約可否、決定監査）およびパラメータ定義を追加。 |
| **15.5** | カテゴリカルレポーティングガイド更新 | `.agents/skills/vcd-categorical-reporting/SKILL.md` | 複数テーマ一括比較エビデンス（RD/RR/方向支持/実務領域/U-Grade）、ゼロセル確定挙動（`mean = null`, `mean_is_finite = false`）、完全自己完結 HTML ダッシュボード、安全シグナルスクリーニング仕様を詳細化。 |
| **15.6** | 新規 2 スキルガイドの整備 | `.agents/skills/comparative-design-analysis/SKILL.md`<br>`.agents/skills/evidence-decision-review/SKILL.md` | 新規作成されたスキルの SKILL.md を精査し、最新の数理契約・実行手順・入出力契約・非責任範囲を明記。 |
| **15.7** | アーカイブ文書のレガシー明記 | `docs/Archives/` 該当文書 | 過去のレポーティング・旧仕様に関する記述について「レガシー（改定前）」である旨の注釈・ポインタを追記（過去ログ自体は改竄せずヘッダ等に明記）。 |
| **15.8** | 過去アーカイブの不可侵性検証 | `docs/Archives/` 全体 | 歴史的記録ファイルがポインタ調整を除いて不用意に変更されていないことを静的スキャンで検証。 |
| **15.9** | 相対リンク整合性検証 | 全 `.md` ドキュメント | Markdown 内部リンクがすべて相対パス（`file:///` や OS 絶対パスの非含有）であることを検証するスクリプトを実行し 100% 整合を確認。 |

---

## 3. データ契約先行 (Provenance & Data Contract)

1. **スキル識別子 (Canonical Skill Slugs)**:
   - `vcd-categorical-reporting`: 2群比較・スクリーニング
   - `comparative-design-analysis`: IPTW・マッチドペア・マッチドセット・人年発症率
   - `evidence-decision-review`: 統計エビデンスプロファイルと専門家判定の乖離監査・先例検索
2. **実行出力ディレクトリ契約 (Run Scope Directory Contract)**:
   - `evidence_runs/vcd_categorical_reporting/run_<id>/`
   - `evidence_runs/comparative_design/run_<id>/`
   - `evidence_runs/evidence_decision_review/run_<id>/`
3. **統計用語・概念契約 (Terminology Separation Contract)**:
   - **ベイズ推論**: `inferential_semantics = "posterior"`, `interval: "posterior_eti"`, `posterior_median`
   - **IPTW ブートストラップ**: `inferential_semantics = "bootstrap_resampling"`, `interval: "bootstrap_percentile"`, `resample_median`
   - **U-Grade**: 実務領域（`practical_neutral`, `target_excess`, `reference_excess`）に対する事後確信度区分（U0: $\ge 0.95$, U1: $\ge 0.80$, U2: $\ge 0.60$, U3: $< 0.60$）。標本サイズやサンプリング精度（ESS/区間幅）、および臨床的重症度とは完全に直交する指標として定義。

---

## 4. 統計・概念分離の構造監査 (Conceptual Integrity)

1. **自動規制判断の完全排除 (No Automated Regulatory Determination)**:
   - `evidence-decision-review` は決定ラベルを用いない統計特徴量（Gower 距離、HAC）から過去の専門家判断との整合性を探索・提示するのみであり、自動で「承認/棄却/安全警告」を判定してはならない旨を全ドキュメントに明記。
2. **多重性制御の非主張 (Exploratory Multiplicity Disclaimer)**:
   - 複数テーマのバッチ解析はシグナル探索・優先順位付け（Screening）であり、FWER (Family-Wise Error Rate) や FDR (False Discovery Rate) の厳格な制御を主張してはならない。
3. **集計の非加加重契約 (Safety PT Deduplication Invariant)**:
   - MedDRA 等の有害事象集計において、SOC 件数は PT 件数の単純和ではなく、症例単位（Subject-level）の重複排除（Deduplication）による固有集計であることを明記。

---

## 5. 一次情報の完全照合 (Zero-Guesswork)

コードベースおよびスキーマ定義から正確な名称を照合：
- スキーマ: `schemas/comparative-draws-v1.json`, `schemas/comparative-evidence-v1.json`, `schemas/evidence-feature-v1.json`, `schemas/decision-ledger-v1.json`
- 関数名: `generate_comparative_report()`, `run_independent_beta_binomial()`, `run_person_time_rate()`, `run_iptw_inference()`, `run_matched_pair_dirichlet()`, `run_matched_set_inference()`, `extract_evidence_features()`, `gower_distance_matrix()`, `hierarchical_cluster_evidence()`, `find_historical_precedents()`, `verify_decision_ledger()`, `trajectory_from_ledger()`
- 診断バッジ: `ZERO_REFERENCE`, `UNSTABLE_RR_INTERVAL`, `SPARSE_EVENTS`, `EXTREME_WEIGHTS`, `COVARIATE_IMBALANCE`, `GOWER_REFERENCE_RANGE_EXCEEDED`, `QA_REVIEW_CANDIDATE`

---

## 6. 具体的テストマトリクス (Test Matrix)

| テスト分類 | 検証内容 (Checks) | 対象ファイル / コマンド | 期待結果 (Expected Result) |
| :--- | :--- | :--- | :--- |
| **T15.1** | 相対パスリンク監査 | 全 `.md` ファイル走査スクリプト | `file:///` または OS ローカル絶対パス（`/Users/` 等）が 0 件 |
| **T15.2** | リンク切れ監査 | `tests/test_doc_links.R` または走査スクリプト | リポジトリ内 Markdown リンクの参照先実体ファイルが存在すること |
| **T15.3** | ドキュメント文言監査 | 全 `.md` ファイル走査 | 規約に反する「自動規制決定」「因果的優越」「同等性誤認」表現が 0 件 |
| **T15.4** | OpenSpec 整合性検証 | `openspec validate comparative-evidence-reporting-v3 --strict --json` | バリデーションエラー 0 件 |
| **T15.5** | Git 差分チェック | `git diff --check` | 空白エラー・不正改行なし |

---

## 7. 実行手順

1. **Step 1: ドキュメント改修**
   - `AGENTS.md` (15.1)
   - `README.md` (15.2)
   - `docs/reference/skill_responsibilities.md` (15.3)
   - `.agents/skills/vcd-pass0-consultation/SKILL.md` (15.4)
   - `.agents/skills/vcd-categorical-reporting/SKILL.md` (15.5)
   - `.agents/skills/comparative-design-analysis/SKILL.md` & `.agents/skills/evidence-decision-review/SKILL.md` (15.6)
   - `docs/Archives/` 該当ファイルへのレガシー注記 (15.7, 15.8)
2. **Step 2: リンカー・バリデータ作成と実行**
   - 相対リンクおよびパス整合性検証スクリプトの実行 (15.9)
3. **Step 3: 回帰テスト・OpenSpec 検証**
   - `openspec validate` および回帰テストの実行
4. **Step 4: 実行記録 (Execution Record) の作成**
   - `docs/Artifacts/s15_documentation_ecosystem_exec_001_0926.md`
5. **Step 5: 中間コミット (`Yip:`) とプッシュ**
   - `git commit` & `git push`
   - QA レビュー用メタデータの提示

---

## 8. 事後是正・実測確定記録 (Post-Execution Canonical Reconciliation)

*記録日: 2026-09-26 JST (Section 15 実装・QA Review 2 是正)*

本計画書策定時（実行前ドラフト）に記載された一部の識別子・用語について、実装およびスキーマ・テストの確定に伴い、以下の通り実測確定値（Canonical Values）との対応・是正を記録する（トレーサビリティおよび原本監査性の保全のため、策定時本文の意図を保持しつつ本節にて確定値を明定する）。

| 計画書策定時（ドラフト表記） | 実装・リポジトリ実測確定値 (Canonical) | 根拠・確定理由 |
| :--- | :--- | :--- |
| **IPTW/マッチドセット推論セマンティクス**<br>`inferential_semantics = "bootstrap_resampling"`<br>`interval: "bootstrap_percentile"`<br>`resample_median` | `inferential_semantics = "bootstrap"`<br>`estimate.source = "observed_sample_estimate"`<br>`interval.method = "bootstrap_percentile"` | 点推定値は観測標本から解析的に算出し、不確実性のみを患者レベル/クラスタブートストラップから導出する数理原則（Abadie & Imbens 2008 / Austin 2014）に準拠。推論セマンティクス列挙子は `bootstrap` に確定。 |
| **意思決定台帳スキーマファイル名**<br>`schemas/decision-ledger-v1.json` | `schemas/decision-ledger-record-v1.json` | 追記専用・改竄検知台帳の個別レコードスキーマとして `schemas/decision-ledger-record-v1.json` が配備・検証されている。 |
| **統計概念次元**<br>統計 6 次元 | **統計 7 次元の厳格分離原則**<br>$\text{Domain} \ne \text{Design} \ne \text{Inference} \ne \text{Contrast} \ne \text{Region Resolution} \ne \text{Numerical Precision} \ne \text{Decision}$ | 影響度・数値安定性（Leverage, Quarantine, 参照群ゼロ期待値無限大確定）と先例監査（Label-free HAC）を分離し、7次元として正本化。 |
| **スキルインベントリ**<br>既存 5 スキルに加え... | **全 9 スキル**<br>（`comparative-design-analysis`, `evidence-decision-review`, `questionnaire-batch-analysis`, `sas-proc-freq`, `sas-proc-means`, `vcd-bayesian-evidence-analysis`, `vcd-categorical-analysis`, `vcd-categorical-reporting`, `vcd-pass0-consultation`） | `tests/test_skill_ownership_contract.py`、`AGENTS.md`、`README.md` と同期した正本 9 スキル体制に確定。 |
