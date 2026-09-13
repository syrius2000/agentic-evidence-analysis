# Quality Loop 初回運用マニュアル作成計画

created: 2026-09-12 23:35 (JST)
update: 2026-09-12 23:35 (JST)
author: Codex (GPT-5)

---

## 1. 目的

Quality Loop を初めて運用する利用者が、通常の文書・コード点検と正式な `quality-review` を混同せず、案件作成から Owner 裁定までを安全に進められる日本語マニュアルを作成する。

本マニュアルは、次の疑問に直接答える。

1. いつ Quality Loop を開始するか。
2. どの自然言語指示で Reviewer 工程を依頼するか。
3. `quality-review` を実行できる状態を、何で判定するか。
4. `review`、`review-plan`、`verify`、`assess-risk` の違いは何か。
5. Plan 合意、Owner の実装許可、Implementer の変更提出、Reviewer の独立検証、Owner の最終裁定をどう区別するか。
6. 今回観測した2案件の事実を、一般規則と区別してどう参照するか。

## 2. 根拠と現状

### 2.1 使用する根拠

- `/tmp/qms_three_way_dashboard_001_meta_20260912.md` の `QMS-THREE-WAY-DASHBOARD-001` 運用履歴。
- 本リポジトリの `quality-loop/cases/QA-CRR-001` に対する公開CLIの読み取り専用 status 結果。
- `quality-review` Skill の公開CLI、役割境界、許可語彙、禁止事項。
- 本リポジトリの段階的承認規則およびGit差分保護規則。

### 2.2 本計画作成時の事実

- `QMS-THREE-WAY-DASHBOARD-001` のメモは、revision 14 時点で Reviewer の独立 verify 後、Owner の `adjudicate` を次操作としていた履歴である。
- `QA-CRR-001` の公開CLI status は、revision 16、`current_state: accepted-with-risk`、`next_role: null`、`next_action: null`、open findings なしの終端状態を示した。
- よって、現在の `QA-CRR-001` は `quality-review` を開始できる案件ではない。新たなレビューを始めるには、新規または再開された案件が公開CLI statusで `next_role: reviewer` を示す必要がある。

## 3. 作成対象と構成

承認後、次の新規文書を作成する。

`docs/Artifacts/quality_loop_manual_001_0912.md`

本文はすべて日本語とし、以下の章で構成する。

1. **まず押さえる境界**
   - Quality Loop が向く変更（高い失敗影響、複数役割による証跡、Owner裁定が必要な変更）と、通常の読み取りレビュー・軽量QAで十分な変更を分ける。
   - OpenSpec、Git commit/push、通常のコードレビューとの非同値を明示する。
2. **役割と権限**
   - Owner、Reviewer、Implementer の担当、してよいこと・してはいけないことを表で示す。
   - Reviewer が対象実装や案件正本を直接編集せず、Owner裁定を代行しない境界を示す。
3. **開始（キック）条件**
   - `case_id`、`case-root`、baseline、Purpose、Intended Use、Risk Context、要求、受入基準を準備する。
   - 公開CLIの `status` で `next_role=reviewer` と現在handoffを確認できたときだけ Reviewer 操作を開始する。
   - `next_action` が `review`、`review-plan`、`verify`、`assess-risk` のどれかを判定して、同一応答では1操作だけを実行する。
4. **Reviewer の4操作**
   - 初回 `review`、Plan評価 `review-plan`、独立検証 `verify`、残余リスク評価 `assess-risk` の入力・判断・次工程を対比する。
   - Findingの根拠、比例性ゲート、Evidence gap、申告外変更の拒否を具体化する。
5. **Implementer・Ownerとの受け渡し**
   - `submit-plan`、`submit-response`、Owner `adjudicate` の関係を説明する。
   - Plan合意と実装許可を別ゲートとして扱い、`implementation_authorization.allowed`、`finding_ids`、`allowed_targets` を確認する手順を示す。
6. **そのまま使える依頼文**
   - OwnerからReviewerへ初回レビュー、Planレビュー、独立verifyを依頼するための、必要情報を埋めるテンプレートを提示する。
   - statusがReviewerでない場合の安全な依頼文も提示する。
7. **実例から学ぶ分岐**
   - `QMS-THREE-WAY-DASHBOARD-001` で観測した Plan合意とOwner許可の分離を、一般規則ではなく「観測された運用例」として記録する。
   - `QA-CRR-001` の終端状態を例に、`next_role: null` の案件ではレビューを再開しないことを示す。
8. **チェックリストと復旧**
   - Reviewer操作前・操作後のチェックリスト、`next_role` 不一致、handoff/revision不一致、Evidence不足、申告外変更の対応を載せる。

## 4. 実施方針

1. `/tmp` の履歴は参照根拠としてのみ用い、リポジトリへ複製するのは再利用に必要な要約・一般化・今回の観測事実に限る。
2. 実案件の `case.json`、handoff、Evidence、Owner裁定を代筆・改変しない。マニュアル内のコマンド例はプレースホルダーを使い、実在のhandoffを再利用しない。
3. Reviewerの完了語彙は `verified`、`remediated`、`not-verified`、`unverified`、`finding-withdrawn`、`converted-to-suggestion`、`not-applicable` に限定する。Reviewer結果として `accepted`、`rejected`、`closed` を使わない。
4. Owner裁定の `accepted` / `accepted-with-risk` は、Reviewerの検証結果ではなく、Ownerだけが行う終端判断であると明示する。
5. 現在の `QA-CRR-001` に対して review、review-plan、verify、assess-risk を実行しない。読み取り済みstatusはマニュアルの終端状態の例に限定する。

## 5. 検証

| 検証観点 | 完了基準 | 方法 |
| --- | --- | --- |
| 役割境界 | Reviewer、Implementer、Ownerの権限を混同していない。 | `quality-review` Skillと文書本文を照合する。 |
| 開始条件 | statusの `next_role` と `next_action` を必須のキック条件としている。 | 状態表と依頼テンプレートを点検する。 |
| 事実と一般規則 | 2案件の履歴を一般化し過ぎず、観測例として区別している。 | 出典・注記を確認する。 |
| 安全性 | case正本の直接編集、Evidence捏造、ReviewerによるOwner裁定を促していない。 | 禁止事項と復旧手順を点検する。 |
| 可用性 | 初学者がコピーして使える依頼文、チェックリスト、失敗時の次操作がある。 | 手順を最初から通読する。 |
| 形式 | 日本語、Artifact命名、JSTメタデータ、相対リンクの規約を満たす。 | Markdownとリンクを確認し、`git diff --check` を実行する。 |

## 6. 除外範囲

- Quality Loop Skill、CLI、状態遷移、既存case、Evidence、コード、OpenSpec、テストは変更しない。
- 新規ケース作成、実レビュー、Owner裁定、実装許可、commit、pushは行わない。
- `/tmp` の元メモは編集・移動・削除しない。

## 7. 承認後の作業範囲

本計画への承認は、`docs/Artifacts/quality_loop_manual_001_0912.md` の新規作成、および上記検証に限って有効である。Quality Loopの実行・案件操作・Skill変更・Git操作は別途の明示承認を必要とする。
