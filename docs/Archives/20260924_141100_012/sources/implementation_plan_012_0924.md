# 実装計画 012 — Phase 2 Section 11 人年発生率エンジン

created: 2026-09-24 01:38 (JST)
update: 2026-09-24 01:38 (JST)
author: Codex (GPT-6)

## 1. 目的と対象

OpenSpec Change `comparative-evidence-reporting-v3` のSection 11（11.1〜11.6）を実装する。[QA報告3](Phase2_Section10_IPTW_QA_Repair_Report3_20260924.md)はSection 10を`PASS / ACCEPT`とし、Section 11への着手を許容している。本計画はSection 11のGamma–Poisson人年発生率推論、IRD/IRR、出力schema、回帰検証だけを対象とする。

## 2. 現状と設計上の境界

- 現在のHEADは`4829cb0`、ブランチは`feat/comparative-evidence-reporting-v3`。Section 10受入後修復の未コミット差分、計画011・実施記録003・共有PS schema、既存の未追跡QA報告3を保持する。
- OpenSpec CLIは`spec-driven`、計画成果物完了、全201タスク中139完了・62残件、適用状態`ready`を示す。Section 11の6タスクは未完了。
- 既存の`compute_comparative_contrasts()`と`comparative-evidence-v1.json`は二値リスクの項目名と分母を前提にする。率を`risk_difference`・`relative_risk`・`incidence_proportion`へ入れず、共有contrastモジュールに率専用変換を加え、率専用evidence schemaを定義する。
- 本フェーズは集計イベント数と曝露人時からの推論エンジンである。患者レベルの反復イベント相関、変動ハザード、IPTW、レポート画面への率表示は含めない。

## 3. 実装契約

| OpenSpecタスク | 実装内容 | 受入証拠 |
|---|---|---|
| 11.1 | 非負整数のイベント数`x_g`と有限・正の曝露量`T_g`を検証し、Jeffreys事前分布から`Gamma(shape=x_g+0.5, rate=T_g)`を生成する。`x_g > T_g`は人年率では許容する。 | 入力境界・形状/率・再現性の単体確認。 |
| 11.2 | 目標群・参照群の率drawを生成し、事後中央値と95% ETIを`posterior`/`posterior_median`/`posterior_eti`として記録する。raw drawの永続化は明示指定時のみ。 | 解析的Gamma分位点との数値比較、同一seedで一致。 |
| 11.3 | 共有contrastモジュールに率専用変換を追加し、drawごとに`IRD=λ_T−λ_R`、`IRR=λ_T/λ_R`を計算する。率差と率比の名前・単位をリスク差/比から分離する。 | 計算済みdrawからの直接照合、正値・有限性確認。 |
| 11.4 | `person_years`/`person_months`、各群曝露分母、`gamma_parameterization=shape_rate`をdraw/evidence metadataに保存する。100人年当たり追加イベント数は月単位入力を年換算して算出する。率専用evidence schemaを追加し、draw schemaにはperson-time metadataを加える。 | 正例・欠落/不正単位/分母のschema負例。 |
| 11.5 | 一定発生率の仮定と、個人内反復イベントのクラスタリングを扱わない限界を構造化出力に記録する。 | 単体テストで文言と出力項目を確認。 |
| 11.6 | 両群・参照群のゼロイベントを検証する。参照群0件時、IRRの理論平均は発散するため`mean=null`、`mean_is_finite=false`とし、中央値・ETIは保持する。曝露量0は拒否する。 | ゼロイベントfixture、発散平均の抑止、有限な分位点。 |

## 4. 想定変更対象

- `.agents/shared/person_time_rate.R`（新規）
- `.agents/shared/comparative_contrasts.R`（率専用変換を追加。既存リスク変換の意味は維持）
- `schemas/comparative-draws-v1.json`（既存のSection 10差分を保持しつつperson-time metadataを追加）
- `schemas/comparative-rate-evidence-v1.json`（新規、率専用evidence）
- `tests/test_person_time_rate.R`（新規）、`tests/test_comparative_schemas.R`
- `tests/run_regression_suite.R`（新テストを正規対象に追加）
- `openspec/changes/comparative-evidence-reporting-v3/design.md`、`specs/comparative-design-inference/spec.md`、`tasks.md`（率出力契約の明確化と進捗）
- `docs/Artifacts/person_time_section11_execution_001_0924.md`（新規実施記録）

上記以外のコード・文書に変更が必要になった場合は、計画を更新し再承認を得る。

## 5. 検証

1. `Rscript tests/test_person_time_rate.R`
2. `Rscript tests/test_comparative_schemas.R`
3. `Rscript tests/run_regression_suite.R`
4. `openspec validate comparative-evidence-reporting-v3 --strict --json`
5. JSON schema構文、`git diff --check`、Section 10既存差分・未追跡ファイルの保持を確認する。

結果は実施記録に実測値として残す。構文検証・回帰テスト・独立QA・Owner判断を区別する。commit、push、archiveは対象外。

## 6. 承認境界

本計画の作成と読み取り専用調査は実装承認を意味しない。リポジトリの`AGENTS.md`にある段階的承認ルールに従い、本計画の対象と方式への明示的承認後にコード・schema・テスト・OpenSpecの変更と実行フェーズへ移る。
