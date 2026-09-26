## Context

動機と利用者向け変更は[proposal](proposal.md)、合意範囲と承認境界は[実装計画](../../../docs/Artifacts/implementation_plan_013_0912.md)、必須の振る舞いは3つのdelta specを正本とする。

mainとAntigravityには同名スキルの異なる主系があり、mainには旧Evidence Score中心の表示、AntigravityにはM1〜M9・因子凡例・最良モデル表示・UCB固定参照がある。別の `templates/three_way/` 経路は厳格な設定と文章根拠照合を持つが、静的UIと別結果契約である。二重正本を維持せず、Antigravity主系を基底に必要な契約を選択移植する。

現在のmain Worktreeにはユーザーの既存差分があり、ローカルmainは手元の `origin/main` 参照より4コミット遅れている。実装は最新リモート状態を確認した分離Worktreeで行う。既存OpenSpec change `validate-three-way-statistical-foundations` は34/35タスクで、EBIC原典監査が未完了である。本changeはその状態を変更しない。

## Goals / Non-Goals

**Goals:**

- 3次元カテゴリカル分析の計算・結果JSON・日本語考察・ダッシュボードを一つの正本経路にそろえる。
- モデル全体、基準別セル診断、条件付き割合、不確実性、旧監査指標を区別する。
- 別AIがタスク単位で実装し、監査担当がdelta specと証拠を独立照合できるようにする。
- UCB Admissionsを数値・UI受入fixtureとし、旧AG UIを不変参照として残す。

**Non-Goals:**

- 2変数分析、質問票バッチ、モバイル表示、非集計度数データへ今回の機能を展開しない。
- `renv`を導入せず、MathJax一式をvendorしない。
- `templates/three_way/`を削除または同時拡張しない。
- 現在のmain・Antigravity Worktree、既存出力、既存OpenSpec changeの未完了タスクを変更しない。
- 本changeの計画作成は、commit、mainへのmerge、pushを含まない。

## Decisions

### 1. Artifact計画・delta spec・tasksの責務を分ける

実装計画013はユーザーとの意思決定、範囲、承認境界の正本とする。delta specは外部から検証可能な振る舞い、designは実装方式と移行、tasksは担当・順序・完了証拠を管理する。内容が衝突する場合は、ユーザーが再承認した最新の実装計画に合わせてOpenSpec成果物を更新し、仕様変更を黙って実装しない。

別案の計画書だけによる管理は、実装者がテスト可能なシナリオへ分解しにくいため採用しない。既存changeへの追記は、数理基盤検証の残タスクとUI統合の完了を混同するため採用しない。

### 2. Antigravity主系を正本へ選択移植する

`templates/analysis.R`、`pass1_compute.R`、`dashboard.Rmd`を基底とし、mainの既存機能とファイル単位で統合する。`templates/three_way/`から、Pass 0設定境界、結果ハッシュ・JSON Pointerによる文章根拠照合、オフライン出力方針だけを移す。ディレクトリ全体の上書き、branch merge、rebaseは行わない。

`templates/three_way/`は互換性維持のみの非正本経路と明記する。削除は利用状況を確認する別changeにする。

### 3. 結果JSONを基準モデル別にする

新規結果は `cells.by_base_model.<model_id>` に、問い、基準モデル、4軸値、件数、分母、全セルを保持する。UCBの必須基準はM1とBIC最良モデルM5である。設定は `base_models` 配列として検証し、未知ID・重複・未推定モデルを暗黙にM1へ置き換えない。

旧単一 `cells` 構造は新規出力しない。表示側は識別可能な旧schemaだけを限定的に読み、基準が不明な旧値を新指標へ変換しない。

### 4. ポアソン明示式BICを唯一の画面基準にする

各モデルについて、Poisson GLMの完全対数尤度、切片を含むrank、総度数Nから `-2 log L + p log N` を再構成する。固定総度数の多項BICは監査用JSON・数理説明に限定する。同じデータ内で順位とΔBICが一致しても、絶対値を同じ列へ混ぜない。

最良モデル表示は候補集合内の相対評価とする。UCBではM5とM8の固定参照値を回帰試験に使うが、条件付き独立の真理・公平性・因果を結論にしない。

### 5. 条件付き割合をPass 0設定駆動にする

`conditional_rate_view` は、応答、分子水準、分母水準、比較変数、層別変数、区間水準、必要な参照水準を持つ。分子は分母の部分集合とし、役割の重複と暗黙の応答末尾選択を禁止する。

計算結果は設定の写し、観測分子・分母、生割合、Dirichlet事後平均、ETI、比較差、状態を保存する。不足または不適用はこの機能だけを部分HOLDにし、独立して成立するモデル比較とセル診断を止めない。

### 6. Pass 2文章を計算結果へ結び付ける

本番HTMLには `executive_summary.md`、`quality_check.md`、`narrative_claims.json`を要求する。claimsは対象結果JSONのSHA-256と、文章で使う各数値のJSON Pointer・値を持つ。レンダラーは一致を確認し、不一致時は非ゼロ終了する。preview用stubは本番の代替証拠にしない。

### 7. 完全オフラインの単一HTMLにする

R Markdownは `self_contained` を維持し、数式は `r-katex`で生成時にHTML化する。DataTables本体のJavaScript/CSSはHTMLへ埋め込み、日本語文言はテンプレートの `language` オブジェクトへ直接記述する。外部MathJax、CDNロケール、Ajax、フォント取得を残さない。

MacTeXはHTML閲覧時の数式レンダラーではないため使用しない。KaTeX関連パッケージは自動インストールせず、README、第三者通知、標準manifestへ実使用版を記録する。`renv`導入は別変更とする。

### 8. デスクトップUIと参照fixtureを固定する

読解順序は、因子凡例、平易な要約と相対最良モデル、件数、条件付き割合、M1〜M9、M1/M5診断、ベイズ推論、旧監査・品質・再現情報とする。モデル表はBIC昇順で開始し、意味のある全列をソート可能にする。基準別件数は同時表示し、詳細はタブで切り替える。条件付き割合は静的な点・区間図と数値表にする。

最良モデル表示はコンパクト要約帯と抑制した独立カードを同じ内容で生成し、デスクトップのスクリーンショットをユーザーが比較して1案を選ぶ。モバイル用調整は行わない。

旧AG UIと新UCB標準は `tests/fixtures/dashboard_ui/` にmanifest付きで保存する。生入力を重複せず、絶対パス・機微情報・生成ログを除く。実使用依存版と成果物SHAを残す。

### 9. 実装者・監査者・Ownerの役割を分離する

実装担当AIはtasksの実装項目と直接テストを実行し、変更ファイル、コマンド、結果、未検証を報告する。チェックボックスはコードの存在だけで完了にせず、記載した証拠がそろった項目だけ更新する。

監査担当Codexはdelta specの全Scenario、数理固定値、設定拒否・HOLD、文章改ざん検知、ブラウザ操作、オフライン通信、パス漏えい、差分境界を独立に確認する。`openspec status`のdone、`valid: true`、実装者のチェックだけを実行完了の証拠にしない。

Ownerは最良モデル表示のデザイン選択、範囲変更、main統合、commit、pushを判断する。監査担当はOwner判断を代行しない。

## Risks / Trade-offs

- [二つの既存経路からの選択移植で意味が混ざる] → ファイル単位の差分台帳を作り、各出力フィールドをspecと固定fixtureへ対応づける。
- [新JSONが旧利用者を壊す] → BREAKINGとして版を上げ、表示側の限定互換と移行説明を設け、基準不明値は変換しない。
- [最良モデルを真のモデルと誤読する] → 比較候補、次点差、推定状態、非因果・相対評価を同じ表示単位に置く。
- [Dual-Filter件数が重要性判定に見える] → 「探索候補」と命名し、基準モデル・分母・多重性・実務判断の限界を常時表示する。
- [KaTeXが一部TeX記法を処理できない] → 全数式の生成試験とオフラインブラウザ確認を受入条件にし、外部資産が残る場合は合格にしない。
- [汎用条件付き割合が高水準数で読みにくい] → Pass 0で比較・層別の意味を限定し、意味を確定できない場合は部分HOLDにする。
- [大きなHTML fixtureがGitを増量する] → 標準2例だけを保存し、生入力・重複資産・rawログを除き、manifestで再生成可能にする。
- [現在のdirty mainと計画成果物を失う] → 実装前に名前付きパスの差分とハッシュを保存し、分離WorktreeへOpenSpec changeと実装計画を明示的に移す。

## Migration Plan

1. 明示的な実装承認後、リモート・Worktree・既存差分を確認し、最新 `origin/main` から `codex/dashboard-unification` を分離する。
2. 本changeと実装計画013を名前付きパスで分離Worktreeへ移し、元checkoutと内容・ハッシュを照合する。
3. 旧AG UI fixtureを先に保全し、Antigravity主系を対象ファイル・テスト単位で移植する。
4. UCBのPass 0を実行し、合意した設定を `analysis_config.json`へ固定してからPass 1を実行する。
5. 計算・schema・文章ゲート・UI・オフライン化を段階的に実装し、各段階で対象テストとdiffを確認する。
6. UCBのPass 1〜3、固定数値、HOLD、ブラウザ、通信、パス、fixtureを検証する。
7. 2つの最良モデル表示案をOwnerへ提示し、選択した1案だけを新標準fixtureへ固定する。
8. 監査担当が全Scenarioと証拠を照合し、未検証または不合格を残したまま完了扱いにしない。
9. commit、mainへのmerge、pushはOwnerの別指示まで行わない。

ロールバックは分離Worktree内で今回追加した変更だけを名前付きパス・編集ラウンド単位で戻す。現在のmain、Antigravity、旧AG fixture、ユーザーの既存差分を復元対象に含めない。
