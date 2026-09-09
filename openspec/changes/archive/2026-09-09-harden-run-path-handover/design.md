# Technical Design: 実行成果物ライフサイクルと実行パス引き継ぎの堅牢化 (harden-run-path-handover)

## Context

分析パイプライン（Pass 0 〜 Pass 3）は、統計計算の完全性と再現性を保証するための 4 段階アーキテクチャ（Pass 0: 相談・設定確定、Pass 1: R 統計計算、Pass 2: AI 考察・スタブ作成、Pass 3: ダッシュボード統合描画）を採用している（詳細は [proposal.md](proposal.md) 参照）。

現行コードベースおよび実務運用の徹底的な調査により、以下の設計課題が判明している：

1. **暗黙的探索による結果取り違え（`.agents/shared/run_scope.R`）**:
   - `run_output_dir_from_root()` は親ディレクトリに対して無条件に `run_<first16>` を結合する。
   - `resolve_pass3_run_dir()` は、直下に成果物がない場合に親配下の `run_*` サブディレクトリを mtime や名前順でソートして `pick_order[1L]` を暗黙選択している。複数 run が存在する環境では別 run の結果を拾って描画・統合するリスクが極めて高い。また、親直下とサブディレクトリの合算候補数判定が未定義である。
2. **統計成果物構成の不統一と個別ファイル決め打ち**:
   - スキルによって統計成果物のファイル名や構成が異なっており（Bayesian: `evidence_results.json`、Categorical: `categorical_results.json`、Questionnaire: `summary.csv` および各設問の `questionnaire_results.json`）、Pass 2/3 が個別ファイル名を直接推測・決め打ちで参照しているため、特に複数成果物を持つバッチ分析で網羅的な完全性検証ができない。
3. **Categorical における run 作成主体の逆転と多重予約矛盾**:
   - `vcd-categorical-analysis/templates/analysis.R` の実処理を精査すると、Pass 0 補助の `--profile` が正式な run を予約して `run_meta.json` を作成し、Pass 1 の `--render` がそれを `claim_resumable_profile_run()` により再利用（claim）している。
   - これは「Pass 1 が実実行ディレクトリを決定・予約する唯一の主体である」というパイプライン共通原則と矛盾し、プロファイルのみで中断された未完 run の放置や二重予約の温床となる。`--profile` は consultation workspace へのプロファイル出力に限定し、Pass 1 の `--render --config` が必ず新しい正式 run を原子的に予約する設計へ是正しなければならない。
4. **マニフェストハッシュ算出の曖昧さと論理正規化依存**:
   - 「キー順ソート等で正規化」という抽象的な定義では、シリアライザの改行・空白・型出力差異によって検証が不安定になる。マニフェスト内の成果物配列（`artifacts`）を決定的に整列し、固定された出力条件で一度だけ書き出した実ファイルバイト列に対する SHA-256 として定義しなければ、再現性のある厳格な検証が成立しない。
5. **finalizer 並行実行時の TOCTOU 競合と封印後不変性の破壊**:
   - 同一 run に対して 2 つの finalizer が同時に実行された場合、存在確認から rename までの競合によって成果物や `run_meta.json` が後勝ち置換される危険がある。
   - 排他ロックが必要であるが、run 内にロックディレクトリを置くと `run_state = sealed` への更新後にロックを削除することになり、「封印後は一切の追加・変更・削除を拒絶する」という sealed 契約と直接矛盾する。ロックは run 外（`out_root` 管理下）に配置する必要がある。
6. **run 外ロック作成時の信頼境界欠如**:
   - `run_meta.json` に記載された `out_root` を検証せずに信用して外部ロックを作成すると、改ざんされたメタデータによって想定外の外部ディレクトリへ `.run_locks/` が作成される危険がある。ロック取得前に CLI の `--run-dir` との完全一致、スキル別レイアウト整合性、および symlink 検証を厳格に行わなければならない。
7. **legacy run における必須 manifest 検証との矛盾**:
   - `--allow-legacy-run-meta` により v1.0 run の後続処理を無制限に許容すると、必須である `results_manifest.json` や由来ハッシュが存在せず本番確定が実行不能となる。legacy run に対する許容範囲を読み取り・診断・preview 生成に限定し、本番確定や sealed 遷移、supersede 元指定を拒絶する必要がある。
8. **Pass 2/3 成果物の直接書き込みと確定前露出・クラッシュ回復の欠如**:
   - AI 考察やダッシュボードを、確定前に最終ファイル名（`executive_summary.md`, `dashboard.html`）で run 直下へ直接書き込むと、生成途中や検証失敗時の不完全なファイルが残存する。成果物は staging 領域へ出力した上で検証を経て promotion し、その後 `run_meta.json` を原子的更新する確定契約が必要である。また、promotion 完了後・メタデータ更新前のクラッシュから安全に回復する冪等性契約が不可欠である。
9. **スタブ成果物・プレビューと本番成果物の混同および再実行矛盾**:
   - `pass2_stub.R` が本番と同名の `executive_summary.md` を書き込むと、後続の Pass 3 が本番考察完了と誤認して確定ダッシュボードを出力してしまう。スタブは `executive_summary_preview.md`、本番考察は `executive_summary.md` と完全に分離し、preview の存在が本番追加を妨げないようにする必要がある。また、固定名 preview の再実行は追記限定契約と衝突するため、同一 run での生成は一回限りとし、更新は新しい supersede run で行わなければならない。
10. **Questionnaire 部分失敗時の状態管理の欠如**:
    - `batch_runner.R` は設問エラーを `summary.csv` に記録しつつ終了コード 0 で終了する。これを無条件に `pass1 = completed` とみなすと、欠損した設問成果物を抱えたまま本番ダッシュボードが生成・封印されてしまう。全成功のみを `completed` とし、失敗混在時は `partial`、全失敗時は `failed` として本番後続処理を確実に遮断する必要がある。
11. **finalizer 引数の allowlist 制限の欠如**:
    - `finalize_run_stage.R` が任意の `target-name` や `source-artifact` を外部引数として受け入れると、想定外のファイル確定配置や run 外 symlink の混入を招く。stage と skill に応じた allowlist 検証が不可欠である。
12. **Pass 3 レンダラーラッパーの不統一とアセット外部化リスク**:
    - Bayesian には `render_dashboard.R` があるが、Categorical や Questionnaire には独立した CLI ラッパーがなく、呼び出しが分断されている。また、`self_contained: true` が明示されていない場合、外部アセットディレクトリが生成されて単一ファイルの原子的 promotion が破綻する。
13. **ライフサイクル定義の矛盾と上書き破損リスク**:
    - 「run 作成後は完全不変」と定義すると、Pass 2 による考察の追加や Pass 3 によるダッシュボードの出力、`run_meta.json` の状態更新が自己矛盾を起こす。一方で自由な更新を許すと、新旧成果物の混在や破損を招く。
    - Pass 1 完了後は入力・設定・統計結果を不変とし、Pass 1 から Pass 3 までは確定成果物の追記限定（Append-only）ライフサイクルに従い、本番 Pass 3 確定時に封印（`run_state = "sealed"`）して run 全体を不変化するモデルが正解である。確定済み成果物の改定や再計算は、元 run を監査証跡として残し、新しい supersede run で行わなければならない。
14. **ハンドオーバーの実行カレントディレクトリ依存と AI の実行負荷**:
    - `run_handover.json` 内のコマンドがリポジトリ相対パスのみで定義されていると、リポジトリルート以外から実行された場合に失敗する。また、AI が R 内部関数を組み立ててメタデータを更新する運用は脆弱であるため、staging 確定に対応した共通 CLI ラッパーが必要である。
15. **入力データ複製の禁止と推測排除**:
    - コードが入力データの機微性を推測することは不可能かつ不適切であり、外部データ本体を不用意に run ディレクトリへ複製すると情報漏洩やアクセス制御迂回、ストレージ浪費を招く。設定ファイル（`analysis_config.json` 等）のみをスナップショット保存し、データ本体は一律でコピーしない（hash_only）原則を確立する必要がある。
16. **パストラバーサル判定の脆弱性**:
    - 単純な `startsWith(target, run_root)` では、`/output/run_abc` に対して `/output/run_abc_external/` を誤許可するプレフィックス衝突の脆弱性がある。
17. **Questionnaire の親直下出力による無言上書き**:
    - `--run-id` 省略時に `--out` 直下へ出力する既存挙動があり、前回の `summary.csv` や成果物を無言上書きする破壊的リスクがある。

## Goals / Non-Goals

### Goals
- **唯一の決定主体**: Pass 1 を実実行ディレクトリ（`run_output_dir`）の唯一の決定主体とし、Pass 0 の親ディレクトリと `run_id` から確定的かつ衝突安全にディレクトリを確保する。
- **Categorical における Pass 1 唯一 run 作成原則と claim 廃止**:
  - `analysis.R --profile` は Pass 0 consultation workspace へのプロファイル出力に限定し、正式な run や `run_meta.json` を作成しない。
  - `analysis.R --render --config` が必ず新しい正式 run を原子的に予約する。
  - `claim_resumable_profile_run()` および `.render_claim` を完全に廃止する。
- **親専用の `output_dir` と FAIL-FAST**: Pass 1 の `--output-dir` は親ディレクトリ専用とし、実 run パスが渡された疑いがある場合は自動補正を行わず、診断メッセージと修正例を示して即時停止する。
- **秒単位 JST タイムスタンプ衝突の原子的解決**: run ID 省略時は秒単位 JST タイムスタンプを発行し、`dir.create(..., recursive = FALSE)` の成否に基づく原子的予約を用いて `_2`, `_3` サフィックスを付与し、同一秒のプロセス同士を確実に隔離する。
- **3 スキル共通 `results_manifest.json` と決定的実ファイルバイト列ハッシュ**:
  - `artifacts` 配列を `path`, `role`, `question_id` の決定的な順序で一意ソート。
  - スキーマ制約（POSIX 相対一意パス、小文字 64 桁 hash、role allowlist、question_id 一意性）を検証。
  - 固定した JSON 出力条件（キー順、インデント、改行）で一度だけ書き出し、実ファイルバイト列に対する SHA-256 として検証。論理正規化を行わない。
- **信頼境界検証に基づく run 外専用制御領域での stage 単位排他ロック制御**:
  - ロック作成前に `run_meta.run_output_dir` と CLI `--run-dir` の実パス一致、スキル別レイアウト整合性（Bayesian/Categorical: `dirname(run_dir) == out_root`、Questionnaire: `dirname(dirname(run_dir)) == out_root` かつ中間階層が `runs`）、symlink 検証を実施。
  - `<out_root>/.run_locks/<run_lock_id>/` 配下に `pass2.lock/`, `pass3.lock/` を配置。run 内にはロックファイルを作成しない。
  - `run_lock_id` は正規化済み絶対 run path の SHA-256 全 64 桁に完全固定。
  - `dir.create` の成功のみをロック取得とし、TOCTOU 競合を防止。競合プロセスは即座にエラー停止。
  - `lock_info.json` の記録と、明示的 `--recover-stale-lock` 引数による安全な回復判定（監査ログは `.run_locks/<run_lock_id>/audit.jsonl` に保存）。
  - Pass 3 ロック保持中に `run_meta.json` を `sealed` へ更新し、事後検証完了後に run 外のロックを解放することで封印後の不変性を完全保護。
- **legacy run（v1.0）の読み取り・preview 限定と本番確定拒絶**:
  - `--allow-legacy-run-meta` は v1.0 run の読み取り、探索、診断、preview 生成だけに限定。
  - 本番 Pass 2/3 確定、promotion、run_meta 更新、sealed 遷移を拒絶。本番成果物が必要な場合は v2.0 Pass 1 からの新規 run 再実行を要求。
  - legacy run を通常の `--supersedes-run` 元として指定することを拒絶。
- **run 内 staging 領域・検証・promotion およびクラッシュ回復契約**:
  - `staging/` を正式成果物集合外の一時領域と定義し、確定成果物のみを追記限定対象とする。
  - finalizer が manifest、入力成果物、生成成果物を検証し、成功後に同一ファイルシステム rename で promotion。
  - その後 `run_meta.json` を一時ファイル＋rename で原子的更新。
  - promotion 後・メタデータ更新前のクラッシュ回復: 最終ファイルが存在し期待ハッシュと一致する場合に限り finalizer の冪等な再実行を許容。不一致時は上書き拒絶。
  - sealed 遷移前に staging が空または不存在であることを検証（残存時は封印拒絶）。sealed 後の staging 作成を拒絶。
- **スタブ成果物（`executive_summary_preview.md`）と本番考察（`executive_summary.md`）の完全分離および一回限り方針**:
  - `pass2_stub.R` は preview ファイルを出力。preview の存在で本番追加は妨げられない。
  - preview（`executive_summary_preview.md`, `dashboard_preview.html`）は同一 run で一度だけ生成（既存同名 preview がある場合は上書き拒絶、更新は supersede run）。
  - 状態遷移として `pending -> stub_generated -> completed` および `pending -> completed` を許可。`completed` 後の上書きは拒絶。
- **プレビューダッシュボード（`dashboard_preview.html`）と本番（`dashboard.html`）の分離と封印制御**:
  - プレビュー出力は `dashboard_preview.html`（AI 考察未確定バナー必須）とし、`finalize_pass3` は実行せず `sealed` にしない。
  - 本番 Pass 2 確定後に `dashboard.html` を一度だけ生成・確定して `run_state = "sealed"` に封印する。
- **3 スキル共通 self_contained: true ダッシュボード単一ファイル契約**:
  - Bayesian, Categorical, Questionnaire の全 3 スキルの `dashboard.Rmd` において `self_contained: true` を明示し、公開 HTML のローカル一時アセット依存を禁止。
- **Questionnaire の 3 区分状態遷移と部分失敗時の後続処理遮断**:
  - 全設問成功のみ `pass1 = "completed"`。
  - 成功と失敗が混在する場合は `pass1 = "partial"`。全設問失敗時は `pass1 = "failed"`。
  - `partial` および `failed` は、いずれも本番 Pass 2/3 確定および `sealed` 封印を完全に遮断。
  - 部分失敗 run でも診断成果物（`summary.csv`、成功設問 JSON、`results_manifest.json`、失敗設問情報メタデータ）を保持。
  - `results_manifest.json` には実在する成功成果物のみを登録し、`summary.csv` 成功設問と完全一致を検証。
  - `partial` run は整合性検証後に `--supersedes-run` 元として許可。`failed` run は supersede 元への指定を拒絶。
- **finalizer 引数の allowlist 制限（`finalize_run_stage.R`）**:
  - `--target-name`: basename 限定、`run_meta.json` の skill と stage から期待値を導出して一致を検証。
  - `--source-artifact`: 正規化後に当該 run の専用 staging 領域配下にある通常ファイル限定。symlink、run 外、prefix 衝突、同一指定を拒絶。
- **追記限定ライフサイクル、Pass 3 封印（sealed）、および supersede 系統管理**:
  - Pass 1 完了後は入力・設定・統計結果を不変とする。
  - Pass 1 〜 Pass 3 は確定成果物の追記限定（Append-only）ライフサイクルとし、`run_meta.json` はガードされた状態遷移のための可変制御ファイルとする。
  - 本番 Pass 3 確定時に `run_state = "sealed"` として run 全体を不変化（封印）し、以降の追加・上書きを完全拒絶する。
  - 確定済み成果物の改定や再計算は、常に新しい run を原子的に予約して実行し、`supersedes_run` 系統を記録する。元 run は不変の監査証跡として保存する。
- **supersede 元 run の厳格な検証契約（`--supersedes-run <path>`）**:
  - 元 run の存在、`run_meta.json`、スキル一致、成果物マニフェスト、全成果物の実ハッシュ再検証。
  - `superseded_results_manifest_sha256` は元 run の実ファイルバイト列から自ら再計算（外部指定値は信用しない）。
  - 自己参照・循環参照の拒絶。
  - `supersede_reason`、入力・設定変更有無（`inputs_changed`, `config_changed`）の記録。
- **cwd 付き kind タグ付き機械可読ハンドオーバー（`run_handover.json`）**:
  - 実 run 直下に JSON を出力し、`cwd`（正規化リポジトリルート）とリポジトリ相対 `argv` を記録。
  - `pass2_ai` には `input_manifest`, `expected_results_manifest_sha256`, `staging_output`, `output`, および staging 対応 `finalize` アクションを明記。
- **推測なしデータ保護（hash_only）と設定スナップショット保存**: 外部データファイルは出自にかかわらず一律でコピー禁止（`hash_only`）とし、設定ファイル（`analysis_config.json`, `question_config.csv`）のみを実 run 直下にスナップショット保存する。
- **`inputs` 配列の単一正本化**: `run_meta.json` の保存正本を `inputs` 配列のみとし、旧フィールドは読み取りアダプターから透過的に導出する。
- **3 スキル共通の薄い Pass 3 レンダラー提供**: Bayesian, Categorical, Questionnaire のすべてに `render_dashboard.R --run-dir <path>` を配置し、Rmd への直接伝達（二重探索排除）を統一する。
- **プレフィックス衝突を防ぐ厳格なパストラバーサル防止**: `target == run_root || startsWith(target, paste0(run_root, "/"))` による完全検証を行う。
- **Questionnaire 親直下出力の完全廃止**: run ID 省略時も JST タイムスタンプを発行し、必ず `runs/<id>/` 配下へ隔離出力する。
- **リポジトリ共通 4-Pass 正式対応**: Categorical の実態（`--render` = Pass 1 統計計算）に即した正しいマッピングを確立する。

### Non-Goals
- データ本体を run ディレクトリ内へコピーするオプトイン機能（外部データは一律 `hash_only` とする）。
- `sealed` 状態となった run に対する破壊的上書きや成果物の事後改変（改定は常に `--supersedes-run` を用いる）。
- 全スキルのディレクトリ構造を `run_<id>` に画一的強制統一すること（Questionnaire の `runs/<id>` を無理に変更しない）。
- 統計モデル計算アルゴリズム自体の変更。
- 承認前の先行コード実装や git コミット・プッシュ。

## Decisions

### Decision 1: Pass 1 の `output_dir` は「親ディレクトリ専用」と定義し、実 run 誤指定は自動補正せず FAIL-FAST 停止する
Pass 1 が受け取る `--output-dir`（または `analysis_config.json` の `output_dir`）は、新規 run を作成する親ディレクトリ（`out_root`）専用とする。渡されたパスの末尾が既存の run ディレクトリ形式（例: `run_*` または `runs/*`）に合致し、かつそのディレクトリ内に `run_meta.json` や成果物ファイルが存在するなど実 run である疑いがある場合、暗黙の自動読み替えや二重ネスト（`run_01/run_<id>`）の作成を行わず、エラー停止する。

### Decision 2: 秒単位 JST タイムスタンプ衝突の原子的解決
run ID 省略時は秒単位 JST タイムスタンプ（`YYYYMMDD_HHMMSS`）を発行する。
同一 ID が既に存在する場合、または同一秒に複数プロセスが同時に起動した場合、`dir.create(candidate, recursive = FALSE)` の成否に基づく原子的予約を用いて `_2`, `_3` の予約サフィックスを付与し、完全なプロセス間隔離を担保する。

### Decision 3: Categorical における Pass 1 唯一 run 作成原則と claim 廃止
Categorical 分析における run 作成の二重構造を解消し、パイプライン共通原則を徹底する：
1. **Pass 0 補助（`--profile`）**: consultation workspace（または指定出力先）に `data_profile.json` を出力するのみとする。正式な `run_meta.json` や production run ディレクトリは一切作成しない。
2. **Pass 1 統計計算（`--render --config`）**: 必ず新しい正式 run を原子的に予約して作成する。
3. **claim 機構の完全廃止**: 既存の `claim_resumable_profile_run()`、`.render_claim` 制御、および Pass 1 に対する既存 `--run-dir` 受入を完全に廃止・撤廃する。Pass 0 のプロファイル情報が必要な場合は、設定ファイルまたは明示引数から読み込み、Pass 1 が正式 run へ必要なスナップショットのみを追加する。

### Decision 4: 追記限定ライフサイクル（Append-only）、Pass 3 封印（`run_state = "sealed"`）、および supersede 系統管理
run ディレクトリのライフサイクルを以下のように厳格に定義する：
1. **Pass 1 完了後**: 入力スナップショット、設定ファイル、および統計結果ファイルは不変（Immutable）とする。
2. **Pass 1 〜 Pass 3**: 確定成果物の追加のみを認める追記限定（Append-only）ライフサイクルとする。run 共通ファイルは直下に配置し、Questionnaire の設問別成果物は既存の設問別サブディレクトリを維持する。`run_meta.json` はガードされた状態遷移のための可変制御ファイルとして機能する。
3. **本番 Pass 3 確定時**: 本番ダッシュボード（`dashboard.html`）の生成成功と確定をもって `run_state = "sealed"` に更新し、run 全体を不変化（封印）する。`sealed` 状態の run に対するいかなる追加・上書き・変更も拒絶する。プレビューダッシュボード（`dashboard_preview.html`）では封印しない。
4. **成果物の改定・再計算**: 確定済み考察・ダッシュボードの修正や Pass 1 の再計算を行う場合は、**常に新しい run ディレクトリを原子的に予約**して実行する。
   - 元 run は当時の完全な成果物集合（不変監査証跡）として一切改ざんせず保持する。
   - 新 run の `run_meta.json` には、`supersedes_run: "/path/to/old/run"`、元 run 実ファイルバイト列から再計算した `superseded_results_manifest_sha256`、`supersede_reason`、および `inputs_changed` / `config_changed` を記録する。
   - 新 run は各 pass が pending の状態で開始し、Pass 1 の再計算成功後だけ completed とする。
   - run 共通ファイルは直下、Questionnaire の設問結果は設問別サブディレクトリに配置し、manifest に run 相対パスを記録する。

### Decision 5: 3 スキル共通 `results_manifest.json` とスキーマ制約・決定的実ファイルバイト列ハッシュ
Pass 1 完了時、実 run 直下に 3 スキル共通の `results_manifest.json` を出力する。
各スキルは成果物を登録する：
- Bayesian: `evidence_results.json`（`role: "primary_results"`）
- Categorical: `categorical_results.json`（`role: "primary_results"`）
- Questionnaire: `summary.csv`（`role: "summary_table"`）および成功設問の `questionnaire_results.json`（`role: "question_result"`）

**スキーマ制約とハッシュ算出の決定性ルール**:
1. `path`: run 基準の正規化された相対 POSIX パス。絶対パス、空文字、`.`、`..`、run 外 escape、symlink を拒絶する。正規化後の `path` は manifest 内で一意。
2. `sha256`: 小文字 64 桁 16 進数。
3. `role`: skill ごとの allowlist（`primary_results`, `summary_table`, `question_result` 等）。
4. Questionnaire の `question_result`: `question_id` を必須かつ一意とする。同一 `question_id` が複数 path を指すことを拒絶する。
5. `artifacts` 配列内の各要素は、`question_id` のない要素を空文字として扱い、`path`、`role`、`question_id` のキー順で決定的に一意ソートする。
6. 固定した JSON 出力条件（キー順、インデント、改行コード）で `results_manifest.json` を一度だけディスクに書き出す。
7. `results_manifest_sha256` は、保存された `results_manifest.json` の**実ファイルバイト列に対する SHA-256** とする。
8. 後続処理（Pass 2 / Pass 3 確定処理）は、`results_manifest.json` ファイル自体の実ファイルバイト列ハッシュと、manifest 登録済み全成果物の実ファイルハッシュの両方を検証する。論理正規化は行わない。

```json
{
  "interface_version": "1.0",
  "skill": "vcd-bayesian-evidence-analysis",
  "artifacts": [
    {
      "path": "evidence_results.json",
      "role": "primary_results",
      "sha256": "4a7f...64hex"
    }
  ]
}
```

### Decision 6: 信頼境界検証に基づく run 外専用制御領域での stage 単位排他ロック制御
同一 run に対する finalizer の並行実行（TOCTOU 競合）を排除するため、確定開始時に stage ごとの排他ロックを取得する：
1. **ロック作成前の信頼境界検証**:
   - `run_meta.json` に記載された `out_root` および `run_output_dir` を無条件に信用して外部ロックを作成してはならない。
   - ロック作成前に、`run_meta.run_output_dir` の正規化実パスが CLI の `--run-dir` と完全一致することを検証する。
   - スキル別のディレクトリレイアウト整合性を検証する：
     - Bayesian / Categorical: `dirname(run_dir) == out_root`
     - Questionnaire: `dirname(dirname(run_dir)) == out_root` かつ `basename(dirname(run_dir)) == "runs"`
   - `out_root`、`.run_locks`、`run_dir` の各祖先に想定外の symlink がないことを検証する。
   - いずれかの検証に失敗した場合、ロックディレクトリを作成することなく即座にエラー停止する。
2. **ロック配置（run 外）**:
   - stage 単位ロックは、対象 run の外にある `out_root` 直下の専用制御領域 `.run_locks/<run_lock_id>/` 配下に配置する（例: `<out_root>/.run_locks/<run_lock_id>/pass2.lock/`, `pass3.lock/`）。
   - **run ディレクトリ内にはロックファイルやロックディレクトリを一切作成しない**。
3. **`run_lock_id` の完全固定**:
   - run の正規化済み絶対パスに対する SHA-256 全 64 桁に完全固定する（短縮プレフィックスは使用しない）。
4. **原子的取得と競合停止**:
   - `dir.create(lock_path, recursive = FALSE)` の成否に基づく原子的取得を行う。
   - ロック取得に失敗したプロセスは、同 stage の確定処理が並行進行中として即座にエラー停止する。
5. **ロック情報（`lock_info.json`）の記録**:
   - ロックディレクトリ直下に `lock_info.json`（PID、hostname、token、開始時刻、run_dir、stage）を書き出す。
6. **封印との整合性**:
   - Pass 3 ロック保持中に `run_meta.json` を `sealed` へ更新し、事後検証完了後に run 外のロックを解放する。これにより `sealed` 後の run ディレクトリに変更を発生させない。
7. **stale lock 回復規則**:
   - 通常の finalizer は既存ロックを自動削除しない。
   - 明示的な `--recover-stale-lock` 引数が指定された場合のみ回復判定を行う：
     - hostname が現在のホストと異なる場合は回復しない。
     - PID が生存中の場合は回復しない。
     - PID 不在に加え、最低経過時間（300秒）を超過している場合のみ stale 候補とする。
     - 監査ログは `<out_root>/.run_locks/<run_lock_id>/audit.jsonl` に追記保存する。
     - ロック回復後、確定処理を開始する前に run_meta、最終成果物、staging、期待ハッシュをすべて再検証する。

### Decision 7: legacy run（v1.0）の読み取り・preview 限定と本番確定拒絶
1. `--allow-legacy-run-meta` は、過去に作成された v1.0 形式 run の読み取り、探索、診断、および preview 生成（`executive_summary_preview.md`, `dashboard_preview.html`）のみに限定して許容する。
2. v1.0 run には必須の `results_manifest.json` や由来ハッシュが存在しないため、本番 Pass 2 確定（`finalize_pass2`）、本番 Pass 3 確定（`finalize_pass3`）、promotion、`run_meta.json` の確定更新、および `run_state = sealed` への封印は一切拒絶する。
3. 本番成果物が必要な場合は、元入力データと設定ファイルから v2.0 の Pass 1 を新しい run として再実行することを要求する。
4. legacy run は厳格な成果物マニフェストを持たないため、通常の `--supersedes-run` の元としても指定を拒絶する。

### Decision 8: run 内 staging 領域・検証・promotion およびクラッシュ回復契約
1. **staging 領域の位置づけ**:
   - `staging/` は未確定の一時作業領域であり、正式な run 成果物集合には含めない（`run_meta.json` の `artifacts` に登録しない）。
   - 追記限定・監査対象となるのは、確定成果物、Pass 1 成果物、`run_meta.json` に登録された成果物のみとする。
2. **直接書き込みの禁止**:
   - AI 考察やダッシュボードを、確定前に最終ファイル名（`executive_summary.md`, `dashboard.html` 等）で run 直下へ直接書き込んではならない。
3. **検証と promotion**:
   - finalizer がマニフェスト実バイト列ハッシュ、全成果物ハッシュ、staging 成果物の妥当性を検証。
   - 検証成功後、同一ファイルシステム上の rename で最終ファイル名へ promotion する。
4. **メタデータの原子的更新**:
   - promotion 完了後、`run_meta.json` を同一ファイルシステム一時ファイル経由の原子的 rename で更新する。
5. **promotion 後・メタデータ更新前クラッシュからの回復**:
   - 最終ファイルが既に存在し、`run_meta.json` に未登録（または `pending`）である場合、その既存ファイルの実ハッシュが staging 元成果物のハッシュ（期待ハッシュ）と完全一致するときに限り、finalizer の冪等な再実行を許可する。
   - 既存最終ファイルの実ハッシュが期待ハッシュと一致しない場合は、上書きを行わずエラー停止する。
6. **sealed 前の staging 検証**:
   - 本番 Pass 3 確定による `run_state = sealed` 遷移前に、当該 run の staging 領域が空または不存在であることを検証する。未処理ファイルが残存している場合は封印を拒絶する。sealed 後は staging の新規作成も拒絶する。

### Decision 9: スタブ成果物と本番 AI 考察の完全分離および一回限り方針
1. `pass2_stub.R` の出力を `executive_summary_preview.md` とする。
2. 本番 AI 考察の出力を `executive_summary.md` とする。
3. preview ファイル（`executive_summary_preview.md`）が存在していても、本番ファイル（`executive_summary.md`）の追加・確定は妨げられない。
4. preview（`executive_summary_preview.md`, `dashboard_preview.html`）も同一 run では一度だけ生成を許可し、同名 preview が既に存在する場合は上書きを拒絶する（更新は新しい supersede run で行う）。
5. Pass 2 の状態遷移として以下を許可する：
   - `pending` -> `stub_generated` -> `completed`
   - `pending` -> `completed`
6. `completed` 状態に遷移した後の考察上書き・再確定はエラーとして拒絶する。

### Decision 10: プレビューダッシュボードと本番ダッシュボードの完全分離および封印契機
1. プレビューダッシュボードの出力は `dashboard_preview.html` とする。
2. 本番ダッシュボードの出力は `dashboard.html` とする。
3. プレビュー経路では `finalize_pass3` を実行しない。
4. プレビュー経路では `pass3 = completed` または `run_state = sealed` への更新を行わない。
5. `dashboard_preview.html` には、AI 考察が未確定（またはスタブ）である旨の明示的な警告バナー表示を必須とする。
6. 本番 Pass 2 確定（`pass2 = completed`）後、`render_dashboard.R` が `dashboard.html` を一度だけ生成し、`finalize_pass3` を通じて確定して `run_state = "sealed"` へ進める。

### Decision 11: 3 スキル共通 self_contained: true ダッシュボード単一ファイル契約
Bayesian, Categorical, Questionnaire の全 3 スキルにおいて、`dashboard.Rmd` のレンダリング設定で `self_contained: true` を明示する。
- 公開 HTML の外部ローカルアセット（`dashboard_files/` 等）への依存を禁止し、ダッシュボード成果物を `dashboard.html` 単一ファイルとして完結させる。
- これにより、同一ファイルシステム上の単一 rename による原子的 promotion を確実に保証する。

### Decision 12: Questionnaire の 3 区分状態遷移と部分失敗時の後続処理遮断
Questionnaire バッチ分析において、全設問の成否に応じた明確な 3 区分状態遷移を定義する：
1. **`pass1 = "completed"`**: 全設問が `status == "success"` で完了した場合のみ。本番 Pass 2 へ進行可能。
2. **`pass1 = "partial"`**: 1 件以上の設問が成功し、かつ 1 件以上の設問が失敗（`status == "error"`）した場合。
3. **`pass1 = "failed"`**: 成功した設問が 0 件の場合、または `summary.csv` / `results_manifest.json` を安全に生成できなかった場合。
4. **後続処理の厳格遮断**:
   - `partial` および `failed` は、いずれも本番 Pass 2 確定、本番 Pass 3 確定、`run_state = "sealed"` への遷移を許可しない（エラー停止）。
5. **部分失敗（partial）における診断成果物の保持と manifest 整合**:
   - 診断用として `summary.csv`、成功設問の `questionnaire_results.json`、`results_manifest.json`、および失敗設問情報（`run_meta.json` 内の `partial_failures` メタデータ）を出力・保持する。
   - `results_manifest.json` には**summary.csv と実在する成功設問の成果物**を登録する。
   - `summary.csv` に記載された成功設問集合と manifest の `question_result` 集合が完全一致することを検証する。
6. **supersede 系統管理**:
   - `partial` run: 診断成果物と manifest の整合性が検証できる場合に限り、修正版再実行の `--supersedes-run` 元として許可する。
   - `failed` run: 完全な成果物集合が存在しないため、`--supersedes-run` の元としては指定できない（エラー停止）。

### Decision 13: finalizer 引数の allowlist 制限と検証（`finalize_run_stage.R`）
AI エージェントが安全に確定処理を実行できるよう、CLI 引数の厳格な allowlist 検証を行う：
- **`--target-name` の検証**:
  - basename のみ受け付け、パス区切り、`.`、`..`、絶対パスを拒絶する。
  - `run_meta.json` の skill と stage から期待値を導出し、完全一致を検証する：
    - Pass 2 + Bayesian: `executive_summary.md`
    - Pass 2 + Categorical: `executive_summary.md`
    - Pass 2 + Questionnaire: `cross_question_summary.md`
    - Pass 3: `dashboard.html`
- **`--source-artifact` の検証**:
  - 正規化後に当該 run の専用 staging 領域（`<run_dir>/staging/`）配下にある通常ファイルのみを許可する。
  - symlink、ディレクトリ、FIFO、device、run 外パス、prefix 衝突、`../` escape を拒絶する。
  - source と target が同一パスの場合は拒絶する。
  - target が既に存在する場合、クラッシュ回復条件（期待ハッシュ一致）以外は上書き拒絶する。

- **CLI 実行例**:
  ```bash
  # Pass 2 確定
  Rscript .agents/shared/finalize_run_stage.R \
    --stage pass2 \
    --run-dir "/path/to/run_dir" \
    --source-artifact "/path/to/run_dir/staging/executive_summary.md" \
    --target-name "executive_summary.md" \
    --expected-results-manifest-sha256 "<64hex>"

  # Pass 3 確定
  Rscript .agents/shared/finalize_run_stage.R \
    --stage pass3 \
    --run-dir "/path/to/run_dir" \
    --source-artifact "/path/to/run_dir/staging/dashboard.html" \
    --target-name "dashboard.html" \
    --expected-results-manifest-sha256 "<64hex>" \
    --expected-narrative-sha256 "<64hex>"
  ```

### Decision 14: 入力データの推測なし hash_only 原則と設定スナップショット保存
コードがデータの機微性（RWD、公開、合成等）を推測・分類する余地を排除し、以下のポリシーを厳格に適用する：
1. **外部データファイル（`role: "data"`）**: 出自にかかわらず、**一律で既定 `snapshot_policy: "hash_only"`** とし、データ本体を run ディレクトリ内へコピーしない。元パスおよび 64 桁 SHA-256 のみを記録する（データ本体コピーのオプトイン機能は提供しない）。
2. **`analysis_config.json`**: 設定スナップショットとして実 run 直下に保存する。正式分析（`config_origin: "pass0_file"`）では元ファイルをコピーし、手動試行・自動テスト（`config_origin: "resolved_cli"`）では実効引数から生成して保存し、64 桁 SHA-256 を記録する。
3. **`question_config.csv`**: 設定スナップショットとして実 run 直下に保存し、64 桁 SHA-256 を記録する。
4. **組み込みデータ**: `source_kind: "builtin"` とし、データフレームハッシュを記録する（スナップショット不要）。

### Decision 15: メタデータにおける `inputs` 配列の単一正本化
`run_meta.json` の保存上の正本を `inputs` 配列のみとする。
旧トップレベルフィールド（`input_data` / `input_sha256`）は JSON ファイルへ直接永続化しない。旧コード向けには、共通読み取りアダプター関数（`get_run_input_data()`, `get_run_input_sha256()`）が `inputs[role == "data"]` から透過的に値を導出する。

### Decision 16: Pass 2 / 3 は実 run パスを `--run-dir` で直接受け取る
Pass 2（AI 考察・スタブ）および Pass 3（ダッシュボード生成）の CLI 引数は `--run-dir <path>` に統一する。
成果物は常に指定された実 run ディレクトリ直下のファイル（`results_manifest.json` 等）のみを読み込み、カレントディレクトリの既定ファイルを優先するバグを解消する。

### Decision 17: 3 スキル統一の薄い Pass 3 レンダラー（`render_dashboard.R`）の配置
Bayesian に加え、Categorical および Questionnaire にも薄い CLI ラッパー `templates/render_dashboard.R` を配置する。
- すべてのスキルで `Rscript templates/render_dashboard.R --run-dir <path>` という統一インターフェースを実現。
- レンダラー内部で実 run パスを検証し、下位の `dashboard.Rmd` へ `params = list(run_dir = run_dir, ...)` として直接引き渡すことで、二重探索を完全に解消する。

### Decision 18: 暗黙 mtime 探索の廃止と親直下を含む厳格な互換探索
通常実行経路における親配下の mtime 自動選択を完全廃止する。
明示的な `--discover-single-run` オプション指定時は、**親直下の成果物（旧形式）とサブディレクトリ（`run_*` 等）の双方を走査し、有効候補の総数を算出**する：
- `候補総数 == 1`: 警告メッセージを出力してその 1 件を採用（親直下が旧形式の場合は、さらに `--allow-legacy-run-meta` が必要）。
- `候補総数 == 0`: エラー停止（成果物なし）。
- `候補総数 >= 2`: エラー停止（複数候補が存在するため `--run-dir <path>` での明示を要求）。

### Decision 19: cwd 付き kind タグ付き機械可読ハンドオーバーファイル `run_handover.json`
Pass 1 完了時、実 run ディレクトリ直下に機械可読な `run_handover.json` を生成する。

```json
{
  "interface_version": "1.0",
  "run_output_dir": "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6",
  "cwd": ".",
  "run_meta": "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6/run_meta.json",
  "results_manifest": "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6/results_manifest.json",
  "results_manifest_sha256": "4a7f...64hex",
  "config": "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6/analysis_config.json",
  "next_actions": {
    "pass2_ai": {
      "kind": "agent_action",
      "action": "executive_summary_generation",
      "input_manifest": "results_manifest.json",
      "expected_results_manifest_sha256": "4a7f...64hex",
      "output": "executive_summary.md",
      "staging_output": "staging/executive_summary.md",
      "instructions": "Pass 2 AI expert narrative generation. Write to staging_output first, then execute the finalize command.",
      "finalize": {
        "kind": "command",
        "argv": [
          "Rscript",
          ".agents/shared/finalize_run_stage.R",
          "--stage",
          "pass2",
          "--run-dir",
          "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6",
          "--source-artifact",
          "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6/staging/executive_summary.md",
          "--target-name",
          "executive_summary.md",
          "--expected-results-manifest-sha256",
          "4a7f...64hex"
        ]
      }
    },
    "pass2_stub_preview": {
      "kind": "command",
      "argv": [
        "Rscript",
        ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R",
        "--run-dir",
        "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6"
      ],
      "output": "executive_summary_preview.md",
      "production_eligible": false
    },
    "pass3_preview": {
      "kind": "command",
      "argv": [
        "Rscript",
        ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
        "--run-dir",
        "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6",
        "--preview"
      ],
      "output": "dashboard_preview.html",
      "production_eligible": false
    },
    "pass3": {
      "kind": "command",
      "argv": [
        "Rscript",
        ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
        "--run-dir",
        "/absolute/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6"
      ],
      "output": "dashboard.html",
      "requires": ["pass2_ai"]
    }
  }
}
```

### Decision 20: `run_meta.json` v2.0 スキーマと状態管理
実実行ディレクトリ直下の `run_meta.json` を以下のように設計する。

```json
{
  "interface_version": "2.0",
  "skill": "vcd-bayesian-evidence-analysis",
  "run_id": "c85d85fe30da64f6...",
  "run_id_short": "c85d85fe30da64f6",
  "requested_run_id": "my_run_01",
  "run_state": "sealed",
  "supersedes_run": null,
  "superseded_results_manifest_sha256": null,
  "supersede_reason": null,
  "inputs_changed": null,
  "config_changed": null,
  "out_root": "/path/to/output/case_01/vcd_bayesian",
  "run_output_dir": "/path/to/output/case_01/vcd_bayesian/run_c85d85fe30da64f6",
  "results_manifest": "results_manifest.json",
  "results_manifest_sha256": "4a7f...64hex",
  "inputs": [
    {
      "role": "data",
      "source_kind": "file",
      "source_path": "/secure/rwd/data.csv",
      "snapshot": null,
      "snapshot_policy": "hash_only",
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    }
  ],
  "config_origin": "pass0_file",
  "config_source_path": "/path/to/original/analysis_config.json",
  "config_snapshot": "analysis_config.json",
  "config_sha256": "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb",
  "artifacts": {
    "results_manifest": {
      "path": "results_manifest.json",
      "sha256": "4a7f...64hex"
    },
    "narrative_preview": {
      "path": "executive_summary_preview.md",
      "sha256": "3e4f...64hex"
    },
    "narrative": {
      "path": "executive_summary.md",
      "sha256": "8b2a...64hex",
      "based_on_results_manifest_sha256": "4a7f...64hex"
    },
    "dashboard_preview": {
      "path": "dashboard_preview.html",
      "sha256": "7a8b...64hex"
    },
    "dashboard": {
      "path": "dashboard.html",
      "sha256": "1c3d...64hex",
      "based_on_results_manifest_sha256": "4a7f...64hex",
      "based_on_narrative_sha256": "8b2a...64hex"
    }
  },
  "partial_failures": null,
  "pass_status": {
    "pass0": "completed",
    "pass1": "completed",
    "pass2": "completed",
    "pass3": "completed"
  },
  "timestamps": {
    "created": "2026-09-08T10:00:00+09:00",
    "pass1_completed": "2026-09-08T10:00:05+09:00",
    "pass2_completed": "2026-09-08T10:05:00+09:00",
    "pass3_completed": "2026-09-08T10:05:30+09:00",
    "sealed": "2026-09-08T10:05:30+09:00"
  }
}
```

### Decision 21: supersede 元 run の厳格な検証契約（`--supersedes-run <path>`）
再計算や成果物改定時に元 run を指定する引数は `--supersedes-run <path>` とする。
パイプラインは元 run に対し以下を検証する：
1. ディレクトリの存在確認、`run_meta.json` の存在と正常性。
2. `skill` の完全一致（異なるスキルの run の supersede 拒絶）。
3. `results_manifest.json` の存在および実ファイルバイト列 SHA-256、全登録成果物の実ハッシュ再計算・一致検証。
4. `superseded_results_manifest_sha256` は元 run の実ファイルバイト列から自ら再計算して記録（外部入力を信用しない）。
5. 自己参照（指定パスが自身と同じ）および循環参照を拒絶。
6. `pass1 == "failed"` の run および v1.0 legacy run に対する supersede を拒絶（`partial` run は成果物・manifest 整合性検証合格時のみ許可）。
7. `supersede_reason`、および元 run との入力データ比較・設定比較による `inputs_changed`（TRUE/FALSE）、`config_changed`（TRUE/FALSE）を記録。

### Decision 22: プレフィックス衝突を防ぐ厳格なパストラバーサル防止
`assert_path_within_run_dir(target_path, run_root)` において：
- `target == run_root || startsWith(target, paste0(run_root, "/"))` による厳格チェックを行う。
- 実ファイルは `normalizePath(mustWork = TRUE)` によりシンボリックリンクを実パスへ解決して検証。未作成の出力ファイルは親ディレクトリを検証。

### Decision 23: Questionnaire 親直下出力の完全廃止（破壊的変更）
`--out` 親ディレクトリ直下への出力を完全に廃止する。
`--run-id` 省略時も JST タイムスタンプを発行し、必ず `runs/<id>/` 配下へ隔離出力する。
既存の自動化スクリプト向けには破壊的変更として移行手順を案内する。

### Decision 24: パス・リンクの表現基準と AI 完了報告の標準化
- リポジトリ内の成果物: リポジトリルート基準の相対リンク（Markdown 相対パス）
- リポジトリ外の成果物: 正規化された絶対パス
- `run_meta.json` 内の `artifacts`: 実 run ディレクトリ基準の相対パス
- AI 最終報告では 4 大要素（レポートリンク、実 run パス、設定・結果リンク、進行状態）を提示する。

### Decision 25: リポジトリ共通 4-Pass 正式対応表（Categorical の実態に即したマッピング）
実コードに合致した正式な対応関係を以下のように定義する。

| 共通 4-Pass | Bayesian (`vcd-bayesian`) | Categorical (`vcd-categorical`) | Questionnaire (`questionnaire-batch`) |
|---|---|---|---|
| **Pass 0** (Consultation) | `inspect_data.R` / `analysis_config.json` | `vcd-pass0-consultation` ＋ 必要に応じ `analysis.R --profile` (データ構造プロファイル生成、正式run作成なし) | `question-config.csv` 策定・設問定義 |
| **Pass 1** (Statistical Compute) | `pass1_compute.R` / `analysis.R` (`results_manifest.json`) | `analysis.R --render --config ...` (集計・モデル適合・`results_manifest.json`、正式run原子予約) | `batch_runner.R` (全設問計算・`results_manifest.json`、正式run原子隔離) |
| **Pass 2** (Expert Narrative) | `executive_summary.md` (AI 考察) / `finalize_run_stage.R` | `executive_summary.md` (AI 考察) / `finalize_run_stage.R` | 設問別解釈・`cross_question_summary.md` / `finalize_run_stage.R` |
| **Pass 3** (Dashboard / Report) | `templates/render_dashboard.R` / `finalize_pass3` (sealed) | `templates/render_dashboard.R` / `finalize_pass3` (sealed) | `templates/render_dashboard.R` / `finalize_pass3` (sealed) |

## Risks / Trade-offs

- **[Risk 1] Questionnaire 親直下出力の廃止に伴う既存自動化スクリプトの失敗**
  → **Mitigation**: 破壊的変更であることを明記し、`run_handover.json` から確定パスを取得する移行手順を案内する。
- **[Risk 2] sealed 後の成果物変更拒絶による運用厳格化**
  → **Mitigation**: 確定済み成果物の改定には `--supersedes-run` を提供し、過去の監査証跡を損なわずに安全に再分析・改定を行える系統追跡機能を提供する。
- **[Risk 3] staging promotion 後のクラッシュによる孤立成果物**
  → **Mitigation**: 既存最終ファイルの実ハッシュが期待ハッシュと一致する場合に限り、finalizer を冪等に再実行してメタデータを正常確定できるクラッシュ回復契約を導入する。
- **[Risk 4] finalizer 並行実行による TOCTOU 競合**
  → **Mitigation**: 信頼境界検証付き run 外専用制御領域（`<out_root>/.run_locks/<run_lock_id>/`）における stage 単位原子的排他ロック制御により、二重実行を確実に遮断する。

## Migration Plan

1. **フェーズ 1: 共有共通基盤（`.agents/shared/run_scope.R`, `finalize_run_stage.R`）の改定**
   - 親ディレクトリ検証（FAIL-FAST 診断）。
   - 秒単位 JST タイムスタンプ衝突の原子的解決（`dir.create`）。
   - 厳格パストラバーサルガード `assert_path_within_run_dir()`（プレフィックス衝突回避）。
   - 親直下合算カウントによる互換探索。
   - `inputs` 単一正本化および読み取りアダプター。
   - `results_manifest.json` のスキーマ検証（POSIX 相対一意パス、小文字 64 桁、role allowlist、question_id 一意性）および実ファイルバイト列 SHA-256 検証ロジック。
   - 信頼境界検証付き run 外排他ロック（`.run_locks/`、原子的取得、`lock_info.json`、`--recover-stale-lock` 回復、監査ログ）。
   - legacy run（v1.0）の読み取り・preview 限定（本番確定拒絶）。
   - staging 領域からの検証・promotion、クラッシュ回復、sealed 前 staging 空検証。
   - 一時ファイル＋原子的 rename による `run_meta.json` 更新。
   - `finalize_pass2` / `finalize_pass3` 共通確定処理および共通 CLI ラッパー `.agents/shared/finalize_run_stage.R`（allowlist 検証組み込み）の実装。
   - `--supersedes-run` 元 run 検証ロジック（存在、skill一致、実バイト列ハッシュ再計算、自己/循環参照拒絶、failed 元拒絶、変更有無記録）。
   - `cwd` 付き kind タグ付き `run_handover.json` 生成。
2. **フェーズ 2: 各スキルテンプレートの改定**
   - Bayesian: `results_manifest.json` 出力、`render_dashboard.R` の `--run-dir` 改定、設定スナップショット保存、`run_handover.json` 出力、排他ロックおよび staging 経由 `finalize_pass2` / `finalize_pass3` 組み込み、`executive_summary_preview.md` 出力、`self_contained: true` 明示、プレビューダッシュボード `dashboard_preview.html`。
   - Categorical: Pass 1 唯一 run 作成原則対応（`claim_resumable_profile_run()` と `.render_claim` 廃止、`--profile` は consultation workspace へのプロファイル出力限定、`--render --config` が正式 run 予約）、`results_manifest.json` 出力、新設 `render_dashboard.R` ラッパー配置、`inputs` 統合、排他ロックおよび staging 経由 `finalize_pass2` 組み込み、`self_contained: true` 明示、プレビュー成果物分離。
   - Questionnaire: 親直下出力の完全廃止と `runs/<id>` 強制隔離、部分失敗時の状態遷移（`completed` / `partial` / `failed`）と診断成果物保持・後続遮断、複数設問を網羅した `results_manifest.json` 出力、`inputs` 配列管理、新設 `render_dashboard.R` ラッパー配置、`self_contained: true` 明示、`cross_question_summary.md` の排他ロックおよび staging 経由 `finalize_pass2` 組み込み、プレビュー成果物分離。
3. **フェーズ 3: テストスイートの追加と検証**
   - 単体テスト: 同一秒 2 プロセスの原子的隔離、Pass 1 成果物の不変性検証、`sealed` 後の追加・上書き拒絶、Questionnaire 複数設問 manifest 完全性、Categorical 結果の manifest 登録、Categorical Pass 0 profile 出力と Pass 1 正式 run 原子的作成の分離検証（claim廃止検証）、パストラバーサル（prefix 衝突、symlink、`../../`）、親直下合算探索、supersede 自己参照・skill不一致・壊れた元 run の拒絶、`results_manifest.json` 実ファイルバイト列ハッシュ一致検証、manifest スキーマ制約（重複 path, 重複 question_id, 不正 role, 不正 hash 拒絶）、run 外排他ロックの信頼境界検証（改ざん out_root / run_output_dir で外部ディレクトリ作成阻止）、同時実行競合（1つだけ成功、置換なし、敗者エラー、sealed 不変性維持）、stale ロック回復（`--recover-stale-lock`、PID生存時拒絶、ホスト不一致拒絶）、legacy run の preview 許可・本番確定拒絶検証、staging からの promotion、確定失敗時の未確定本番成果物残存防止、promotion 後クラッシュからの冪等回復、既存ファイルハッシュ不一致時の上書き拒絶、sealed 前の staging 空検証、スタブ生成後の本番 Pass 2 確定、プレビュー再実行上書き拒絶、プレビューダッシュボード生成後の本番ダッシュボード確定、プレビュー時の未封印検証、Questionnaire 部分失敗（`partial` / `failed`、診断成果物、後続拒絶、supersede 許可/拒絶）、finalizer allowlist 攻撃的テスト、3 スキル `self_contained: true` ダッシュボード単一ファイル性、`finalize_run_stage.R` 経由の確定、`cwd + argv` による任意ディレクトリ実行再現、Questionnaire 親直下出力廃止検証、3 スキルの `render_dashboard.R` 動作、推測なしデータ hash_only ポリシー。
   - 結合テスト: Pass 1 -> Pass 2 -> Pass 3 の一貫実行と `sealed` 封印。
   - 既存回帰テスト: 全テストがパスすることを確認。

## Open Questions

現時点でブロッキングとなる未解決事項はありません。
上記の Categorical における Pass 1 唯一 run 作成原則（resumable claim 廃止）、信頼境界検証に基づく run 外専用制御領域（`<out_root>/.run_locks/<run_lock_id>/`）での stage 単位排他ロック制御、legacy run の読み取り・preview 限定（本番確定拒絶）、sealed 封印との完全な整合性、run 内 staging 領域からの検証・promotion・クラッシュ回復および sealed 前空検証、スタブ（`executive_summary_preview.md`）と本番考察（`executive_summary.md`）の完全分離と一回限り生成方針、プレビューダッシュボード（`dashboard_preview.html`、未封印）と本番ダッシュボード（`dashboard.html`、sealed 封印）の完全分離、Questionnaire の 3 区分状態遷移（`completed` / `partial` / `failed`）と部分失敗時遮断、finalizer の skill/stage 導出 allowlist 制限、3 スキル共通 self_contained: true ダッシュボード単一ファイル契約、`results_manifest.json` のスキーマ制約と実ファイルバイト列ハッシュによる決定的一意検証、ライフサイクル（Pass 1 成果物の不変性、Pass 1〜Pass 3 追記限定、Pass 3 確定による sealed 封印、改定時の supersede 系統記録）、メタデータ正本（`inputs` 単一正本化）、および `cwd` 付きハンドオーバーのすべての方針が具体的に確定しています。

## 最終確定時の補足契約

- **排他範囲**: stage ロックだけでは preview と本番が共有する run_meta.json を保護できないため、run 外に run.lock を追加する。取得順は run 共通 → stage、解放順は逆。ロック保持下で状態を再読し、検証・公開・メタデータ更新を実行する。生成中のファイルは呼び出し固有の一時領域へ置き、同じ staging ファイルを複数プロセスで共有しない。
- **クラッシュ回復**: promotion 前に制御領域へ transaction_<stage>.json を原子的保存する。source / target パス、成果物ハッシュ、期待結果・考察ハッシュ、run / stage を記録し、source 消失後も target と証跡を照合して回復する。証跡がない既存 target は採用しない。回復証跡は run 外に残す。stage ロックの通常解放は所有 token 一致を必須とし、stale 回復も共通ロックを含む回復操作を直列化する。lock_info 欠損・破損や所有者の生死不明は自動回復せず診断停止する。
- **失敗の境界**: promotion 前の失敗は本番成果物を残さない。promotion 後の中断は target と証跡を保持する回復対象であり、通常の失敗時削除を適用しない。Pass 3 は対象以外の staging 残存を promotion 前に拒絶し、promotion 後に空確認して封印する。
- **保証範囲**: sealed は本パイプラインの書き込み経路で強制する状態契約である。OS 権限を越えた外部編集防止や電源断時の永続化保証は本変更の対象外とし、後続検証では記録ハッシュとの不一致を拒絶する。
- **診断経路**: Questionnaire の manifest は summary.csv と成功設問 JSON を含む。partial / failed は非ゼロ終了し、本番 next_actions を空にして理由を記録する。元成果物の出力不能時まで診断ファイル生成を保証しない。legacy preview は --preview-output-dir で指定した元 run 外へ出力し、元 run を変更しない。
- **HTML の配置**: self_contained は公開 HTML がローカルの一時アセットに依存しないための条件である。レンダリング中の一時アセットは許容し、公開前に作業領域を整理する。既存の MathJax 等のネットワーク参照の全撤廃や完全オフライン対応を意味しない。
- **状態の意味**: run_state は active / sealed、pass_status が各工程の進行を表す。supersede の新 run は pending から再計算し、成功を先取りしない。元 run が active の場合もその状態のまま保持する。
