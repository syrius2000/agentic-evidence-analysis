## Why

分析パイプライン（Pass 0 〜 Pass 3）において、各スキル（`vcd-bayesian-evidence-analysis`, `vcd-categorical-analysis`, `questionnaire-batch-analysis`, `vcd-pass0-consultation`）の間で出力先の決定権限と後続処理への引き継ぎルールが曖昧であるため、以下の実務的リスクが存在します：

1. **暗黙的探索による結果取り違え**: Pass 3（ダッシュボード描画）が親ディレクトリ配下のファイルの更新日時（mtime）から最新 run を自動探索（`resolve_pass3_run_dir`）する経路に依存しており、複数 run が存在する場合に意図しない別 run の結果を描画・統合する危険がある。
2. **二重階層化とパス混乱**: Pass 0 や利用者が `output_dir` に既に run 階層を含むパス（例: `output/project/run_01`）を指定した場合、Pass 1 がその配下にさらに `run_<prefix>` を作成し、意図しない二重階層（`run_01/run_<prefix>`）が発生する。
3. **無言上書きと衝突**: 新規分析（設定変更）と既存分析の継続（Pass 2/3）の区別が曖昧で、既存 run に対する予期せぬ上書きや破壊的変更が発生しうる。
4. **利用者の確認負荷**: AI による完了報告の形式が統一されておらず、「結局どの HTML を開けばよいか」「どの run ディレクトリが成果物なのか」の確認に手間がかかる。

本変更は、単なるディレクトリ名の画一的統一ではなく、**「誰が出力親ディレクトリを決め、Pass 1 がどの実 run ディレクトリを確定し、Pass 2/3 がそれをどう厳密に引き継ぐか」** という成果物ライフサイクルのガバナンスを確立し、分析パイプラインの再現性・堅牢性を担保します。

## What Changes

- **出力親ディレクトリと実 run ディレクトリの明確な責務分離**:
  - Pass 0 は案件・手法に応じた「親ディレクトリ（`output_dir`）」と「実行識別子（`run_id`）」を設定ファイル（`analysis_config.json`）で確定する。
  - Pass 1 は親ディレクトリと `run_id` から「実際の run ディレクトリ（`run_output_dir`）」を一意に決定・確保し、二重階層化（親パス末尾に既に `run_` がある場合の重複作成）を防止して `run_meta.json` に記録する。
- **実 run パスの直接引き継ぎ（暗黙探索の廃止・安全化）**:
  - Pass 2（AI 考察）および Pass 3（ダッシュボード生成）は、親ディレクトリからの曖昧な最新 mtime 探索に依存せず、**Pass 1 が確定した「実際の run ディレクトリ」を直接指定して実行**するプロトコルを確立する。
  - レンダラースクリプト（`render_dashboard.R` 等）において、直接 run ディレクトリが渡された場合はそれを厳密に採用し、親ディレクトリ探索を行う場合も警告と検証を強化する。
- **親ディレクトリ階層と run 隔離の標準配置の定義**:
  - 正式分析: `output/<案件名>/<手法・スキル>/`（consultation, vcd_bayesian, vcd_categorical, questionnaire を案件配下で並列管理）
  - 手動試行・スモーク確認: `skill_out/<スキル>/`
  - 自動テスト: `tests/` 内の一時ディレクトリ
  - 既存の `run_<id>`（単一表）と `runs/<id>`（バッチ設問）の構造差は無理に一度に壊さず、局所的な安全性を最優先とする。
- **新規分析・継続実行・再計算のライフサイクル規約**:
  - 新規分析／設定変更: 新しい明示的 `run_id` を発行。
  - Pass 2 追記／Pass 3 描画: 確定済みの同一 run ディレクトリを直接指定して継続。
  - 既存 run への再計算: 破壊的変更・上書き可否の明示的確認を必須化。
- **AI 完了報告フォーマットの標準化（4大要素）**:
  - 主レポートへの直接リンク（相対パス）
  - 実行ディレクトリ（成果物が集約されている実パス）
  - 再現用設定・結果 JSON へのリンク
  - 現在の完了状態（Pass 1完了 / 考察未作成 / ダッシュボード作成済み 等）

## Capabilities

### New Capabilities
- `run-output-lifecycle`: 分析パイプラインにおける出力親ディレクトリの確定、実 run ディレクトリの決定・二重階層防止、メタデータ（`run_meta.json`）の記録、および Pass 2/Pass 3 への厳密な実パス引き継ぎと完了報告規約。

### Modified Capabilities
<!-- 既存 Capability (cell-evidence-interpretation, three-way-model-assessment, three-way-validation-cases) の要件変更はなし。 -->

## Impact

- **共有共通スクリプト**:
  - `.agents/shared/run_scope.R`: run ディレクトリ解決ロジック（`run_output_dir_from_root`、`resolve_pass3_run_dir`、二重階層防止、直接 run 指定の優先サポート）。
- **スキルテンプレート**:
  - `.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R` & `render_dashboard.R`
  - `.agents/skills/vcd-categorical-analysis/templates/analysis.R` & `dashboard.Rmd`
  - `.agents/skills/questionnaire-batch-analysis/templates/batch_runner.R`
  - `.agents/shared/inspect_data.R` (Pass 0)
- **スキル指示文書 (SKILL.md)**:
  - 各スキルの実行コマンド例、引数引き継ぎ手順、AI完了報告フォーマットの記載更新。
- **テストスイート**:
  - 実 run ディレクトリ直接指定、二重階層防止、Pass 1→2→3 引き継ぎの単体・回帰テストの追加。
