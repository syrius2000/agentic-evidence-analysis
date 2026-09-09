# 成果物パス可搬化・個人情報漏洩防止の実装報告

created: 2026-09-09 09:15 (JST)
update: 2026-09-09 09:18 (JST)
author: Codex (GPT-6)

## 実装内容

- `.agents/shared/run_scope.R` に `path_schema_version: "1.0"`、`repo_relative`・`run_relative`・`external` の保存表現、実行時解決、legacy 読み取り互換を追加しました。
- `run_meta.json` の入力・設定・run 参照を可搬化し、外部入力は既定で SHA-256 と論理ラベルだけを保存します。明示的な supersede 元だけは外部絶対パスを互換的に扱います。
- `run_handover.json` は `cwd: "."`、repo root marker、run 内相対引数で保存します。同一プロセスの戻り値は既存呼び出し向けに解決済み値を返します。
- ロック情報には run の物理パスを保存せず、SHA-256 識別子と run 相対 marker を保存します。旧 lock_info の回復も維持しました。
- `inspect_data.R`、Bayesian の結果 provenance、統計基盤検証結果、Questionnaire の `summary.csv`、各ダッシュボード表示からホスト固有の絶対パスを除去しました。
- 可搬 run の移設、外部入力 hash-only、manifest ハッシュ不変、legacy 読み取り、handover の漏洩検査を `tests/test_relocatable_run_lifecycle.R` に追加しました。

## 検証結果

- `Rscript tests/test_run_scope_lifecycle.R`：全 Phase 合格。
- `Rscript tests/test_run_scope_guards.R`：確定境界・回復・排他テスト合格。
- `Rscript tests/test_relocatable_run_lifecycle.R`：可搬性テスト合格。
- `Rscript tests/test_vcd_cat_pass1.R`：Categorical Pass 1 合格。
- `Rscript tests/test_questionnaire_batch_smoke.R`：22 件合格。
- `Rscript tests/test_summary_csv_new_columns.R`：17 件合格。
- Python 契約テスト 12 件合格。
- `git diff --check`：空白・競合マーカーなし。

既存の `docs/Artifacts` 削除および `docs/Archives/archived_summary_003_0909.md` 追加は、作業開始時から存在した整理差分として保持しています。外部への push と commit は実施していません。
