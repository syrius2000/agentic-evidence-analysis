# Spec Delta

## MODIFIED Requirements

### Requirement: Standardized Run State Lifecycle Vocabulary

システムは、すべての解析スキルにおけるRun実行ライフサイクルの状態語彙を `active / completed / failed / sealed` の4値に統一し、不変状態 `sealed` への不可逆遷移を保証しなければならない（MUST）。単一パス解析スキル（`evidence-decision-review`、`sas-proc-freq`、`sas-proc-means` 等）は正常完了時に明示的に `"completed"` を記録しなければならず（MUST）。マルチステージ解析スキル（`vcd-bayesian-evidence-analysis` と `vcd-categorical-reporting`）は、必要な後続レポート生成が完了するまで `"active"` を維持し、最終ステージで正常完了したとき `"sealed"` に遷移しなければならない（MUST）。プロセス異常終了やクラッシュにより終了処理に至らなかったRunは `"active"` のまま残る「中断されたRun」として扱わなければならない（MUST）。

#### Scenario: Run state transitions during execution lifecycle

- **WHEN** 解析処理が開始される
- **THEN** システムは `run_meta.json` の `run_state` を `"active"` として記録する
- **WHEN** 単一パス解析スキルのすべての解析および成果物出力が正常に完了する
- **THEN** システムは `run_state` を `"completed"` へ更新する
- **WHEN** マルチステージ解析スキルが後続のAI要約またはDashboard生成を必要とする初期ステージを完了する
- **THEN** システムは最終ステージまで `run_state` を `"active"` に維持する
- **WHEN** マルチステージ解析の最終成果物が検証され封緘される
- **THEN** システムは `run_state` を `"sealed"` へ不可逆に更新し、それ以降の状態変更や成果物上書きを拒否する
- **WHEN** 処理中に回復不能なエラーが発生して異常終了する
- **THEN** システムがエラーを捕捉して正常に終了処理を行える場合は `run_state` を `"failed"` へ更新する。予期せぬSIGKILLやクラッシュで終了処理が行われなかった場合は `run_state` を `"active"` のまま残し、中断されたRunとして識別する
