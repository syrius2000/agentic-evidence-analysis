# evidence_runs整理とQA履歴を含むトピックのmain集約計画

created: 2026-10-06 22:49 (JST)
update: 2026-10-06 22:56 (JST)
author: Codex (GPT-6)

## 1. 目的と境界

`codex/standardize-evidence-run-output-contract` の実装・修復・QA成果物を、Yip形式のQA専用コミット列を `main` の履歴へ持ち込まずに集約する。同時に、リポジトリ内 `evidence_runs/` と作業で特定できる一時ディレクトリを整理する。

本書は計画のみである。承認まではファイル削除、tempディレクトリ削除、ブランチ切替、履歴変更、merge、commit、push、ブランチ削除を行わない。

## 2. 現状確認

- 作業ブランチ: `codex/standardize-evidence-run-output-contract`
- 作業HEAD: `f00b3bc42909a8a29b4782bbe60c14a5e05dfa63`（c4 QA成果物コミット）
- ローカル `main` と `origin/main`: `65821b3da618a57ea9775eb0c1054eea6ffe546a`（一致）
- トピックブランチのリモート追跡先: `origin/codex/standardize-evidence-run-output-contract` は `03081d6fe278b83c349ff65d4ea23f92b7328a7e`。ローカルにはその後の4コミットがある。
- 現時点でtracked作業差分はない。`evidence_runs/` は `.gitkeep` のみtrackedで、他はGit ignore対象。
- `evidence_runs/` は約20 MB、645ファイル、第一階層のrun/testディレクトリが17個。`.gitkeep`以外はすべてignoredの生成出力であり、今回のcleanup候補を全域へ広げる。
- `evidence_runs/`のcleanup範囲は、明確なテスト名の出力7個に加え、`inspections/appleton_1996/`、`vcd_categorical_reporting/run_*`を含む全slug root内のrun・inspection成果物とする。解析結果も再生成対象として削除する。`evidence_runs/`外の入力元ファイルや原本には触れない。
- `TMPDIR`配下に最近更新されたRの`Rtmp*`ディレクトリを6個確認した。内容に`callr`、一時`.rds`等がある。cleanup時点でR/callr等の実行プロセスがなく、manifest後も開かれていないものは一時生成物として削除候補にする。
- workspaceの一時生成候補は`tests/skill_out_smoke/`、`scripts/__pycache__/`、`tests/__pycache__/`。`tests/fixtures/vcd_bayesian_dashboard/.../dt_table_files/`はfixture利用物の可能性があるため現状維持とする。
- `tests/fixtures/path_sanitization/would_reject_examples.md`は「追跡されると回帰テストが失敗する」ため意図的にuntrackedであるpositive-control fixtureであり、temp扱いで削除しない。`.agents/skills/openspec-*`はインストール済みスキル、`/private/tmp/codex-browser-use`とCUAサービス領域はアプリ管理下なので対象外とする。
- `main...topic` は84ファイル、約2,057行追加の差分で、実装、計画、c1〜c4 QA成果物を含む。`.agents/skills/.openspec-target` は `main` の `codex` からtopicの `agents` に変わっている。この変更はQA checkpoint由来で、今回の出力契約機能との関係が確認できないため、集約前に扱いを確定する。

## 3. 推奨方針

### QA用コミットログ

ローカル `main` 上でトピック全体をsquashし、単一の機能コミット `feat: standardize evidence run output contract` として記録する。c1〜c4の招待・レビュー・タスク・STATUSファイルはツリー内に保持し、コミット履歴だけを簡潔にする。topicブランチの履歴自体は書き換えない。

### `codex/standardize-evidence-run-output-contract` の扱い

マージとmain検証が完了するまではローカルブランチを保持し、復旧・照合用にする。mainのsquash後も直ちに削除しない。安定確認後のローカルブランチ削除は別の明示承認に分ける。リモートtopic branchのpush・削除・force-pushはこの計画に含めない。

### 実行出力と一時ディレクトリ

`evidence_runs/`は`.gitkeep`を除く全run/inspection内容をcleanupする。加えて、現存するworkspaceのPython cache・smoke outputと、非稼働を確認できた`TMPDIR/Rtmp*`をcleanupする。削除前に対象パス・サイズ・ファイル数・SHA-256を記録し、他の一時退避領域へ隔離して検証する。positive-control fixture、HTML fixture資産、インストール済みスキル、Codex/CUA管理tempは保持する。

## 4. 実施手順（承認後）

1. **事前固定**: `git fetch origin`後、`main`、`origin/main`、topic HEAD、作業ツリーを再確認する。mainまたはtopicが本計画記載のSHAから動いていた場合は停止して計画を更新する。mainとtopicの参照SHAを記録する。topicのローカル履歴は変更しない。
2. **cleanup対象の確認と削除**: `evidence_runs/`内の`.gitkeep`以外すべて、workspaceの2つの`__pycache__`と`tests/skill_out_smoke/`、および非稼働のRtmp候補をmanifest（パス、バイト数、ファイル数、SHA-256）へ記録する。削除中の復旧用に候補を一時隔離し、対象件数・ハッシュを照合してから隔離コピーと一時manifestを削除する。positive-control fixture、`dt_table_files`、アプリ管理tempは削除しない。
3. **統合範囲を確定**: squash前の差分をレビューする。`.agents/skills/.openspec-target`は基点の`codex`を維持し、別途必要とOwnerが判断した場合のみ変更対象に含める。evidence_runsの無視対象や外部tempファイルがGit indexへ入らないことを確認する。
4. **squash集約**: `main`へ切り替え、トピック差分をsquashする。c1〜c4のQA成果物、実装、テスト、計画書を保持し、`.openspec-target`は上記方針どおりに扱う。差分を確認してから `feat: standardize evidence run output contract` の1コミットを作る。
5. **main検証**: `Rscript tests/test_skill_run_isolation.R`、関連する出力root回帰テスト、`python3 scripts/test_doc_consistency.py`、`openspec validate standardize-evidence-run-output-contract --type change --strict`を実行する。`git diff --check`、QA成果物の存在、mainのcommit graph、evidence_runsの削除manifestとの差を照合する。失敗時は追加変更せず停止し、topicブランチから復旧する。
6. **保持確認**: 検証成功後もtopicブランチを保持する。最終照合後にcleanup用の退避物と一時manifestを削除し、対象一時DIRが残っていないことを確認する。remoteには書き込まない。

## 5. 確認マトリクス

| 対象 | 入力・根拠 | 確認 | 期待結果 |
|---|---|---|---|
| 実行出力候補 | `evidence_runs/`の`.gitkeep`以外全て | 削除前後のmanifest、SHA-256、ファイル数を照合 | ignored run/inspection出力が空になり、`.gitkeep`だけ残る |
| 一時ファイル/dir | `tests/skill_out_smoke/`、2つの`__pycache__`、非稼働`TMPDIR/Rtmp*` | プロセス確認と削除前後一覧を照合 | 対象tempが消え、fixture・アプリ管理領域は維持される |
| squash対象 | `main...codex/standardize-evidence-run-output-contract` | `git diff --name-status/stat` とindex確認 | 実装・QA証跡は保持し、ignored出力は含めない |
| OpenSpec target | `.agents/skills/.openspec-target` | main値`codex`とtopic値`agents`、参照箇所を照合 | Owner確認なしに環境選択値を持ち込まない |
| main統合後 | squash後のmain | 回帰テスト・文書整合・OpenSpec strict・差分確認 | 全確認成功、mainに機能コミット1件、QA証跡ファイル保持 |

### データ契約と由来

統計解析データの再計算・変換は行わない。cleanup対象はGit ignore下の`evidence_runs/`生成出力全てと指定temp/cacheに限定する。解析run成果物も対象に含むことを明示し、元入力ファイルには触れない。実行出力契約は [`evidence-run-layout`](../../openspec/specs/evidence-run-layout/spec.md)、削除対象の実体と来歴は実施時に作るSHA-256 manifestを正本とする。

## 6. 完了条件と停止条件

完了条件:

- `evidence_runs/`の全ignored出力、指定workspace cache/temp、非稼働を確認したRtmpが削除され、trackedの`.gitkeep`と明示保全したfixture・アプリ管理領域だけが残る。
- `main`に機能を表すsquash commitが1件あり、Yip QA専用コミット列をmainの履歴へ持ち込まない。
- c1〜c4のQA証跡、実装・テストがmainのツリーに存在し、確認マトリクスがすべて成功する。
- `codex/standardize-evidence-run-output-contract`は復旧用に保持され、push・force-push・remote branch削除はない。

停止条件:

- remote main/topicの更新、作業ツリー差分、cleanup対象内に再生成不能な入力原本・手作業ファイルが見つかる、削除対象外tempの所有者が不明、`.openspec-target`の用途不明、またはsquash差分が本計画範囲外に及ぶ。
- テスト・OpenSpec・文書検査のいずれかが失敗する。

この計画の承認は、`evidence_runs/`全生成出力、指定workspace temp/cache、非稼働Rtmpのcleanupとローカルmain squash統合に限る。positive-control fixture、HTML fixture、アプリ管理領域、evidence_runs外の原本、topic/remote branch削除、remote push、その他のデータ削除は含まない。
