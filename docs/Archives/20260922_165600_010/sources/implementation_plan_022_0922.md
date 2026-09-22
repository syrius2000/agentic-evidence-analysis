# リポジトリ内スキル出力先の `evidence_runs/` 統一・移行計画

created: 2026-09-22 10:41 (JST)
update: 2026-09-22 10:47 (JST)
author: Codex (GPT-5)

status: 提案・承認待ち（本書の更新は実装、OpenSpec Change作成、既存出力の移動・削除を許可しない）

## 1. 概要と目的

本リポジトリ内の各スキル（`vcd-bayesian-evidence-analysis`、`vcd-categorical-analysis`、`questionnaire-batch-analysis`、`sas-proc-freq`、`sas-proc-means`）が新規解析で使用する推奨出力ルートを、`evidence_runs/` 配下へ整理する。

同時に、Run単位の隔離、パストラバーサル・シンボリックリンク対策、衝突時の採番、`run_meta.json` の整合性を維持する。`vcd-pass0-consultation` は解析エンジンではないため、検査結果と確定設定の出力契約を別枠で扱う。

本変更は文字列上の既定値置換に限定されない。特に `questionnaire-batch-analysis` の `runs/<id>/` は共有基盤の信頼境界と探索ロジックに組み込まれているため、OpenSpec、共有基盤、各スキル、利用者向け文書、回帰テストを一体として変更する。

## 2. 目標ディレクトリ構造

新規に書き込む成果物の推奨構造を次のとおりとする。

```text
evidence_runs/
├── vcd_bayesian/
│   └── run_<first16_run_id>[_N]/
├── vcd_categorical/
│   └── run_<prefix16>[_N]/
├── questionnaire/
│   └── run_<logical_id>[_N]/
│       ├── <output_slug>/
│       │   └── report.html
│       ├── summary.csv
│       └── cross_question_summary.md
├── sas_proc_freq/
│   └── run_<first16_run_id>[_N]/
├── sas_proc_means/
│   └── run_<first16_run_id>[_N]/
└── inspections/
    └── run_<logical_id>[_N]/
        └── inspection_results.json
```

`figures/` は標準成果物として新設しない。各スキルが既に必須成果物として持つファイルだけを維持し、不要な中間画像の恒久保存を導入しない。

## 3. 契約設計

### 3.1 出力ルートとRun隔離

1. `evidence_runs/` はリポジトリ相対の推奨既定ルートとする。利用者が明示した絶対パスまたは別の出力ルートは、既存の安全性検証を通過する限り許容する。
2. 新規解析は必ず物理ディレクトリ `run_<canonical_id>[_N]/` に隔離し、出力ルート直下への成果物書込みを禁止する。
3. 論理Run IDと物理ディレクトリ名を分離する。入力IDが `run_001` の場合も `run_run_001` を生成しないよう、先頭の `run_` を一度だけ正規化してから物理名を構成する。
4. 衝突時は共有基盤の原子的予約処理を使用し、`_2`、`_3` のような既存規約に従う。既存ディレクトリを上書きしない。
5. `questionnaire-batch-analysis` でRun IDが未指定の場合は、JSTの実行時刻を含む論理IDを生成する。曖昧な固定値 `run_default` は採用しない。
6. `run_meta.json` では、少なくとも論理Run ID、解決済みRun ID、出力ルート、物理Runディレクトリ、パススキーマ版を相互整合させる。レイアウト変更が既存版と互換でない場合はパススキーマ版を更新する。

### 3.2 CLIと設定JSON

CLIを機械的に一種類へ統一せず、責務別に契約を定める。

| 対象 | To-Be契約 | 注意事項 |
| :--- | :--- | :--- |
| `vcd-categorical-analysis` | 既存の `--out` を正規形とする。エイリアス追加の可否はOpenSpecで明示する | canonical modeの許可リストは入力安全境界であり、無条件に緩和しない |
| `vcd-bayesian-evidence-analysis` | 現行の `--output_dir` / `--output-dir` と `--out` の関係を仕様化する | 追加する場合は同時指定時の優先順位と競合エラーを定義する |
| `questionnaire-batch-analysis` | 既存の `--out` を維持する | `--run-id` の論理ID正規化を追加する |
| `sas-proc-freq` / `sas-proc-means` | 設定JSONの `output_dir` を正本とし、原則として出力先CLI上書きを追加しない | schemaの `default` は実行時に自動適用されるとは限らないため、単なる注釈で既定動作を主張しない |
| `inspect_data.R` | 検査出力用の `--out-dir` を維持する | 解析ランナーの `--out` と同一視しない |
| `finalize_pass0_config.R` | 確定設定用の `--output-dir` を維持する | 検査成果物と解析成果物の責務を分離する |

設定JSONとCLIの両方が出力先を指定できる実装では、優先順位を暗黙にしない。同時指定を拒否するか、CLIを優先するかをOpenSpecのシナリオとして固定し、テストする。

### 3.3 後方互換性と移行境界

1. 新規書込みは新レイアウトへ統一する。
2. 既存の `questionnaire` 出力 `runs/<id>/` は移動・改名・削除しない。
3. 既存成果物を参照する処理は、移行期間中、旧 `runs/<id>/` を読取り専用の探索対象として維持する。新規書込み先としては使用しない。
4. 既存の `skill_out/`、`skill_output/` と旧Run成果物は本計画の削除対象外とする。
5. `.gitignore` には `evidence_runs/` を追加する一方、旧ローカル成果物の誤追跡を防ぐため `skill_out/` と `skill_output/` の除外規則を保持する。
6. 旧パスを説明する履歴文書・legacy referenceは、削除せず「旧形式」と明記するか、静的検査の明示的除外対象にする。

## 4. OpenSpec方針

現時点でアクティブなOpenSpec Changeは存在しない。既存Specに固定の `skill_out` がないことだけでは、今回の変更が完全互換であるとは判定しない。共有信頼境界、Questionnaireの物理レイアウト、CLI許可リスト、既存Run探索は観測可能な契約である。

実装前に、本計画を親文書として新しいOpenSpec Changeを作成し、fast-forwardで `proposal.md`、`design.md`、delta spec、`tasks.md` を揃える。少なくとも次の要件とシナリオを記載する。

- 新規Runはスキル別の `evidence_runs/<skill_slug>/run_<id>[_N]/` に隔離される。
- 出力ルート直下に成果物を書き込まない。
- `run_` 付き入力でも二重プレフィックスを生成しない。
- 同名Runが存在しても上書きせず、一意なRunディレクトリを予約する。
- 旧 `questionnaire/runs/<id>/` は読取り可能だが、新規書込みには使用しない。
- パストラバーサル、出力ルート外へのシンボリックリンク、信頼境界外のRunを拒否する。
- CLIと設定JSONの競合時の挙動を対象ごとに確定する。
- `run_meta.json` と実際の物理パス、パススキーマ版が一致する。

`openspec validate --strict` の合格は文書構造の証拠として扱い、実装・数理・ランタイムの正しさの証明とは区別する。

## 5. 変更対象

| コンポーネント | 対象 | 主な変更内容 |
| :--- | :--- | :--- |
| 計画・仕様 | `docs/Artifacts/implementation_plan_022_0922.md`、新規OpenSpec Change | 本計画、要件、シナリオ、設計、タスク、テストの追跡性を確立 |
| 共通規約 | `AGENTS.md`、`README.md` | 鉄則3、実行例、出力規約、旧形式の互換境界を更新 |
| Git除外 | `.gitignore` | `evidence_runs/` を追加し、旧出力の除外規則は保持 |
| 共有基盤 | `.agents/shared/run_scope.R` | Questionnaire特例、新旧探索、ID正規化、衝突回避、信頼境界、パススキーマ版を更新 |
| Pass 0 | `.agents/shared/inspect_data.R`、`.agents/shared/finalize_pass0_config.R`、`.agents/skills/vcd-pass0-consultation/` | 検査と確定設定の例・責務を更新。不要なCLI統一は行わない |
| 3次元VCD | `.agents/skills/vcd-bayesian-evidence-analysis/` | ランナー、設定例、ダッシュボード、利用文書、legacy referenceの整合 |
| 2次元VCD | `.agents/skills/vcd-categorical-analysis/` | ランナーの許可引数、テンプレート、利用文書、参照文書の整合 |
| Questionnaire | `.agents/skills/questionnaire-batch-analysis/` | 新規書込みレイアウト、既定Run ID、旧レイアウト読取り互換、文書の整合 |
| SAS | `.agents/skills/sas-proc-freq/`、`.agents/skills/sas-proc-means/` | config例、schema、SKILL、ランナーの実際の契約を確認し、必要箇所だけ更新 |
| Legacy skill | `.agents/skills/vcd-categorical-reporting/` | 正本ではないことを維持しつつ、現役説明に残る旧パスを監査 |
| 補助コード | `scratch/` | 実行例に残る旧パスを監査し、現役例のみ更新 |
| テスト | `tests/` | 共有基盤、各スキル、所有権契約、旧形式読取り互換の期待値を更新・追加 |

ファイル名を列挙しただけで変更対象を固定せず、実装開始時に `rg` で現役参照を再棚卸しする。履歴・アーカイブ・fixture内の証拠値は、意味を確認せず一括置換しない。

## 6. 実装フェーズ

### Phase 0: 契約確定

1. 新規OpenSpec Changeを作成し、必要な全Artifactをfast-forwardで作成する。
2. スキルごとの現行CLI、設定JSON、既定出力、Run ID、探索処理を契約表として確定する。
3. Questionnaireの新規書込みと旧形式読取りの境界、パススキーマ版を確定する。
4. 計画とOpenSpecをレビューし、実装承認を得る。

### Phase 1: 共有基盤

1. 先に失敗する回帰テストを追加する。
2. `run_scope.R` のID正規化、原子的予約、信頼境界、新旧探索を実装する。
3. Questionnaireの新規書込みを `run_<id>[_N]/` へ変更し、旧形式は読取り専用で維持する。

### Phase 2: スキル別設定と文書

1. 各スキルの推奨出力ルート、config例、利用例を更新する。
2. CLIエイリアスはOpenSpecで承認された対象だけに追加する。
3. SASはconfig-only契約を維持し、実行時に効かないschema既定値を追加しない。
4. Pass 0は検査・確定設定・解析Runの責務を分離したまま例を更新する。

### Phase 3: 全体検証

1. 焦点テスト、正規回帰スイート、Python所有権テストを実行する。
2. 各対象スキルで最小実演を行い、生成先と `run_meta.json` を確認する。
3. Zero-External-Asset、絶対パス漏洩、Git除外、差分品質を検査する。
4. 検証結果をOpenSpec tasksと照合し、アーカイブ可否は別途Owner判断を受ける。

## 7. 必須テスト

- 各スキルの推奨既定ルートが `evidence_runs/<skill_slug>` であること。
- 明示した別出力ルートが安全性検証後に尊重されること。
- 新規Runが出力ルート直下へ成果物を書き込まないこと。
- `abc` と `run_abc` の双方から `run_abc` を生成し、`run_run_abc` を生成しないこと。
- 同一IDの連続実行で既存成果物を上書きせず、衝突サフィックスを付与すること。
- Questionnaireの新規出力が `run_<id>/` になり、旧 `runs/<id>/` を読取り可能であること。
- `../`、絶対パス注入、出力ルート外を指すシンボリックリンクを拒否すること。
- CLIと設定JSONの競合が仕様どおりに処理されること。
- `run_meta.json` の論理ID、解決済みID、出力ルート、Runディレクトリ、パススキーマ版が実体と一致すること。
- SASの設定JSONから `<output_dir>/run_<first16_run_id>[_N]/` が生成されること。
- 旧出力ディレクトリが移動・削除・上書きされないこと。

## 8. 検証手順

1. OpenSpec構造検証を実行する。

   ```bash
   openspec validate --strict
   ```

2. 焦点テストを実行後、正規回帰スイートを実行する。テスト本数は計画書へ固定せず、実装時のインベントリと実行結果を記録する。

   ```bash
   Rscript tests/run_regression_suite.R
   python3 tests/test_skill_ownership_contract.py
   ```

3. 現役コード・現役文書の旧パスを棚卸しする。`.gitignore`、legacy reference、履歴、アーカイブ、意味を持つfixtureは理由を記録して除外するため、単純なゼロ件判定にはしない。

   ```bash
   rg -n -i 'skill_out|skill_output|runs/' AGENTS.md README.md .agents tests scratch .gitignore
   ```

4. 各スキルの最小実演で、実ファイル、manifest、`run_meta.json`、HTMLを検査する。生成HTMLに外部URLまたは環境依存の絶対パスが混入していないことを確認する。
5. Git除外と差分品質を確認する。

   ```bash
   git check-ignore evidence_runs/
   git diff --check
   git status --short
   ```

## 9. 非対象と承認ゲート

- 本計画のレビュー・更新だけでは、コード、OpenSpec Change、テスト、データ、既存成果物を変更しない。
- 既存の `.playwright-mcp`、`figure` ディレクトリ、`skill_out/`、`skill_output/` の削除は本計画に含めない。
- 既存成果物の一括移行、改名、削除は別計画・別承認とする。
- 依存関係の追加、commit、push、OpenSpec archiveは別承認とする。
- Phase 0のOpenSpec一式をレビューし、明示的な実装承認を得るまでPhase 1以降へ進まない。

## 10. 完了条件

次のすべてを満たした場合にのみ実装完了候補とする。

1. 計画、OpenSpec要件・シナリオ、設計、タスク、コード、テストが追跡可能である。
2. 新規Runの保存先が目標構造へ統一され、出力ルート直下書込みがない。
3. Questionnaire旧形式の読取り互換が維持され、旧成果物へ破壊的変更がない。
4. 共有信頼境界、パス安全性、衝突回避、`run_meta.json` 整合性の焦点テストが合格する。
5. 正規回帰スイート、所有権テスト、最小実演、Zero-External-Asset検査が合格する。
6. 未検証項目、既知の互換性制約、残存するlegacy参照が明記される。
7. Ownerが検証証拠を確認し、OpenSpec archiveを別途承認する。
