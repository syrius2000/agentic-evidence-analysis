# テスト共有ヘルパーのroot tests配下への移動計画

created: 2026-09-18 06:45 (JST)
update: 2026-09-18 06:45 (JST)
author: Codex (GPT-5)

## 1. 目的

Skill実行資産とroot回帰テスト資産の責務を分離するため、テスト専用の共有ヘルパーを `.agents/skills` から `tests/` 配下へ移動する。

## 2. 変更対象

- 移動元: `.agents/skills/questionnaire-batch-analysis/tests/helpers_backup_recovery.R`
- 移動先: `tests/helpers/helpers_backup_recovery.R`
- 参照更新:
  - `tests/test_questionnaire_backup_recovery.R`
  - `tests/test_questionnaire_batch_ucbadmissions.R`

## 3. 対象外

- `.agents/skills` 配下のSkill本体、テンプレート、Schema、Reference
- `docs/Archives/` の履歴資料
- 既存のrootテストの検証内容
- 依存関係、データ、解析成果物
- commit、push、ブランチ操作

## 4. 検証計画

1. 移動元が消え、移動先に共有ヘルパーが存在することを確認する。
2. 2つのrootテストが移動先を参照していることを確認する。
3. `.agents/skills` 配下にテスト専用ディレクトリ・ファイルが残っていないことを確認する。
4. `tests/test_questionnaire_backup_recovery.R` と `tests/test_questionnaire_batch_ucbadmissions.R` を実行する。
5. `git diff --check` とGit差分範囲を確認する。

## 5. 完了条件

- テスト共有ヘルパーがrootの `tests/helpers/` に集約される。
- 参照元2テストが正常に実行できる。
- 既存の未コミット変更と履歴資料を保持する。
