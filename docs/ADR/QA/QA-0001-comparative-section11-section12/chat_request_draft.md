# CloudAI QA依頼案

以下をGitHub上のCloudAIレビュー依頼に貼り付ける。

---

`syrius2000/agentic-evidence-analysis` の独立QAレビューをお願いします。

**対象revision:** `9a74bcfa485913e4ddebceec7b69207cd9b86905`

**比較基準:** `1d42f4ae7a7e0649b755ab437c9e67c673078cc2`

**QAケース:** `docs/ADR/QA/QA-0001-comparative-section11-section12/`

レビュー対象は対象revisionが導入した差分です。主目的は、Section 11の人年・人月率draw/evidence契約の後続強化（11.R7–11.R11）と、Pass 0における反復観測行の被験者単位集約・ルーティング境界（12.1–12.4）が、Purpose・OpenSpec・受入条件を満たすかを独立に評価することです。

初回レビューでは実装者の結論や既存QA判定を正しさの根拠にせず、対象revisionのコード、schema、OpenSpec、テストを独立に確認してください。特に、person-timeのposterior semantics、単位の組合せ、参照群0件時のIRR状態、persisted/ephemeral drawの境界、反復行集約の確認条件、被験者内不整合・欠測・非二値結果・マッチング構造・上位クラスタの拒否、入力不変性とprovenanceを確認してください。GLMM/GEEまたはcluster bootstrapの実装が対象範囲へ紛れ込んでいないことも確認してください。

実施記録中のテスト結果、 assertion数、回帰スクリプト数、OpenSpec/Draft-07検証は実装者の主張として扱い、可能な範囲で対象revision上の一次証拠と照合してください。実行できない場合は未検証とし、実行済みと記載しないでください。

結果は、重大度（critical/high/medium/low/informational）、Finding ID、根拠（ファイルと行または具体的な入力・出力）、影響、推奨対応、検証状況を含むMarkdownで返してください。問題が見つからない場合も、確認した範囲と未検証事項を記録してください。最初の回答は独立レビュー結果のみとし、実装者回答や修正の受入判定は行わないでください。

---

依頼時にCloudAIのモデル/バージョン、実行環境、レビュー日時をQAケースへ追記する。
