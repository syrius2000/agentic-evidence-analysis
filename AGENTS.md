# AGENTS.md — Evidence-Driven Statistical Analysis Guidelines

本リポジトリは、統計解析・エビデンス分析スキルおよび R 解析スクリプト群の**唯一の正本リポジトリ**です。
エージェントが本リポジトリで作業する際は、以下の基本鉄則および運用規約を遵守してください。

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
- **多次元・カテゴリカル探索ワークフロー（`vcd-*` 系）**:
  - 次元の呪いや解釈不能な結果を防ぐため、**Pass 0（`vcd-pass0-consultation`）による `analysis_config.json` の作成が必須**。
- **Pass 0 必須の対象外（除外）**:
  - **SAS 互換プロシージャ（`sas-proc-freq`, `sas-proc-means`）**
  - 定型バッチ処理（`questionnaire-batch-analysis` 等）
  - 単体集計スクリプトの直接実行、回帰・ユニットテスト、ドキュメントやコードの改修保守

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
- エコシステム境界:
  - 一般コード・SQL 理解: `Productivity-Skill`
  - RWD/DB 実行ハブ: `rwd-mysql-skill-toolkit`
  - 統計仕様・数理実装の変更は、すべて本リポジトリ（正本）に集約する。

---

## 3. 統計哲学と数理リファレンス

- **P 値単独判定の禁止**: 普遍的な標本サイズ境界や、P 値・BF・効果量の一律閾値から重要性を機械的に自動判定しない。
- **次元の分離原則**:
  1. 全体連関構造
  2. 差の大きさ（局所対数効果比、標準化差、率差）
  3. 統計的証拠強度（Rao スコア検定統計量 $T_i^{\rm score}$、対数 P 値）
  4. 影響度（Leverage $h_{ii}$）と安定性（Quarantine 3 条件）
  5. 不確実性（多項 Dirichlet 信用区間、事前感度）
  6. 実務判断（意思決定基準）

> [!NOTE]
> 各スキルの数理モデル詳細（3次元対数線形 M1〜M9、明示式 BIC、新 4 軸セル診断、多項 Dirichlet 事後推論、大標本 Dual-Filter 原則、旧スコアの監査列化など）は、正本リファレンスを参照してください：
> - [`docs/reference/README.md`](docs/reference/README.md)
> - [`docs/reference/three_way_models.md`](docs/reference/three_way_models.md)
> - [`docs/reference/skill_responsibilities.md`](docs/reference/skill_responsibilities.md)

---

## 4. 主なスキルのディスパッチ指針

| 分析目的・タスク | 推奨スキル | ワークフロー概要 |
| :--- | :--- | :--- |
| **3次元集計表の探索・因果構造・局所セル診断** | `vcd-bayesian-evidence-analysis` | Pass 0（事前相談）$\to$ Pass 1（R 計算）$\to$ Pass 2（AI レビュー）$\to$ Pass 3（HTML） |
| **2次元分割表の全体効果量・残差分析** | `vcd-categorical-analysis` | 2次元特化プロファイル・レポート |
| **SAS PROC FREQ 互換度数集計・独立性検定** | `sas-proc-freq` | **Pass 0 不要**。直接実行（JSON/CSV/MD 出力） |
| **SAS PROC MEANS 互換記述統計・層別集計** | `sas-proc-means` | **Pass 0 不要**。直接実行（JSON/CSV/MD 出力） |
| **アンケート設問の量産・一括バッチ** | `questionnaire-batch-analysis` | 設定 CSV に基づくバッチ実行 |
