# 実装計画 001: 分析系スキルの品質改善（.agents/skills、openspec除く）

- 作成日: 2026-10-13 (JST)
- 開始時点: branch `main`, commit `8298116`（作業ツリーはクリーン）
- 作業ブランチ: `feat/skills-quality-hardening`
- 承認: 会話内でユーザーが承認済み。決定事項は §2、決定の経緯は §2.7 の台帳を正本とする（会話中に質問番号の体系が複数あったため、番号ではなく内容と決定ラベルで参照する）

## 1. 背景

分析系スキルの棚卸しで、統計の正しさ、バグ、仕様と実装の不整合、run 出力の不統一、HTML 組立と数式表示の方式の混在が見つかった。

## 2. 決定事項

| 項目 | 決定 |
|---|---|
| subset_expr 失敗 | 当該設問を failed とし理由を記録。他設問は続行。`eval(parse())` の制限は別 Change |
| pass2_stub.R | 旧 Evidence Score の文言を削除し、現行のセル診断用語に置換 |
| 数式表示 | **出力契約を native MathML（`<math>`、フォント・CSS・JS・外部不要）に統一**。生成経路はスキル別: bayesian は `katex::katex_mathml()`（共有ラッパー `render_math()` 経由）、categorical は Pandoc `--mathml` 維持、reporting は手書き MathML 維持。`katex` は任意依存のままフォールバック（`<code class="tex-fallback">`）を維持し、発動時はダッシュボードに明示。KaTeX の woff2 埋込と `katex.min.css` は不要（Q9/Q-B'/Q-C） |
| HTML 組立 | `htmltools::tags` へ移行。共有ヘルパーを `.agents/shared/` に置き段階移行 |
| 外部参照検査 | 共有化。`url(`、`@import`、`script/link/img` の http、絶対パスを検査。警告扱い |
| 画像 | 相対参照を維持。run 内存在と `..`・絶対パス逸脱を検査し、results_manifest に登録。任意の `embed_images`（既定 OFF） |
| run_state | 語彙を `active / completed / failed / sealed` に統一（検証後に確定） |
| メタ統合 | sas の `manifest.json` を `run_meta.json` / `results_manifest.json` へ統合。categorical は **run 内の** `run_state.json` のみ `run_meta.json` へ統合し、**出力 root 直下の早期失敗記録 `run_state.json` は維持**（run ディレクトリ未作成の段階の失敗を記録するため）（Q-A=a） |
| index / latest | `runs_index.jsonl`（追記専用）と `latest.json`（原子的更新、symlink 不使用）。第 2 段階 |
| 再現性 | `run_meta.json` に共通の `environment`（R、platform、パッケージ版、seed、sessionInfo） |
| ID 方式 | **現行 spec の規則（論理 ID `run_001` → 物理名 `run_001`、ID の先頭 16 文字を使用）を維持する。** 当初の「spec を実装に合わせて修正（sha256 化）」（Q18=a）は撤回（2026-10-13 Phase 3A レビュー）。理由: 物理名は、questionnaire・sas・reporting・evidence-decision-review では渡された ID の先頭 16 文字、bayesian（ID 指定あり）は `sanitize_run_slug`、categorical は署名の先頭 16 文字、bayesian（ID なし）は入力ファイルのハッシュであり、明示 ID を sha256 化する経路は実際の呼び出し側にない。`logical_run_id` の記録は現行 spec ですでに要求済み |

## 2.5 進め方（確定）

- ハイブリッド: 仕様に違反するだけのバグ修正（subset_expr、pass2_stub）と tags 移行は計画書から自動実施。仕様が変わるものは OpenSpec Change で扱う。
- OpenSpec Change は 2 本: 「run 基盤の統一」と「HTML・数式の品質契約」。
- 自動実施中の停止条件: 仕様変更、統計値の変化、既存ファイル名の変更などの破壊的変更が出たとき。
- commit はフェーズごとに 1 回。push と main への集約は指示があるまで行わない。
- レビュー: 統計値に影響する Phase 2・3 の末に、code-reviewer（または私）のレビューを挟み、ユーザーへ中間報告する（Q-D=c）。他のフェーズは完了時にまとめてレビュー。
- 実行権限: `.claude/settings.json` に、`Rscript`・`openspec`・`git status/diff/log/add/commit/branch`・`grep`・`ls` の許可と、`git push` の拒否を設定済み（Q-E=a）。`merge`・`rebase`・`reset`・`rm` は許可しない。
- 実行担当: 長時間の実装は Haiku が `implementation_tasks_001_1013.md` に従って進める。停止条件はタスクリスト §0.1 を正本とする。

## 2.6 spec 整合性の訂正（現行 `openspec/specs/` が対象。`changes/archive/` は履歴のため編集しない）

実装方針と衝突する現行 spec を洗い出した。各 Change の delta spec（MODIFIED / ADDED）で訂正し、対応する実装・テストと同時に更新する。

| spec | 該当 | 衝突の内容 | 訂正方針 |
|---|---|---|---|
| `evidence-run-layout` | L68-69 | 論理ID `run_001` → 物理名 `run_001` と規定 | **変更しない**（実装と一致していることを呼び出し側で確認済み。Q18=a は撤回）。必要なら、物理名が ID の先頭 16 文字、categorical は署名、bayesian の自動 ID は入力ハッシュに由来する旨の説明文のみを追加する |
| `evidence-run-layout` | L106-111 | `run_meta.json` の整合要件のみ | run_state 語彙、`environment`、`results_manifest`、index/latest の要件を ADDED |
| `sas-proc-freq` | L122,127,136 | `manifest.json` を成果物として規定 | `run_meta.json` / `results_manifest.json` への統合に合わせて修正（決定済: Q-A=a、sas の manifest.json も run_meta.json / results_manifest.json へ統合） |
| `sas-proc-means` | L81,86 | 同上 | 同上 |
| `two-way-evidence-analysis` | L16-54,224-248 | `run_state.json`（出力 root 直下の早期失敗記録を含む）と `.run_lock`（`CONCURRENT_RUN_IN_PROGRESS`）を規定。実装の `.run_lock` は予約済みの新規 run 内に作られ、判定がデッドコード | 決定済(Q-A=a): 出力 root 直下の早期失敗記録 `run_state.json` は維持。run 内の `run_state.json` のみ `run_meta.json` へ統合。`.run_lock` は spec の意図（同一署名の並行実行防止）を維持し、共通 `acquire_stage_lock` で実効化する（spec の文言を実装に合わせて明確化） |
| `comparative-evidence-reporting` | L173,178 | 数式は native MathML（`<math>`）と規定 | 変更不要（全スキル native MathML 統一の方針と一致）。共有契約として `shared-dashboard-presentation` に数式要件を ADDED |
| `shared-dashboard-presentation` | L68 | 完全自己完結型オフライン契約 | 画像は run 内相対参照可、検査の共有化、`embed_images` を反映して明確化 |
| `three-way-dashboard-reporting` | L172 | 外部 URL / 絶対パスの静的検査 | 検査項目に `url(`・`@import`・画像参照の run 内検証を追加 |

Phase 1 に「spec 全 19 件と実装の一致監査」を加える（上記表以外に衝突が無いことを確認する）。

## 2.7 決定台帳（会話での質問ラベルとの対応）

| 決定ラベル | 論点 | 決定 |
|---|---|---|
| 目的 | 議論の出口 | 計画書化して OpenSpec Change / 自動実施へ（Q1=b） |
| 対象 | スキルの範囲 | 核（vcd-bayesian, vcd-categorical, comparative-design）と周辺（reporting, questionnaire, evidence-decision-review, sas-proc-*）（Q3） |
| 観点 | 優先順位 | 統計の正しさ → バグ・仕様不整合 → 保守性 → 使い勝手（Q4） |
| subset_expr | 失敗時の挙動 | 設問を failed + 理由、他設問は続行（Q5=a）。`eval(parse())` は将来課題（Q6=c） |
| pass2_stub | 旧スコア文言 | 削除して現行用語へ（Q7=a） |
| 数式 | 表示方式 | native MathML に統一、生成経路はスキル別（Q9、Q-B'、Q-C） |
| HTML | 組立方式 | htmltools::tags へ全面移行（Q10=b） |
| 検査 | 外部参照 | 共有化、警告扱い（Q11=a） |
| 画像 | 埋込 | 相対参照維持 + 検査 + 任意 `embed_images`（Q12） |
| 検証 | 実機確認 | ヘッドレスでの数式描画確認（Q13）、run_state の実確認（Q14=a） |
| run メタ | 統合範囲 | 二重管理の解消、早期失敗記録は維持（Q15=a、Q-A=a） |
| run index | 横断参照 | `runs_index.jsonl` と `latest.json`（Q16=a） |
| 再現性 | environment | 共通ブロックを追加（Q17） |
| ID | 方式 | 現行 spec を維持（Q18=a は撤回。物理名は ID の先頭 16 文字等で、sha256 化は一部のスキルのみ）。2026-10-13 Phase 3A レビューで訂正 |
| 進め方 | OpenSpec 運用 | ハイブリッド、Change は 2 本、停止条件で止まる、commit はフェーズごと（推奨どおり） |
| レビュー | 体制 | Phase 2・3 の末にレビュー（Q-D=c） |
| 権限 | 実行許可 | settings.json に許可を設定（Q-E=a） |
| ロック | categorical の排他 | 共通ロック方針（H2=a）。ただし `acquire_stage_lock` は run ディレクトリが前提で、署名ロックは run 予約の前に取るため使えない。`run_scope.R` に兄弟 API（`acquire_signature_lock` / `release_signature_lock`）を新設する方式を承認（2026-10-13、Phase 2R レビュー）。stale 回復は持たず、回復は手動削除（spec が許容）。復旧手順は `vcd-categorical-analysis/SKILL.md` に記載 |
| ライフサイクル | 単一パスのスキルの正常終了 | `vcd-categorical-reporting` と `evidence-decision-review` は、正常終了時に `run_state="completed"` を書く（現状は既定の `active` のまま）。実装の小さな挙動変更で、統計値には影響しない。クラッシュ等で `active` のまま残る run は「中断された run」として spec に注記する（2026-10-13 Phase 3A 再レビュー） |
| 索引 | `runs_index.jsonl` の意味 | 「1行1run」ではなく「1行1確定事象」の履歴ログ。同じ run が複数行になってよく（例: bayesian の Pass 1 確定と Pass 3 封緘）、読み取り側は `run_id` ごとの最後の行を採る（同上） |
| タイムスタンプ | `run_meta.json` の `timestamps` | 実行環境のタイムゾーンではなく JST（`Asia/Tokyo`）で書く。sas の旧 `manifest.json` の `timestamp_jst`（JST 明示）の保証を失わないため。全スキルの `run_meta.json` に効く挙動変更で、統計値には影響しない（同上） |
| latest.json | `path` の意味 | 最新 run **ディレクトリ名**（出力 root からの相対パス。`run_id` ではない）。索引の各行にも run のディレクトリ名を持たせる。実際にスキルを走らせ、指す先が実在することを統合テストで検証する（2026-10-14 Phase 3B-1 レビュー H1） |
| session_info | 絶対パスの扱い | `session_info.txt` の絶対パス（BLAS・LAPACK 等）はファイル名だけに置き換え、他の内容は残す。`results_manifest_sha256` が環境依存になる点を design に明記する（同 M1） |
| seed | `environment.seed` | 乱数を使うスキルはシードを渡して記録し、使わないスキルは `null`。spec にも「乱数を使わない場合は `null`」と書く。対象スキルの洗い出しは実装担当が行う（同 M2）。`environment.platform` は `R.version$platform` とする（同 M3） |
| 3B-1 軽微指摘 | 追加作業 | bayesian のシードを 1 つの定数にまとめる（計算側と記録側の直書き 2 か所の重複を解消）。sas-proc-freq の `environment.seed` が「単一値なら整数、異なる値が複数なら配列」になる点を design に記載する。いずれも 3B-2 の小さな追加作業として実施（2026-10-14 Phase 3B-1 修正レビュー） |
| 3B-2 レビュー指摘 | 入力検証失敗経路の run_state 撤去と SHA 移送 | `validate_input_table` から `run_dir` 引数と内部の `run_state.json` 書き込みを完全撤廃し純粋な検証関数とする。`analysis.R` の呼び出し側でエラーを捕捉し `record_run_failure()` 経由で `run_meta.json`（`run_state="failed"`）を記録。`config_file_sha256` を `run_meta.json`（完了時・失敗時）の `extra` に移送。running 状態記録廃止と dashboard フォールバックの扱いを `design.md` に追記（2026-10-14 Phase 3B-2 レビュー） |
| 既存テスト | 失敗 3 本の修復と残骸対策 | Phase 2B（B1〜B5）として別タスク化。テスト側のみ修正し、製品コードは変更しない（2026-10-13） |

## 3. 範囲外（別 Change）

- `eval(parse())` の構文制限
- 主結果 JSON の命名統一
- 巨大ファイルの分割（`comparative_reporting.R` など）
- AGENTS.md「自己完結型」文言の明確化（提案のみ。承認が必要）
- `vcd-categorical-analysis/templates/report.Rmd:247` のシードなし `fisher.test(simulate.p.value = TRUE, B = 2000)`（レポート出力が実行ごとに変わる可能性。元からある問題。2026-10-14 記録）

## 4. フェーズ

- **Phase 1 検証（読み取り中心）**
  - (a) `read_run_control` を各スキルの出力に対して実行し、run_state の不整合を確定する
  - (b) フォントなし環境で bayesian ダッシュボードをレンダし、数式の崩れを確認する（一時ディレクトリのみ）
  - (c) `pass2_stub.R` の呼び出し元を確認する
  - (d) categorical `analysis.R:54,388` と `batch_runner.R` の `q_out` が run 配下か確認する
- **Phase 2 バグ修正（TDD）**
  - batch_runner の subset_expr fail-fast
  - pass2_stub の文言修正
  - run_state 語彙の統一（確定した場合）
  - categorical の `.run_lock` を共通 `acquire_stage_lock` に一本化し、lock_info を tmp→rename で書く
- **Phase 3 run 基盤**
  - メタ統合、environment ブロック、runs_index / latest
  - spec 修正は OpenSpec Change として扱う
- **Phase 4 HTML と数式**
  - 共有ヘルパーと tags 移行（疎表抑制文言など重複の多い箇所から）
  - 数式: `render_math()` 共有ラッパー、bayesian を `katex_mathml()` へ差し替え、フォールバック明示、数式検査（`katex-html` / `@font-face` 混入の検出）
  - 外部参照検査の共有化、画像検査と `embed_images`
- **Phase 5 検証とレビュー**
  - 回帰テスト全体、code-reviewer、セキュリティ確認

## 5. 確認マトリクス

| 項目 | Fixture | Check | 期待結果 |
|---|---|---|---|
| subset_expr 不正 | 不正式を含む設問 CSV | batch 実行 | 当該設問 failed と理由。他設問は成功。全行 TRUE にならない |
| pass2_stub | bayesian の既存 fixture | 出力 MD を検索 | 「Evidence Score」による偏りの記述がない |
| run_state | 各スキルの run 出力 | `read_run_control` | 全スキルで読込成功。語彙が定義内 |
| 数式 | KaTeX を使うダッシュボード | フォントなし環境でレンダ | 外部参照ゼロ。数式が崩れない |
| 外部参照検査 | `url()` / `@import` を含む HTML | 共有検査 | 警告が出る |
| 画像 | questionnaire の出力 | 検査 | run 内の相対参照のみ。manifest に登録 |
| 再現性 | 任意の run | run_meta.json | `environment` ブロックが存在 |
| index / latest | 複数 run | 実行後 | runs_index に追記され、latest が最新を指す |
| 既存回帰 | — | `tests/run_regression_suite.R` | 全件パス。統計値は不変 |

## 6. リスク

- run_state 不整合はコード読解による疑いで、実行確認は未実施
- フォントなし環境の崩れ方は未確認
- tags 移行は差分が大きいため、小単位のコミットに分け、各単位で統計出力の不変を確認する

## 7. 完了報告の区分

構文確認、テスト、解析実行、独立 QA、commit、push を区別して報告する。未実施の確認は「未検証」とする。push と main への集約は、ユーザーの明示指示があるまで行わない。

## 8. Phase 3B-2 第2次レビュー対応（canonical_config_sha256 移送とエラーコード整合）

- **指摘A（必須・中）**:
  - `analysis.R` の完了時 `extra_meta` および失敗時 `record_run_failure` の `extra` の双方に `canonical_config_sha256` を追加。
  - `tests/test_vcd_categorical_input_validation.R` および `tests/test_vcd_categorical_smoke.R` に、`run_meta.json` 内の `canonical_config_sha256` 存在アサーションを追加。
  - `design.md` の対応表を実装実態に合わせて更新（`extra$canonical_config_sha256` と `provenance$config_sha256` の両立）。
- **指摘B（低）**:
  - `analysis.R` の未抽出時既定エラーコード `INPUT_VALIDATION_FAILED` を維持し、前回報告の誤記を訂正。
  - `design.md`、`SKILL.md`、`references/` に `INPUT_VALIDATION_FAILED`（非 `[CODE]` 形式例外時のフォールバック）を追記。
  - 非 `[CODE]` 形式の例外発生時に `INPUT_VALIDATION_FAILED` が記録されるテストケースを追加。
- **指摘C（低）**:
  - ベースコミットハッシュの実測値（`2783fe90e5eb3af28fac5ee3465ac76a813894b8`）による報告の訂正。
- **指摘D（情報）**:
  - run ディレクトリ予約後の `record_run_failure` 呼び出し全件における `config_file_sha256` / `canonical_config_sha256` の受け渡し範囲を点検し、各箇所の理由を報告に記載。
