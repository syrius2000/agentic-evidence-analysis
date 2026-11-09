# 実装計画 002: 比較DashboardへのAI要約統合

- 作成日: 2026-11-09 (JST)
- 開始時点: branch `main`, commit `75c9400`。既存ユーザー変更 `agentic-evidence-analysis.code-workspace` を保持。
- OpenSpec change: `embed-executive-summary-in-dashboard`
- 承認: 2026-11-09、会話内でユーザーが計画002を承認。

## 1. 背景と確認結果

- `vcd-categorical-reporting` は `comparative_evidence.json`、`comparative_summary.csv`、`comparative_report.md`、`dashboard.html` を一回の処理で生成する。Dashboard生成コードは `executive_summary.md` を読み込まない。
- 現行 `SKILL.md` の標準成果物一覧にも `executive_summary.md` がない。
- `.agents/shared/analysis_quality_contract.md` の適用スキル一覧から `vcd-categorical-reporting` が漏れており、Pass 2 AI要約要件がこのスキルに適用されない。
- 比較報告のOpenSpecは指標表・免責・表示契約を定めるが、AI要約のDashboard統合を要求していない。
- 共有 `run_scope.R` にはPass 2/3のstaging、結果manifestとの来歴検証、成果物ハッシュ記録、Pass 3後の封緘機構があるが、比較報告スキルは未接続。

このため今回の分離は設定漏れではなく、適用スキル、成果物契約、実行順序の3点が未定義だったことによる。

## 2. 目標と受入条件

1. 最終Dashboardに同一runの `executive_summary.md` 全文と `run_meta.json` 由来のスキルIDを表示する。
2. Pass 1後はrunを `active` に保ち、summary未作成・空・別結果由来のときはPass 3を失敗させ、最終Dashboardと完了状態を作らない。
3. summary・DashboardのSHA-256とresults manifest／相互の来歴を `run_meta.json` に記録し、成功時だけrunを `sealed` にする。
4. summary本文は安全にHTMLエスケープし、完全オフライン仕様を維持する。統計JSONとsummary CSVのcanonical schemaは変えない。
5. スキル説明と共通品質契約がPass 1 → AI要約 → Dashboardの順序を明記し、未完了runを完成成果物として案内しない。

## 3. 実装範囲

- `.agents/skills/vcd-categorical-reporting/comparative_reporting.R` とPass 3 renderer / handover連携
- `.agents/shared/run_scope.R` または既存のstage helper（必要最小限）
- `.agents/skills/vcd-categorical-reporting/SKILL.md`
- `.agents/shared/analysis_quality_contract.md`
- 既存run lifecycle関連ドキュメントと対象テスト
- OpenSpec delta: `comparative-evidence-reporting`、`evidence-run-layout`

非対象: 既存のsealed/completed runの書換え、統計推定や閾値の変更、canonical JSON・40列summary CSVの変更、外部依存の追加。

## 4. TDDフェーズ

### Phase 1: Pass 1 lifecycleとhandover

1. 現状の一括生成を再現するテストを作り、Pass 1後にfinal Dashboardが無いこと、`run_state=active`、Pass 2/3 handoverがあることを期待値として固定する。まず現状実装で失敗することを確認する。
2. generatorをPass 1 canonical成果物と後段Dashboard生成に分け、stable results manifestを生成し、共有stage helperへhandoverする。該当テストを実行して通す。

### Phase 2: summary取込と安全なPass 3

1. summary全文、skill ID、欠落・空・ハッシュ不一致、HTMLタグやscript文字列を含むsummaryの回帰テストを先に追加し、現状で失敗することを確認する。
2. safe embeddingとPass 3 finalizationを実装する。共通finalizerでmanifest digest、summary digest、stage順序、sealed状態を検証し、対象テストを通す。

### Phase 3: 契約と文書の同期

1. `SKILL.md` にPass 1/2/3、必須成果物、停止条件、スキルIDの表示を記載。
2. quality contractの適用一覧へこのスキルを追加し、Pass 2要約とPass 3統合確認を適用。
3. OpenSpec deltaおよびrun lifecycle文書と実装の一致を確認し、`openspec validate embed-executive-summary-in-dashboard --strict` を実行。

### Phase 4: End-to-end TDD確認

1. 小規模fixtureでPass 1 → AI要約stage → Pass 3を通す統合ケースを追加。
2. 対象テスト、既存比較報告回帰スイート、manifest/metadata整合、HTMLの外部参照ゼロとsummary文字列保持を確認する。
3. 最終Dashboardを視覚確認できない環境制約が残る場合は、静的HTML検査と未検証事項を記録する。

## 5. 主要リスクと対策

| リスク | 対策 |
|---|---|
| AI要約前の中断runが増える | `active` とPass状態で未完了を可視化し、handoverに次段階を明記 |
| Pass 1 manifestと最終runの役割が曖昧 | canonical計算結果はstable manifest、summary/Dashboardはrun_metaのハッシュ付きstage artifactsとして記録 |
| 任意HTMLを介したscript注入 | Markdownをraw HTMLとして解釈せず、HTML escapeして表示 |
| 過去runとの互換 | 既存runは変更せず読取可能なまま維持。統合Dashboardは新規runで生成 |

## 6. 検証と報告

- TDD: 新しい回帰テストが実装前に失敗し、各実装後に対象テストが通ること。
- 統合: stage状態、handover、summaryとDashboardのSHA-256、manifest、`sealed` 状態を照合。
- OpenSpec: `openspec validate embed-executive-summary-in-dashboard --strict`。
- 静的HTML: summary全文とskill slugが含まれ、script実行・外部URL・絶対パスが混入しないこと。
- 独立QA、Owner判断、commit、pushは別工程として扱い、依頼がない限り実施しない。

## 7. 着手ゲート

本書とOpenSpec artifactsはレビュー用であり、コード変更の承認を意味しない。Ownerがこの計画を承認した後にのみ、TDDのPhase 1から実装を開始する。
