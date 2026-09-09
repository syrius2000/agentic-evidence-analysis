# 成果物パス可搬化・個人情報漏洩防止の実装計画

created: 2026-09-09 08:58 (JST)
update: 2026-09-09 08:58 (JST)
author: Codex (GPT-6)

## 目的

実行時の絶対パスを永続化成果物へ直接保存している問題を解消し、リポジトリ移動、別worktree、CI、コンテナでもrun成果物を再検証できるようにする。実行時の安全な絶対パス解決は維持し、JSON、CSV、HTML、ログに個人名やホームディレクトリを出力しない。

## 対象範囲

- `.agents/shared/run_scope.R`、`finalize_run_stage.R`、`inspect_data.R`
- 3スキルのPass 1・Pass 3テンプレートと成果物メタデータ
- 可搬化、legacy互換、外部入力hash-only、run handover、ロック監査情報
- 絶対パス漏洩、worktree移動、legacy、symlink、パストラバーサル、数値不変性のテスト

## 実装契約

- 永続化パスは `path_kind`（`repo_relative` / `run_relative` / `external`）と `path_schema_version` を持つ。
- 外部入力は既定で物理パスを保存せず、SHA-256と論理ラベルを保存する。物理パスの保存は明示オプトインに限る。
- リポジトリルートは明示引数、Git worktree、共通スクリプト配置位置の順で解決し、曖昧・解決不能なら停止する。
- legacy絶対パスは読み取り・previewだけ許可し、新規書込みや本番再確定で再出力しない。
- 通常モードはGit indexを変更せず、既存差分を保持する。commit、push、既存runの一括書換えは対象外とする。
- 実装前後で統計値、モデル評価、4軸指標を比較し、パス表現以外の差分を許可しない。

## 受入条件

1. 新規runの永続化テキストにホームディレクトリ、個人名、ホスト固有ルートが残らない。
2. repo内、run内、外部入力、legacy、symlink、`..`、prefix衝突を保存・復元・拒否テストで網羅する。
3. 別一時worktreeへrunを移してmanifest、Pass 2、Pass 3、supersede検証が成功する。
4. `run_handover.json` のcwdとargvが物理環境に依存せず、外部cwdから再実行できる。
5. 可搬化前後の統計結果と既存回帰テストが不変である。
6. 途中失敗時にjournalとsnapshotから復旧または機械可読なfailed停止ができる。

## 検証

- `tests/test_relocatable_run_lifecycle.R` を新設する。
- 既存のrun scope、3スキル、統計基盤、Python契約テストを順次実行する。
- `rg` による全成果物の個人パス・不要な絶対パス走査を実施する。
- `git diff --check` と開始時・終了時の差分境界を確認する。

## 参照計画

詳細な背景と対象ファイル一覧は、次のIDE計画を正本として参照する。

`/Users/myamaguchi/.gemini/antigravity-ide/brain/7dd0df52-1968-4fd3-a9aa-b5556aae5965/implementation_plan.md`
