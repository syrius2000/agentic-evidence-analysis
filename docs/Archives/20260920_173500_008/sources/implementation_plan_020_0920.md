# shared-dashboard-theme-assets 最終独立QA実施計画

created: 2026-09-20 16:27 (JST)
update: 2026-09-20 16:27 (JST)
author: Codex (GPT-5)

## 1. 目的と結論

本計画の本命は、`shared-dashboard-theme-assets` の修正実装後に、
[`docs/plans/test_plan_005_0920_shared_dashboard_final_qa.md`](./test_plan_005_0920_shared_dashboard_final_qa.md)
を基準として行う最終独立QAである。

実装を担当するAIと、検証を担当するCodexを分離する。Codexは実装者の説明や過去のPASS報告を根拠に完了判定を出さず、対象revisionを固定したうえで、blind-first順に仕様・テスト・実装・生成成果物を自ら検査する。

本書は「QAを開始するための実施計画」であり、現時点ではコード変更、依存関係追加、テストの修正、OpenSpecのarchive、commit、push、既存成果物の削除を承認しない。

## 2. 対象と責務分離

### 2.1 対象

- Active Change: `openspec/changes/shared-dashboard-theme-assets/`
- 実装修正計画: [`docs/plans/implementation_plan_009_0920_shared_dashboard_repair.md`](./implementation_plan_009_0920_shared_dashboard_repair.md)
- 最終QA基準: [`docs/plans/test_plan_005_0920_shared_dashboard_final_qa.md`](./test_plan_005_0920_shared_dashboard_final_qa.md)
- 代表生成物: `skill_out/vcd_categorical/run_otc_q05_design_test/dashboard.html`

### 2.2 役割

| 役割 | 担当 | 許可される作業 | 許可されない作業 |
|---|---|---|---|
| 実装者 | 別AI | 修正計画に沿うOpenSpec・R・Rmd・テストの実装、自己検証 | QA結果の自己承認、Codex名義の独立QA報告 |
| 独立QA担当 | Codex | T01〜T18の再実行、証跡収集、FindingとPASS/HOLDの報告 | 実装修正、テストをPASSさせるための変更、archive、commit、push、削除 |
| Owner | ユーザー | 修正の実施承認、QA後の残余リスク受容、archive/commit/pushの個別判断 | なし |

## 3. QA開始ゲート

実装者が「完了」と報告しても、以下がそろうまで独立QAを開始しない。

- [ ] 対象Change、対象branch、HEAD SHA-256ではなくGit commit SHAを記録できる
- [ ] 実装者が変更対象ファイル、実施したテスト、未検証項目を明示している
- [ ] `git status --short` を取得し、QA開始前から存在する差分と対象実装差分を区別できる
- [ ] QAのために生成する一時出力先を、既存のcanonical run・ユーザー成果物と衝突しない場所へ定めた
- [ ] 入力fixture、R実行環境、利用パッケージの可用性を事前記録できる

開始ゲートを満たさない場合は、推測で補わず `HOLD（対象revisionまたは証跡不足）` と報告する。

## 4. 独立QAの実施順序

`test_plan_005` のblind-first原則を次の順で厳守する。実装者の自己評価と従前の検証報告は手順7まで参照しない。

1. `openspec/specs/` の正本仕様を読む
2. active change の proposal、design、delta spec、tasksを読む
3. 本計画と `test_plan_005` の受入基準を照合する
4. テストの期待値と網羅性を確認する
5. 実装を読む
6. 新規に生成した2-way/3-way HTMLおよびJSONを検査する
7. 過去のverification reportと実装者説明を読み、独立結果との不一致を確認する
8. Owner裁定に必要な残余リスクを整理する

## 5. テスト実行マトリクス

| 群 | テスト | 主な判定 | 必須証跡 |
|---|---|---|---|
| 契約・構文 | T01, T02, T03, T16 | JSON schemaのparse、fixed prior、正本責務、OpenSpec strict | 実行コマンド、終了値、関連ファイルの抜粋 |
| 数学・数値 | T04, T05, T06, T13, T14 | 希少確率、ゼロ分母、ETI、prior metadata、非回帰 | 入力、期待式または期待状態、実測JSON/R出力 |
| 2-way表示 | T07, T08, T09, T10, T17 | 11分析section、Glossary Appendix、導線、文言、MathML | 新規HTML、DOM/静的検査結果、目視結果 |
| 共通アセット | T11, T12 | 外部参照ゼロ、inline asset、共有asset失敗時の明示停止 | 静的スキャン条件と件数、失敗系の実測 |
| 運用回帰 | T15 | official regression登録とcore/render gate | runner出力、登録根拠 |
| 対話・ブラウザ | T18 | accordion、表操作、JS error、network、可読性 | 使用ブラウザ・日時・確認項目別の結果 |

### 5.1 数学判定の補足

T04では、与えられた希少事象fixtureについて主事前の集約事後が `Beta(2, 120001.5)` となることを独立に確認する。モンテカルロ推定との比較を行う場合は、乱数seed、draw数、比較する統計量、MC誤差を踏まえた事前宣言済み許容差をQA報告に明記する。単に表示がゼロでないだけではPASSとしない。

T14は、条件付き割合表示以外の値が完全なバイト一致であることを要求しない。Poisson/BIC、局所診断式、ゼロセル規約、3-way candidate ruleに影響がないことを、固定fixtureの対応フィールドで確認する。

## 6. 生成・ブラウザ検証の境界

- 生成HTMLは新規の隔離出力先に出し、既存の `skill_out` runを上書きしない。
- T11の外部参照判定は、本文中の文献URLやMathML namespaceを誤検知しない。`src`、`href`、CSS `url()`、module/import等のリソース属性を対象にする。
- T18は、実際に使用したブラウザ/自動化手段、実行日時、コンソールエラーの有無、Network観察の可否を記録する。ブラウザ利用が不能なら「未検証」とし、静的検査で代替した事実を明記する。
- 画面の審美性は合否を恣意的にしない。長いラベル、グラフの凡例、accordion、DataTables操作を具体的な観察対象に分解して記録する。

## 7. QA報告と判定

QA終了時に、`docs/Artifacts/` の命名規約に従う新規の独立QA報告を作成する。報告は少なくとも以下を含む。

- 対象HEAD、branch、Change、実行日時、実行環境
- blind-first順序を守った記録
- T01〜T18の各結果、実行コマンド、終了値、証跡への相対リンク
- FindingごとのSeverity、契約、再現手順、影響、必要な修正
- 実行不能・未検証事項と理由
- 最終状態を `PASS` または `HOLD` として明記
- Ownerが判断すべき残余リスク

`openspec validate --strict` の成功、チェックボックスの完了、実装者の自己テスト成功は、単独ではPASS根拠にしない。

## 8. 判定規則

次のいずれかがあれば `HOLD` とする。

- JSON schema不正、固定prior逸脱受容、希少正確率のゼロ化、ETI表示不整合
- 11分析sectionの破壊またはGlossaryのSection 12化
- 外部またはローカル絶対アセットの導入
- old runのJeffreysへの再ラベル
- presentation層での統計量再計算
- mandatory regressionの失敗または未実行
- 対象revision・入力・生成物の対応関係を証明できない

T01〜T18の該当項目がすべてPASSし、material findingがなく、未検証事項が残らない場合のみ `PASS` を報告する。PASS後のarchive、commit、pushはOwnerの別指示を必要とする。

## 9. 非目標

- Markdown linterの導入、`package.json`/lockfileの追加、wrapper作成
- 実装修正そのもの、テストの緩和、リファクタリング
- KaTeX/MathJax導入、MathML方式変更、ダークモード、モバイル再設計
- 新しい統計手法、任意alpha設定、規制提出可否の認証
- 既存run、文書archive、Git履歴、未追跡ファイルの削除

Markdown lint導入は依存関係変更を伴いうるため、本QAの完了後に別の実装計画・別承認で扱う。

## 10. 実施承認の範囲

ユーザーが本計画を承認し、かつ実装者の対象revisionが固定された後、Codexは本書と `test_plan_005` の範囲に限り独立QAを実施する。その承認は修正実装、archive、commit、push、削除、Markdown lint導入を含まない。
