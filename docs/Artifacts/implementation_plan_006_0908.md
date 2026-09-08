# 実行成果物ライフサイクルと実行パス引き継ぎの堅牢化 実装計画書

created: 2026-09-08 18:35 (JST)
update: 2026-09-09 01:10 (JST)
author: Codex (GPT-6)

## 1. 概要と目的

本計画書は、OpenSpec change `harden-run-path-handover` の実装着手（Apply）にあたり、リポジトリガバナンス（`AGENTS.md`）に基づいて作成された正式な実装計画書である。
分析パイプライン（Pass 0 〜 Pass 3）において、各スキル（`vcd-bayesian-evidence-analysis`, `vcd-categorical-analysis`, `questionnaire-batch-analysis`, `vcd-pass0-consultation`）の間で出力先の決定権限、後続処理への引き継ぎルール、成果物の完全性保証、状態遷移、および競合排他制御を厳格化し、分析結果の取り違え、無言上書き、並行実行時の破損を防止する。

## 2. 対象変更と変更対象ファイル

### 対象 OpenSpec 変更
- 変更名: `harden-run-path-handover`
- 仕様スキーマ: `spec-driven`
- 計画 Artifact:
  - `openspec/changes/harden-run-path-handover/proposal.md`
  - `openspec/changes/harden-run-path-handover/specs/run-output-lifecycle/spec.md`
  - `openspec/changes/harden-run-path-handover/design.md`
  - `openspec/changes/harden-run-path-handover/tasks.md`

### 実装変更対象ファイル
1. **共有共通基盤（Shared Engine）**:
   - `.agents/shared/run_scope.R` (改定: 親ディレクトリ検証、秒単位JST衝突解決、厳格パストラバーサル、結果マニフェスト出力・実バイト列ハッシュ検証、信頼境界検証付きrun外排他ロック、staging境界・promotion・クラッシュ回復、sealed封印制御、supersede元run検証、legacy run読み取り限定)
   - `.agents/shared/finalize_run_stage.R` (新設: 共通確定CLIラッパー、信頼境界検証、排他ロック、allowlist検証、staging promotion、原子的更新)
2. **Bayesian Evidence スキル**:
   - `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R`
   - `.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`
   - `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R`
   - `.agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R`
   - `.agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd`
   - `.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md`
3. **Categorical Analysis スキル**:
   - `.agents/skills/vcd-categorical-analysis/templates/analysis.R` (Pass 1 唯一run作成原則、resumable claim廃止)
   - `.agents/skills/vcd-categorical-analysis/templates/render_dashboard.R` (新設)
   - `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd` (`self_contained: true` 明示)
   - `.agents/skills/vcd-categorical-analysis/SKILL.md`
4. **Questionnaire Batch Analysis スキル**:
   - `.agents/skills/questionnaire-batch-analysis/templates/batch_runner.R` (親直下出力廃止、3区分状態遷移 `completed`/`partial`/`failed`、診断成果物保持、後続遮断)
   - `.agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R` (新設)
   - `.agents/skills/questionnaire-batch-analysis/templates/dashboard.Rmd` (`self_contained: true` 明示)
   - `.agents/skills/questionnaire-batch-analysis/SKILL.md`
5. **Pass 0 指示文書**:
   - `.agents/skills/vcd-pass0-consultation/SKILL.md`
6. **テストスイート**:
   - `tests/test_vcd_categorical_run_isolation.R` および変更する CLI・出力契約に対応する既存 `tests/test_*.R` / `tests/test_*.py`（期待値の移行。統計上の受入基準は維持）
   - `tests/test_run_scope_lifecycle.R` (新設: 30タスクの全要件を網羅する単体・統合テスト)

## 3. 実装の順序とタスク分割（全 30 タスク）

本変更の実装は、下位依存から上位スキル、統合テストの順で 5 つのフェーズに分割して実施する。

```text
フェーズ 1: 共有共通基盤改定 (.agents/shared/)
  |
  +--> フェーズ 2: Bayesian Evidence テンプレート改定
  |
  +--> フェーズ 3: Categorical テンプレート改定 (claim廃止)
  |
  +--> フェーズ 4: Questionnaire テンプレート改定 (3区分状態)
  |
  v
フェーズ 5: 統合テストスイート新設・全テスト実行・SKILL.md更新
```

### フェーズ 1: 共有共通基盤（run_scope.R, finalize_run_stage.R）
- **タスク 1.1**: 親ディレクトリ検証関数 `assert_valid_out_root()` の実装（実run誤指定FAIL-FAST）。
- **タスク 1.2**: 秒単位 JST タイムスタンプ衝突の原子的解決ロジックの実装（`_2`, `_3` サフィックス）。
- **タスク 1.3**: 厳格パストラバーサルガード関数 `assert_path_within_run_dir()` の実装（prefix衝突・symlink拒絶）。
- **タスク 1.4**: 設定スナップショット保存および推測なし外部データ保護（`hash_only`）、`inputs` 配列単一正本化と読み取りアダプターの実装。
- **タスク 1.5**: 3スキル共通マニフェスト `write_results_manifest()` / `verify_results_manifest()` の実装（POSIX相対一意パス、小文字64桁、role allowlist、question_id一意性、空文字ソート順、実ファイルバイト列SHA-256）。
- **タスク 1.6**: 信頼境界検証付きrun外排他ロック（`<out_root>/.run_locks/<run_lock_id>/`、全64桁lock_id、実パス・スキルレイアウト一致検証、symlink拒絶、`lock_info.json`、`--recover-stale-lock` 回復、監査ログ）。
- **タスク 1.7**: run内staging領域（`staging/`）制御（正式成果物外、確定成果物追記限定、promotion、クラッシュ回復、本番Pass 3 sealed前空検証、sealed後作成拒絶）。
- **タスク 1.8**: preview成果物の一回限り生成制御（既存preview存在時の上書き拒絶、更新時のsupersede要求）。
- **タスク 1.9**: 本番Pass 2確定関数 `finalize_pass2()` の実装（信頼境界検証、排他ロック、staging検証、promotion、原子的更新、冪等回復、確定済み上書き拒絶）。
- **タスク 1.10**: Pass 3確定関数 `finalize_pass3()` の実装（信頼境界検証、排他ロック、staging検証、promotion、由来ハッシュ記録、staging空検証、`sealed` 封印、ロック解放）。
- **タスク 1.11**: 共通確定CLIラッパー `.agents/shared/finalize_run_stage.R` の新設（allowlist検証: target-name basename/skill-stage導出一致、source staging配下通常ファイル限定）。
- **タスク 1.12**: legacy run（v1.0）読み取り限定モード（`--allow-legacy-run-meta`、preview許可、本番確定・sealed・supersede元指定拒絶）。
- **タスク 1.13**: supersede元run検証関数の実装（skill一致、マニフェスト実バイト列ハッシュ、自己/循環参照拒絶、failed run / legacy run拒絶、partial run整合性検証）。
- **タスク 1.14**: `cwd` 付き kind タグ付き機械可読ハンドオーバー `run_handover.json` 生成関数の実装。
- **タスク 1.15**: `resolve_pass3_run_dir()` の改定（暗黙mtime廃止、親直下＋サブディレクトリ合算探索）。

### フェーズ 2: Bayesian Evidence スキルテンプレート改定
- **タスク 2.1**: `pass1_compute.R` / `analysis.R` での結果マニフェスト出力、設定スナップショット保存、ハンドオーバー出力、`--supersedes-run` 対応。
- **タスク 2.2**: `pass2_stub.R` の出力を `executive_summary_preview.md` に変更、既存preview上書き拒絶、`pass2 = "stub_generated"` 記録。
- **タスク 2.3**: `render_dashboard.R` の `--run-dir` 直接受け入れ、プレビュー出力（`dashboard_preview.html`、未封印、上書き拒絶、バナー）、本番出力（`dashboard.html`、Pass 2確定後、排他ロックおよびstaging経由 `finalize_pass3` による sealed 封印）。
- **タスク 2.4**: `dashboard.Rmd` の `self_contained: true` 明示、二重探索廃止、バナー表示。

### フェーズ 3: Categorical Analysis スキルテンプレート改定
- **タスク 3.1**: `analysis.R` における Pass 1 唯一run作成原則の確立（`claim_resumable_profile_run()` および `.render_claim` 機構の完全廃止、`--profile` は consultation workspace へのプロファイル出力限定、`--render --config` が正式run予約）、マニフェスト出力、スナップショット保存。
- **タスク 3.2**: Categorical 専用薄型 CLI レンダラー `templates/render_dashboard.R` の新設（プレビュー未封印、本番 sealed 封印）。
- **タスク 3.3**: `dashboard.Rmd` の `self_contained: true` 明示、公開 HTML のローカル一時アセット依存排除。
- **タスク 3.4**: run予約の衝突回避を維持し、旧状態を active / sealed と pass_status に移行して既存の分離テストを改定する。

### フェーズ 4: Questionnaire Batch Analysis スキルテンプレート改定
- **タスク 4.1**: `batch_runner.R` における親直下出力の完全廃止（`runs/<id>` 強制隔離）、全設問結果に応じた 3 区分状態遷移（`completed` / `partial` / `failed`）の実装、診断成果物保持、成功設問と manifest の完全一致検証、ハンドオーバー出力、`--supersedes-run` 対応（partial 許可、failed 拒絶）。
- **タスク 4.2**: Questionnaire 専用薄型 CLI レンダラー `templates/render_dashboard.R` の新設（partial/failed 本番遮断、プレビュー未封印、本番 sealed 封印）。
- **タスク 4.3**: `dashboard.Rmd` の `self_contained: true` 明示、公開 HTML のローカル一時アセット依存排除。
- **タスク 4.4**: 設問横断考察成果物 `cross_question_summary.md` の排他ロックおよび staging 経由 `finalize_pass2()` / `finalize_run_stage.R` 確定処理。

### フェーズ 5: 統合テストスイート新設・回帰検証・SKILL.md更新
- **タスク 5.1**: 新規統合テストスイート `tests/test_run_scope_lifecycle.R` の作成（FAIL-FAST、同一秒隔離、パストラバーサル、設定保存、`inputs` 正本、マニフェスト実バイト列ハッシュ、スキーマ制約、Categorical claim 廃止、run 外排他ロック信頼境界検証、同時実行排他、stale ロック回復、legacy run preview 許可・本番確定拒絶、staging promotion、クラッシュ回復、ハッシュ不一致上書き拒絶、sealed 前 staging 空検証、preview 再実行拒絶、Questionnaire partial/failed 遮断、allowlist 攻撃テスト、3 スキル self_contained 単一ファイル性、sealed 封印保護、supersede 厳格検証、ハンドオーバー再現実行、Questionnaire 隔離等）。
- **タスク 5.2**: 各スキル `SKILL.md`（4スキル）の文書更新（4-Pass 正式対応表、マニフェスト、run 外排他ロック、staging 確定、preview 分離・一回限り、legacy run 読み取り限定、Questionnaire 3 区分状態、sealed ライフサイクル、allowlist 仕様、AI 完了報告 4 大要素）。
- **タスク 5.3**: 既存の全テストスイート（`tests/test_*.R`）を実行し、既存統計計算およびモデル評価の振る舞いにリグレッションがないことを確認。

## 4. 既存差分の保護方針

- 作業ツリーには本変更の計画文書に加え、文書アーカイブ・README・TODO・QA記録等の既存差分がある。Apply開始時に差分を再取得し、既存差分を保持して本実装による差分と区別する。
- 既存の統計計算ロジック（Bayesian 推定、対数線形モデル適合、残差二乗、BIC、Cramér's V 等）およびモデル評価アルゴリズム本体には一切の破壊的変更を加えない。
- 変更は、出力ディレクトリ決定、成果物確定ハンドオーバー、排他ロック、メタデータ管理、および CLI ラッパーのインターフェース層に限定する。

## 5. 段階的テスト方針

1. **単体レベル（フェーズ 1 完了時）**:
   - `assert_valid_out_root()`, `acquire_stage_lock()`, `write_results_manifest()`, `finalize_pass2()` などの単体テストを実施し、境界条件や異常入力の遮断を検証。
2. **テンプレートレベル（フェーズ 2〜4 完了時）**:
   - 各スキルの Pass 1、Pass 2、Pass 3 を個別実行し、成果物の出力パス、staging からの promotion、`results_manifest.json` の整合性を検証。
3. **結合・境界レベル（フェーズ 5）**:
   - 新規テスト `tests/test_run_scope_lifecycle.R` を実行し、並行実行競合、改ざんメタデータ、模擬クラッシュ、部分失敗時の遮断を網羅的に検証。
4. **全体回帰テスト**:
   - 独立実行型の `tests/test_*.R` を各々 `Rscript <file>` で実行し、終了コードとログを収集する。`tests/statistical_foundations/` のテストおよび変更対象に関係する Python 契約テストも実行する。既存失敗は着手前との差分で区別し、未実行や隔離済みテストを合格数に含めない。

## 6. 作業スコープとガバナンス境界

- 本計画書に基づく実装作業は、ローカルワークスペース内でのコード・テスト・テンプレート作成および実行検証に限定する。
- **明示的なユーザー承認なしに Git commit や Git push は一切実行しない**。
- 実装着手（Apply）は、本計画書のユーザー承認後に開始する。

## 7. 承認欄

- [x] 本実装計画書（`docs/Artifacts/implementation_plan_006_0908.md`）の記載内容を確認し、OpenSpec change `harden-run-path-handover` のコード実装（Apply）着手を承認する。

## 8. 計画FIXの受入条件

計画文書の最終整合を確定した。実装タスクの正本は [tasks.md](../../openspec/changes/harden-run-path-handover/tasks.md)（30件）とし、[仕様](../../openspec/changes/harden-run-path-handover/specs/run-output-lifecycle/spec.md)および[設計](../../openspec/changes/harden-run-path-handover/design.md)の最終補足契約を含めて実装する。

run 共通ロック、source 消失後の回復証跡、preview 競合、Questionnaire の設問別配置・非ゼロ終了・診断 handover、legacy preview の元 run 外隔離を既存タスクの完了条件に含める。公開 HTML のローカル依存を検証し、完全オフライン化を追加要件にしない。

計画FIXは実装済みを意味しない。実装の明示指示後、既存差分を再確認して着手し、各タスクの検証証拠が得られてからチェックを付ける。

## 9. 検証指摘への修正実装

ユーザーの「発見した問題をきみが解決して」により、本計画と検証報告書 verification_report_001_0908.md の指摘修正を実施する。既存実装差分を退避し、共通ガード、状態遷移、回復証跡、各CLI、回帰検証の順で修正する。統計上の受入基準は変更しない。
