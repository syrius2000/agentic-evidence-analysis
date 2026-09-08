# harden-run-path-handover 実装検証報告

created: 2026-09-08 19:58 (JST)
update: 2026-09-08 19:58 (JST)
author: Codex (GPT-6)

## 判定

**アーカイブ不可。CRITICAL 7件、WARNING 4件、SUGGESTION 1件。**
タスクは30/30完了扱いだが、最終受入条件が実装・テストへ反映されていない。計画の厳格検証合格と実装の正しさは別である。

対象は [OpenSpec変更](../../openspec/changes/harden-run-path-handover/proposal.md)、[仕様](../../openspec/changes/harden-run-path-handover/specs/run-output-lifecycle/spec.md)、[設計](../../openspec/changes/harden-run-path-handover/design.md)、[タスク](../../openspec/changes/harden-run-path-handover/tasks.md)。作業開始時に存在した実装差分を検証し、コード・テスト・タスクチェックは変更していない。

| 観点 | 結果 |
|---|---|
| 完全性 | チェック30/30。ただし共通ロック、回復証跡、legacy出力隔離等の受入条件が未達 |
| 正確性 | 26要件・45シナリオを対象に照合。全件合格とは判定できず、重要な逸脱を再現 |
| 整合性 | design.mdの最終補足契約と実装・テストが不一致 |

## CRITICAL：アーカイブ前に修正

### C1：確定済み状態と考察の由来が共通finalizerで保護されない

対象：`.agents/shared/run_scope.R:743`、`:803`、各スキルの `templates/render_dashboard.R`（Categoricalは`:193`以降）。タスク1.9、1.10、1.11、4.4。

`finalize_pass2()` はpass1完了やpass2未完了を要求しない。`finalize_pass3()` はpass2完了と記録済みnarrativeハッシュを必須照合せず、任意引数の期待ハッシュが省略されると実ファイルをそのまま採用する。通常レンダラーも期待narrativeハッシュを渡していない。

一時runで、完了済みPass 2の再確定、pass1=partialのPass 2確定、確定後に書き換えた考察を使うPass 3封印を受け入れることを再現した。

修正：ロック内でメタデータを再読し、v2のスキル・状態・遷移を検証する。Pass 2再確定を拒絶し、Pass 3は記録済みnarrativeハッシュと由来manifestをレンダリング前後に必須照合する。CLI直接呼び出しでもpartial/failedを遮断する。

### C2：run共通ロック、preview直列化、所有token確認が未実装

対象：`.agents/shared/run_scope.R:534`、`:646`、Bayesian `templates/pass2_stub.R:268`、各 `templates/render_dashboard.R` のpreview経路。タスク1.6、1.8〜1.10。

stageロックのみで `run.lock` がなく、finalizerはロック取得前にメタデータを読み、取得後に再読しない。previewはロックなしで公開とメタデータ更新を行う。stubはsealedもpass2=completedも拒絶せず、pass2をstub_generatedへ戻す。レンダラーは同一staging/dashboard.htmlを共有する。releaseは所有tokenを確認せずロックを削除する。

修正：run共通→stageの順でロックし、逆順に所有token一致時だけ解放する。previewも同じ直列化と状態再読を適用する。生成は呼び出し固有の一時領域へ分離し、競合・stale回復を実プロセスで検証する。

### C3：回復証跡がなく、出所不明の既存成果物を確定できる

対象：`.agents/shared/run_scope.R:687`、`:771`、`:845`、`.agents/shared/finalize_run_stage.R:137`。タスク1.7、1.9〜1.11。

transaction_<stage>.jsonの保存・照合がない。内部finalizerはsourceがなくてもtargetがあれば取り込む一方、CLIはsource実在を必須としているため、rename後の正規回復を拒絶する。Pass 3はpromotion後に初めて余分なstagingを検査する。rename失敗時には非原子的なcopyへ退避する。

回復証跡なしでrun直下に作った考察がPass 2確定されることを再現した。

修正：promotion前にトランザクションを原子的保存し、source消失時は証跡・target・由来ハッシュの一致を必要条件とする。余分なstagingはpromotion前に拒絶する。rename失敗時のcopyフォールバックを廃止し、メタデータrenameの成否も確認する。

### C4：ロック制御領域のsymlinkを経由して外部へ書き込める

対象：`.agents/shared/run_scope.R:487`、`:547`。タスク1.3、1.6。

正規化後のrun/out_rootにSys.readlinkを適用しているため元のsymlink経路を失う。また `.run_locks` と子制御ディレクトリを検証せず再帰作成する。

一時out_rootの `.run_locks` を別の一時ディレクトリへ向けると、acquire_stage_lockが外部側へlock_info.jsonを書き込むことを再現した。

修正：書き込み前に元パスと既存祖先・制御領域を検査し、symlinkを拒絶する。未作成出力も既存親の実パスを確認する。拒絶時に外部変更がないことをテストする。

### C5：Questionnaire部分失敗が成功終了し、本番アクションを提示する

対象：Questionnaire `templates/batch_runner.R:543`、`:606`、`.agents/shared/run_scope.R:930`、`tests/test_run_scope_lifecycle.R:660`付近。タスク1.14、4.1、5.1。

partialは終了コード0で終了し、handoverは状態にかかわらずpass2_aiとpass3を含む。既存テストも「一部失敗でも終了コード0」を正解としており、最終仕様と逆である。failedではrun_state=failedを書き、active/sealedとpass_statusを分離する設計とも不一致。

修正：partial/failedは非ゼロ終了、本番next_actionsは空配列、停止理由を記録する。run_stateとpass_statusを設計に合わせ、テストの期待値も修正する。

### C6：legacy previewが元runへ書き込む

対象：各スキルの `templates/render_dashboard.R` の引数処理・preview分岐、Bayesian `templates/pass2_stub.R:54`。タスク1.12、2.2〜2.3、3.2、4.2。

`--preview-output-dir` が実装されておらず、legacy許可時もdashboard_preview.htmlを元run直下へ書く。stubも同様に元runを既定出力先とする。

修正：legacyでは元run外の明示出力先を必須にし、元run全ファイルの前後ハッシュが不変であること、同名出力を上書きしないことを確認する。

### C7：supersede検証が記録済みmanifestとの一致・循環・変更比較を満たさない

対象：`.agents/shared/run_scope.R:882`、`:920`、Categorical `templates/analysis.R:644`、Questionnaire `templates/batch_runner.R:579`。タスク1.13、2.1、3.1、4.1。

verify_superseded_runはverify_results_manifestへ元メタデータの期待ハッシュを渡さず、成果物とmanifestの両方を書き換えたrunを記録済み値と比較しない。祖先参照の循環探索がない。Categorical/Questionnaireはinputs_changed・config_changedの比較結果を渡していない。

修正：元メタデータのハッシュと実manifestを照合し、訪問済み集合で循環を拒絶する。全スキルで入力・設定比較の真偽値を記録し、破損runと循環、変更あり/なしをテストする。

## WARNING：仕様・検証の不足

### W1：manifestの厳格スキーマと一回限り出力が不足

対象：`.agents/shared/run_scope.R:306`、`:414`。

roleはスキル別ではなく共通allowlistで、検証時に正規化相対パス・小文字64桁の厳密制約を網羅していない。run内symlinkは正規化後の検査で見逃しうる。write_results_manifestは既存manifestを直接上書きできる。

修正：作成・検証で同じ厳格スキーマを使い、skill別成果物集合とQuestionnaire成功設問集合を照合する。既存/封印済みmanifestの上書きを拒絶する。

### W2：handoverのcwdと一部アクションが実行契約と不一致

対象：`.agents/shared/run_scope.R:932`、`:968`。

cwdをgetwd()で記録する一方でargvはリポジトリ相対。外部cwdからPass 1を起動すると後続コマンドが解決できない。Categorical/Questionnaireのpass2_stub_previewは、それぞれanalysis.R/batch_runner.Rへ--run-dirだけを渡しているが、専用stubではない。

修正：cwdを確定したリポジトリルートにするか実行ファイルを絶対パス化する。実装済みアクションのみを出し、handoverのcwd+argvを別cwdから実行して出力まで検証する。

### W3：実HTML描画と全回帰テストの証拠不足

対象：`tests/test_run_scope_lifecycle.R:4`、`tasks.md` 2.4/3.3/4.3/5.3。

今回ライフサイクルテストは成功したが、AGENTIC_MOCK_RENDER=1で固定HTMLを書き出すためRmd、バナー、ローカルアセット依存を検証していない。全Rテスト・統計基盤テストの成功は今回未検証。

修正：モックによる状態遷移テストと別に3スキルを実描画し、公開HTMLのローカル一時アセット依存を検査する。修正後、各Rテストを独立実行し、統計基盤とPython契約テストも記録する。受入条件未達のタスクを完了扱いにしない。

### W4：inputs配列の渡し込みが破棄される

対象：`.agents/shared/run_scope.R:1101`、`:1155`。

write_run_metaはinput_data_pathからだけinputsを作り、extra$inputsをマージ対象から除外する。組み込みデータや複数入力の呼び出し側がextra$inputsを供給しても保存に反映されない。

修正：検証済みinputs配列を共通入口で受け入れ、builtinと複数入力を永続化する。旧トップレベルフィールドを復活させず、保存JSONを検証する。

## SUGGESTION

S1：`git diff --check` は終了コード2。run_scope.R等に末尾空白、EOF空行がある。機能修正後、対象差分に限定して除去する。

## 実施した検証と限界

| 検証 | 結果 |
|---|---|
| openspec status / instructions apply | 計画4/4、タスク30/30の表示を確認 |
| openspec validate harden-run-path-handover --strict | 合格 |
| Rscript tests/test_run_scope_lifecycle.R | 終了コード0、Phase 1〜5成功。ただし描画はモック |
| 関連Python契約テスト2ファイル | 12 passed |
| 一時runでの境界再現 | 再確定、partial確定、考察改ざん後封印、証跡なし取り込み、symlink外部ロック書き込みを再現 |
| git diff --check | 不合格（既存実装差分の空白問題） |

統計解析の新規実行依頼としては扱わず、既存の合成データ・テストfixtureと一時runで検証した。ユーザーデータは変更していない。全R回帰、実ブラウザ、実並行プロセスの競合再現は未実施。既にアーカイブを妨げる不具合を確認したため、全件合格の証明は修正後の再検証へ残す。

## 推奨する修正順序

1. 共通finalizerの状態・由来検証、run共通ロック、トランザクション回復、信頼境界を修正する（C1〜C4）。
2. Questionnaire診断、legacy出力、supersede、manifest、handover、inputsを契約へ合わせる（C5〜C7、W1/W2/W4）。
3. 現在誤った挙動を正解にしているテストを改定し、不具合再現を回帰テストにする。実描画と全回帰を実施した後にタスク完了を再判定する（W3）。

本検証では修正実装・アーカイブ・commit・pushは行っていない。

## 要件別の実装対応表

「実装あり」は対応入口を確認した意味であり、全シナリオの動作保証ではない。シナリオ単位の完全な試験網羅率は未確定とする。

| 仕様内の要件（登場順） | 主な対応箇所 | 判定 |
|---|---|---|
| 1 出力親と実runの責務 | run_scope.R assert_valid_out_root | 実装あり・基本テスト成功 |
| 2 Categorical作成主体とclaim廃止 | Categorical analysis.R | 実装あり・統合テスト成功 |
| 3 原子的予約 | run_scope.R reserve_run_output_dir | 連続衝突テスト成功・実並行未検証 |
| 4 追記限定とsealed | finalize_pass2/3、pass2_stub.R | C1/C2、W1 |
| 5 manifest | write/verify_results_manifest | W1 |
| 6 stageロックと信頼境界 | acquire/release_stage_lock | C2/C4 |
| 7 legacy互換 | 各render_dashboard.R | C6 |
| 8 staging | promote_staging_artifact | C3 |
| 9 stub分離 | pass2_stub.R | 分離実装あり・C2 |
| 10 previewと本番分離 | 各render_dashboard.R | 分離実装あり・C1/C2 |
| 11 self_contained | 各dashboard.Rmd | W3（実描画未検証） |
| 12 Questionnaire状態機械 | batch_runner.R、finalizer | C1/C5 |
| 13 finalizer allowlist | finalize_run_stage.R | 基本拒絶テスト成功・C3/C4、W1 |
| 14 pass2_aiハンドオーバー | write_run_handover | C5、W2 |
| 15 supersede | verify_superseded_run | C7 |
| 16 hash_onlyと設定snapshot | save_config_snapshot、各Pass 1 | 基本実装あり・組み込み入力はW4 |
| 17 inputs正本化 | write_run_meta | W4 |
| 18 実run直接引継ぎ | 各Pass 2/3 CLI | 実装あり・基本統合テスト成功 |
| 19 統一Pass 3 CLI | 3スキルrender_dashboard.R | 配置あり・モック統合成功 |
| 20 暗黙探索廃止 | resolve_pass3_run_dir | 実装あり・基本拒絶テスト成功 |
| 21 パス境界 | assert_path_within_run_dir | 基本逸脱拒絶あり・C4/W1 |
| 22 Questionnaire強制隔離 | reserve_run_output_dir、batch_runner.R | 実装あり・統合テスト成功 |
| 23 共通4-Pass | 各SKILL.md、各Pass 1 | 対応記述と入口あり・確定段階C1 |
| 24 リンクと完了報告 | 各SKILL.md | 記述あり・実AI報告運用未検証 |
| 25 確定トランザクション | 共通finalizer | C2/C3（重要部分未実装） |
| 26 診断と出力状態 | batch_runner.R、preview CLI | C5/C6 |
