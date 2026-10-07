# AGENTS.md の Artifacts 契約と解析出力先規則の整備

作成日: 2026-10-06 (JST)  
状態: レビュー待ち  
対象: `AGENTS.md`、`.agents/skills/vcd-categorical-reporting/references/interface.md`

## 1. 目的と範囲

AGENTS.mdに `docs/Artifacts/README.md` のエージェント向け必須契約を反映し、Implementation Planの作成先を `docs/Artifacts/plans/` に統一する。また、解析結果の出力ルートを一律に `evidence_runs/<skill_slug>/` とする現在の一般記述をやめ、永続化を行うスキルの実際の設定と責務に整合させる。

`vcd-categorical-reporting` の現行SKILL.md・コードと、`references/interface.md` に異なる出力rootが記載されているため、同参照文書も現行値へ修正する。

コード、統計計算、データ、OpenSpec、外部システムは変更しない。前回からの `README.md`、`AGENTS.md` の未コミット編集は保持し、今回の差分はAGENTSの追記・修正と指定参照文書のroot記述に限定する。

## 2. 一次情報と現状

| 対象 | コードベースで確認した契約 | 含意 |
|---|---|---|
| `docs/Artifacts/README.md` | Planは `plans/`、QAは `qa_cycles/<topic>/c<N>/`、メタ反省は `meta/`、計画上書き禁止、既存flat文書は読取互換、完了物は `docs/Archives/` へ | AGENTSに作成先・命名・連番・禁止事項・参照先を明記する |
| `vcd-bayesian-evidence-analysis` | CLI既定root `evidence_runs/vcd_bayesian`; run分離は共有 `run_scope.R` | canonical rootはスキル固有slug |
| `vcd-categorical-analysis` | CLI既定root `evidence_runs/vcd_categorical`; canonical run layout | canonical rootはスキル固有slug |
| `vcd-categorical-reporting` | 実装既定root `evidence_runs/vcd_categorical_reporting`; SKILL.mdも同値 | `references/interface.md` の `evidence_runs/vcd_categorical/` は不一致のため修正 |
| `evidence-decision-review` | 推奨root `evidence_runs/evidence_decision_review` | canonical rootはスキル固有slug |
| `questionnaire-batch-analysis` | 既定 `evidence_runs/questionnaire/`, `run_<id>/`; `runs/<id>/` は旧形式互換 | ディレクトリ名は skill name そのものではない |
| `sas-proc-freq`, `sas-proc-means` | schema例はそれぞれ `evidence_runs/sas_proc_freq`, `evidence_runs/sas_proc_means`; `output_dir` は設定必須 | 出力rootは利用者設定値。例示rootと実行時既定値を区別する |
| `comparative-design-analysis` | SKILL.md記載の共有推論器はrunディレクトリを直接作成しない。永続化する呼び出し側がrun layoutを確保する | このスキルに一律の既定出力rootを割り当てない |
| `vcd-pass0-consultation` | `inspect_data.R` は既定カレントディレクトリ、推奨は `evidence_runs/inspections/<project>/run_<id>/` | 分析スキルrootとは別の検分出力である |

したがって `evidence_runs/<skill_slug>/` という一律指定は不正確である。全スキルが同じrootを使うわけではなく、共有推論器や相談スキルの出力責務も異なる。run単位分離は共通原則として残し、出力root・識別子・永続化責任は各SKILL.mdと設定schemaに委譲する。

## 3. 変更設計

### `AGENTS.md`

- 「解析成果物をrun単位で分離する」を一般原則として保つ。
- `evidence_runs/<skill_slug>/` を共通既定値とする文を削除する。
- 出力を永続化するスキルでは、各 `SKILL.md`・schema・共有run基盤が定めるrootを使用する、と明記する。
- `comparative-design-analysis` の共有推論器のようにrun作成責任を持たない処理は、永続化する呼び出し側がrun layoutを担うとする。
- `vcd-pass0-consultation` の検分出力が分析結果の出力rootとは別契約であると明記する。
- `docs/Artifacts/README.md` を置き場の詳細正本としてリンクし、AGENTSに以下のエージェント必須要約を記載する。
  - 新規Implementation Planは `docs/Artifacts/plans/implementation_plan_NNN_MMDD.md` に作成する。
  - `plans/` 内の最大連番+1を用い、既存計画を上書きしない。
  - 新規文書を `docs/Artifacts/` 直下へ作らず、Plan・QA・metaの所定フォルダに置く。
  - QAサイクルと完了済み成果物のアーカイブは詳細READMEと専用スキルに従う。
- 「計画承認前に実装へ進まない」既存規則を保持する。

### `vcd-categorical-reporting/references/interface.md`

- 推奨rootを `./evidence_runs/vcd_categorical_reporting/` に修正する。
- 旧 `./skill_out/vcd_categorical/` が移行互換として今も扱われるかを実装・仕様から確証できない限り、現行rootの契約として掲載しない。歴史的説明が必要な場合はlegacyと明示する。

## 4. 具体的確認マトリクス

| Fixture / 対象 | Checks | Expected Results |
|---|---|---|
| `docs/Artifacts/README.md` | Plan/QA/meta/禁止事項/連番/アーカイブ条項を照合 | AGENTSの要約が規則を欠落・改変せず、詳細READMEへリンクする |
| 9スキルの `SKILL.md` と関連schema | 各スキルのroot・run分離・永続化責務を照合 | AGENTSは実在するroot名を一律化せず、skill-specific契約へ委譲する |
| `comparative-design-analysis/SKILL.md` | 共有推論器のrun作成責任を確認 | AGENTSは共有推論器が自らrunを作ると誤記しない |
| Pass 0スキルと `inspect_data.R` | 検分output-dirの推奨・既定を照合 | 検分出力と解析rootの違いが明確 |
| `vcd-categorical-reporting` の実装、SKILL、interface reference | root文字列を横断比較 | 現行rootが三箇所で一致し、旧rootは現行契約として残らない |
| `AGENTS.md` と Artifact計画ディレクトリ | パス・命名・最大番号+1・上書き禁止を確認 | 今後の計画先が一貫して `docs/Artifacts/plans/` |
| Markdownリンクと差分 | 相対リンク存在確認、`git diff --check`、変更ファイル確認 | リンク切れ・空白エラーなし。前回作業中の変更を保持し、追加変更は計画対象内 |

テストスイート、R解析、HTML生成は変更しないため実行しない。これは文書契約・リンク・差分の静的確認である。

## 5. 受入条件と未変更範囲

- AGENTSにArtifact配置契約の実行可能な要約と詳細正本リンクがある。
- 今後のImplementation Plan作成先は `docs/Artifacts/plans/` に統一され、既存計画上書き禁止が明記される。
- run分離原則とoutput-rootの責任所在が分けて記述され、一律 `evidence_runs/<skill_slug>/` の誤った一般化がない。
- `vcd-categorical-reporting` のSKILL・実装・参照インターフェース間でrootが一致する。
- Rコード、schema、分析ロジック、入力データは変更しない。

## 6. 承認境界

本計画の承認後に、指定した2ファイルを編集して静的確認を行う。対象範囲に追加・変更が必要になった場合は計画を更新し、再承認を得る。
