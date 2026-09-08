# harden-run-path-handover 実装検証報告（Codex・独立再検証）

created: 2026-09-09 01:42 (JST)
update: 2026-09-09 01:42 (JST)
author: Codex (GPT-6)

## 判定

OpenSpecの計画状態、実装タスク、主要な確定境界および回帰試験を再検証した。今回のChangeに属するCRITICALな未実装・再現不具合は確認されなかった。アーカイブへ進める状態だが、既存UIテストの失敗3件と利用不能スキルによるスキップ1件は、未解決の検証上の注意点として記録する。

## 検証スコアカード

| 観点 | 結果 | 根拠 |
|---|---|---|
| 完全性 | 30/30タスク完了 | `tasks.md` のチェックボックスを再集計。未完了0件。 |
| 仕様網羅 | 要件26件、シナリオ45件を抽出 | delta specを機械的に再集計し、実装・テストのキーワードと主要経路を照合。 |
| 正確性 | 主要な危険経路は合格 | 排他競合、故障注入・回復、証跡改ざん、symlink、legacy、supersede、partial/failed、sealed再実行を実テストで確認。 |
| 整合性 | 設計方針と整合 | 共通`run_scope.R`／CLI finalizerへの委譲、追記限定、staging、原子的rename、ハッシュ由来、cwd付きhandoverを確認。 |

## 実行した検証

- `openspec validate harden-run-path-handover --strict`：合格。
- `openspec instructions apply --change harden-run-path-handover --json`：30/30、`state: all_done`。
- `Rscript tests/test_run_scope_guards.R`：確定境界・回復・排他・改ざん・supersede・handover等を全件成功。
- `Rscript tests/test_run_scope_lifecycle.R`：3スキルのPass 1〜3、partial/failed、preview、本番封印、公開HTMLのローカル補助アセット非依存を全件成功。
- `Rscript tests/test_vcd_categorical_dashboard_run_resolution.R`：JST・指定名・衝突サフィックスのrun解決を成功。
- `python3 -B -m pytest --assert=plain -p no:cacheprovider tests/test_analysis_quality_contract_docs.py tests/test_skill_ownership_contract.py`：12 passed。
- `git diff --check`：合格。

競合テストでは並行プロセスのロック解放と読み取りが重なるため、`lock_info.json` の一時的な不存在を示す警告が1件出力された。ただし対象プロセスの終了コードと全アサーションは成功しており、成果物の外部書き込みや確定漏れは確認されなかった。

既存の全Rテストは修正後に順次実行済みで、47ファイル中43成功、1ファイル全体スキップ、3ファイル失敗だった。失敗3件は修正前の一時チェックアウトでも同じ失敗を再現しており、本Changeの実装差分による回帰とは判定しない。

## 課題（優先度別）

### CRITICAL

なし。今回のChangeに定義された実装タスクの未完了および、主要な確定・回復境界の再現不具合は確認されなかった。

### WARNING

1. `tests/test_vcd_dashboard_display_formats.R`、`tests/test_vcd_dashboard_layout_core.R`、`tests/test_vcd_dashboard_layout_foundation.R` の3件は失敗している。いずれも修正前から同一内容で失敗しており、今回のrun handover変更とは別の既存UIアサーション差分である。UI変更を扱う別Changeで更新する。
2. `tests/test_security_skill_references.R` は対象スキルがリポジトリに存在しないため、全体スキップとなっている。スキル配布後に再実行する。

### SUGGESTION

- `tests/test_summary_csv_new_columns.R` の任意列4項目は未実施として記録されている。列契約を変更する場合に、専用フィクスチャを追加して検証する。

## 整合性確認

`design.md` の親ディレクトリと実runの分離、Pass 3の`sealed`封印、manifest由来ハッシュ、run外ロック、stagingからの同一ファイルシステムrename、legacy読み取り限定、`--supersedes-run`検証、Questionnaireの3状態、自己完結HTMLという決定は、実装とテストに対応している。確定処理は各スキルから共通`finalize_stage()`および`.agents/shared/finalize_run_stage.R`へ委譲され、個別スキルが独自に状態遷移を実装する分岐は確認されなかった。

## 次のアクション

このChangeは、上記の既存テスト注意点を記録したうえで、次の段階としてOpenSpecアーカイブへ進められる。

```text
$openspec-archive-change harden-run-path-handover
```

アーカイブ、commit、pushは別操作であり、この検証では実施していない。
