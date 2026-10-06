# 比較ダッシュボードの指標解説と未評価表示の改善計画

created: 2026-10-01 19:25 (JST)
update: 2026-10-01 19:48 (JST)
author: Codex (GPT-6)

## 1. 調査結果と承認境界

対象は [dashboard.html](../../../evidence_runs/vcd_categorical_reporting/run_20261001_190907/dashboard.html)。開始時の追跡差分・通常の未追跡ファイルはなく、ブランチは `main`。本ラウンドで作成するのはこの計画書のみ。実装・解析実行・成果物更新は未着手。

対象runの `comparative_evidence.json` は `domain = "safety"`、`primary_delta = 0.05`、`seed = 42`。8行すべてに U0〜U3 と優勢領域があり、対象runには未評価行はない。E100と逆数RDの説明はRDの解説に含まれるが、独立した解説項目がない。

別ケースの未評価は仕様上存在する。[比較推論の実装](../../../.agents/shared/comparative_contrasts.R)では `primary_delta = null` の場合、`practical_region_support = null`、`resolution_grade.grade = "NONE"`、`dominant_region = "none"` とする。JSON設定に限らず、API引数の既定値 `primary_delta = NULL` でも発生する。これは U3、実務的中立、同等性、計算失敗とは区別する。

## 2. 対象範囲

- [レポート生成コード](../../../.agents/skills/vcd-categorical-reporting/comparative_reporting.R)：要約データ搬送、HTML・Markdown解説、未評価表示、フィルタ。
- [ダッシュボード回帰テスト](../../../tests/test_comparative_dashboard_qa.R)と [レポート回帰テスト](../../../tests/test_vcd_categorical_reporting.R)：解説・表示状態の受入確認。
- [数理正本](../../reference/comparative_evidence_math.md)と [比較報告仕様](../../../openspec/specs/comparative-evidence-reporting/spec.md)：追加する解説・未評価の表示契約を同期する。

推論式、実務閾値、U0〜U3境界、事前分布、方向支持の計算は変更しない。実務閾値を自動補完しない。対象runを含む既存runは保存し、依存関係変更・commit・push・独立QA起動は本計画に含めない。

## 3. データ契約を先行定義

既存の canonical データを唯一の根拠とし、表示層で指標の再推定やグレード判定をしない。

| 搬送するデータ | 正本フィールド | 契約 |
|---|---|---|
| E100 | `risk_difference.excess_per_100` → `summary_df.excess_per_100` | RD点推定の100倍。表示丸め値から再計算しない |
| 逆数RD | `risk_difference.reciprocal_absolute_rd`、`reciprocal_status`、`reciprocal_direction` | 値と表示可否を分離し、既存状態機械を維持 |
| 実務評価 | `practical_region_support`、`resolution_grade.grade`、`resolution_grade.dominant_region` | `NONE / none`をU3や中立へ置換しない |
| 実務評価の表示状態（追加） | 正本の実務評価フィールドから要約構築時に確定 | `practical_evaluation_status` に `evaluated` または `not_evaluated` を搬送。正本が欠落・矛盾する場合は入力不整合として停止し、未設定と推測しない |
| 未評価の理由（追加） | 正本の明示的な無効化状態 | `practical_evaluation_reason` に `primary_delta_not_set` を搬送。評価済みはnull。HTML・Markdown・埋込JSON・CSVで共通利用 |

追加する名前は本計画で定義する新規フィールドであり、既存フィールドと混同しない。設計考慮型の `evidence_overrides` では各contrastの正本状態を優先し、バッチ引数だけで全行を未評価と判断しない。既存JSON schemaの必須構造を維持し、要約への追加列に伴うCSVエクスポートへの影響を確認する。

## 4. 表示と解説の変更

### E100とNNT・NNH-like

HTMLガイドへ「100人あたり差 (E100)」「NNT・NNH-like」の独立項目を追加し、Markdownにも対応する見出しを設ける。表の見出しから該当ガイドへ移動し、折りたたみ項目を開ける導線を追加する。見出しのクリック・Enter・Spaceによるソートと導線の操作を分離する。

E100は `100 × RD`、RD=0.03なら100人あたり3人多いという絶対差の換算であること、負の値は比較対象群のイベント発生が少ないことを示すと説明する。確率の相対的な増減と混同しない。

逆数RDは `1/|RD|`、RD=±0.03なら約33.3人に対しイベント発生者1人分の差に相当する規模であると説明する。canonical RD点推定の変換であり、逆数の事後中央値ではない。`domain = "safety"` かつ `STABLE_DIRECTION` の場合のみ `target_excess → NNH-like`、`reference_excess → NNT-like` を用い、非Safetyでは `1/|RD|` とする。`SIGN_AMBIGUOUS`、`RD_NEAR_ZERO`、`NOT_INTERPRETABLE` の表示抑制理由を日本語で説明する。ゼロを含むRD区間を単純反転した区間は作らず、因果的NNTや同等性を主張しない。

### 実務領域・U-Gradeの未評価

正本12列契約を保つため、列は保持する。未評価セルを「未評価：実務閾値未設定」とし、全行未評価なら表上部に「実務閾値が未設定のため、この実行では実務領域・U-Gradeを評価していません」と一度案内する。全行未評価時は実務領域・U-Gradeフィルタを無効化し、理由を添える。混在時は評価済み行の既存フィルタを維持し、未評価を選択可能にする。

閾値を設定する場合は目的に応じて事前に決めること、割合尺度の `primary_delta = 0.05` は5パーセントポイントに相当する例であって既定推奨値ではないことをガイドで説明する。

背景色は評価済みの実務領域セルだけに付け、未評価は無彩色。効果量・方向・実務領域・精度の概念分離と既存の `NONE` のソート順を維持する。列の自動非表示は今回の範囲に含めない。

## 5. 具体的な検証マトリクス

| 入力例・境界 | 確認事項 | 期待結果 |
|---|---|---|
| RD=+0.03、−0.03、有限かつ同符号区間、Safety | E100と逆数の説明・方向ラベル | +3 / −3、約33.3人、NNH-like / NNT-likeの区別 |
| 同じ入力、非Safety | 過大解釈の防止 | 表は `1/|RD|`、因果的NNTを断定しない |
| 区間がゼロを含む・端点ゼロ、数値的ゼロ、非有限・符号不整合 | 既存の逆数状態契約 | 状態ごとの抑制が維持され、理由が解説に存在する |
| `primary_delta = NULL`、全行 `NONE / none` | 表・通知・フィルタ・CSV | 12列保持、未評価理由表示、フィルタ無効、canonical NONE保持、着色なし |
| 正の閾値でU0〜U3、評価済み／未評価混在の正本override | 行単位の評価状態・ソート・フィルタ | 評価済み値とセル配色維持、未評価だけ理由表示、空行や誤分類なし |
| 正本の欠落・矛盾 | 未設定との区別 | 明示的エラー、閾値未設定と誤表示しない |
| HTML・Markdownの指標ガイド | 独立項目、移動導線、キーボード操作 | 2指標を個別に見つけられ、ソート操作が維持される |
| 生成された全HTML | オフライン・再現性 | 外部アセットとOS絶対パス依存なし。表示改修前後で既存canonical数値が一致 |

承認後、対象回帰テストと関連するschema・テーマ契約を実行する。必要なRライブラリが不足したら停止し、自動インストールしない。ブラウザで全未評価／評価済み／混在の表示、フィルタ、ソート、ガイド導線を確認する。生成検証は隔離された新しい出力先で行い、既存runを上書きしない。

## 6. 承認後の実施順序

専用トピックブランチで開始時diffを確認し、データ契約→解説→未評価表示→回帰検証の順に実装する。終了時diffで変更範囲を固定する。静的検証、テスト実行、ブラウザ確認、独立QA、commit、pushは別々に報告する。独立QA・commit・pushは未実施として保持する。


## 7. 実施記録（2026-10-01 19:48 JST）

ユーザーの「実行して」により承認を受領し、`codex/reporting_metric_guides` ブランチで実装した。E100・逆数RDの個別ガイド、表見出しの解説リンク、未評価理由の搬送、全行未評価時の通知とネイティブフィルタ無効化、混在時の行単位状態と配色を追加した。見出しのリンクは白文字を継承し、暗色背景で読めることをブラウザで確認した。

### 検証結果

| 証拠区分 | 実施内容 | 結果 |
|---|---|---|
| 構文・差分 | R構文確認、`git diff --check` | 成功 |
| 回帰テスト | `test_comparative_dashboard_qa.R` / `test_vcd_categorical_reporting.R` / `test_comparative_schemas.R` / `test_dashboard_theme_contract.R` | 226 / 38 / 139 / 88件のアサーション成功、失敗0 |
| スキーマ照合の制約 | 外部Python `jsonschema` によるDraft-07照合 | ライブラリ未導入のため未検証。139件には明示的スキップ確認を含む。ローカル検証は成功し、自動インストールしていない |
| 仕様検証 | `openspec validate comparative-evidence-reporting --type spec --strict` | 成功。長い既存要件の情報メッセージのみ |
| 数値不変性 | 元runと新runの8件の `contrasts`、改修前後の既存要約40項目 | 完全一致。新規の表示状態・理由2項目を追加 |
| ブラウザ実行 | ローカルの導入済みChromeによる評価済み・全未評価・混在の確認 | 12列、解説展開、クリック／Enter／Spaceとソートの分離、未評価フィルタの9項目無効化、混在行選択と解除が成功 |
| CSV・オフライン | ブラウザ全件CSV、埋込データ、OSパス、実際のネットワーク要求 | 42列・8行、状態と理由が一致。JavaScriptエラー0、外部通信0、OS絶対パスなし |
| 実行成果物 | 新しいrunのmanifest照合 | 3種の最終プレビューすべて成功 |
| 独立QA・Owner判断・Git書き込み | 独立QA、完了承認、commit、push | 未実施 |

### 最終プレビュー

- [対象runと同じ数値の修正版](../../../evidence_runs/vcd_categorical_reporting/run_metric_guides_20_2/dashboard.html)
- [実務閾値が全行未設定の表示例](../../../evidence_runs/vcd_categorical_reporting/run_metric_guides_un_2/dashboard.html)
- [評価済みと未評価が混在する設計考慮型の合成例](../../../evidence_runs/vcd_categorical_reporting/run_metric_guides_mi_2/dashboard.html)

元runの要約CSVを入力来歴として、同じ群・件数・閾値・seedから数値一致を確認した。既存runは上書きしていない。検証途中の新規プレビューも保存している。テーマ契約テストが再生成した3つの既存fixtureは、開始時に差分がなかったことを確認したうえで、そのテストが作成した差分だけを復元した。

終了時の編集境界は、本計画書、生成Rコード、回帰テスト2本、数理正本、比較報告仕様の6ファイル。解析計算エンジン、既存run、依存関係に変更なし。
