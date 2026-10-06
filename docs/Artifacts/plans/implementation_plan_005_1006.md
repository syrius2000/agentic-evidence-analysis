# Skill出力契約とエージェント文書の正本階層・全体整合

作成日: 2026-10-06 (JST)
状態: 草案・実装未承認
置換対象: [`implementation_plan_004_1006.md`](implementation_plan_004_1006.md)（本計画を採用する場合も004は変更せず保持）

## 1. 目的

解析Skillの出力ルート、run隔離、永続化責務をリポジトリ全体で一貫させる。正本の階層を明確にし、エージェント向け共通ルール、Skill固有手順、実装とテストが現行OpenSpecに整合する状態を作る。OpenSpecの計画文書を作るだけで完了とはせず、承認後はREADME、AGENTS、対象となる全Skill文書、schema、runner/shared実装、関連テストまで実改定する。

本計画は、過去の計画004にあった「`evidence_runs/<skill_slug>/` が各Skillの出力契約と不整合」という判断を採用しない。現行の [evidence-run-layout仕様](../../../openspec/specs/evidence-run-layout/spec.md) が定める共通root形式を維持し、具体slugの登録と各成果物の責務を明確にする。

## 2. 合意済み設計判断

1. **正本階層**:
   - 現行OpenSpecが規範的な挙動を定める。
   - `AGENTS.md` はエージェントの横断的行動規則・承認境界を定める。
   - 各Skillの `SKILL.md` と参照資料は固有の使用条件・手順を定め、OpenSpecおよびAGENTSの共通規則に適合する。
   - コード、schema、テストは規範仕様に適合し、適合性を検証する。
2. **slugライフサイクル**:
   - 出力slugは表示上のSkill名と独立した安定IDとする。
   - Skill名の変更ではslugを維持する。
   - 新Skillには一意のslugを割り当てる。廃止slugは再利用しない。
   - 出力契約が非互換となる場合のみ、互換性を評価した上で新slugを割り当てる。
3. **全体監査・改定範囲**: 現行OpenSpec、README/AGENTS、全解析Skillの入口・参照・テンプレート、schema、runner/shared実装、関連テストを漏れなく台帳化する。正規契約と不一致のファイルは全て改定し、すでに一致するファイルは根拠を記録して確認済みにする。OpenSpec文書の作成のみで完了扱いにしない。
4. **履歴資料**: `docs/Archives/` と、legacy用途が明記された資料は履歴として保全する。現行契約と誤認される場合は、legacy表示または現行正本への案内で区別する。
5. **Artifacts計画**: 今後のImplementation Planは `docs/Artifacts/plans/implementation_plan_NNN_MMDD.md` に作成する。004は置き場契約により上書きせず、005で置き換え案を提示する。

## 3. 現状の一次情報

### 3.1 現行仕様

`openspec/specs/evidence-run-layout/spec.md` は全解析Skillの推奨rootを `evidence_runs/<skill_slug>/`、runを `run_<canonical_id>[_N]/` と定める。明示rootの指定を許容し、`inspect_data.R` の後方互換既定値 `.` と明示時の `evidence_runs/inspections/<project>/run_<id>/`、questionnaire旧runの読取互換を個別に規定する。現仕様にSkillごとのslug対応表とslugのライフサイクル規則はない。

### 3.2 正規rootと永続化責務の計画台帳

以下を今回の計画で統一する正規契約とする。実装・Skill・schemaの現状が異なる場合は現状を例外として残さず、差分修正対象として監査・OpenSpec Changeに含める。実装時の監査では根拠ファイルと実行経路を特定し、永続化ownerと設定の受け渡しを確定する。

| Skill / 実行責務 | 安定slug | 正規root / 出力契約 | 永続化責務・確認事項 |
|---|---|---|---|
| `vcd-bayesian-evidence-analysis` | `vcd_bayesian` | `evidence_runs/vcd_bayesian/run_<canonical_id>[_N]/` | `templates/analysis.R`、config example、SKILL.mdとrunnerを照合 |
| `vcd-categorical-analysis` | `vcd_categorical` | `evidence_runs/vcd_categorical/run_<canonical_id>[_N]/` | canonical `--out` は正規rootを指し、成果物はrun配下へ保存 |
| `vcd-categorical-reporting` | `vcd_categorical_reporting` | `evidence_runs/vcd_categorical_reporting/run_<canonical_id>[_N]/` | Reporting自身の出力root。analysis rootと混同しない |
| `comparative-design-analysis` | `comparative_design` | `evidence_runs/comparative_design/run_<canonical_id>[_N]/` | 共有推論器がrunを直接作らない場合も、永続化するwrapper/callerがこのrootとrun形式を使う |
| `evidence-decision-review` | `evidence_decision_review` | `evidence_runs/evidence_decision_review/run_<canonical_id>[_N]/` | Skillとshared extractorの永続化経路を照合 |
| `questionnaire-batch-analysis` | `questionnaire` | `evidence_runs/questionnaire/run_<canonical_id>[_N]/` | 新規出力は共通形式。旧 `runs/<id>/` は読取互換のみ |
| `sas-proc-freq` | `sas_proc_freq` | `evidence_runs/sas_proc_freq/run_<canonical_id>[_N]/` | 必須 `output_dir` の既定・設定値を正規rootに統一し、成果物はrun配下へ保存 |
| `sas-proc-means` | `sas_proc_means` | `evidence_runs/sas_proc_means/run_<canonical_id>[_N]/` | 必須 `output_dir` の既定・設定値を正規rootに統一し、成果物はrun配下へ保存 |
| `vcd-pass0-consultation` | 分析Skill slugの割当対象外 | `evidence_runs/inspections/<project>/run_<id>/` | 分析出力ではなく検分成果物の明示例外。未指定時 `.` の互換挙動は維持 |

明示的な利用者指定rootを受け付ける既存仕様との整合はOpenSpec Changeで明文化する。指定rootを許す場合もSkillごとの安定slugを含む正規root配下に限定し、run隔離形式を崩さない。SASの `output_dir` は例示に留めず、schema・設定例・runner全体で正規rootを指す契約として扱う。

### 3.3 全面照合対象と既知の不整合

実改定前に、下記の全領域をファイル単位のインベントリにし、各ファイルを「改定」「契約と一致・改定不要」「履歴/例外として維持」のいずれかに分類する。分類理由と根拠をOpenSpec tasksまたは実装完了報告に残す。

- `README.md`、`AGENTS.md`、`docs/Artifacts/README.md`と、出力契約を記載する現行reference文書。
- 解析対象8 Skill: `vcd-bayesian-evidence-analysis`、`vcd-categorical-analysis`、`vcd-categorical-reporting`、`comparative-design-analysis`、`evidence-decision-review`、`questionnaire-batch-analysis`、`sas-proc-freq`、`sas-proc-means`。各Skillの `SKILL.md`、出力契約に関係する参照資料、schema、template/runnerを対象に含める。
- Pass 0検分Skillおよびその実行主体である `.agents/shared/inspect_data.R`。検分出力は解析runと区別した既定例外契約を照合する。
- `.agents/shared/` のrun生成・finalize・scope・routing等の共通基盤、トップレベル `schemas/`、OpenSpec関連仕様、runner/CLI、関連テストと出力期待値。
- 上記対象への参照、root例、legacy path説明があるMarkdown/JSON/R/Rmd/CSS/HTML等を `rg` 等で横断検索し、インベントリに追加する。

既知の照合点:

- `vcd-categorical-reporting/references/interface.md` はInterface 2.1と `evidence_runs/vcd_categorical/` を記す一方、Reporting自身のrootは `vcd_categorical_reporting` とする。
- `vcd-categorical-reporting/references/workflow.md` は `skill_out/` を使う旧2パス手順であり、現行SKILL.mdのworkflowと一致しない。
- `vcd-categorical-reporting/references/report-template.md` はlegacy資料として保持し、現行テンプレートと誤認させない。
- `vcd-categorical-analysis/references/report-template.md` 等、各Skillのpath例が共通runディレクトリまで示しているか確認する。
- `comparative-design-analysis` の永続化callerとSAS `output_dir` の実行時解釈を実物で照合し、正規root契約へ修正する。

`.agents/skills/blind-qa-cycle/` は統計解析SkillではなくQA成果物固有の契約を持つため、解析run rootの統一対象外とする。出力契約への誤った参照が見つかった場合のみ修正対象に含め、既存QA契約自体は変更しない。Archivesと明示legacy資料は履歴保全条件に従う。

## 4. 変更設計

### Phase A: OpenSpec Change文書の作成

- `openspec-ff-change` を用いて新規Changeの `proposal`、`specs`、`design`、`tasks` を作成し、計画005の範囲・正規契約・既知の不整合を反映する。
- ff-change時の読み取り調査で全対象インベントリを確定し、Changeのtasksにファイル群ごとの改定タスク、依存順、具体的な受入条件を列挙する。
- ここで作るOpenSpec文書は実装設計書であり、README/AGENTS/Skill/コード/schema/test自体の改定を代替しない。
- すべてのtasksを実行する前提でChangeを完成させる。未解決事項があれば推測で閉じず、対象箇所と必要判断を示す。

### Phase B: 台帳と規範契約

- `evidence-run-layout` にSkill名、安定slug、正規root、共通run形式、永続化owner、root設定の許容範囲、廃止時の扱いを規範的に登録する。
- slug追加・名称変更・廃止・互換破壊時の更新規則と既存run保全を定義する。
- Pass 0検分、root設定の許容範囲、共有推論器が呼び出し側に永続化を委ねる場合のowner境界を明記する。SASの `output_dir` も例外扱いせず、正規rootとrun形式に接続する。
- この規範変更は作成したOpenSpec Changeのspec deltaとして提示し、実装承認後に正本仕様へ適用する。

### Phase C: README・AGENTS・Artifacts規約

- `AGENTS.md` の役割をエージェント共通作業契約に絞り、OpenSpec・AGENTS・各Skillの正本階層、承認境界、共通出力契約を明確にする。
- `README.md` は利用者向け導入・利用方法・Skill案内を保ち、AGENTSの説明を複製せず、全解析Skillの正規root/Pass 0例外と矛盾しないよう更新する。
- `docs/Artifacts/README.md` を置き場の詳細正本として参照し、Planの `docs/Artifacts/plans/` 配置契約をAGENTSにも整合させる。
- README/AGENTS双方の既存内容を全節レビューし、今回の出力契約に関係する記載を残存させない。無関係な記載は根拠なく削らない。

### Phase D: 全対象Skill・実装・schema・テストの改定

- 解析対象8 Skillすべての入口資料・出力関連reference・schema・runner/template・出力メタデータをインベントリに照らして改定し、全Skillで正規rootと `run_<canonical_id>[_N]/` をそろえる。該当の記載がないファイルは一致確認として記録する。
- `comparative-design-analysis` は出力を永続化するwrapper/callerを特定し、`evidence_runs/comparative_design/run_<canonical_id>[_N]/` 契約を適用する。
- SAS FREQ/MEANSはschema、例、runner、Skill文書で `output_dir` の意味を統一し、正規rootとrun隔離を実現する。
- `.agents/shared/` の共通run実装、root検証、ID/suffix、metadata、inspectionの例外契約を実装と仕様の両面から整合させる。
- Reporting側のInterface 2.1コピーは、analysis側Interface 3.0を正本として案内し、`vcd_categorical` が分析側rootであることとReporting自身の `vcd_categorical_reporting` rootを区別する。
- Reportingの旧2パスworkflowを現行SKILL.mdと整合する手順へ置換する。
- 明示的legacyレポートテンプレートとArchivesは保全し、現行資料から区別する。
- 関連する全テストとfixtureの期待値をインベントリに照らし、slug/root/run隔離、Pass 0例外、root指定、衝突suffix、metadata、legacy読取境界を検証するよう追加・更新する。
- 共通root/run形式からの不適合は全対象に対して修正し、未改定の既知不整合を残さない。調査で新たな対象が見つかった場合は、同じ契約範囲内ならChange tasksへ追加して実施する。

### Phase E: 横断検証と完了記録

- インベントリ全行の状態を確認し、未分類・未確認・既知不整合がゼロであることを受入条件とする。
- 正規root契約・コード/schema・全Skill文書・README/AGENTS・テスト期待値を横断検索し、現行説明の食い違いがないことを確認する。
- 対象テスト、schema検証、文書リンク/Markdown、`git diff --check` を実行し、各結果を別々に記録する。ユーザーが求めていない追加テストは計画承認後の実装範囲で実施判断を明示する。
- 全ての変更ファイルと、確認の結果変更不要としたファイルをインベントリで追跡可能にし、未実施項目を完了扱いにしない。

## 5. 変更対象候補

正規rootとrun形式、全面照合するファイル群は本計画で確定する。ff-change時の読み取り専用棚卸しで具体的なパスを確定し、全パスと対応タスクをOpenSpec Changeのtasksへ列挙する。対象群は以下の通りであり、「候補」や「必要に応じて」による範囲縮小は行わない:

- OpenSpec `evidence-run-layout` と関連する現行specs
- `README.md`、`AGENTS.md`、`docs/Artifacts/README.md`
- 全解析SkillのSKILL.md、root/run記述を持つreference、schemas、templates、runners
- `.agents/shared/` のrun/inspection契約に関わる実装
- `schemas/` と設定JSON schema、run metadata schema/contract
- 関連するテスト、fixtures、static consistency scriptsと、root/pathを記載する現行文書
- 読取専用の出力先指定や互換読取経路。出力契約と無関係な内容は変更しない

`implementation_plan_003_1006.md` と `implementation_plan_004_1006.md`、Archive、ユーザーの既存変更、無関係な未追跡ファイルは保持する。

## 6. 受入確認マトリクス

| Fixture / 対象 | Checks | Expected Results |
|---|---|---|
| 正常: 解析対象8 Skill | 各Skill入口・参照・設定・実行経路・成果物をインベントリと照合 | 8 Skillすべてが正規slug/root/run形式に一致し、全永続化ownerが特定される |
| 境界: root指定 | 各公開interfaceの設定優先順位、許容範囲、path検証を照合 | 許可された範囲内のみ保存し、共通run隔離とroot直下書込禁止を満たす |
| 境界: `inspect_data.R` | out-dir未指定と明示指定を確認 | 既定 `.` の互換挙動と、指定時のinspection rootが仕様どおり区別される |
| 境界: 共有design推論器 | standalone実行、永続化caller、生成先root、run ID決定を確認 | 推論器自身が作成しない構成でもcallerが `evidence_runs/comparative_design/run_<canonical_id>[_N]/` に保存する |
| 正常: SAS設定JSON | `output_dir` schema、設定例、runnerの保存先、衝突時suffixを照合 | FREQ/MEANSとも正規root配下に `run_<canonical_id>[_N]/` が作られ、root直下への成果物書込みがない |
| 回帰: questionnaire | 新規runと旧 `runs/<id>/` 読取経路を確認 | 新規出力は登録root、legacyはread-only互換を維持する |
| 異常: slug/rootドリフト | 全Skillのfrontmatter、schema、runner、README/AGENTS、テスト契約を横断比較 | 整合性チェックが失敗し、不一致箇所を特定できる。修正後は全対象一致を確認する |
| 異常: 新規Skill登録漏れ | slug未登録の解析runnerを検査 | canonical root契約違反として検出する |
| 正常: Reporting v3 | runner・SKILL・現行workflow・正本案内を横断確認 | `vcd_categorical_reporting` がReporting root、`vcd_categorical` がanalysis側rootとして明確に分離される |
| 境界: legacy資料とArchives | `skill_out` 等の旧パスを検索し、legacy annotation/Archive区分を確認 | 現行手順と誤認する旧記述はなく、履歴資料は改変されない |
| 全面完了 | ファイルインベントリの分類とtasksの消化状況を照合 | 全対象を改定または根拠付き確認済みとし、未分類・未対応・既知不整合ゼロ |
| 文書品質 | Markdownリンク、OpenSpec validate、schema検証、`git diff --check`、変更前後Git状態 | 検証結果を記録し、既存のユーザー変更を保全する |

## 7. 承認境界・検証・報告

- OpenSpec Change作成と実装は別の承認段階とする。ff-changeでのproposal/specs/design/tasks作成は実装許可を意味しない。
- Change作成後、実装着手前に全改定対象のfile inventoryとtasksをユーザーに提示し、計画範囲内で全ファイルの実改定を実施する。新規で重要な破壊的影響が判明した場合は停止して計画・Changeを改訂し、再承認を得る。
- 実装完了はOpenSpec文書が揃った時点ではなく、README/AGENTS、対象Skill資料、関連schema/runner/shared実装/testsを改定または根拠付きで現状適合確認し、Phase Eの全受入条件を満たした時点とする。
- 実装フェーズでは正本台帳・Skill契約・schema・runtime・testsを順に照合し、テスト結果、未検証、QA、commit、pushを分けて報告する。
- commit、push、Archive移動、legacy資料削除は本計画の自動的な許可に含まない。
