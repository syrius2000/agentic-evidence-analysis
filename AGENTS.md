# AGENTS.md — Evidence-Driven Statistical Analysis Guidelines

本リポジトリは、統計解析・エビデンス分析スキルおよび R 解析スクリプト群の**唯一の正本リポジトリ**です。
エージェントが本リポジトリで作業する際は、以下の基本鉄則および運用規約を遵守してください。

この文書はエージェントの作業契約です。利用者向けの導入手順と実行例は [`README.md`](README.md)、統計数理の詳細は [`docs/reference/README.md`](docs/reference/README.md) を参照してください。

---

## 1. コミュニケーション・出力スタイル

ユーザーへの報告・出力スタイル（ADHD 配慮、結論先行、次のアクション明示）の詳細は、以下を参照してください：

- [`docs/reference/output_style_adhd.md`](docs/reference/output_style_adhd.md)

---

## 2. 共通鉄則（Iron Laws）

### 鉄則 1: R パッケージ実行時インストールの絶対禁止（Fail-Fast 原則）

- 解析実行中、レポート生成中、テスト実行中にパッケージの自動インストール（`install.packages()`, `pacman::p_load()` 等）を試みてはならない。
- すべてのスクリプトとスキルは事前導入済みライブラリに依存し、不足時は即座に停止（`check_r_dependencies()`）して明示的に案内する。

### 鉄則 2: Pass 0（対話的相談）の適用境界

- **必須**: `vcd-bayesian-evidence-analysis` と `vcd-categorical-analysis` の新規分析、および `comparative-design-analysis` の非独立観測デザイン（マッチドペア、IPTW、人年発症率、集約可能判定）。`vcd-pass0-consultation` で入力品質、変数、次元、欠測、疎セル、デザイン境界、分析目的を確認し、`analysis_config.json` または `routing_decision.json` を確定する。
- **推奨**: `questionnaire-batch-analysis`、`vcd-categorical-reporting`（複数テーマ一括比較）。複数設問・比較群の入力・出力設計をそろえるため、可能な限りPass 0を経由する。
- **対象外**: `sas-proc-freq`、`sas-proc-means`、単体集計スクリプトの直接実行、回帰・ユニットテスト、ドキュメントやコードの改修保守。

### 鉄則 3: 出力先の完全分離とディレクトリ規約

- 解析実行の出力先は、推奨出力ルート `evidence_runs/<skill_slug>/` を基本とし、同一入力や実行間で衝突しないよう `run_<canonical_id>[_N]/`（SHA-256 ハッシュまたは明示的 ID）を用いた物理ディレクトリに完全に分離する（出力ルート直下への書き込み禁止）。
  - `vcd-bayesian-evidence-analysis`: `<out>/run_<first16>[_N]/`（推奨: `evidence_runs/vcd_bayesian/`、`.agents/shared/run_scope.R` 経由）
  - `vcd-categorical-analysis`: `<out>/run_<first16>[_N]/`（推奨: `evidence_runs/vcd_categorical/`）
  - `vcd-categorical-reporting`: `<out>/run_<first16>[_N]/`（推奨: `evidence_runs/vcd_categorical_reporting/`）
  - `comparative-design-analysis`: `<out>/run_<first16>[_N]/`（推奨: `evidence_runs/comparative_design/`）
  - `evidence-decision-review`: `<out>/run_<first16>[_N]/`（推奨: `evidence_runs/evidence_decision_review/`）
  - `questionnaire-batch-analysis`: `<out>/run_<id>[_N]/`（推奨: `evidence_runs/questionnaire/`、旧形式 `runs/<id>/` は読取り専用互換）
  - `sas-proc-freq`: `<output_dir>/run_<first16>[_N]/`（推奨: `evidence_runs/sas_proc_freq/`）
  - `sas-proc-means`: `<output_dir>/run_<first16>[_N]/`（推奨: `evidence_runs/sas_proc_means/`）

### 鉄則 4: 言語・タイムゾーン契約

- 生成するレポート、AI 要約（`executive_summary.md` 等）、解説は原則として**日本語**で作成する。
- タイムスタンプおよび解析コンテキストは **JST（日本標準時）** に準拠する。

### 鉄則 5: 正本リポジトリ境界

- スキルツリーは `.agents/skills` のみを管理対象とする（`.cursor/skills` は作成・復元しない）。
- 共通R基盤は `.agents/shared`、統計数理と責務の正本は `docs/reference` とする。
- `agentic-evidence-analysis` は、全9スキル、統計schema、統計品質契約、Rテンプレート、統計回帰テストの唯一の正本である。
- エコシステム境界:
  - 一般コード・SQLコード理解: `Productivity-Skill`
  - RWD/DB実行・統合ハブ: `rwd-mysql-skill-toolkit`
  - 統計仕様・数理実装の変更は、すべて本リポジトリ（正本）に集約する。

### 鉄則 6: 完全自己完結型オフライン成果物（Zero-External-Asset 原則）

- 生成される HTML ダッシュボードおよびレポートは、外部 CDN（DataTables 日本語辞書、外部 CSS/JS、Google Fonts 等）や OS ローカル絶対パス（`/Users/`, `/home/` 等）への依存を一切排除した完全自己完結型（スタンドアローン）とする。
- 生成成果物に対する静的スキャンで外部通信（`http:`, `https:`, `//`）や環境依存パスが検出された場合は受入拒絶（Fail-Fast）する。

---

## 3. 統計哲学と数理リファレンス

- **P 値単独判定の禁止**: 普遍的な標本サイズ境界や、P 値・BF・効果量の一律閾値から重要性を機械的に自動判定しない。
- **次元の厳格な分離原則**:
  \[
  \text{Domain} \ne \text{Design} \ne \text{Inference} \ne \text{Contrast} \ne \text{Region Resolution} \ne \text{Numerical Precision} \ne \text{Decision}
  \]
  1. 全体連関構造・推論デザイン（独立二値、マッチドペア、マッチドセット、IPTW、人年発症率）
  2. 差の大きさ（リスク差 RD、リスク比 RR、率差 IRD、率比 IRR、オッズ比 OR、局所対数効果比、標準化差）
  3. 方向支持指標（ベイズ事後確率 $P(RD > 0)$、ブートストラップ支持比率 $\hat{p}^*$）※因果的優越の主張禁止
  4. 実務領域・U-Grade（実務領域 $q_T, q_N, q_R$ への不確実性分布の収まり具合 U0〜U3）※標本精度や臨床重症度と峻別
  5. 連続精度指標（95% 等裾信用区間 ETI 幅、ブートストラップパーセンタイル区間幅、有効標本サイズ ESS）
  6. 影響度（Leverage $h_{ii}$）と数値安定性（Quarantine 3 条件、参照群ゼロ発生時の理論的無限大 $E(RR)=\infty$ における `mean=null, mean_is_finite=false` 確定契約）
  7. 人間による意思決定と監査（決定ラベルを用いない Gower 距離・HAC による先例監査、自動規制決定の絶対禁止）

> [!NOTE]
> 各スキルの数理モデル詳細（3次元対数線形 M1〜M9、明示式 BIC、新 4 軸セル診断、多項 Dirichlet 事後推論、独立 Jeffreys Beta-Binomial、デザイン考慮型推論、エビデンス決定監査など）は、正本リファレンスを参照してください：
>
> - [`docs/reference/README.md`](docs/reference/README.md)
> - [`docs/reference/three_way_models.md`](docs/reference/three_way_models.md)
> - [`docs/reference/skill_responsibilities.md`](docs/reference/skill_responsibilities.md)

---

## 4. 主なスキルのディスパッチ指針

| 分析目的・タスク | 推奨スキル | ワークフロー概要 |
| :--- | :--- | :--- |
| **3次元集計表の構造・局所セル診断** | `vcd-bayesian-evidence-analysis` | Pass 0（事前相談）$\to$ Pass 1（R 計算）$\to$ Pass 2（AI レビュー）$\to$ Pass 3（HTML） |
| **2次元分割表の全体効果量・残差分析・11セクション自己完結Dashboard** | `vcd-categorical-analysis` | Pass 0（事前相談）$\to$ Pass 1（R 計算: 新4軸・Jeffreys事後推論）$\to$ Pass 2（AI レビュー）$\to$ Pass 3（完全オフラインHTML） |
| **比較群間エビデンス・多テーマスクリーニング (2群比較・安全性PT・処方)** | `vcd-categorical-reporting` | Pass 0（事前検分）$\to$ Pass 1（独立 Jeffreys 推論）$\to$ Pass 2（JSON/CSV）$\to$ Pass 3（完全オフラインHTML・多重性免責明記） |
| **デザイン考慮型比較推論 (マッチドペア/セット・IPTW・人年発症率)** | `comparative-design-analysis` | Pass 0（デザイン検証）$\to$ デザイン特化推論（Dirichlet/IPTW/Gamma-Poisson）$\to$ 標準化 Draw/Evidence 出力 |
| **統計エビデンス決定監査・歴史的先例検索** | `evidence-decision-review` | 決定ラベル非含有特徴量抽出 $\to$ Gower 距離・HAC $\to$ QA Review Candidate 助言（自動決定排除） |
| **SAS PROC FREQ 互換度数集計・独立性検定** | `sas-proc-freq` | **Pass 0 不要**。直接実行（JSON/CSV/MD 出力） |
| **SAS PROC MEANS 互換記述統計・層別集計** | `sas-proc-means` | **Pass 0 不要**。直接実行（JSON/CSV/MD 出力） |
| **アンケート設問の量産・一括バッチ** | `questionnaire-batch-analysis` | 設定 CSV に基づくバッチ実行 |

## 5. 作業と変更の承認境界

- 調査、現状確認、差分確認、計画書作成は読み取り専用で実施できる。
- 大規模変更、コード・依存関係・データの変更、外部システムへの書き込みの前に、`docs/Artifacts/implementation_plan_NNN_MMDD.md` を作成する。
- 計画の承認前は、実装・データ変更・外部書き込みへ移行しない。対象範囲、方式、影響範囲が変わる場合は計画を更新して再承認を得る。
- 作業開始時点のユーザー変更、無関係な差分、未追跡ファイルを保持する。復元や削除が必要な場合は対象を限定し、明示的な承認を得る。

### 実装計画書（implementation_plan）の品質受入契約

計画書はタスク文面の単なる転記や抽象的願望であってはならず、以下の4要件を必ず網羅すること（不備がある計画は受入拒絶）：

1. **データ契約先行（Data / Provenance First）**: UI/レポート/推定の変更前に、中間データ構造（`summary_df`, JSON等）へ搬送する canonical 指標をスキーマレベルで先行定義すること（表示層での ad-hoc な再推論・再判定の禁止）。
2. **統計・概念分離の構造監査**: 効果量・方向・実務領域・精度の分離原則がレイアウト・CSS設計（セル限定着色等）に反映されていること。
3. **一次情報の完全照合（Zero-Guesswork）**: 定数・バッジ名・列名・識別子はコードベース実物から grep して完全一致転記し、推測による命名を排除すること。
4. **具体的テストマトリクス（Test Matrix）**: 抽象的な「テストする」を排し、対象 Fixture（正常・異常・境界値）、Checks、Expected Results を表形式で明記すること。

### Git ブランチ・コミットおよびレビュー運用規約（案A: トピックブランチ分離）

1. **トピックブランチの作成（作業開始ベースライン）**:
   - 大規模な改修や OpenSpec Change の実装を開始する際は、`main` から `feat/<feature-name>` などの専用トピックブランチを切り、作業開始基準点（ベースラインコミット）とする。
2. **レビュー用中間コミット（`Yip:` コミット）の自律作成**:
   - `openspec-apply-change` 等の実装作業やレビュー指摘の修復区切りにおいて、エージェントは **`Yip: <タスク・変更要約>`** というプレフィックスを用いて作業ブランチ上へ中間コミットを自律的に作成できる。
   - コミット作成後、独立レビュー役の別 AI に対して、レビュー対象コミット（`Reviewed commit: <Commit ID>`）および差分基準（`Baseline: <Base ID>`）を一意に提示して確定的なブラインドレビューを依頼する。この時、QA用のメタデータをコードブロックで表示して依頼を効率化する
3. **完了時の `main` への集約（`--squash` マージ & 履歴クリーンアップ）**:
   - 一連の実装・レビューがすべて PASS し、フェーズ完了または Change 完了となった段階で、ユーザーの承認に基づき、`main` ブランチへ `--squash` マージ（または集約コミット）を実施してコミットログを整理する。
   - 過去のレビュー文書（`docs/Artifacts/`）とのトレーサビリティ（監査証跡）を維持するため、集約コミットメッセージ内には取り込んだ `Yip:` コミットのハッシュ一覧を明記する。
4. **プッシュ・破壊的操作の禁止**:
   - `git push`（特に force push）、ブランチ削除、リモートへの書き込みは、実装完了や squash 完了とは別の操作として扱い、ユーザーからの明示的な指示がない限り一切実施しない。

## 6. 報告時の証拠区分

- 構文検証、静的テスト、実行結果、独立QA、Owner判断、commit、pushを別々に報告する。
- 実行していない検証は `未検証` とし、過去の記録や実装者の報告だけで現行状態を確定しない。
