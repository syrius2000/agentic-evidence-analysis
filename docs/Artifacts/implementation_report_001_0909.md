# harden-run-path-handover 検証指摘への修正実装報告

created: 2026-09-09 01:10 (JST)
update: 2026-09-09 01:10 (JST)
author: Codex (GPT-6)

## 結果

[検証報告書](verification_report_001_0908.md) のCRITICAL 7件、WARNING 4件、SUGGESTION 1件に対応した。OpenSpecの30タスクを再検証し、完了へ更新した。統計計算・モデル評価の数値基準は変更していない。

全回帰が無条件に合格したという意味ではない。Rは47ファイルを独立したRscriptで順次実行し、43ファイル成功、1ファイル全体スキップ、3ファイルは修正前と同じ失敗だった。成功に数えたsummary列テストには、既存の任意列4項目の未実施が含まれる。関連Python契約は12件成功。

## 指摘への対応

| 指摘 | 修正 | 主な検証 |
|---|---|---|
| C1 状態・由来検証 | 共通finalizerでv2、pass1完了、工程未完了、確定済み考察と由来manifestを必須検証 | 再確定・partial・考察改ざんを内部関数とCLIで拒絶 |
| C2 排他・preview | run共通→stageロック、所有情報・token照合、preview状態再読、呼び出し固有の描画領域 | 実プロセス確定競合、preview競合、stub逆戻り・sealed拒絶 |
| C3 回復証跡 | promotion前のtransaction保存、source消失後のCLI回復、事前staging検査、rename失敗時停止 | promotion後故障注入、証跡保存失敗、証跡改ざん、無証跡target拒絶 |
| C4 symlink | run・出力祖先・制御領域を実変更前に検査。macOSの既知システム別名だけを解決 | .run_locksの外部symlinkで外部変更なし、run内symlink拒絶 |
| C5 部分失敗 | partial/failed非ゼロ終了、next_actions空配列、停止理由、active/sealedとpass_status分離 | Questionnaireの全成功・部分失敗・全失敗を実行 |
| C6 legacy | 元run外preview出力先を必須化、警告を出力、元run不変 | 外部への一回公開、元run全ファイルハッシュ不変 |
| C7 supersede | 記録済みmanifestとの照合、循環検査、共通入力・設定比較 | 破損manifest・循環・不正元run拒絶、正常supersede |
| W1 manifest | スキル別role、正規化相対パス、厳格ハッシュ、一意性、成功設問集合、設定snapshot検証、一回出力 | 不正role/パス/hash、重複、symlink、上書き拒絶 |
| W2 handover | 読み込んだ共通コードの位置からrepo cwdを確定し、未実装stubアクションを除外 | 外部cwdで生成したhandoverのcwd+argv実行 |
| W3 検証不足 | モック描画を廃止し、3スキル実描画とアセット検査、全回帰を実施 | preview→本番→sealed、ローカル補助アセット依存なし |
| W4 inputs | extraから受け取る複数入力と組み込みデータを検証・保存 | builtin/複数入力、hash_only、旧フィールド重複なし |
| S1 空白 | 対象差分の末尾空白・末尾空行を整理 | git diff --check合格 |

## 共通処理と停止境界

- [共通基盤](../../.agents/shared/run_scope.R) の `finalize_stage()` が本番確定を一元管理する。[確定CLI](../../.agents/shared/finalize_run_stage.R) と各render_dashboard.Rはこの処理へ委譲する。
- previewとstubは `publish_run_preview()` を通す。本番描画は `render_run_dashboard()` を通し、同じrunロックと状態検証を使う。
- 変更前：信頼境界・ロック所有・状態・manifest・narrative・stagingを検証し、transactionを保存できなければpromotionしない。
- 変更中：同一ファイルシステムのrenameだけで公開する。公開後の中断はtargetとtransactionを残し、元sourceパスと期待ハッシュでCLI回復する。
- 変更後：ハッシュ再検証、staging空確認、メタデータ原子的更新、所有情報一致のロック解放を行う。確定済みの再実行は拒絶する。
- stale回復は明示フラグ、同一ホスト、PID不在、経過時間、所有情報を検証し、回復操作自体を直列化して監査ログを残す。欠損・破損・生死不明は停止する。
- 封印は本パイプラインの書き込み契約である。OS権限を越える外部編集防止や電源断時の永続化保証は対象外。実描画時のネットワーク参照全撤廃も対象外。

## 試験結果

実行コマンド：`Rscript <各テストファイル>`。描画中間ファイルを共有する既存テストがあるため、最終結果は並列実行ではなく順次実行で確定した。

| テスト | 結果 |
|---|---|
| `tests/test_2way_table_analysis.R` | 成功 |
| `tests/test_ai_interpretation_and_stub.R` | 成功 |
| `tests/test_dashboard_fallbacks.R` | 成功 |
| `tests/test_dashboard_loglinear_ui.R` | 成功 |
| `tests/test_ggplot2_jp_font.R` | 成功 |
| `tests/test_inspect_data_out_dir.R` | 成功 |
| `tests/test_loglinear_json_output.R` | 成功 |
| `tests/test_loglinear_specs_and_formulas.R` | 成功 |
| `tests/test_model_spec_oracle_and_order.R` | 成功 |
| `tests/test_questionnaire_batch_smoke.R` | 成功 |
| `tests/test_questionnaire_batch_ucbadmissions.R` | 成功 |
| `tests/test_questionnaire_duplicate_output_slug.R` | 成功 |
| `tests/test_questionnaire_marginal_strata_contract.R` | 成功 |
| `tests/test_questionnaire_symlink_escape.R` | 成功 |
| `tests/test_run_scope_guards.R` | 成功 |
| `tests/test_run_scope_lifecycle.R` | 成功 |
| `tests/test_security_skill_references.R` | スキップ（対象スキル不在） |
| `tests/test_skill_run_isolation.R` | 成功 |
| `tests/test_summary_csv_new_columns.R` | 成功（任意列4項目は未実施） |
| `tests/test_ucb_numerical_invariance.R` | 成功 |
| `tests/test_vcd_bayesian_config_validation.R` | 成功 |
| `tests/test_vcd_bayesian_dashboard_html_asis.R` | 成功 |
| `tests/test_vcd_bayesian_dt_filter_factor.R` | 成功 |
| `tests/test_vcd_bayesian_help.R` | 成功 |
| `tests/test_vcd_bayesian_insight.R` | 成功 |
| `tests/test_vcd_bayesian_pass2_stub.R` | 成功 |
| `tests/test_vcd_bayesian_run_id.R` | 成功 |
| `tests/test_vcd_bayesian_stability_leverage.R` | 成功 |
| `tests/test_vcd_bayesian_topk.R` | 成功 |
| `tests/test_vcd_cat_pass1.R` | 成功 |
| `tests/test_vcd_categorical_dashboard_run_resolution.R` | 成功 |
| `tests/test_vcd_categorical_run_isolation.R` | 成功 |
| `tests/test_vcd_categorical_smoke.R` | 成功 |
| `tests/test_vcd_categorical_template_assoc_shade.R` | 成功 |
| `tests/test_vcd_categorical_template_residual_layout.R` | 成功 |
| `tests/test_vcd_dashboard_display_formats.R` | 既存失敗（修正前でも再現） |
| `tests/test_vcd_dashboard_layout_core.R` | 既存失敗（修正前でも再現） |
| `tests/test_vcd_dashboard_layout_foundation.R` | 既存失敗（修正前でも再現） |
| `tests/test_vcd_dashboard_layout_integration.R` | 成功 |
| `tests/test_vcd_interpretation_guide.R` | 成功 |
| `tests/test_vcd_residual_plot_order.R` | 成功 |
| `tests/statistical_foundations/test_intentional_mismatch.R` | 成功 |
| `tests/statistical_foundations/test_reproducibility.R` | 成功 |
| `tests/statistical_foundations/test_section3_models.R` | 成功 |
| `tests/statistical_foundations/test_section4_ic_score.R` | 成功 |
| `tests/statistical_foundations/test_section5_bayesian.R` | 成功 |
| `tests/statistical_foundations/test_validate_config.R` | 成功 |

追加の証跡保存故障・証跡改ざん試験を `tests/test_run_scope_guards.R` に追加した後、同ファイルを再実行して成功した。3スキルの実描画は `tests/test_run_scope_lifecycle.R` 内で行い、公開HTMLのsrc/hrefを検査した。

Python：`python3 -B -m pytest --assert=plain -p no:cacheprovider tests/test_analysis_quality_contract_docs.py tests/test_skill_ownership_contract.py` → **12 passed**。

OpenSpec：`openspec validate harden-run-path-handover --strict` → 合格。`git diff --check` → 合格。

## 修正前から残る表示テスト3件

| テスト | 修正前・修正後で共通する失敗 |
|---|---|
| test_vcd_dashboard_display_formats.R | 旧bf10表示等の定義を期待 |
| test_vcd_dashboard_layout_core.R | .exec-topk-layoutのdisplay:blockを期待 |
| test_vcd_dashboard_layout_foundation.R | max-width:1000pxを期待 |

修正開始時の実装を別の一時チェックアウトに再構成し、3件とも終了コード1と同じ失敗内容を確認した。今回の確定・引き継ぎ契約の修正とは分離し、合格として扱っていない。

## 差分境界と証拠

基準HEAD：`1cd575edd0550327cb45557943c4eb7ae38b3442`。開始時の未コミット実装を保全し、今回の修正をその上へ追加した。

開始時の退避先：`/var/folders/w4/kqtskdyx29vdbjvlv7gx0t9h0000gn/T/handover_pre_fix_85s6_3mj`。実行ログ：`/tmp/handover_regression/verified_results.json` と同ディレクトリの `verified_*.log`。これらは一時ファイルであり、恒久的な証拠は本報告の試験一覧・下記ハッシュとリポジトリ内の再実行可能なテストとする。

| 主な検証済みファイル | SHA-256 |
|---|---|
| `.agents/shared/run_scope.R` | `36bd742cf93abc639a42f045298b1888d6e44af0ed3427865717951d383be481` |
| `.agents/shared/finalize_run_stage.R` | `ad4a5a7699a77ca47f7389b3f4af92a9265c93e4f58318e7f9a8e5a2992e78d3` |
| `tests/test_run_scope_guards.R` | `d138b2047ed1f97aca74b25776bcd6ee4c6dcfce4250c8d72dbc8c68b6bf2a26` |
| `tests/test_run_scope_lifecycle.R` | `9665ed9914a593d189caffa9745762debf2a8f7be308369b6fe5ed044a2b22a7` |

コード・テスト修正はユーザーの明示指示に基づく。commit、push、OpenSpec archiveは実施していない。
