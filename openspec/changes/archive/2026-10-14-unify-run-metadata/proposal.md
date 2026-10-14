# Proposal

## Why

本リポジトリの解析スキル（VCD系、SAS系、questionnaire、comparative-design、evidence-decision-review）において、Run内部のメタデータファイル構成（manifest.json vs run_meta.json vs run_state.json）、ライフサイクル状態（run_state）、実行環境の再現性メタデータ、および横断索引（runs_index.jsonl / latest.json）の管理方式に不統一が残っている。

特に現行仕様と実装の間で以下の不整合・課題が存在する：

1. `sas-proc-freq` および `sas-proc-means` は個別の `manifest.json` を出力しているが、他スキルでは `run_meta.json` と `results_manifest.json` による2層監査契約へ移行しているため、SAS成果物の監査体系が二重化・孤立している。
2. `vcd-categorical-analysis` ではrunディレクトリ内に `run_state.json` を出力しているが、これは `run_meta.json` の `run_state` フィールドと責務が重複している。
3. 全スキル横断の実行環境（Rバージョン、OS platform、依存パッケージバージョン、乱数シード、sessionInfo）の再現性記録契約が未統一であり、監査時の環境再現性が担保されていない。
4. 出力ルート直下における過去実行の横断索引（`runs_index.jsonl`）および最新実行ポインタ（`latest.json`）の配置契約が未標準化である。

本Changeにより、全解析スキルのrunメタデータおよび索引契約を `run_meta.json` と `results_manifest.json` に一本化し、完全な決定論的再現性と横断監査可能性を確立する。

## What Changes

- **BREAKING**:
  - `sas-proc-freq` / `sas-proc-means`: run内の個別 `manifest.json` を廃止し、内容を `run_meta.json`（環境・設定・ステータス）および `results_manifest.json`（成果物SHA-256）へ完全移行する。下流処理およびテストは `run_meta.json` / `results_manifest.json` を参照するよう更新される。
  - `two-way-evidence-analysis`: runディレクトリ内に生成されていた `run_state.json` を廃止し、ライフサイクル状態を `run_meta.json` の `run_state` フィールドへ統合する。ただし、runディレクトリ作成前の早期失敗を記録する出力root直下の `run_state.json` は引き続き維持する。
- **ADDITIONS**:
  - `run_state` の正規語彙を `active / completed / failed / sealed` の4状態に規定し、`sealed` への遷移は不可逆の一方向とする。単一パススキル（`vcd-categorical-reporting`, `evidence-decision-review` 等）は正常終了時に `completed` を記録し、異常終了やクラッシュで中断された run は `active` のまま残る。
  - `run_meta.json` の `timestamps` は実行環境のローカルタイムゾーンではなく JST（`Asia/Tokyo`、オフセット付き ISO 8601）で固定記録し、旧 manifest.json の JST 保証および AGENTS.md 契約を維持する。
  - `run_meta.json` に共通の `environment` ブロック（`r_version, platform, packages[{name,version}], seed, session_info_path`）を必須化し、完全な `sessionInfo()` 出力（`session_info.txt`）を生成して `results_manifest.json` に登録する（既存runの読み取りは寛容モード）。
  - 各解析スキルの出力root直下に、追記専用の横断実行台帳 `runs_index.jsonl`（1行1確定事象の履歴ログ。同一runが複数行になり得、読み取り側は `run_id` ごとの最終行を現在状態として採用）と、原子的更新（tmp→rename、symlink不使用）による最新実行ポインタ `latest.json` を配備する。
  - `two-way-evidence-analysis` の同一署名並行実行排他ロックについて、出力root直下の予約ディレクトリ `<out_root>/.run_locks/<signature16>.lock`（`lock_info.json` 保持）による署名ロック契約を明文化し、先行実行中は `CONCURRENT_RUN_IN_PROGRESS`、権限不足等の作成不能は `CANNOT_CREATE_LOCK_DIR` として区別記録する。また `.run_locks` は出力ルート直下の予約ディレクトリとし、run列挙処理は `run_*` でフィルタリングすることを規定する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `evidence-run-layout`: `run_state` 語彙（`active/completed/failed/sealed`、中断された run の扱い）、JST タイムスタンプ契約、共通 `environment` ブロック契約、および出力root直下の `runs_index.jsonl`（1行1確定事象）/ `latest.json` 契約を規定・拡張する。
- `sas-proc-freq`: 成果物仕様から `manifest.json` を削除し、`run_meta.json` および `results_manifest.json` への統合仕様に改定する。
- `sas-proc-means`: 成果物仕様から `manifest.json` を削除し、`run_meta.json` および `results_manifest.json` への統合仕様に改定する。
- `two-way-evidence-analysis`: run内の `run_state.json` を廃止して `run_meta.json` へ統合し、出力root直下の早期失敗 `run_state.json` の維持契約、および `.run_locks` 署名ロック（`CONCURRENT_RUN_IN_PROGRESS`, `CANNOT_CREATE_LOCK_DIR`）契約を明確化する。

## Impact

- **Affected specifications**:
  - `openspec/specs/evidence-run-layout/`
  - `openspec/specs/sas-proc-freq/`
  - `openspec/specs/sas-proc-means/`
  - `openspec/specs/two-way-evidence-analysis/`
- **Affected documentation**:
  - `AGENTS.md`（契約文言の確認）
  - `README.md`
  - `docs/Artifacts/README.md`
  - 各解析スキルの `SKILL.md`（特に SAS 2スキルおよび vcd-categorical-analysis）
- **Affected implementation**:
  - `.agents/shared/run_scope.R`: `write_run_meta()`（JSTタイムスタンプ固定、`environment` 統合）、`collect_run_environment()`, `append_run_index()`, `write_latest()`, `read_run_control()`
  - `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`: 正常終了時 `run_state = "completed"`
  - `.agents/shared/evidence_feature_extract.R`: 正常終了時 `run_state = "completed"`
  - `.agents/skills/sas-proc-freq/templates/run_freq.R`: `manifest.json` 出力撤廃と `run_meta.json` 強化
  - `.agents/skills/sas-proc-means/templates/run_means.R`: `manifest.json` 出力撤廃と `run_meta.json` 強化
  - `.agents/skills/vcd-categorical-analysis/templates/analysis.R`: run内 `run_state.json` 出力撤廃
- **Affected verification**:
  - SAS数値パリティ・回帰テスト（`manifest.json` 依存のアサーションを `run_meta.json` / `results_manifest.json` へ移行）
  - run隔離・ロックテスト（`test_run_scope_lock.R`, `test_vcd_categorical_run_isolation.R`, `test_vcd_categorical_pass0_boundary.R`）
- **Preserved guarantees**:
  - 統計推定値、乱数再現性、計算ロジック、および出力される主結果（JSON/CSV/HTML/MD）の統計数値は一切変化しない。
  - 物理ディレクトリ名の決定ロジックは一切変更せず、現行実装と現行仕様を維持する。
