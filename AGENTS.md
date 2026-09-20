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

- **必須**: `vcd-bayesian-evidence-analysis` と `vcd-categorical-analysis` の新規分析。`vcd-pass0-consultation` で入力品質、変数、次元、欠測、疎セル、分析目的を確認し、`analysis_config.json` を確定する。
- **推奨**: `questionnaire-batch-analysis`。複数設問の入力・出力設計をそろえるため、可能な限りPass 0を経由する。
- **対象外**: `sas-proc-freq`、`sas-proc-means`、単体集計スクリプトの直接実行、回帰・ユニットテスト、ドキュメントやコードの改修保守。

### 鉄則 3: 出力先の完全分離とディレクトリ規約

- 解析実行の出力先は、同一入力や実行間で衝突しないよう `run_id`（SHA-256 ハッシュまたは明示的 ID）を用いたディレクトリ構造に完全に分離する。
  - `vcd-bayesian-evidence-analysis`: `<out>/run_<first16>/`（`.agents/shared/run_scope.R` 経由）
  - `vcd-categorical-analysis`: `<out>/run_<first16>[_N]/`
  - `questionnaire-batch-analysis`: `<out>/runs/<id>/`

### 鉄則 4: 言語・タイムゾーン契約

- 生成するレポート、AI 要約（`executive_summary.md` 等）、解説は原則として**日本語**で作成する。
- タイムスタンプおよび解析コンテキストは **JST（日本標準時）** に準拠する。

### 鉄則 5: 正本リポジトリ境界

- スキルツリーは `.agents/skills` のみを管理対象とする（`.cursor/skills` は作成・復元しない）。
- 共通R基盤は `.agents/shared`、統計数理と責務の正本は `docs/reference` とする。
- `agentic-evidence-analysis` は、同名5スキル、統計schema、統計品質契約、Rテンプレート、統計回帰テストの唯一の正本である。
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
- **次元の分離原則**:
  1. 全体連関構造
  2. 差の大きさ（局所対数効果比、標準化差、率差）
  3. 統計的証拠強度（Rao スコア検定統計量 $T_i^{\rm score}$、対数 P 値）
  4. 影響度（Leverage $h_{ii}$）と安定性（Quarantine 3 条件）
  5. 不確実性（多項 Dirichlet 信用区間［主事前: 多項 Jeffreys $\alpha=0.5$、感度分析: Laplace $\alpha=1.0$］、条件付き事後予測確率 $P(B|A)$ / $P(A|B)$、独立性からの事後乖離）
  6. 実務判断（意思決定基準）

> [!NOTE]
> 各スキルの数理モデル詳細（3次元対数線形 M1〜M9、明示式 BIC、新 4 軸セル診断、多項 Dirichlet 事後推論、大標本 Dual-Filter 原則、旧スコアの監査列化など）は、正本リファレンスを参照してください：
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
| **SAS PROC FREQ 互換度数集計・独立性検定** | `sas-proc-freq` | **Pass 0 不要**。直接実行（JSON/CSV/MD 出力） |
| **SAS PROC MEANS 互換記述統計・層別集計** | `sas-proc-means` | **Pass 0 不要**。直接実行（JSON/CSV/MD 出力） |
| **アンケート設問の量産・一括バッチ** | `questionnaire-batch-analysis` | 設定 CSV に基づくバッチ実行 |

## 5. 作業と変更の承認境界

- 調査、現状確認、差分確認、計画書作成は読み取り専用で実施できる。
- 大規模変更、コード・依存関係・データの変更、外部システムへの書き込みの前に、`docs/Artifacts/implementation_plan_NNN_MMDD.md` を作成する。
- 計画の承認前は、実装・データ変更・外部書き込みへ移行しない。対象範囲、方式、影響範囲が変わる場合は計画を更新して再承認を得る。
- 作業開始時点のユーザー変更、無関係な差分、未追跡ファイルを保持する。復元や削除が必要な場合は対象を限定し、明示的な承認を得る。
- commit、push、ブランチ操作、アーカイブ、削除は、実装完了とは別の操作として扱い、個別の指示がない限り実施しない。

## 6. 報告時の証拠区分

- 構文検証、静的テスト、実行結果、独立QA、Owner判断、commit、pushを別々に報告する。
- 実行していない検証は `未検証` とし、過去の記録や実装者の報告だけで現行状態を確定しない。
