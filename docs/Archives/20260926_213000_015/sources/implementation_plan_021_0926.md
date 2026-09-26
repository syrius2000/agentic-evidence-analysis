# Implementation Plan 021: Section 16 — Independent QA and Regression Verification Gate

## 1. 概要と目標

- **Change**: `comparative-evidence-reporting-v3`
- **対象フェーズ**: **Section 16: Independent QA and Regression Verification Gate** (Tasks 16.1 - 16.13)
- **前提条件**: Section 15 QA Review 3 にて HOLD が完全解除され、PASS / ACCEPT 認定を受領した状態。
- **目標**: 本 Change で導入された全統計機能（独立 Jeffreys Beta-Binomial、1:1 マッチドペア Dirichlet、1:k マッチドセット クラスタブートストラップ、IPTW 患者ブートストラップ、人年発症率 Gamma-Poisson、決定ラベル非含有先例監査 HAC/Gower、自己完結 HTML ダッシュボード）およびエコシステム同期について、全 13 項目のゲート要件を数理的・実証的・回帰テスト的に網羅検証し、Change 完了および Section 17 アーカイブ移行への準備を確定する。

---

## 2. タスク分解と対象ファイルマッピング

| タスク ID | 概要 | 主な対象ファイル / 根拠 | 監査・検証項目 |
| :---: | :--- | :--- | :--- |
| **16.1** | ブラインド先行独立 QA レビュー | `docs/Artifacts/s16_independent_qa_exec_001_0926.md` | 実装者の主観的解説に先立ち、OpenSpec 仕様・コード・客観テスト結果に基づく独立レビュー依頼メタデータの整備。 |
| **16.2** | 参照群ゼロ数理挙動の検証 | `.agents/shared/comparative_contrasts.R`<br>`tests/test_vcd_categorical_reporting.R`<br>`tests/test_comparative_dashboard_qa.R` | $x_R = 0$ 時に $E(RR) = \infty$ となる数理的発散に対し、事後中央値・ETI 区間は正しく出力されつつ `mean = null`, `mean_is_finite = false`, `rr_diagnostic = "ZERO_REFERENCE_RISK"` が全成果物で確定していること。 |
| **16.3** | 実務差域（primary_delta）セマンティクス検証 | `.agents/shared/independent_beta_binomial.R`<br>`tests/test_comparative_dashboard_qa.R` | `primary_delta = null` 時に領域分類（`target_excess`, `reference_excess`）および着色キューが無効化（透明背景・中立）されること。 |
| **16.4** | U-Grade 実務領域解決度セマンティクス検証 | `.agents/shared/comparative_contrasts.R`<br>`docs/reference/skill_responsibilities.md` | U-Grade（U0〜U3）が実務領域への不確実性分布の収まり具合（確信度）であり、標本精度（ESS/区間幅）や臨床的重症度とは完全に直交・峻別されていること。U3 はアラーム赤ではなく減衰グレー表示。 |
| **16.5** | ベイズ事後 ETI vs ブートストラップ パーセンタイル区間用語の厳格分離 | 各種スキーマ、レポート生成関数、`tests/test_comparative_schemas.R` | ベイズ推論（`inferential_semantics = "posterior"`, `posterior_eti`）とリサンプリング推論（`inferential_semantics = "bootstrap"`, `bootstrap_percentile`）の混同がないこと。 |
| **16.6** | 非整数度数・加重擬似度数の拒絶検証 | `.agents/shared/independent_beta_binomial.R`<br>`tests/test_independent_beta_binomial.R` | 非整数カウントや複雑調査重みが投入された際、整数前提違反（`NON_INTEGER_COUNT`）として Fail-Fast 拒絶されること。 |
| **16.7** | 安全性階層の集計不変量検証 | `.agents/shared/safety_adapter.R`<br>`tests/test_safety_adapter.R` | 同一被験者が同一 SOC 内で複数 PT を発現した場合、SOC 症例数が症例単位で重複排除（Deduplicated）され、PT 症例数の単純和と一致しない仕様の保全。 |
| **16.8** | 探索的バッチスクリーニング多重性免責検証 | `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`<br>`tests/test_vcd_categorical_reporting.R` | 複数テーマ一括解析レポート（Markdown / HTML）に、探索的優先順位付けのための指標であり FWER/FDR 制御を主張しない明示的免責条項が含まれること。 |
| **16.9** | 自動規制判断・決定ラベル付与の完全排除検証 | `.agents/shared/evidence_precedent.R`<br>`tests/test_evidence_cluster.R` | `evidence-decision-review` が決定ラベルを用いない特徴量から類似先例を提示し、乖離を "QA Review Candidate" として提示する探索的支援に留まり、承認/棄却の自動裁定を行わないこと。 |
| **16.10** | 全正規回帰テストスイート 100% 通過検証 | `tests/run_regression_suite.R`<br>`tests/test_skill_ownership_contract.py`<br>`tests/test_archive_manifest_integrity.py` | 50 本の R 回帰テスト、10 項目の所有権・参照契約テスト、全アーカイブ原本完全性テストの 100% 成功。 |
| **16.11** | OpenSpec 厳格バリデーション検証 | `openspec validate comparative-evidence-reporting-v3 --strict --json` | バリデーションエラー 0 件。 |
| **16.12** | Git 空白・改行検証 | `git diff --check` | 空白エラー・不正改行なし。 |
| **16.13** | 未解決リスクの記録と Owner 裁定受領 | `docs/Artifacts/s16_independent_qa_exec_001_0926.md` | 残余リスク・運用上の前提条件・成立制限を体系的に記録し、ユーザー（Owner）の最終裁定を仰ぐ。 |

---

## 3. データ契約先行 (Provenance & Data Contract)

本ゲートで検証される主たる canonical データ構造およびスキーマ契約：

1. **ゼロ参照群契約 (`ZERO_REFERENCE_RISK` / `ZERO_REFERENCE_EVENTS`)**:
   - `relative_risk`: `estimate.source = "posterior_median"`, `interval.method = "posterior_eti"`, `mean = null`, `mean_is_finite = false`, `diagnostic = "ZERO_REFERENCE_RISK"`
   - `incidence_rate_ratio`: `estimate.source = "posterior_median"`, `interval.method = "posterior_eti"`, `mean = null`, `mean_is_finite = false`, `diagnostic = "ZERO_REFERENCE_EVENTS"`
2. **推論セマンティクス分離契約**:
   - ベイズ推論（独立 2 群、1:1 ペア、人年）: `inferential_semantics = "posterior"`, `interval.method = "posterior_eti"`
   - リサンプリング推論（IPTW、1:k セット）: `inferential_semantics = "bootstrap"`, `estimate.source = "observed_sample_estimate"`, `interval.method = "bootstrap_percentile"`, `direction$method = "bootstrap_support_fraction"`
3. **実務領域判定契約 (`practical_difference`)**:
   - `primary_delta` 設定時: `u_grade` $\in$ `{"U0", "U1", "U2", "U3"}`、`region` $\in$ `{"target_excess", "practical_neutral", "reference_excess"}`
   - `primary_delta = null` 時: `u_grade = null`, `region = null`, CSS クラス `practical-none`, 背景色透明
4. **意思決定台帳契約 (`schemas/decision-ledger-record-v1.json`)**:
   - 改竄検知ハッシュ連鎖: `previous_record_sha256` (SHA-256 / 64桁 16進数または genesis `0000...`)
   - 助言文言契約: `divergence_status = "QA_REVIEW_CANDIDATE"`（システムエラーや無効判定表現の禁止）

---

## 4. 統計・概念分離の構造監査 (Conceptual Integrity)

本 Change の根底にある **統計 7 次元の厳格分離原則**：
\[
\text{Domain} \ne \text{Design} \ne \text{Inference} \ne \text{Contrast} \ne \text{Region Resolution} \ne \text{Numerical Precision} \ne \text{Decision}
\]
に照らし、以下の構造的混同がコードおよびレポートにおいて完全に排除されていることを監査する：

1. **効果量 vs 方向支持**: 方向支持指標（$P(RD > 0)$ または $\hat{p}^*$）が高いことのみを根拠に「大きな差がある」または「優越性が証明された」と主張しない。
2. **確信度 (U-Grade) vs 標本精度 (Precision)**: U-Grade は実務領域 $q_T, q_N, q_R$ への不確実性分布の収まり具合であり、有効標本サイズ ESS や信用区間幅とは独立した指標として別列表示する。
3. **確信度 (U-Grade) vs 臨床的重症度 (Severity)**: U-Grade は統計的・推論的な確信度区分であり、疾患や有害事象の臨床的深刻さを表さない。
4. **観察データ vs 介入因果効果**: 観察研究マッチドペアにおける McNemar オッズ比を因果的治療効果として解釈しない。
5. **探索的先例監査 vs 規制判断**: 決定ラベルを含まない客観的特徴量のクラスタリング結果を、自動的な承認・不承認裁定として適用しない。

---

## 5. 一次情報の完全照合 (Zero-Guesswork)

実コード・スキーマ・テストファイルと 100% 完全一致する識別子：

- **スキーマ定義**: `schemas/comparative-draws-v1.json`, `schemas/comparative-evidence-v1.json`, `schemas/comparative-evidence-batch-v1.json`, `schemas/evidence-feature-v1.json`, `schemas/decision-ledger-record-v1.json`
- **中核推論器**: `.agents/shared/independent_beta_binomial.R`, `.agents/shared/matched_pair_dirichlet.R`, `.agents/shared/matched_set_inference.R`, `.agents/shared/iptw_inference.R`, `.agents/shared/person_time_rate.R`, `.agents/shared/comparative_contrasts.R`
- **レポート・ダッシュボード**: `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
- **先例監査・台帳**: `.agents/shared/evidence_feature_extract.R`, `.agents/shared/evidence_gower.R`, `.agents/shared/evidence_cluster.R`, `.agents/shared/evidence_precedent.R`, `.agents/shared/evidence_ledger.R`, `.agents/shared/evidence_discordance.R`, `.agents/shared/evidence_trajectory.R`

---

## 6. 具体的テストマトリクス (Test Matrix)

| テスト ID | 検証項目 (Checks) | 対象 Fixture / スクリプト | 期待される判定・結果 (Expected Result) |
| :---: | :--- | :--- | :--- |
| **TM16.1** | 参照群ゼロ時の数理確定性 (16.2) | `tests/test_vcd_categorical_reporting.R`<br>`tests/test_comparative_dashboard_qa.R` | $x_R = 0$ で `mean = null`, `mean_is_finite = false`, `rr_diagnostic = "ZERO_REFERENCE_RISK"`。警告コールアウト表示。 |
| **TM16.2** | デルタ null 時の無効化挙動 (16.3) | `tests/test_comparative_dashboard_qa.R`<br>`test_practical_difference.R` | `primary_delta = null` で行・セル着色なし（透明）、実務領域未判定。 |
| **TM16.3** | U-Grade 表示分離と U3 減衰色 (16.4) | `tests/test_comparative_dashboard_qa.R` | U3 がアラーム赤（`#e53935` 等）を含まず、減衰スレートグレー（`#e2e8f0`）でレンダリング。 |
| **TM16.4** | 推論用語の厳格分離 (16.5) | `tests/test_vcd_categorical_reporting.R`<br>`tests/test_comparative_schemas.R` | IPTW/Matched-Set レポートに `posterior` / `ETI` 語彙が非含有（0 件）。 |
| **TM16.5** | 非整数度数の拒絶 (16.6) | `tests/test_independent_beta_binomial.R` | $x = 10.5$ の投入で即座に `NON_INTEGER_COUNT` エラー停止。 |
| **TM16.6** | 安全性被験者重複排除 (16.7) | `tests/test_safety_adapter.R` | 同一被験者の 2 件の PT 発症に対し、SOC は 1 件（Deduplicated）として計上。 |
| **TM16.7** | 多重性免責条項の存在 (16.8) | `tests/test_vcd_categorical_reporting.R` | Markdown/HTML 双方に「探索的スクリーニング免責」「多重比較スクリーニング免責」を含む。 |
| **TM16.8** | 自動裁定排除と QA Review 助言 (16.9) | `tests/test_evidence_cluster.R`<br>`tests/test_evidence_discordance.R` | 乖離判定が `QA_REVIEW_CANDIDATE` となり、自動的な規制判定・ラベル付与が一切行われない。 |
| **TM16.9** | 正規 R 回帰テストスイート (16.10a) | `tests/run_regression_suite.R` | 全 50 本の R 回帰テストが 100% PASS。 |
| **TM16.10** | ガバナンス・参照契約テスト (16.10b) | `tests/test_skill_ownership_contract.py` | 全 10 本の Python 契約テストが 100% PASS。 |
| **TM16.11** | アーカイブ原本整合性テスト (16.10c) | `tests/test_archive_manifest_integrity.py` | Batch 002, 003, 004, 007, 012〜014 全 5 スイートが 100% PASS。 |
| **TM16.12** | OpenSpec 厳格バリデーション (16.11) | `openspec validate --strict --json` | バリデーションエラー 0 件、valid = true。 |
| **TM16.13** | Git 差分チェック (16.12) | `git diff --check` | 空白エラー・不正改行なし、クリーン。 |

---

## 7. 実行手順

1. **Step 1: 統合検証スイートの実行**
   - TM16.1 〜 TM16.8 の各概念・数理・不変量テストの実行とエビデンス採取
   - TM16.9 `tests/run_regression_suite.R` の一括実行
   - TM16.10 `tests/test_skill_ownership_contract.py` の実行
   - TM16.11 `tests/test_archive_manifest_integrity.py` の実行
2. **Step 2: ツール整合性・Git 検証**
   - TM16.12 `openspec validate comparative-evidence-reporting-v3 --strict --json`
   - TM16.13 `git diff --check`
3. **Step 3: Section 16 実行記録 (Execution Record) の作成**
   - `docs/Artifacts/s16_independent_qa_exec_001_0926.md` を作成し、数理検証、不変量検証、全テスト通過ログ、残余リスク整理（16.13）を記録。
4. **Step 4: タスク更新と中間コミット (`Yip:`)**
   - `openspec/changes/comparative-evidence-reporting-v3/tasks.md` の Section 16 チェックボックスを更新。
   - `git commit` & `git push`
5. **Step 5: 独立 QA レビュー役へのメタデータ提示と Owner 裁定依頼**
   - レビュー依頼用メタデータブロックを提示し、Section 16 の独立 QA レビューを仰ぐ。

---

## 8. Canonical Contract Reconciliation (16.R1 照合記録)

独立 QA レビュー 1（`s16_independent_qa_review1_001_0926.md`）の指摘（H16-01）に基づき、本計画書内の各記述と実コード・スキーマ・テストの canonical 契約との照合・訂正内容を記録する：

1. **ゼロ参照群契約（対照群ゼロ $x_R = 0$）**:
   - 独立 Jeffreys Beta-Binomial: `relative_risk.mean = null`, `relative_risk.mean_is_finite = false`, `diagnostics.badges` に `ZERO_REFERENCE`（および必要に応じて `UNSTABLE_RR_INTERVAL`）。UI 表示は `N/A`（または `x.xx [N/A]`）＋警告コールアウト `#numerical-instability-warning`。
   - （注: `relative_risk.diagnostic = "ZERO_REFERENCE_RISK"` は IPTW / bootstrap 等のデザイン考慮型推論における RR 抑制パスの仕様）。
2. **実務差域 `primary_delta = null`**:
   - `practical_region_support = NULL`
   - `resolution_grade.grade = "NONE"`
   - `resolution_grade.dominant_region = "none"`
   - `resolution_grade.max_region_probability = NULL`
   - ダッシュボードの該当セル背景色は無彩色（`background: transparent`）。
3. **意思決定台帳ジェネシスレコード**:
   - `previous_record_sha256 = null`（`0000...` ではない）。
4. **先例乖離助言契約**:
   - `is_qa_review_candidate = true`
   - `advisory_flag = "QA Review Candidate"`
   - `severity = "advisory"`
   - `halts_workflow = false`, `exploratory_only = true`, `decision_rule = false`（`QA_REVIEW_CANDIDATE` などの非 canonical 識別子は不使用）。
5. **U3 配色オーバーライド**:
   - Section 14 で策定・検証された canonical CSS 値は `rgba(148, 163, 184, 0.12)`（減衰スレート色）。
6. **Task 7.4 スコープ**:
   - `departmental_policy.json` は Section 7 で Deferred（延期）とされており実リポジトリには未導入。本 Change のスコープ外として扱う。
7. **アーカイブ整合性テスト範囲**:
   - `tests/test_archive_manifest_integrity.py` は選定された過去バッチ（002, 003 Plan 016, 004, 007, 012–014）の SHA-256 チェックサム完全性を検証するテストスイート。

---

## 9. Late Owner Enhancement E16-01 — Sortable Comparative Evidence Summary

### 9.1 Decision and placement

2026-09-26 の Owner 追加要望として、HTML ダッシュボードの「比較エビデンス解析サマリー」に列ソート機能を追加する。

この変更は Section 16 の QA ロジックそのものではなく **Section 14 の dashboard usability enhancement** であるため、OpenSpec には late-added **Task 14.10** として追加する。

実施順序は以下とする：

1. OpenSpec Task 14.10 を追加し、未完了 `[ ]` とする。
2. Section 17 の freeze/archive readiness に入る前に Task 14.10 を実装する。
3. `tests/test_comparative_dashboard_qa.R` を拡張し、sorting/accessibility/self-contained 契約を自動検証する。
4. 1280x800 browser QA で少なくとも RD と U-Grade の昇順・降順ソートを確認する。
5. dashboard/report 回帰、full regression、OpenSpec strict validation、`git diff --check` を再実行する。
6. Section 16 execution record を更新し、再検証結果を固定する。
7. Owner adjudication（16.13）を完了してから Section 17 に進む。

**結論:** ソート機能は Section 17 の最後で追加するのではなく、**この段階で OpenSpec に取り込み、Section 16 最終 ACCEPT 前に実装・再検証する**。

### 9.2 Functional contract

対象テーブル：

`#comparative-evidence-table`

各 sortable header はクリックおよびキーボード操作で次の状態を切り替える：

`ascending -> descending -> ascending ...`

アクセシビリティ契約：

- sortable header/control は keyboard operable とする。
- active sort column に `aria-sort="ascending"` または `aria-sort="descending"` を付与する。
- 非 active sortable column は `aria-sort="none"` とする。
- 表示上の矢印・記号だけを状態の唯一の情報源にしない。

外部依存契約：

- DataTables 等の外部 JS/CSS/CDN は使用しない。
- self-contained HTML 契約を維持し、inline vanilla JavaScript のみを使用する。
- Task 14.6 の zero external HTTP/HTTPS dependency を維持する。

### 9.3 Sort semantics

表示文字列を直接 parse せず、各セルへ machine-readable sort key を明示的に持たせる。

推奨属性：

`data-sort-value`

列別 canonical sort key：

- Theme: case-insensitive text
- Comparison: case-insensitive text
- Descriptive N (T / R): target N を primary、reference N を tie-break
- Event counts (T / R): target events を primary、reference events を tie-break
- RD: `rd_estimate`
- RR: `rr_estimate`; unavailable / N/A は有限値の後ろ
- Direction support: `direction_support`
- Practical/U-Grade: ordinal `U0 < U1 < U2 < U3 < NONE`
- Precision: `rd_interval_width` を primary
- Diagnostics: normalized badge text

数値の同値行は元の行順を保持する **stable sort** とする。

N/A / unavailable 値は昇順・降順のいずれでも有限値群の後ろへ送る。

### 9.4 Presentation invariants

行順の変更のみを行い、既存セル DOM は破壊しない。

以下は sorting 後も不変でなければならない：

- Practical Difference cell-only color encoding
- U3 `rgba(148, 163, 184, 0.12)` override
- diagnostic badge markup
- RR instability warning callout
- HTML escaping boundary
- caption / table ID / `aria-describedby`
- zero external asset contract
- zero local absolute path contract

### 9.5 Required automated tests

`tests/test_comparative_dashboard_qa.R` に少なくとも以下を追加する：

1. sortable header metadata / controls are present.
2. `aria-sort` initial and toggled states satisfy the contract.
3. text ascending / descending works.
4. numeric RD ascending / descending works numerically rather than lexically.
5. RR N/A sorts after finite values.
6. U-Grade uses ordinal `U0 < U1 < U2 < U3 < NONE`.
7. equal keys preserve original order.
8. sorting preserves badges and practical-cell markup/colors.
9. hostile/free-text HTML escaping remains intact.
10. zero-external-asset scanner remains PASS.

### 9.6 Browser acceptance

実ブラウザで 1280x800 を用い、少なくとも次を確認する：

- RD header click: ascending / descending row order changes correctly.
- U-Grade header click: U0/U1/U2/U3/NONE ordinal order is correct.
- keyboard activation works.
- `aria-sort` updates.
- no page-level horizontal overflow regression.
- warning/callout/badges/colors remain visually intact.

browser QA artifact / screenshot / viewport / measured result を execution record に残す。

### 9.7 Section 16 revalidation after implementation

Task 14.10 実装後は、少なくとも以下を再実行する：

- `Rscript tests/test_comparative_dashboard_qa.R`
- `Rscript tests/test_vcd_categorical_reporting.R`
- `Rscript tests/run_regression_suite.R`
- `python3 tests/test_skill_ownership_contract.py`
- `python3 tests/test_archive_manifest_integrity.py`
- `openspec validate comparative-evidence-reporting-v3 --strict --json`
- `git diff --check`
- 1280x800 browser visual/interaction QA

その結果を `docs/Artifacts/s16_independent_qa_exec_001_0926.md` に追記してから Section 16 最終独立 QA を依頼する。

