# AG版・M版ダッシュボードの統合改善計画

created: 2026-09-12 02:02 (JST)
update: 2026-09-12 04:24 (JST)
author: Codex (GPT-6 / GPT-5)

## 状態と承認境界

設計インタビューの第1〜第8ラウンドで、Q1〜Q28の推奨事項についてユーザーの合意を得て、最終共同理解も確定した。確認用データは `ucb_admissions.csv`、主対象は3次元ダッシュボードとする。実装全体はOpenSpec change `standardize-three-way-dashboard` で管理する。計画資産は作成済みだが、コード変更、依存追加、Pass 0成果物の作成、Pass 1以降の解析実行、参照版のコピー保存、Worktree・ブランチ作成、commit、mainへの統合、pushはまだ承認されていない。

## OpenSpecによる全体管理

- OpenSpec changeは [`standardize-three-way-dashboard`](../../openspec/changes/standardize-three-way-dashboard/proposal.md) とする。`openspec-ff-change` によりproposal、3つのdelta-spec、design、tasksを作成し、strict validationを通過した状態から実装へ引き渡す。
- 本計画書は合意の経緯、比較対象、統計的判断、承認境界の上位記録とする。delta-specは外部から観測できる必須動作、designは実装境界と判断理由、tasksは担当、作業順、検証証拠を管理する。
- delta-specは `three-way-dashboard-reporting`、`multi-baseline-cell-diagnostics`、`conditional-rate-view` の3能力に分ける。UCB固有の数値参照と、他の妥当な3変数カテゴリカル集計度数表へ適用する汎用契約を同じchange内で追跡する。
- 別AIを実装担当、Codexを独立監査担当、ユーザーをOwnerとする。実装担当は変更ファイル、実行コマンド、終了コード、主要件数、成果物ハッシュ、未検証事項を報告する。Codexは全Scenarioをコード、テスト、実行結果、画面証跡へ対応付け、数理、HOLD、完全オフライン、差分境界を独立に再確認する。
- `openspec status` の完了表示と `valid: true` は計画ファイルの存在とdelta-specの構文整合を示す。実装完了、統計的正しさ、画面受入、commit、merge、pushの証拠としては扱わない。
- 既存change `validate-three-way-statistical-foundations` は、EBICの一次資料照合タスク4.2が未完了のため変更しない。本件のダッシュボード製品化を別changeに分離し、既存の数理基盤changeを誤って完了扱いしない。

## 目的と比較対象

AG版の凡例・結論表示・モデル比較と、M版のセル集計・監査表示の良さを3次元ダッシュボードへ取り入れ、評価指標の定義と説明を整合させる。確認用データには [`examples/ucb_admissions.csv`](../../examples/ucb_admissions.csv) を使用する。

- UI要素のAG版参照元：[OTC_Q05参照HTML](/Users/myamaguchi/Programing/00TotalRWD/agentic-evidence-analysis-antigravity/output/OTC_Q05/10_bayesian/run_otc_q05_brand_sy/dashboard.html)
- UI要素のM版参照元：[OTC_Q05参照HTML](../../output/OTC_Q05/10_bayesian/run_otc_q05_brand_sy/dashboard.html)
- 3次元確認用データ：[`examples/ucb_admissions.csv`](../../examples/ucb_admissions.csv)

## 第1ラウンドの合意事項と変更記録

1. 当初案では共通テンプレートを改善し、OTC_Q05を比較・確認用の題材として、3変数を対象、2変数と質問票バッチ全体を対象外とする推奨に合意を得た。
2. 統計の専門家ではない共同研究者も読者に含める。入口では変数間の関係と解釈できる範囲を伝え、数式・モデル比較・診断の根拠をたどれる構成とする。
3. AG版は現在のHTMLだけでなく、生成テンプレート、入力JSON、生成条件をひも付けた再現可能な参照版として保存する。ブランチ名のみを保存根拠にしない。
4. 変数定義と因子記号の対応凡例は必須とする。
5. 調査によりOTC_Q05の両HTMLは2変数分析と判明したため、ユーザー指定により確認用データを `ucb_admissions.csv` に変更した。3変数のM1〜M9、セル診断、ベイズ推論を確認できるダッシュボードを主対象とする。OTC_Q05の両HTMLは採用したいUI要素を確認する参照資料として残す。
6. 2変数ダッシュボードへの実装展開は今回の主対象から外す。3変数で合意・検証した共通表示方針を将来2変数へ展開できるよう、適用可能な要素と次元固有の要素を計画上で区別する。

## 第2ラウンドの合意事項

1. UCB Admissionsの正本となる変数対応は `A=Dept`、`B=Gender`、`C=Admit` とし、応答変数は `Admit` とする。既存の固定参照設定、結果JSON、モデル辞書と一致させる。
2. モデル選択の内容として、モデル番号、日本語の意味、比較した候補集合、明示式BIC、次点との差、推定状態を一組で示す。UCBでは「M5：Deptで層別するとGenderとAdmitは条件付き独立」と「比較した9モデルのうち明示式BICが最小」を併記する。
3. 前項の情報を利用者が早い段階で確認できるようにする一方、「大きく表示する」こと自体は固定要件にしない。カードの大きさ、色、配置、強調度は好みが分かれるため、情報階層と可読性を守った複数案を比較し、過度な強調を避けて決める。
4. M版の分母付き件数・率という表示形式を継承する。主表示は、評価対象セル、安定セル、隔離セル、探索候補セルとする。探索候補セルは大標本Dual-Filterを満たす探索用の件数であり、実務的重要性やセル合否の自動認定には使用しない。
5. 旧Evidence Scoreの正値セル数・率は「旧Evidence Score正値セル数・率（監査用）」と明記して詳細または折りたたみ領域へ残す。Rao scoreによるEvidence、セルBF、重要性とは明確に区別する。
6. OTC_Q05の現AG版は、HTML、設定、結果JSON、run情報、ソースリビジョンをひも付けた旧AG UI参照版として保全する。改善後に検証したUCB Admissions版は、3次元ダッシュボードの新しい標準参照版として保存する。
7. エグゼクティブサマリーは、非専門家向けの「今回分かったこと」、分析者向けの「統計的根拠」、「解釈上の限界と次の確認」の3層構造とする。第1層でもDeptによる層別を省略せず、因果関係や性差の不存在へ飛躍しない。
8. M1〜M9のモデル比較表はBIC昇順を初期表示とし、利用者がモデル名、生成クラス、残差自由度、逸脱度、BIC、ΔBICを列見出しから並べ替えられる対話表とする。既存のDataTables機能で実現でき、数値列は数値として並べ替える。モデル名と仮定を含むHTML列は、必要に応じて安定したソートキーを別に持たせる。
9. 画面は、分析対象と因子凡例、平易な要約と相対的な最良モデル、セルの評価状態と探索候補件数、Dept内の条件付き合格割合、M1〜M9のモデル比較、基準別セル診断、ベイズ事後推論と事前感度、旧指標監査・品質確認・限界・再現情報の順に構成する。

## 第3ラウンドの合意事項

1. セル診断はM1基準とM5基準を別セクションで併記する。M1は3因子の相互独立からの乖離、M5はDeptによる構成差を考慮した後に残る局所的不適合を表す。「M1基準の探索候補」と「M5基準の残余探索候補」を分離し、基準モデル名と分母を常に表示する。
2. 条件付き割合の主表示は、各 `Dept × Gender` 群を分母とする合格割合 `P(Admitted | Dept, Gender)` とする。各Dept内のFemaleとMaleの合格割合および割合差を示し、全学部合算の男女差は参考値として区別する。分母の定義を表とグラフの直上に明記する。
3. 新しい標準ダッシュボードは、インターネット接続なしでも数式、表、展開、並べ替えを利用できる完全オフラインHTMLとする。第三者資産の正本、生成時の埋め込み、ライセンス記録の具体的な方式は、既存構成の調査に基づいて本計画へ固定する。
4. 外部資産は「リポジトリ内に再生成情報、完成HTML内に閲覧用資産」を持つ。MathJax一式をリポジトリへ複製せず、生成時にKaTeXで数式をHTML化する。DataTables本体のJavaScript/CSSは `self_contained` 出力へ埋め込み、日本語文言は外部 `ja.json` を使わずテンプレート内の `language` 設定へ直接記述する。
5. 再生成に必要な依存名はルートREADMEへ追記し、第三者ライブラリの名称、使用版、ライセンス、用途を `.agents/skills/vcd-bayesian-evidence-analysis/THIRD_PARTY_NOTICES.md` に記録する。標準参照runにはR、Pandoc、rmarkdown、DT、htmlwidgets、KaTeX関連パッケージの実使用版と生成HTMLのSHA-256を保存する。

## 第4ラウンドの合意事項

1. 旧AG UI参照版と改善後UCB標準版は、ソース管理されるUI受入フィクスチャとして `tests/fixtures/dashboard_ui/` に保存する。
2. `antigravity_otc_q05_v1/` にはHTML、解析設定、結果JSON、manifestを保存する。`ucb_admissions_three_way_v1/` にはこれらに加えてエグゼクティブサマリーと品質確認を保存する。
3. 各manifestには入力SHA-256、ソースコミット、生成日時、生成コマンド、依存バージョン、成果物SHA-256を記録する。生の入力データは重複保存せず、リポジトリ内の入力パスとハッシュを参照する。
4. 最良モデル表示は、同じ内容によるコンパクトな横長要約帯と、強調を抑えた独立カードの2案をUCBで描画し、スクリーンショット比較後に標準を1案へ確定する。違いは余白、文字サイズ、色、配置に限定し、統計的内容は共通とする。

## 第5ラウンドの合意事項

1. Antigravity主系の `analysis.R`、`pass1_compute.R`、`dashboard.Rmd` をmain側の唯一の正本生成経路とする。M1/M5二基準診断、Pass 0設定境界、`narrative_claims.json`による数値根拠照合、完全オフライン化、現行4軸に整合した分母付きセル件数・率を追加する。
2. `templates/three_way/` は完成経路として並行拡張せず、設定契約、文章根拠照合、オフライン方針の移植元として扱う。移植後の扱いは次ラウンドで決める。
3. 実装と検証は、現在のmain Worktreeにあるユーザー差分を避け、新しい分離Worktreeの `codex/dashboard-unification` ブランチで行う。完成後に差分、UCBダッシュボード、テスト、UI比較を確認する。mainへのmerge、commit、pushは別の承認境界とする。
4. 今回はリポジトリ全体への `renv` 導入を行わない。KaTeX関連を明示依存とし、テンプレートによる自動インストールは行わず、不足時は明確なエラーにする。実使用版、ライセンス、生成HTMLのSHA-256を標準参照runへ記録する。

## 第6ラウンドの合意事項

1. `templates/three_way/` は今回削除せず、「互換性維持のみ・新規開発停止」の非正本経路として明示する。既存出力の再現可能性を保持し、削除は利用状況を調べる別計画で判断する。
2. 新しい結果JSONは、セル診断を `cells.by_base_model.M1` と `cells.by_base_model.M5` のように基準モデル別に分ける。各要素に問い、評価可能・安定・隔離・探索候補の件数と分母、全セル値を保持する。未知のモデルIDをM1へ黙って戻す処理を廃止し、許容されない指定は明示エラーにする。旧JSONの読込互換は表示側へ限定し、新規出力形式は一本化する。
3. UCBの総度数4,526・24セル、M1〜M9、M5とM8のBIC、M1/M5別セル診断、条件付き割合の分母、サマリー数値根拠、モデル表の初期順と列ソート、完全オフライン、AG旧版の不変性を独立して検証する。
4. レイアウト検証とスクリーンショット比較はデスクトップ幅のみを対象とする。モバイルでの利用、モバイル向けCSS調整、モバイル幅スクリーンショット、モバイル操作テストは今回の対象外とする。

## 第7ラウンドの合意事項

1. ダッシュボードのBIC主表示は、ポアソンGLMの完全対数尤度、切片を含むパラメータ数 `p`、総度数 `N` による明示式 `-2 log L + p log N` に統一する。式と各項の意味を表の上に表示する。固定総度数の多項BICは同じ表へ併記せず、結果JSONの監査情報と数理リファレンスに定義上の関係を残す。
2. M1/M5基準のセル診断は、両基準の件数要約を同時表示し、詳細表とヒートマップをタブで切り替える。初期タブはM1とし、M5は「選択モデルからの残余乖離」と表示する。各タブの冒頭に問い、基準モデル、分母を記載する。
3. 条件付き割合は点・95%事後信用区間の静的プロットと数値表を併用する。UCBでは各Dept内のFemale・Maleについて、分子、分母、生割合、事後平均、信用区間を表示する。全学部合算値は参考表示として区別する。この可視化を他データへ適用するための設定契約は追加調査後に確定する。
4. 実装承認後の最初にリモート状態を確認し、その時点の最新 `origin/main` とAntigravity成果の差分台帳を作る。その後 `codex/dashboard-unification` の分離Worktreeを作成する。現在のmain Worktreeとユーザー差分を保持し、mainへのmerge・commit・pushは別承認とする。

## 第8ラウンドの合意事項

1. 条件付き割合の可視化はUCB専用にせず、3変数カテゴリカル集計度数表で再利用できる設定駆動機能とする。`analysis_config.json` の `conditional_rate_view` に `response_var`、`numerator_levels`、`denominator_levels`、`compare_by`、`stratify_by`、`interval_level`、必要に応じて `reference_level` を明示する。
2. 結果JSONには表示設定の写しと、各点の分子度数、分母度数、生割合、事後平均、信用区間、推定状態を保存する。見出し、軸名、凡例、分母説明は設定された変数名・水準から生成し、UCB固有語をテンプレートへ埋め込まない。
3. 応答・比較・層別の列または水準がない、分子が分母の部分集合でない、役割が重複する、必要な分子・分母または参照水準が未指定、分母度数がゼロ、Pass 0で意味が合意されていない場合は、条件付き割合の計算と図だけを部分HOLDにする。理由をJSONとダッシュボードへ表示し、応答水準の末尾などを暗黙に選ばない。
4. 適用範囲は、Pass 0で意味のある分子・分母・比較・層別を定義できる3変数カテゴリカル集計度数表とする。二値応答に限定せず、複数の分子水準を許容する。連続値、割合のみ、個人内反復、重み付き標本、複数回答などは自動流用せず、別の推定モデルと可視化をPass 0で相談する。

## 設計判断の状態

現時点で、実装範囲を変える未決の設計判断はない。実装中に取得する証拠に基づく次の確認を残す。

- 実装開始時の最新 `origin/main` とAntigravityの正確な先頭SHA・差分台帳。
- Pass 0で作成するUCB用 `analysis_config.json` と、合意済み表示契約の一致。
- M5基準で再計算した探索候補・HOLD件数。既存fixtureにないため事前に数値を断定しない。
- KaTeXで現在の全数式を単一HTMLへ埋め込めること。外部資産が残れば受入不合格とする。
- コンパクト要約帯と抑制した独立カードのデスクトップ比較。統計内容を変えず、ユーザーが標準を1案選ぶ。

## 変更対象

### 3次元分析と結果契約

- `.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`：Antigravity主系のM1〜M9、因子辞書、ポアソン明示式BICを基底にし、M1/M5複数基準のセル診断を結果JSONへ保存する。
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R`：4軸セル診断を基準モデル別に計算し、`conditional_rate_view` に基づくDirichlet事後割合・差・ETI・分子・分母・状態を出力する。
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R` と `references/analysis_config.schema.json`：`base_models` と `conditional_rate_view` の型、列、水準、役割、分子と分母、参照水準を検証し、暗黙のfallbackを禁止する。
- `.agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R`：Pass 2成果物を確認し、`narrative_claims.json` の結果SHA-256とJSON Pointer・数値を照合してから本番HTMLを生成する。

### ダッシュボード

- `.agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd`：因子凡例、相対的な最良モデル、BIC順・列ソート可能なM1〜M9表、分母付き件数、M1/M5タブ、汎用条件付き割合図・表、3層サマリー、旧指標監査、品質・再現情報を合意順に配置する。
- MathJax CDNを `r-katex` に置換し、DataTablesの日本語辞書をテンプレート内へ置く。外部CDN、Ajax、フォント取得を閲覧時に行わない。
- `.agents/skills/vcd-bayesian-evidence-analysis/THIRD_PARTY_NOTICES.md` を追加し、第三者資産の版、用途、ライセンスを記録する。ルートREADMEへ必要依存を追記する。

### Pass 0・文書契約

- `.agents/skills/vcd-pass0-consultation/SKILL.md`：応答、分子、分母、比較、層別、基準モデル、HOLDを対話合意事項とし、正本実行経路を主系へ合わせる。
- `.agents/shared/analysis_quality_contract.md`：正本経路、条件付き割合の根拠、部分HOLD、Pass 2.5照合を最小範囲で追記する。
- `.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md`、`Reference.md`、`references/three_way_contract.md`、`references/legacy_usage.md`：正本経路、BIC定義、M1/M5の意味、旧Evidence Scoreの監査限定、完全オフライン、非正本経路の位置づけを同期する。
- `templates/three_way/` は削除・大規模変更せず、互換性維持のみの非正本経路である旨を記載する。

### テストと参照版

- AntigravityのM1〜M9、UCB数値不変性、設定検証、UI・fallbackテストをmainへ選択移植し、既存mainテストは置換せず新契約へ更新する。
- M1/M5別の基準・分母・件数、二値・多水準・HOLDの条件付き割合、文章claim照合の成功・失敗、ポアソン明示式BIC、表ソート、外部資産不在を回帰テストへ追加する。
- `tests/fixtures/dashboard_ui/antigravity_otc_q05_v1/` と `ucb_admissions_three_way_v1/` に合意済み成果物とmanifestを保存する。絶対パスと機微情報を検査し、生入力は重複保存しない。

## 現状調査で確認した注意点

- 指定された両版は入力ハッシュが一致し、いずれも `Brand × Symptom` の2元表、総度数1,776、200セル。3変数分析の出力ではない。
- M版はEBICで独立対飽和を比較し、AG版は総度数Nの明示式BICでM1（独立）対M2（飽和）を比較する。AG版のM1/M2は3変数のM1〜M9とは異なる候補集合。
- M版の正値セル数は `Evidence_Score > 0` の件数で現物は0/200（0%）。AG版のRao scoreとは異なる指標である。
- 大標本設定もM版は閾値1,000で有効、AG版は無効となっている。入力が同じでも評価設定は一致していない。
- 読み取り専用調査の結果、`ucb_admissions.csv` は `Admit`、`Gender`、`Dept` と度数列 `Freq` を持つ。`Dept` 6水準、`Gender` 2水準、`Admit` 2水準の完全な24セル表で、欠損行・度数ゼロのセルはなく、総度数は4,526。
- 両Worktreeの現在の出力ツリーにUCBの再生成済みHTMLはない。Antigravity側にはUCB用の固定参照設定と結果JSONがあり、変数順は `A=Dept`、`B=Gender`、`C=Admit`、応答変数は `Admit`、基準モデルはM1、大標本閾値は2,000。
- 固定参照JSONでは9モデルを比較し、明示式BICの最小はM5（`cond_indep_BC_given_A`、BIC 332.3119）、次点はM8（BIC 339.1982）。この変数順のM5は、Deptで層別したときGenderとAdmitが条件付き独立であるモデル。
- 固定参照JSONの24セルはすべてREGULAR。既存のM1基準値を現行の大標本Dual-Filter条件へ機械的に照合すると、効果量条件は12セル、Rao score条件は20セル、両条件は12セル。M1基準の探索候補件数として表示するが、実務的重要性の自動判定には使用しない。M5基準件数は実装後に別途計算する。
- AG版のUI参照はOTC_Q05のHTML・設定・結果JSON・run情報をひも付けて保全し、UCBの固定参照設定・結果JSONを3次元の数値参照として扱う。実装後のUCBダッシュボードを新しい3次元UI標準として保存する。
- ローカルmainは `5ca4563`。ローカルにある追跡参照に対して4コミット遅れている表示。リモートの最新状態は未取得。
- AG側の現在のブランチ名は `Antigravity`、先頭は `4186a05`。現在の先頭が指定HTMLの生成時点とは限らない。
- mainには `dashboard.Rmd` と `three_way/render_report.R` という異なる生成経路がある。
- mainの数理リファレンス入口はポアソン尤度による明示式BICを記載する一方、`three_way/render_report.R` は固定総度数の多項BICを表示する。どの経路を統合対象とするか、指定HTMLと結果JSONの調査に基づいて決める。
- 主テンプレートの `analysis.R` は設定されたM1〜M9をセル診断の基準モデルとして計算でき、JSONと `dashboard.Rmd` も基準モデルIDを表示できる。ただし設定検証は未知のIDをエラーにせずM1へ戻し、CLI説明も選択肢をM1またはM8と記載しているため、実装・検証・説明が不整合。
- 別経路の `three_way/analysis.R` はM1・M7・M8の3基準を常時生成し、M5基準は生成しない。採用する3次元正本経路と必要な統合範囲を計画で固定する。
- M1基準のセル診断は相互独立からの乖離、M5基準はM5が許すDept×GenderおよびDept×Admitを差し引いた後の局所的不適合を表す。基準仮説が異なるため、両者の件数・率を同じ「エビデンス率」として混合しない。
- M1〜M9比較表は既にDataTablesで生成されているが、現在は `ordering=FALSE` により列ソートが無効。`ordering=TRUE` と初期BIC昇順を指定すれば、既存構造のままモデル名・逸脱度・BICなどを並べ替えられる。
- `self_contained: true` により主要なJS/CSSはHTMLへ埋め込まれる一方、MathJaxと全セル診断表の日本語化ファイルには外部CDN URLが残る。列ソートの有効化は新しい通信依存を増やさない。完全オフラインを受入条件とするため、この2つの外部参照を除去する。
- 標準R Markdownの `mathjax: local` はMathJax資産をHTML隣接ディレクトリへコピーする方式で、単一HTMLにはならない。MathJax資産は約8MBであるため、リポジトリへの複製と独自インライン化は採用しない。
- 単一HTMLでは、R Markdownの `r-katex` により数式を生成時にHTML化し、必要なCSS等を自己完結出力へ含める方式を採用する。現環境にはKaTeX用Rパッケージが未導入のため、これは計画対象の依存追加であり、実装承認後に導入・互換性確認を行う。
- DataTablesの日本語化は外部ロケールJSONを保存せず、日本語の検索、件数、ページ移動、該当なし等の文言をテンプレートのオプションへ直接定義する。
- このMacにはMacTeXのTeX Live 2026とpdfTeXが導入済み。ただしMacTeXはTeX原稿から主にPDF等を生成するローカル組版環境であり、HTMLを開いたブラウザ内の数式表示機能を提供しない。R Markdown 2.31の `r-katex` はKaTeX用Rパッケージを使って生成時に数式をHTML化し、閲覧時の数式JavaScriptを不要にするため、今回の単一HTML要件にはMacTeXより適合する。
- main主系とAntigravity主系には実装量と検証範囲に大きな差がある。Antigravity主系には因子凡例、M1〜M9比較、最良モデル表示、UCB固定参照、関連するUI・数値テストがそろう。
- `templates/three_way/` 経路は、厳格なPass 0設定、`narrative_claims.json` による結果ハッシュ・数値根拠照合、外部URLのない静的HTMLを持つ。一方、セル診断はM1・M7・M8固定でM5がなく、対話的なモデル表と今回のAG UIからは距離がある。
- 今回の基底はAntigravity主系の `analysis.R`、`pass1_compute.R`、`dashboard.Rmd` とする。`templates/three_way/` から設定境界、文章根拠照合、オフライン方針を選択的に移す。
- Antigravity主系の明示式BICは、ポアソンGLMの完全対数尤度、切片を含むパラメータ数 `p`、総度数 `N` を用いる `-2 log L + p log N`。UCB固定参照ではM5の `log L=-90.397599...`、`p=18`、BIC 332.311887...、M9の `log L=-79.529845...`、`p=24`、BIC 361.081943...であり、9モデル全ての数値回帰テストがある。
- `templates/three_way/` の固定総度数・多項尤度BICは、同じデータ内ではポアソン明示式BICとモデル共通の定数だけ異なる。このため順位とΔBICは一致するが絶対値は異なる。両定義を一つの比較表へ混在させず、表示基準を確定する。
- 現行AG主系の条件付き事後計算は `response_var` の因子水準の最後を注目水準として暗黙に選ぶ。UCBでは `Rejected` が選ばれるため、合意した `Admitted` の表示と一致しない。また、残りの変数をすべて層として全ペア比較し、比較軸・参照水準を設定できない。
- 現行結果JSONは条件付き割合の観測分子・分母、分母水準、表示設定、HOLD理由を十分に保存せず、AG `dashboard.Rmd` に汎用的な点・区間プロットもない。Q24を他データへ適用するには、Pass 0で表示契約を明示し、計算・JSON・表示を設定駆動で追加する必要がある。
- 作業開始時から `.gitignore` の変更、追跡済みTitanic出力の削除、未追跡の計画書012と `examples/OTC_Q05_tidy.csv` が存在する。今回の変更と区別し、保持する。

## 実施段階

1. 本計画への明示的な実装承認後、リモートと全Worktreeのブランチ、HEAD、追跡先、既存差分を再確認し、最新 `origin/main` とAntigravity成果の差分台帳を作る。
2. 最新 `origin/main` を基点とする `codex/dashboard-unification` の分離Worktreeを作り、開始時の `git diff` を固定する。現在のmain WorktreeとAntigravity Worktreeは変更しない。
3. OTC_Q05 AG版を旧UI参照fixtureとして保全し、ソースSHA、入力SHA、依存版、成果物SHAをmanifestへ記録する。絶対パス・機微情報・不要な生成ログを含めない。
4. UCB AdmissionsについてPass 0を実行し、`A=Dept`、`B=Gender`、`C=Admit`、応答 `Admit`、分子 `Admitted`、分母2水準、比較 `Gender`、層別 `Dept`、基準M1/M5を記録した `analysis_config.json` を確定する。Pass 0完了前にPass 1を実行しない。
5. Antigravity主系から対象ファイルとテストを選択移植し、main・Antigravity・`templates/three_way/` の変更を機械的に一括マージしない。既存main機能との競合をファイル単位で解消する。
6. 設定検証、M1/M5別セル診断、汎用条件付き割合、結果JSON、旧指標監査、Pass 2文章根拠照合を実装する。統計計算、表示、説明が同じ設定・結果を参照することを確認する。
7. ダッシュボードを合意した読解順序へ更新し、BIC列ソート、基準別タブ、静的点区間図、KaTeX、DataTables日本語辞書、再現情報を実装する。
8. UCBでPass 1〜3を新しいrunへ実行し、既存のAG版・M版・固定fixtureを上書きしない。コンパクト要約帯と独立カードの2案をデスクトップ幅で提示し、ユーザーが選んだ1案へ固定する。
9. 数値回帰、HOLD、claim改ざん検知、ソート操作、ネットワーク遮断、外部資産、デスクトップ表示、パス漏えい、fixture不変性を検証する。各編集ラウンドの終了時に `git diff` で今回の変更境界を確認する。
10. UCB標準参照fixtureとmanifestを作成し、変更ファイル、試験結果、未検証事項、既存差分との境界を報告する。commit、mainへのmerge、pushは実施しない。

## 完了条件

- 因子凡例からモデル・セル診断まで、一貫した変数名と定義を使用している。
- 選択モデル、モデル比較、セル集計、サマリーが同じ結果JSONと解析条件に基づく。
- 3変数のM1〜M9について、モデル番号、生成クラス、日本語の意味、BIC、推定状態を対応づけて確認できる。
- ポアソン明示式BICを唯一の主表示とし、UCBでM5=332.3119、M8=339.1982、最良M5を許容誤差内で再現する。
- M1基準とM5基準のEffect・Evidence・Influence・Stability、件数、分母、問いを別々に検証できる。
- 旧Evidence Score監査と新しい診断の意味、分母、保留状態を区別でき、旧指標が判断ロジックに使われていない。
- `conditional_rate_view` が二値・多水準の設定を検証し、UCBでは `P(Admitted | Dept, Gender)` の分子・分母・事後平均・95%区間を生成する。不足時は理由付き部分HOLDとなる。
- 非専門家向け説明から専門的根拠へ移動でき、数値の出典を検証できる。
- `narrative_claims.json` の結果SHAと数値pointerが一致する場合だけ本番サマリーを統合し、不一致を検出する。
- モデル比較表はBIC昇順で開始し、モデル名、生成クラス、残差自由度、逸脱度、BIC、ΔBICを正しくソートできる。
- デスクトップ幅で数式、表、タブ、折りたたみ、ソート、点区間図を利用でき、閲覧時の外部script・CSS・Ajax・フォント取得がない。
- AG旧UI参照版とUCB新標準版の保存内容、依存版、SHA-256、再現確認結果が記録される。
- 既存ユーザー差分、既存出力、2変数機能、非正本経路に意図しない変更がなく、合意範囲の試験結果と未検証事項が明記される。

## 対象外

今回の計画では、2変数ダッシュボードと質問票バッチへの機能展開、モバイル対応、連続値・割合のみ・反復測定・重み付き標本・複数回答への自動適用、`renv`導入、MathJax一式のvendor化、`.cursor/skills`作成、`templates/three_way/`削除・大規模改修、無関係なブランチ整理・削除、全ブランチの一括マージ、既存出力の上書き、commit、mainへのmerge、pushを行わない。
