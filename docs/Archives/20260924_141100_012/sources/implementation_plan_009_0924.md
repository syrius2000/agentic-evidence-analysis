# 実装計画 009 — Phase 2 Section 10 IPTW QA 修復

created: 2026-09-24 00:21 (JST)
update: 2026-09-24 00:21 (JST)
author: Codex (GPT-6)

## 1. 目的

独立QAで `HOLD` とされた Phase 2 Section 10（IPTW）の指摘を修復し、重み付き推定量、推論方式、診断および再標本化の意味が実装・出力・レポート間で一貫する状態にする。

## 2. 根拠と対象範囲

- QA報告: [Phase2_Section10_IPTW_QA_Repair_Report_20260924.md](Phase2_Section10_IPTW_QA_Repair_Report_20260924.md)
- 親計画: [implementation_plan_008_0923.md](../Archives/20260924_011800_011/sources/implementation_plan_008_0923.md)
- OpenSpec: [comparative-evidence-reporting-v3](../../openspec/changes/comparative-evidence-reporting-v3/)

本計画は既存の Section 10 初回実装計画を置き換えず、独立QA後の修復を対象とする。変更対象は、IPTW計算・出力・レポートの実装、関連スキーマ、回帰テスト、Section 10 のOpenSpecタスクと必要な契約記述に限定する。

## 3. 修復内容

| ID | 優先度 | 実施内容 | 受入証拠 |
|---|---|---|---|
| 10.R1 | P0 | IPTWとBayesianでレポート表現を推論セマンティクスに応じて分岐 | IPTWのbootstrap percentile / support fraction表現とBayesianのposterior / ETI表現を両方検証 |
| 10.R2 | P0 | PS境界処理を仕様化し、raw/effective PS、clipping回数・閾値を機械可読化 | 分離・境界fixtureとmetadata/diagnostic検証 |
| 10.R3 | P0 | raw events/totalとIPTW weighted riskを出力上で分離 | raw counts保管先、weighted estimates、schemaをfixtureで検証 |
| 10.R4 | P0 | `max_failure_rate` を公開APIから設定可能にし入力検証と診断metadataを追加 | 正常・閾値超過の決定的fixture |
| 10.R5 | P1 | arm別percentile truncation testを既知期待値との厳密比較に置換 | target/reference双方の上下限を数値検証 |
| 10.R6 | P1 | extreme weight warningの実行可能テストを追加 | 警告コードとweight summaryを検証 |
| 10.R7 | P1 | positivity / overlap の通常・非重複ケースを検証 | common supportと診断状態を検証 |
| 10.R8 | P1 | subject ID指定時の欠損・重複行を拒否し、反復測定入力の境界を明記 | duplicate/NA subject fixtureでfail-fastを検証 |
| 10.R9 | P1 | IPTW draws metadataにrefit、truncation、scaling、PS model、境界処理、収束閾値を記録 | schema positive/negative test |
| 10.R10 | P2 | ATT stabilizationとscaling modeのAPI意味を一意にする | 許可・拒否組合せのテスト |
| 10.R11 | P2 | OpenSpec完了チェックを実証状態に合わせて更新 | 各完了項目に対応する自動検証の確認 |

修復方針の未確定事項（PS boundary policy、ATT stabilization組合せ、duplicate ID時のエラー契約）は、実装前にOpenSpec契約と照合し、既存契約を越える選択肢を追加しない。契約変更が必要となる場合は本計画を更新する。

## 4. 想定変更ファイル

- `.agents/shared/iptw_inference.R`
- IPTWを描画・報告する既存reporting実装と、その統合テスト
- `schemas/comparative-evidence-v1.json`
- `schemas/comparative-draws-v1.json`
- `tests/test_iptw_inference.R`
- `tests/test_comparative_schemas.R` および必要なreportingテスト
- `openspec/changes/comparative-evidence-reporting-v3/` の IPTW 契約・タスク
- 必要な場合に限り `.agents/skills/comparative-design-analysis/SKILL.md`

実装開始時に対象箇所と依存関係を再確認する。上記以外の変更が必要と判明した場合、先に計画を更新して承認を得る。

## 5. 検証計画

1. 対象のIPTW単体・スキーマ・reportingテストを実行する。
2. 正規回帰スイートを実行する。
3. `openspec validate comparative-evidence-reporting-v3 --strict --json` を実行する。
4. `git diff --check` と差分対象を確認する。
5. 検証結果、未解決Medium/Low項目、Gate判断をQA修復記録にまとめる。テスト成功のみで `ACCEPT` にせず、Owner裁定を分離して報告する。

## 6. 実施境界

- この計画の作成は調査・計画フェーズであり、実装承認を意味しない。
- コード、schema、テスト、OpenSpecの変更は、ユーザーが本計画の対象範囲を明示承認した後に行う。
- commit、push、branch削除、archiveは本計画に含めない。
