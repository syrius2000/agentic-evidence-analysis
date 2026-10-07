# README.md・AGENTS.md 役割分担の整理

作成日: 2026-10-06 (JST)  
状態: ユーザー承認済み  
対象: `README.md`, `AGENTS.md`

## 1. 目的と範囲

READMEを利用者向けの導入・選択・実行案内、AGENTSをエージェント向けの作業契約に整理する。数理説明・スキル責務・規範挙動は既存の `docs/reference/`、`.agents/skills/`、`openspec/specs/` を参照し、両トップレベル文書で重複して正本化しない。

変更対象はREADME.mdとAGENTS.md、およびこの計画書のみ。実装、データ、依存関係、外部システムは変更しない。

## 2. 現状確認と根拠

- `README.md` は利用者向け概要・4-Pass説明・手法詳細・スキル一覧・導入と実行例を含む。
- `AGENTS.md` は行動規則に加え、詳細な数理説明、スキル一覧、Passワークフローを重複掲載している。
- Pass 0の境界は `.agents/skills/vcd-pass0-consultation/SKILL.md` と `docs/reference/skill_responsibilities.md` に具体化されている。
- `docs/reference/skill_responsibilities.md` は規範挙動を `openspec/specs/`、スキル責務を同文書、数理充足状況をギャップ監査に案内している。
- READMEの「Strict Execution Sequence」はスキルごとの差を覆い隠す。SAS互換、直接集計、保守作業などPass 0対象外の経路も存在する。
- `docs/Artifacts/README.md` は計画書を `docs/Artifacts/plans/` に置く契約を定めている。

## 3. データ／出典契約

| 項目 | 正本・確認元 | 文書での扱い |
|---|---|---|
| 行動規則・承認境界 | `AGENTS.md` | エージェント向けの規範として残す |
| 利用方法・導入例 | `README.md` と各スキル `SKILL.md` | READMEは入口と代表例。引数詳細はスキルへ委譲 |
| Pass 0の適用条件 | `.agents/skills/vcd-pass0-consultation/SKILL.md`、`docs/reference/skill_responsibilities.md` | AGENTSは判定を簡潔に保持し、READMEはスキル差を説明 |
| スキル責務 | `docs/reference/skill_responsibilities.md`、個別 `SKILL.md` | READMEは選択用の簡潔な一覧。AGENTSからは参照 |
| 統計数理 | `docs/reference/README.md` と各数理文書 | 数式・閾値詳細をトップレベル文書へ複製しない |
| 規範挙動 | 対応する `openspec/specs/` | 対象仕様ごとに参照。archiveを規範として扱わない |
| 成果物配置 | `docs/Artifacts/README.md`、各実行スキル | AGENTSに一般規則を保持し、skill-specificな詳細は参照 |

統計仕様と数理解説は性質が異なるため、「文書間の一律な優先順位」ではなく、上記の責務ごとに正本を指示する。矛盾を見つけた場合、作業を止めて該当する仕様・責務の正本を照合し、未解決として報告する。

## 4. 変更設計

### AGENTS.md

- 冒頭に適用範囲と文書責務を置く。
- 依存関係、Pass 0、run分離、言語・時刻、オフライン成果物、リポジトリ境界など作業時に行動を変えるルールを保持する。
- Pass 0の範囲は短く明示し、詳細はPass 0スキルと責務リファレンスへリンクする。
- 数理哲学は「P値単独判定をしない」「効果・証拠・精度・判断等を混同しない」「自動規制判断を行わない」の短い原則にまとめ、詳細文書へリンクする。
- スキル紹介表を削り、責務リファレンスとスキル選択用READMEへ案内する。
- 計画承認、ユーザー変更保全、Git操作、証拠区分は維持する。ブラインドQAの詳細列挙を減らして専用スキルへリンクする。

### README.md

- 概要、選び方、スキル別ワークフロー、導入、実行例、出力・参照文書の順に読める構成にする。
- 「全スキル共通の厳格な4-Pass」という誤解を避け、Pass 0はスキルと目的に応じ必須・推奨・対象外であると記述する。
- 3次元分析向けの既存4-Pass説明は、適用対象を明記した「代表的ワークフロー」として残す。
- 数理の詳細は短い概要と正本リンクに整理する。利用者の選択に必要なスキル一覧はREADMEに残す。
- Pass 0の出力例など、スキル文書と異なる設定経路に見える例を改める。提示するコマンドは実ファイルと引数を照合する。
- 「唯一の正本」は対象を具体化し、統計実装資産を管理するリポジトリである旨をREADMEとAGENTSで整合させる。

## 5. 変更・影響範囲

- 変更ファイル: `README.md`, `AGENTS.md`。
- 追加計画書: `docs/Artifacts/plans/implementation_plan_003_1006.md`。
- 利用者向け実行挙動、統計計算、データ、依存関係、OpenSpec、個別スキルの規範内容は変更しない。
- 既存の未追跡・無関係変更は開始時点で存在しない（作業開始時 `git status --short --branch` は `main...origin/main` のみ）。

## 6. 確認マトリクス

| Fixture / 対象 | Checks | Expected Results |
|---|---|---|
| `README.md` の分析フロー節 | 必須・推奨・対象外の表現と4-Pass説明を確認 | Pass 0を全スキル共通の必須手順と誤読しない。3次元4-Passは適用対象が明記される |
| `.agents/skills/vcd-pass0-consultation/SKILL.md` と責務リファレンス | README/AGENTSのPass 0分類を照合 | 必須・推奨・対象外のスキル名と条件が一致する |
| READMEのコマンドブロック | 記載パスの存在、引数の用法、出力先のrun分離を確認 | 例示スクリプトが実在し、引数は該当SKILL.mdと矛盾しない |
| `AGENTS.md` | 行動規則、承認境界、保全、証拠区分を確認 | 実行時に必要な禁止・必須指示が残り、利用案内・数理解説の重複が縮減される |
| 両文書のMarkdownリンク | 相対リンク先を実在確認 | 新設・変更リンク切れがない |
| 両文書の重複主張 | Pass 0、9スキル、正本境界、run出力、オフライン方針を対照 | 二文書間の矛盾がない。規範の詳細は担当正本への参照となる |
| 差分とGit状態 | `git diff --check`、`git status --short`、`git diff -- README.md AGENTS.md` | 空白エラーなし。変更が承認範囲と計画書内に限定される |

テストスイートや解析処理は変更しないため実行しない。上記は文書・リンク・差分の静的確認とする。

## 7. 完了時の報告

文書改訂、静的確認の結果、未検証事項、Git差分の状態を別々に報告する。コミット、push、独立QAは本計画の範囲に含めない。
