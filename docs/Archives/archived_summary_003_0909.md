# 成果物ライフサイクル堅牢化・実行パス引き継ぎおよびモデル記法形式化アーカイブ

created: 2026-09-09 07:45 (JST)  
update: 2026-09-09 07:45 (JST)  
author: Antigravity (Advanced Agentic Coding)

対象期間: 2026-09-08 〜 2026-09-09

---

## アーカイブ概要

本書は、2026年9月8日から9日にかけて推進された2大開発テーマ：
1. **ログ線形モデル記法の形式化・階層順序確立（`formalize-loglinear-model-notations`）**
2. **実行成果物ライフサイクルと実行パス引き継ぎの堅牢化（`harden-run-path-handover`）**

のうち、特に後者の実装計画書、品質検証報告書、修正実装報告書を1本に集約した恒久的な履歴文書である。

対象文書はすべて OpenSpec Change `harden-run-path-handover` の承認、実装、検証、およびアーカイブ完了（コミット `db7994d`）に伴い完了した過去成果物であり、現在の `./docs/Artifacts/` を整理して再現性とトレーサビリティを担保するために本アーカイブへ統合した。

既存の過年度アーカイブは [archived_summary_001_0906.md](./archived_summary_001_0906.md) および [archived_summary_002_0908.md](./archived_summary_002_0908.md) に保持されている。

---

## アーカイブ元文書

1. `docs/Artifacts/implementation_plan_006_0908.md`（実行成果物ライフサイクルと実行パス引き継ぎの堅牢化 実装計画書）
2. `docs/Artifacts/verification_report_001_0908.md`（harden-run-path-handover 実装検証報告 第1回：CRITICAL 7件、WARNING 4件）
3. `docs/Artifacts/implementation_report_001_0909.md`（harden-run-path-handover 検証指摘への修正実装報告）
4. `docs/Artifacts/verification_report_002_0909.md`（harden-run-path-handover 実装検証報告 第2回・最終）
5. `docs/Artifacts/verification_report_003_0909.md`（harden-run-path-handover 実装検証報告 Codex・独立再検証）

---

## 第1部: 開発の背景と2大テーマの位置づけ

本リポジトリでは、統計学・薬学・リアルワールドデータ（RWD）分析におけるエビデンス推論の再現性と自動化を追求しており、直近で以下の2つのテーマが順次実施された。

### 1.1 テーマ1: ログ線形モデル記法の形式化（`formalize-loglinear-model-notations`）
- **背景と目的**: 3次元カテゴリカルデータ分析において、モデル名の不統一や階層順序の曖昧さが、オラクル適合やAIC/BIC比較の自動検証を困難にしていた。
- **主要成果**: 相互独立モデル `[A][B][C]` から飽和モデル `[ABC]` に至る9候補モデルの標準記法、`model_order`、`model_spec_oracle` の決定論的照合を形式化。OpenSpec 仕様として `openspec/changes/archive/2026-09-08-formalize-loglinear-model-notations/` にアーカイブ完了。
- **課題の抽出**: 統計モデルの計算仕様が確立したことで、逆に「複数スキル間（Bayesian, Categorical, Questionnaire）での出力ディレクトリの決定」「中間成果物の上書き・取り違え」「クラッシュ時の中断回復」「AI考察（Pass 2）とダッシュボードレンダリング（Pass 3）のパス引き継ぎ」といったファイルシステム・ライフサイクル層の脆弱性が顕在化した。

### 1.2 テーマ2: 実行成果物ライフサイクルとパス引き継ぎの堅牢化（`harden-run-path-handover`）
- **背景と目的**: 4-Pass（Pass 0〜Pass 3）パイプラインの実行において、親ディレクトリと実実行ディレクトリの混同、JST秒単位衝突、出所不明な考察の混入、および封印後の無言上書きを防ぐため、厳格なライフサイクルと契約境界を確立した。
- **成果**: OpenSpec delta spec（26要件、45シナリオ）、30の実装タスク、共有基盤（`run_scope.R`, `finalize_run_stage.R`）、および厳格なテスト防護網を構築し、`openspec/specs/run-output-lifecycle/spec.md` として main specs へ統合。

---

## 第2部: `harden-run-path-handover` の主要アーキテクチャ

元計画書（`implementation_plan_006_0908.md`）および実装報告に基づき、以下のアーキテクチャが実装・確立された。

### 2.1 出力親ディレクトリと実実行ディレクトリの明確な分離
- **責務分離**: Pass 0 は親ディレクトリ（`output_dir`）と `run_id` を確定し、Pass 1 が実実行ディレクトリ（`run_output_dir`）を一意に決定・作成する唯一の主体となる。
- **Fail-Closed な親ディレクトリ検証**: 親ディレクトリ引数に誤って `run_*` や既存成果物パスが渡された場合、暗黙の自動読み替えを行わず、診断メッセージを出力して即座にエラー停止する（`assert_valid_out_root()`）。
- **秒単位 JST タイムスタンプ衝突解決**: 同一秒に起動した並行プロセスは、`_2`, `_3` などの予約サフィックスにより原子的に別 run へ隔離される。

### 2.2 Categorical における Pass 1 唯一 run 作成原則と claim 廃止
- Pass 0 補助処理（`analysis.R --profile`）は consultation workspace に `data_profile.json` を出力するのみで、正式 run は作成しない。
- 既存の `claim_resumable_profile_run()` および `.render_claim` 機構を完全撤廃し、Pass 1（`analysis.R --render --config`）が新規正式 run を原子的作成する。

### 2.3 信頼境界検証付き run 外排他ロック（`<out_root>/.run_locks/<run_lock_id>/`）
- **配置境界**: run ディレクトリ内にロックを置くと `sealed` 封印後の不変性と矛盾するため、run 外の管理領域に配置。`run_lock_id` は正規化済み絶対 run パスの SHA-256 全64桁に固定。
- **二重直列化と所有検証**: `run.lock`（run 共通ロック）→ stage ロックの階層取得、逆順解放、所有 `token` 照合による解放制御。
- **symlink 防御**: ロック制御領域および祖先パスの symlink を事前検査し、外部への予期せぬファイル作成を遮断。
- **安全な回復監査**: `--recover-stale-lock` において、同一ホスト・PID不在・経過時間を検証し、`audit.jsonl` に記録。

### 2.4 確定トランザクション・クラッシュ回復と staging promotion
- run 直下への直接書き込みを禁止し、必ず `staging/` 領域で生成・検証した後に同一ファイルシステム内の原子的 rename で promotion。
- promotion 直前に `transaction_<stage>.json` を原子的保存。クラッシュにより source が消失した場合でも、target・回復証跡・期待ハッシュの一致により CLI 回復可能。
- 出所不明な無証跡成果物の確定を拒絶。staging 内に残存ファイルがある場合は本番封印を拒絶。

### 2.5 3スキル共通 `results_manifest.json` と決定的バイト列ハッシュ
- `artifacts` 配列を `path`, `role`, `question_id` 順に決定的一意ソート。
- スキーマ制約（POSIX相対一意パス、role allowlist、小文字64桁ハッシュ）を適用。
- 保存された実ファイルバイト列に対する SHA-256 を `results_manifest_sha256` として記録・照合し、論理正規化による曖昧さを排除。

### 2.6 Questionnaire 3区分状態遷移と部分失敗遮断
- `completed`（全設問成功）、`partial`（一部設問失敗）、`failed`（全設問失敗）を厳格分離。
- 部分失敗および全失敗時は非ゼロ終了コードで終了し、`run_handover.json` の `next_actions` を空配列化して本番 Pass 2/3 確定を確実に遮断。

### 2.7 統一 self_contained ダッシュボード単一ファイル契約
- 3 スキル（Bayesian, Categorical, Questionnaire）共通で `self_contained: true` を明示。
- 公開 HTML がローカル一時アセット（外部CSS/JS/画像）に依存しない単一完結性を保証。

---

## 第3部: 品質是正・検証サイクルの推移

本テーマでは、厳格な品質ループ（計画 → 検証 → 是正 → 再検証）が実行された。

### 3.1 第1回検証での検出事項（`verification_report_001_0908.md`）
初回実装に対する独立検証により、以下の CRITICAL 7件、WARNING 4件が指摘され、アーカイブが一時差し戻された：
- **C1**: 確定済み状態と考察の由来が共通 finalizer で保護されない
- **C2**: run 共通ロック、preview 直列化、所有 token 確認が未実装
- **C3**: 回復証跡がなく、出所不明の既存成果物を確定できる
- **C4**: ロック制御領域の symlink を経由して外部へ書き込める
- **C5**: Questionnaire 部分失敗が成功終了し、本番アクションを提示する
- **C6**: legacy preview が元 run へ書き込む
- **C7**: supersede 検証が記録済み manifest との一致・循環・変更比較を満たさない
- **W1〜W4**: manifest 厳格スキーマ、handover cwd 契約、実描画単一ファイル検証、inputs 配列保存

### 3.2 是正実装と防護境界テスト（`implementation_report_001_0909.md`）
指摘を受け、`.agents/shared/run_scope.R` および `.agents/shared/finalize_run_stage.R` を全面的に改定。
さらに、新設された回帰テスト `tests/test_run_scope_guards.R`（168行）により、故障注入・改ざん注入・実競合・symlink 遮断・証跡回復を実証した。

### 3.3 第2回検証および独立再検証（`verification_report_002_0909.md`, `verification_report_003_0909.md`）
- **完全性**: 全 30 タスク完了（未完了 0件）。
- **正確性**: 26 要件、45 シナリオすべてを網羅。指摘事項 C1〜C7, W1〜W4, S1 すべて PASS。
- **整合性**: `design.md` の Decision 1〜16 に完全準拠。
- **回帰試験結果**:
  - R スクリプト 47ファイル順次実行中 43ファイル成功、1ファイル全体スキップ（対象スキル不在）、3ファイルは改定前と同一内容の表示テスト失敗（今回のスコープ外として隔離）。
  - Python 契約テスト 12件合格（`test_analysis_quality_contract_docs.py`, `test_skill_ownership_contract.py`）。
  - 統計基盤不変性テスト `test_ucb_numerical_invariance.R`（116 passed）、`tests/statistical_foundations/` 全6ファイル（ALL PASS）。
- **判定**: **READY FOR ARCHIVE** を達成し、OpenSpec Change のアーカイブおよび main specs への同期（コミット `db7994d`）を完了。

---

## 第4部: 残存課題と次期アクション境界

1. **表示系テスト3件のアサーション同期（非回帰・スコープ外）**:
   - `tests/test_vcd_dashboard_display_formats.R`
   - `tests/test_vcd_dashboard_layout_core.R`
   - `tests/test_vcd_dashboard_layout_foundation.R`
   - 上記3件は過去のUI微修正時の差分であり、今回の成果物ライフサイクル・ロック契約とは完全に独立している。次期の UI/表示関連の変更タスクにてアサーションを同期する。
2. **新設計画書の採番**:
   - 次回の新しい変更・機能開発においては、本アーカイブによる整理を受け、連番 `docs/Artifacts/implementation_plan_007_{MMDD}.md` を採番して着手する。

---

## アーカイブ時点の注意

本書は元文書の要点、設計判断、検証結果、および修正経緯を統合した恒久的な履歴文書である。コードや仕様の詳細な差分を確認する場合は、アーカイブ済み OpenSpec Change（`openspec/changes/archive/2026-09-09-harden-run-path-handover/`）、Git コミット履歴（`db7994d`）、およびリポジトリ内の再実行可能なテストスイートを参照すること。
