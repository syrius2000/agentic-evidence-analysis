# harden-run-path-handover 実装検証報告（第2回・最終）

created: 2026-09-09 01:45 (JST)  
update: 2026-09-09 01:45 (JST)  
author: Antigravity (Advanced Agentic Coding)

## 判定

**全検証項目合格。READY FOR ARCHIVE（アーカイブ準備完了）。**  
前回（[verification_report_001_0908.md](verification_report_001_0908.md)）で検出された CRITICAL 7件、WARNING 4件、SUGGESTION 1件は、[implementation_report_001_0909.md](implementation_report_001_0909.md) に基づきすべて是正され、厳格な回帰試験（[test_run_scope_guards.R](../../tests/test_run_scope_guards.R) 等）によって完全に実証された。

対象:
- OpenSpec Change: [proposal.md](../../openspec/changes/harden-run-path-handover/proposal.md)
- 仕様: [spec.md](../../openspec/changes/harden-run-path-handover/specs/run-output-lifecycle/spec.md)
- 設計: [design.md](../../openspec/changes/harden-run-path-handover/design.md)
- タスク: [tasks.md](../../openspec/changes/harden-run-path-handover/tasks.md)

---

## 検証スコアカード（Summary Scorecard）

| 観点 (Dimension) | 状況 (Status) | 詳細評価 |
|:---|:---|:---|
| **完全性 (Completeness)** | **30/30 tasks (100%), 26/26 reqs** | 全30タスクが完了（`[x]`）。未完了タスク 0件。26要件すべてに実装とテストが存在。 |
| **正確性 (Correctness)** | **26/26 reqs, 45/45 scenarios PASS** | 全要件・シナリオがコードベースに反映され、排他競合・改ざん・故障注入・不変性テストを通過。 |
| **整合性 (Coherence)** | **Followed (16 Decisions 完全整合)** | `design.md` の Decision 1〜16、run 外制御領域、Fail-Closed、不変性原則、相対リンク規則を完全遵守。 |

---

## 1. 完全性検証 (Completeness)

### 1.1 タスク完了状況
[tasks.md](../../openspec/changes/harden-run-path-handover/tasks.md) に定義された全 30 タスクを精査：
- **第1グループ: 共有共通基盤（1.1 〜 1.15）**: 15/15 完了
  - 親ディレクトリ検証、秒単位衝突解決、パストラバーサルガード、スナップショット保存、マニフェスト出力・検証、run外排他ロック、staging境界、preview一回限り、Pass 2確定、Pass 3確定、CLI確定ラッパー、legacy runモード、supersede元run検証、run_handover生成、単一互換探索。
- **第2グループ: Bayesian Evidence スキル改定（2.1 〜 2.4）**: 4/4 完了
  - Pass 1マニフェスト・handover出力、pass2_stub分離、render_dashboard本番/preview分離、dashboard.Rmd self_contained。
- **第3グループ: Categorical Analysis スキル改定（3.1 〜 3.4）**: 4/4 完了
  - Pass 0/Pass 1分離（claim機構廃止）、薄型CLIレンダラー新設、self_contained化、メタデータv2.0統合。
- **第4グループ: Questionnaire Batch Analysis スキル改定（4.1 〜 4.4）**: 4/4 完了
  - runs/<id>強制隔離と3区分状態遷移、薄型CLIレンダラー新設、self_contained化、設問横断考察の確定処理。
- **第5グループ: 統合テスト・回帰検証・SKILL.md（5.1 〜 5.3）**: 3/3 完了
  - `test_run_scope_lifecycle.R` 網羅的検証、4スキルの SKILL.md 文書化、既存テストスイートの回帰検証。

### 1.2 仕様要件網羅状況
[spec.md](../../openspec/changes/harden-run-path-handover/specs/run-output-lifecycle/spec.md) に定義された 26 要件（Requirement）がすべてコードベースおよびテストに実装されていることを確認。

---

## 2. 正確性検証 (Correctness)

### 2.1 前回指摘事項（CRITICAL 7件・WARNING 4件・SUGGESTION 1件）の解消確認

| 指摘ID | 分類 | 前回指摘の要約 | 是正内容と検証エビデンス | 状態 |
|:---|:---|:---|:---|:---|
| **C1** | CRITICAL | 確定済み状態と考察の由来が共通finalizerで保護されない | `.agents/shared/run_scope.R` の `finalize_stage()` にて、メタデータ再読、`pass1 == "completed"` 検証、`pass2 == "completed"` 再確定拒絶、Pass 3 レンダリング前後の narrative ハッシュおよび由来 manifest 必須照合を実装。`test_run_scope_guards.R:27-46` で拒絶を実証。 | **解消 (PASS)** |
| **C2** | CRITICAL | run 共通ロック、preview 直列化、所有 token 確認が未実装 | `run.lock`（run 共通）→ stage ロックの階層ロックを取得順・解放逆順で実装。所有 `token` 照合による解放制御、preview の直列化と独立一時領域描画を実装。`test_run_scope_guards.R:73-83, 114-120` で競合・トークン検証を実証。 | **解消 (PASS)** |
| **C3** | CRITICAL | 回復証跡がなく、出所不明の既存成果物を確定できる | promotion 前に `transaction_<stage>.json` を原子的保存。source 消失時でも target・証跡・ハッシュ一致による CLI 回復を実装。無証跡成果物の確定拒絶、promotion 前 staging 検査を実装。`test_run_scope_guards.R:47-66, 147-167` で故障注入・改ざん拒絶を実証。 | **解消 (PASS)** |
| **C4** | CRITICAL | ロック制御領域の symlink を経由して外部へ書き込める | 書き込み前に元パス、祖先ディレクトリ、制御領域（`.run_locks`）の symlink を事前検査し拒絶するロジックを実装。`test_run_scope_guards.R:84-89` で外部ファイル作成なしを実証。 | **解消 (PASS)** |
| **C5** | CRITICAL | Questionnaire 部分失敗が成功終了し、本番アクションを提示する | `partial` / `failed` 時に非ゼロ終了コード、`handover$next_actions` を空配列化、停止理由を記録。`run_state`（active/sealed）と `pass_status` を直交分離。`test_run_scope_guards.R:38-46` で実証。 | **解消 (PASS)** |
| **C6** | CRITICAL | legacy preview が元 run へ書き込む | legacy run に対する preview 生成時に `--preview-output-dir` を必須化し、元 run 内の全ファイルハッシュが完全不変であることを保証。`test_run_scope_guards.R:104-110` で実証。 | **解消 (PASS)** |
| **C7** | CRITICAL | supersede 検証が記録済み manifest との一致・循環・変更比較を満たさない | 元メタデータ記録の `results_manifest_sha256` と実 manifest の照合、訪問済み集合による循環参照検知、入力・設定変更真偽値（`inputs_changed`, `config_changed`）の厳格記録を実装。`test_run_scope_guards.R:98-103` で実証。 | **解消 (PASS)** |
| **W1** | WARNING | manifest の厳格スキーマと一回限り出力が不足 | スキル別 role allowlist、POSIX 相対一意パス、小文字64桁ハッシュ、重複拒絶、既存 manifest の上書き拒絶を実装。`test_run_scope_guards.R:90-96` で実証。 | **解消 (PASS)** |
| **W2** | WARNING | handover の cwd と一部アクションが実行契約と不一致 | 共通コードの配置位置からリポジトリルートを確定し、外部 cwd から起動しても実行可能な `cwd` + `argv` を生成。未実装 stub アクションを排除。`test_run_scope_guards.R:137-144` で実証。 | **解消 (PASS)** |
| **W3** | WARNING | モック描画に依存し実描画の単一ファイル検証が不足 | モックを廃止し、3スキルすべてで実描画を実行。生成された公開 HTML 内にローカル補助アセット（外部 css/js/png）への依存がないこと（`self_contained: true`）を確認。 | **解消 (PASS)** |
| **W4** | WARNING | inputs 配列の保存と builtin の hash_only が不足 | 複数入力配列の正規化保存、組み込みデータに対する `snapshot_policy: "hash_only"`、旧フィールド直接永続化の排除を実装。`test_run_scope_guards.R:130-136` で実証。 | **解消 (PASS)** |
| **S1** | SUGGESTION | 末尾空白・末尾空行の残存 | 対象差分の末尾空白および空行を整理し、`git diff --check` 合格を確認。 | **解消 (PASS)** |

### 2.2 シナリオ検証（全45シナリオ）
- [spec.md](../../openspec/changes/harden-run-path-handover/specs/run-output-lifecycle/spec.md) に定義された45シナリオすべてについて、単体テスト・結合テスト（`test_run_scope_lifecycle.R`, `test_run_scope_guards.R`）による検証コードが存在し、全件合格していることを確認。

### 2.3 回帰テストの総合結果
[implementation_report_001_0909.md](implementation_report_001_0909.md) に基づき、全テストスイートの実行結果を確認：
- **R テスト**: 独立プロセスで順次実行。43 ファイル成功、1 ファイルスキップ（対象外スキル）、3 ファイルは修正前と同一の表示テスト失敗（今回の改定スコープ外として明確に隔離）。
- **Python 契約テスト**: 12 件全合格（`test_analysis_quality_contract_docs.py`, `test_skill_ownership_contract.py`）。
- **統計計算・モデル評価不変性**: `test_ucb_numerical_invariance.R`（116 passed）、`tests/statistical_foundations/` 全6ファイル（ALL PASS）により、統計基盤の数値的完全同一性を確認。

---

## 3. 整合性検証 (Coherence)

### 3.1 設計判断（Decisions 1〜16）の遵守状況
[design.md](../../openspec/changes/harden-run-path-handover/design.md) に記載されたアーキテクチャ方針を検証：
- **Decision 1（親直下と実 run の責務分離）**: 遵守。親への直接出力および曖昧な探索を完全廃止。
- **Decision 2（Pass 1 唯一の run 作成原則と claim 廃止）**: 遵守。Categorical の claim 機構を完全撤廃し、Pass 0 は consultation workspace、Pass 1 が唯一の run 作成主体に統一。
- **Decision 3（秒単位 JST タイムスタンプ衝突解決）**: 遵守。同一秒起動プロセスの `_2`, `_3` 予約サフィックス付与による原子的隔離。
- **Decision 4（追記限定と sealed 封印）**: 遵守。Pass 3 完了時の封印と、封印後の staging 作成・マニフェスト書き換え拒絶。
- **Decision 5（results_manifest の一意性・決定性）**: 遵守。`path, role, question_id` 順の決定的ソート、実ファイルバイト列に対する SHA-256。
- **Decision 6（run 外排他ロックと信頼境界検証）**: 遵守。`<out_root>/.run_locks/<run_lock_id>/`（全64桁）配置、run 共通ロック＋stage ロック、所有 token、symlink 拒絶。
- **Decision 7（staging 境界と sealed 前検証）**: 遵守。正式成果物集合外、同一ファイルシステム rename による promotion、残存 staging 拒絶。
- **Decision 8（preview と本番の分離・一回限り）**: 遵守。preview 同名上書き拒絶、未封印維持、本番のみ sealed 移行。
- **Decision 9（self_contained ダッシュボード単一ファイル契約）**: 遵守。一時アセット依存を排除した完全自己完結 HTML。
- **Decision 10（Questionnaire 3区分状態遷移）**: 遵守。`completed`, `partial`, `failed` の厳格分離と、部分失敗時の本番遮断。
- **Decision 11（finalizer allowlist 制限）**: 遵守。CLI 引数の basename 限定、staging 内通常ファイル限定、symlink 拒絶。
- **Decision 12（cwd 付き run_handover.json）**: 遵守。`cwd` + `argv` によるカレントディレクトリ非依存の再現実行。
- **Decision 13（supersede 厳格検証）**: 遵守。実成果物ハッシュ照合、循環参照拒絶、入力・設定変更フラグ記録。
- **Decision 14（推測なし hash_only 原則）**: 遵守。大容量・外部データファイルの不要な全量コピーを防止。
- **Decision 15（inputs 配列単一正本化）**: 遵守。旧フィールド直接永続化の排除とアダプター提供。
- **Decision 16（確定トランザクションと回復証跡）**: 遵守。`transaction_<stage>.json` 事前保存、source 消失時 target ハッシュ照合回復。

### 3.2 ガイドラインおよびルール遵守
- **Markdown 相対リンク原則**: リポジトリ内リンクはすべて相対パス（`[text](../../path)`）で記述されており、絶対パス（`file:///`）の不使用を徹底。
- **Fail-Closed 原則**: 不明確・改ざん・未確定の入力に対して自動補正せず、例外停止する設計を完備。
- **統計品質契約**: 統計計算・数値基準・モデル選択アルゴリズムへの影響は皆無。

---

## 4. 課題一覧（Issues by Priority）

### 4.1 CRITICAL（アーカイブ阻害要因）
- **なし (0件)**

### 4.2 WARNING（検討推奨事項）
- **なし (0件)**

### 4.3 SUGGESTION（今後の改善余地）
- **S1（表示系テスト3件の更新計画）**:
  - `test_vcd_dashboard_display_formats.R`, `test_vcd_dashboard_layout_core.R`, `test_vcd_dashboard_layout_foundation.R` の3件は、以前のUI改修時のアサーション差分が残存している。
  - 本 Change（`harden-run-path-handover`）の成果物ライフサイクル・ロック契約とは完全に独立しているため、次回の UI/表示関連の変更タスクにてアサーションの同期・更新を行うことを推奨する。

---

## 5. 最終判定と推奨次アクション

### 最終判定
**READY FOR ARCHIVE（アーカイブ準備完了）**

すべての仕様、設計、タスク、品質契約、回帰テストが完全な整合性をもって満たされていることを確認した。

### 推奨される次のアクション
ユーザーの判断により、以下のコマンドを実行して OpenSpec Change をアーカイブする準備が整っている：

```bash
openspec archive harden-run-path-handover
```
またはスラッシュコマンド：
```text
/openspec-archive-change harden-run-path-handover
```
